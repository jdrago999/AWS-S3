
package
AWS::S3::Request::ListBucket;

use VSO;

extends 'AWS::S3::Request';

has 'bucket' => (
  is        => 'ro',
  isa       => 'Str',
  required  => 1,
);

has 'max_keys' => (
  is        => 'ro',
  isa       => 'Int',
  required  => 1,
);

has 'marker' => (
  is        => 'ro',
  isa       => 'Str',
  required  => 0,
);

has 'prefix' => (
  is        => 'ro',
  isa       => 'Str',
  required  => 0,
);

has 'delimiter' => (
  is        => 'ro',
  isa       => 'Str',
  required  => 0,
);


sub request
{
  my $s = shift;
  
  my @params = ( );
  push @params, 'max-keys=' . $s->max_keys;
  push @params, 'marker=' . $s->marker if $s->marker;
  push @params, 'prefix=' . $s->prefix if $s->prefix;
  push @params, 'delimiter=' . $s->delimiter if $s->delimiter;
  my $signer = AWS::S3::Signer->new(
    s3            => $s->s3,
    method        => 'GET',
    uri           => $s->protocol . '://' . $s->bucket . '.s3.amazonaws.com/' . ( @params ? '?' . join( '&', @params) : ''),
  );
  $s->_send_request( $signer->method => $signer->uri => {
    Authorization => $signer->auth_header,
    Date          => $signer->date,
  });
}# end request()

sub parse_response
{
  my ($s, $res) = @_;
  
  AWS::S3::ResponseParser->new(
    response        => $res,
    expect_nothing  => 0,
    type            => $s->type,
  );
}# end http_request()


1;# return true:

