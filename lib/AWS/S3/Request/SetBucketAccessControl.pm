
package 
AWS::S3::Request::SetBucketAccessControl;

use VSO;
use AWS::S3::HTTPRequest;

extends 'AWS::S3::Request';

has 'acl_short' => (
  is        => 'ro',
  isa       => 'Maybe[Str]',
  required  => 0,
  where     => sub {
    return 1 unless defined($_);
    m{^(?:private|public-read|public-read-write|authenticated-read)$}
  }
);

has 'acl_xml' => (
  is        => 'ro',
  isa       => 'Maybe[Str]',
  required  => 0,
  where     => sub {
    return 1 unless defined($_);
    m{^\s*<.+>\s*$}s
  }
);


sub http_request
{
  my $s = shift;

  unless( $s->acl_xml || $s->acl_short )
  {
    die "need either acl_xml or acl_short";
  }# end unless()

  if( $s->acl_xml && $s->acl_short )
  {
    die "can not provide both acl_xml and acl_short";
  }# end if()

  my $headers = ( $s->acl_short )
      ? { 'x-amz-acl' => $s->acl_short }
      : {};
  my $xml = $s->acl_xml || '';

  return AWS::S3::HTTPRequest->new(
    s3      => $s->s3,
    method  => 'PUT',
    path    => $s->_uri('') . '?acl',
    headers => $headers,
    content => $xml,
  )->http_request;
}# end http_request()

1;# return true:

