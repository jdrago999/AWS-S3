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
  endpoint          => 'bad.hostname',
);

my $bucket_name = "aws-s3-test-" . int(rand() * 1_000_000) . '-' . time() . "-foo";

eval {
    my $bucket = $s3->add_bucket( name => $bucket_name, location => 'us-west-1' ),
};

like(
    $@,
    qr/Can't connect to aws-s3-test-.*?bad\.hostname/,
    'endpoint was used'
);
