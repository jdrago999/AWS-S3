
package 
AWS::S3::Request::ListBucket;

use VSO;
use AWS::S3::HTTPRequest;

extends 'AWS::S3::Request';

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

sub http_request
{
  my $s = shift;
  
  my @params = ( );
  push @params, 'max-keys=' . $s->max_keys;
  push @params, 'marker=' . $s->marker if $s->marker;
  push @params, 'prefix=' . $s->prefix if $s->prefix;
  push @params, 'delimiter=' . $s->delimiter if $s->delimiter;
  return AWS::S3::HTTPRequest->new(
    s3     => $s->s3,
    method => 'GET',
    path   => $s->_uri('') . '?' . join( '&', @params),
  )->http_request;
  
}# end http_request()

1;# return true:

