
package AWS::S3::Request::ListBucket;

use Moose;

with 'AWS::S3::Roles::Request';

has 'bucket' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has 'max_keys' => (
    is       => 'ro',
    isa      => 'Int',
    required => 1,
);

has 'marker' => (
    is       => 'ro',
    isa      => 'Str',
    required => 0,
);

has 'prefix' => (
    is       => 'ro',
    isa      => 'Str',
    required => 0,
);

has 'delimiter' => (
    is       => 'ro',
    isa      => 'Str',
    required => 0,
);

has '+_expect_nothing' => ( default => 0 );

sub request {
    my $s = shift;

    my @params = ();
    push @params, 'max-keys=' . $s->max_keys;
    push @params, 'marker=' . $s->marker if $s->marker;
    push @params, 'prefix=' . $s->prefix if $s->prefix;
    push @params, 'delimiter=' . $s->delimiter if $s->delimiter;
    my $signer = AWS::S3::Signer->new(
        s3     => $s->s3,
        method => 'GET',
        uri => $s->protocol . '://' . $s->bucket . '.' . $s->endpoint . '/' . ( @params ? '?' . join( '&', @params ) : '' ),
    );
    $s->_send_request(
        $signer->method => $signer->uri => {
            Authorization => $signer->auth_header,
            Date          => $signer->date,
        }
    );
}    # end request()

__PACKAGE__->meta->make_immutable;
