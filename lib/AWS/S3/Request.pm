
package 
AWS::S3::Request;

use VSO;
use AWS::S3::HTTPRequest;
use URI::Escape qw(uri_escape_utf8);
use Carp 'confess';

has 'bucket' => (
  is        => 'ro',
  required  => 1,
  isa       => 'Str',
  default   => sub { '' }
);

has 's3' => (
  is        => 'ro',
  required  => 1,
  isa       => 'AWS::S3',
);


sub _uri {
  my ( $s, $key ) = @_;
  
  return $key
    ? $s->bucket . "/" . (join '/', map {$s->_urlencode($_)} split /\//, $key)
    : $s->bucket . "/";
}

sub _urlencode
{
  my ( $s, $unencoded ) = @_;
  return uri_escape_utf8( $unencoded, '^A-Za-z0-9_-' );
}# end _urlencode()

1;# return true:

