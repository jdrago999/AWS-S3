#!perl

use strict;
use warnings;

use Test::More 'no_plan';
use FindBin qw/ $Bin /;

use Carp 'confess';
$SIG{__DIE__} = \&confess;

use_ok('AWS::S3');

my $s3 = AWS::S3->new(
  access_key_id     => $ENV{AWS_ACCESS_KEY_ID}     // 'foo',
  secret_access_key => $ENV{AWS_SECRET_ACCESS_KEY} // 'bar',
  endpoint          => $ENV{AWS_ENDPOINT}          // 'baz',
);

use_ok('AWS::S3::Signer');

isa_ok(
	my $signer = AWS::S3::Signer->new(
		method  => 'HEAD',
		s3      => $s3,
		uri     => "http://baz/boz",
		content => \'hello world',
	),
	'AWS::S3::Signer'
);

is( $signer->content_type,'text/plain','content_type' );
is( $signer->method,'HEAD','method' );
is( ${ $signer->content },'hello world','content' );

like( $signer->auth_header,qr/AWS foo:.{28}/,'auth_header' );
