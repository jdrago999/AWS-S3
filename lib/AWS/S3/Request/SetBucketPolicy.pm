
package 
AWS::S3::Request::SetBucketPolicy;

use VSO;
use AWS::S3::HTTPRequest;
use JSON::XS;

extends 'AWS::S3::Request';

has 'policy' => (
  is        => 'ro',
  isa       => 'Str',
  required  => 1,
  where     => sub {
    eval { decode_json($_[0]); 1 }
  }
);


sub http_request
{
  my $s = shift;

  return AWS::S3::HTTPRequest->new(
    s3      => $s->s3,
    method  => 'PUT',
    path    => $s->_uri('') . '?policy',
    content => $s->policy,
  )->http_request;
}# end http_request()

1;# return true:

