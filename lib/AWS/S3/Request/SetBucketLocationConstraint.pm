
package 
AWS::S3::Request::SetBucketLocationConstraint;

use VSO;
use AWS::S3::HTTPRequest;

extends 'AWS::S3::Request';

has 'location' => (
  is        => 'ro',
  isa       => 'Str',
  required  => 1,
);


sub http_request
{
  my $s = shift;

  my $xml = <<"XML";
<CreateBucketConfiguration xmlns="http://s3.amazonaws.com/doc/2006-03-01/"> 
  <LocationConstraint>@{[ $s->location ]}</LocationConstraint> 
</CreateBucketConfiguration >
XML

  return AWS::S3::HTTPRequest->new(
    s3      => $s->s3,
    method  => 'PUT',
    path    => $s->_uri('') . '',
    content => $xml,
  )->http_request;
}# end http_request()

1;# return true:

