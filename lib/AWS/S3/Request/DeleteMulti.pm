
package AWS::S3::Request::DeleteMulti;

use Moose;
use AWS::S3::Signer;
use AWS::S3::ResponseParser;

extends 'AWS::S3::Request';

has 'bucket' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has 'keys' => (
    is       => 'ro',
    isa      => 'ArrayRef[Str]',
    required => 1,
);

sub request {
    my $s = shift;

    my $objects = join "\n", map { "<Object><Key>@{[ $_ ]}</Key></Object>" } @{ $s->keys };

    my $xml = <<"XML";
<?xml version="1.0" encoding="UTF-8"?>
<Delete>
$objects
</Delete>
XML

    my $signer = AWS::S3::Signer->new(
        s3           => $s->s3,
        method       => 'POST',
        uri          => $s->protocol . '://' . $s->bucket . '.s3.amazonaws.com/?delete',
        content      => \$xml,
        content_type => '',
    );

    $s->_send_request(
        $signer->method => $signer->uri => {
            Authorization => $signer->auth_header,
            Date          => $signer->date,
            'content-md5' => $signer->content_md5,
        },
        $xml
    );
}    # end request()

sub parse_response {
    my ( $s, $res ) = @_;

    AWS::S3::ResponseParser->new(
        response       => $res,
        expect_nothing => 0,
        type           => $s->type,
    );
}    # end http_request()

1;   # return true:

