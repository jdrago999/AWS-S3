
package AWS::S3::HTTPRequest;

use Moose;
use AWS::S3::Signer;

use Carp 'confess';
use HTTP::Date 'time2str';
use MIME::Base64 qw(encode_base64);
use URI::Escape qw(uri_escape_utf8);
use URI::QueryParam;
use URI::Escape;
use Digest::HMAC_SHA1;
use URI;

my $METADATA_PREFIX      = 'x-amz-meta-';
my $AMAZON_HEADER_PREFIX = 'x-amz-';

enum 'HTTPMethod' => [qw( HEAD GET PUT POST DELETE )];

has 's3' => (
    is       => 'ro',
    required => 1,
    isa      => 'AWS::S3',
);

has 'method' => (
    is       => 'ro',
    required => 1,
    isa      => 'HTTPMethod'
);

has 'path' => (
    is       => 'ro',
    required => 1,
    isa      => 'Str',
);

has 'headers' => (
    is       => 'ro',
    required => 1,
    isa      => 'HTTP::Headers',
    lazy     => 1,
    default  => sub { HTTP::Headers->new() },
    coerce   => 1,
);

coerce 'HTTP::Headers' => from 'HashRef' => via { my $h = HTTP::Headers->new( %$_ ) };

has 'content' => (
    is       => 'ro',
    required => 1,
    isa      => 'Str|ScalarRef|CodeRef',
    default  => '',
);

has 'metadata' => (
    is       => 'ro',
    required => 1,
    isa      => 'HashRef',
    default  => sub { {} },
);

has 'contenttype' => (
    is       => 'ro',
    required => 0,
    isa      => 'Str',
);

# Make the HTTP::Request object:
sub http_request {
    my $s        = shift;
    my $method   = $s->method;
    my $path     = $s->path;
    my $headers  = $s->headers;
    my $content  = $s->content;
    my $metadata = $s->metadata;

    my $protocol = $s->s3->secure ? 'https' : 'http';
    my $uri = "$protocol://s3.amazonaws.com/$path";
    if ( $path =~ m{^([^/?]+)(.*)} && _is_dns_bucket( $1 ) ) {
        $uri = "$protocol://$1.s3.amazonaws.com$2";
    }    # end if()

    my $signer = AWS::S3::Signer->new(
        s3      => $s->s3,
        method  => $method,
        uri     => $uri,
        content => $content ? \$content : undef,
        headers => $headers,
    );

    $headers->header( 'Authorization'  => $signer->auth_header );
    $headers->header( 'Date'           => $signer->date );
    $headers->header( 'Host'           => URI->new( $uri )->host );
    $headers->header( 'content-length' => $signer->content_length ) if $content;
    $headers->header( 'content-type'   => $signer->content_type ) if $content;

    my $request = HTTP::Request->new( $method, $uri, $headers, $content );

    if ( $uri =~ m{location} && 1 || $method eq 'PUT' ) {

        #  warn "StringToSign(" . $signer->string_to_sign . ")";
        #  warn "canonicalized_amz_headers(" . $signer->canonicalized_amz_headers . ")";
        #  warn "Request(" . $request->as_string . ")";
    }    # end if()
    return $request;
}    # end http_request()

# XXX: Not needed by us...
sub _is_dns_bucket { 1 }

__PACKAGE__->meta->make_immutable;

