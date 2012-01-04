
package
AWS::S3::Request::GetBucketLocationConstraint;

use VSO;
use AWS::S3::Signer;
use AWS::S3::ResponseParser;

extends 'AWS::S3::Request';

has 'bucket' => (
  is        => 'ro',
  isa       => 'Str',
  required  => 1,
);


sub request
{
  my $s = shift;
  
  my $signer = AWS::S3::Signer->new(
    s3            => $s->s3,
    method        => 'GET',
    uri           => $s->protocol . '://' . $s->bucket . '.s3.amazonaws.com/?location',
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

