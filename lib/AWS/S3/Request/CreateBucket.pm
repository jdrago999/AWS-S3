
package AWS::S3::Request::CreateBucket;
use VSO;

extends 'AWS::S3::Request';

has 'bucket' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has 'location' => (
    is       => 'ro',
    isa      => 'Str',
    required => 0,
);

sub request {
    my $s = shift;

    if ( $s->location ) {
        my $xml = <<"XML";
<CreateBucketConfiguration xmlns="http://s3.amazonaws.com/doc/2006-03-01/"> 
  <LocationConstraint>@{[ $s->location ]}</LocationConstraint> 
</CreateBucketConfiguration>
XML
        my $signer = AWS::S3::Signer->new(
            s3           => $s->s3,
            method       => 'PUT',
            uri          => $s->protocol . '://' . $s->bucket . '.s3.amazonaws.com/',
            content_type => 'text/plain',
            content_md5  => '',
            content      => \$xml,
        );

        return $s->_send_request(
            $signer->method => $signer->uri => {
                Authorization  => $signer->auth_header,
                Date           => $signer->date,
                'content-type' => 'text/plain',
            },
            $xml
        );
    } else {
        my $signer = AWS::S3::Signer->new(
            s3     => $s->s3,
            method => 'PUT',
            uri    => $s->protocol . '://s3.amazonaws.com/' . $s->bucket,
        );
        return $s->_send_request(
            $signer->method => $signer->uri => {
                Authorization => $signer->auth_header,
                Date          => $signer->date,
            }
        );
    }    # end if()
}    # end request()

sub parse_response {
    my ( $s, $res ) = @_;

    AWS::S3::ResponseParser->new(
        response       => $res,
        expect_nothing => 1,
        type           => $s->type,
    );
}    # end http_request()

1;   # return true:

