
package 
AWS::S3::Request::GetFileContents;

use VSO;
use AWS::S3::HTTPRequest;

extends 'AWS::S3::Request';

has 'key' => (
  is        => 'ro',
  isa       => 'Str',
  required  => 1,
);

sub http_request
{
  my $s = shift;
  
  return AWS::S3::HTTPRequest->new(
    s3     => $s->s3,
    method => 'GET',
    path   => $s->_uri('') . $s->key,
  )->http_request;
}# end http_request()

1;# return true:

