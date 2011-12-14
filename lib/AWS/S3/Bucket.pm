
package AWS::S3::Bucket;

use Carp 'confess';
use VSO;
use IO::Socket::INET;
use AWS::S3::ResponseParser;
use AWS::S3::FileIterator;


has 's3'  => (
  is        => 'ro',
  isa       => 'AWS::S3',
  required  => 1,
);

has 'name'  => (
  is        => 'ro',
  isa       => 'Str',
  required  => 1,
);

has 'creation_date'  => (
  is        => 'ro',
  isa       => 'Str',
  required  => 0,
);

has 'acl' => (
  is        => 'rw',
  isa       => 'Str',
  required  => 0,
  lazy      => 1,
  default   => sub {
    shift->_get_acl()
  }
);

has 'location_constraint' => (
  is        => 'rw',
  isa       => 'Str',
  required  => 0,
  lazy      => 1,
  default   => sub {
    shift->_get_location_constraint()
  }
);

has 'policy' => (
  is        => 'rw',
  isa       => 'Str',
  required  => 0,
  lazy      => 1,
  default   => sub {
    shift->_get_policy()
  }
);


after 'policy' => sub {
  my ($s, $new_val) = @_;
  
  $s->_set_policy( $new_val );
};


after 'acl' => sub {
  my ($s, $new_val, $old_val) = @_;
  
  my %shorts = map {$_=>1} qw(
    private public-read public-read-write authenticated-read
  );
  my %acl = ( );
  if( $new_val =~ m{<} )
  {
    $acl{acl_xml} = $new_val;
  }
  elsif( exists $shorts{$new_val} )
  {
    $acl{acl_short} = $new_val;
  }
  else
  {
    die "Attempt to set an invalid value for acl: '$new_val'";
  }# end if()
  
  $s->_set_acl( %acl );
  $s->{acl} = $s->_get_acl();
};


sub _set_acl
{
  my ($s, %acl) = @_;
  
  my $type = 'SetBucketAccessControl';
  my $req = $s->s3->request($type,
    %acl,
    bucket  => $s->name,
  );
  my $parser = AWS::S3::ResponseParser->new(
    type            => $type,
    response        => $s->s3->ua->request( $req ),
    expect_nothing  => 1,
  );
  
  return if $parser->response->code == 404;
  
  if( my $msg = $parser->friendly_error() )
  {
    die $msg;
  }# end if()
  
  return $parser->response->decoded_content;
}# end _set_acl()


sub _get_acl
{
  my $s = shift;
  
  my $type = 'GetBucketAccessControl';
  return $s->_get_property( $type )->response->decoded_content();
}# end _get_acl()


after 'location_constraint' => sub {
  my ($s, $new_value) = @_;
  $s->_set_location_constraint( $new_value );
};


sub _set_location_constraint
{
  my ($s, $loc) = @_;
  
  my $type = 'SetBucketLocationConstraint';
  my $req = $s->s3->request($type,
    bucket    => $s->name,
    location  => $loc,
  );
  my $parser = AWS::S3::ResponseParser->new(
    type            => $type,
    response        => $s->s3->ua->request( $req ),
    expect_nothing  => 1,
  );
  
  if( my $msg = $parser->friendly_error() )
  {
    die $msg unless $parser->error_code eq 'BucketAlreadyOwnedByYou';
  }# end if()
  
  return 1;
}# end _set_location_constraint()


sub _get_location_constraint
{
  my $s = shift;
  
  my $type = 'GetBucketLocationConstraint';
  my $constraint = $s->_get_property( $type )->xpc->findvalue('//s3:LocationConstraint');
  if( defined $constraint && $constraint eq '' )
  {
    return;
  }
  else
  {
    return $constraint;
  }# end if()
}# end _get_location_constraint()


sub _get_policy
{
  my $s = shift;
  
  my $type = 'GetBucketPolicy';
  return $s->_get_property( $type, is_raw => 1 )->response->decoded_content();
}# end _get_policy()


sub _set_policy
{
  my ($s, $policy) = @_;
  
  my $type = 'SetBucketPolicy';
  my $req = $s->s3->request($type,
    bucket  => $s->name,
    policy  => $policy,
  );
  my $parser = AWS::S3::ResponseParser->new(
    type      => $type,
    response  => $s->s3->ua->request( $req ),
  );
  
  if( my $msg = $parser->friendly_error() )
  {
    die $msg;
  }# end if()
  
  return $parser->response->decoded_content();
}# end _set_policy()


sub enable_cloudfront_domain
{
  my ($s, $cloudfront) = @_;
  
  $cloudfront->isa('AWS::CloudFront')
    or die "Usage: enable_cloudfront_domain( <AWS::CloudFront object> )";
  
}# end enable_cloudfront_domain()


sub files
{
  my ($s, %args) = @_;
  
  return AWS::S3::FileIterator->new(
    %args,
    bucket  => $s,
  );
}# end files()


sub file
{
  my ($s, $key) = @_;
  
  my $type = 'GetFileInfo';
  
  my $parser = $s->_get_property($type, key => $key)
    or return;
  
  my $res = $parser->response;
  return AWS::S3::File->new(
    bucket       => $s,
    key          => $key,
    size         => $res->header('content-length'),
    contenttype  => $res->header('content-type') || 'application/octet-stream',
    etag         => $res->header('etag'),
    lastmodified => $res->header('last-modified'),
  );
}# end file()


sub add_file
{
  my ($s, %args) = @_;
  
  if( ref($args{contents}) eq 'CODE' )
  {
    my $str = $args{contents}->();
    $args{contents} = $str;
  }# end if()
  my $file = AWS::S3::File->new(
    size    => length(${$args{contents}}),
    %args,
    bucket  => $s
  );
  $file->contents( $args{contents} );
  return $file;
}# end add_file()


sub delete
{
  my ($s) = @_;
  
  my $type = 'DeleteBucket';
  
  my $req = $s->s3->request($type,
    bucket  => $s->name,
  );
  my $parser = AWS::S3::ResponseParser->new(
    type            => $type,
    response        => $s->s3->ua->request( $req ),
    expect_nothing  => 1,
  );
  
  if( my $msg = $parser->friendly_error() )
  {
    die $msg;
  }# end if()
  
  return 1;
}# end delete()


sub _get_property
{
  my ($s, $type, %args) = @_;
  
  my $req = $s->s3->request($type,
    bucket  => $s->name,
    %args,
  );
  my $parser = AWS::S3::ResponseParser->new(
    type      => $type,
    response  => $args{is_raw} ? $s->_raw_response( $req ) : $s->s3->ua->request( $req ),
  );
  
  return if $parser->response->code == 404;
  
  if( my $msg = $parser->friendly_error() )
  {
    die $msg;
  }# end if()
  
  return $parser;
}# end _get_property()


sub _raw_response
{
  my ($s, $http_req) = @_;
  
  my ($host, $uri) = $http_req->uri =~ m{://(.+?)/(.+)$};
  unless( $host && $uri )
  {
    ($host) = $http_req->uri =~ m{://(.+?)/?$};
    $uri = '';
  }# end unless()
  my $sock = IO::Socket::INET->new(
    PeerAddr  => $host,
    PeerPort  => 80, 
    Proto     => 'tcp',
  ) or die "Could not create socket: $!";

  my $req = <<"REQ";
@{[ $http_req->method ]} $uri HTTP/1.1
Host: $host
Date: @{[ $http_req->header('Date') ]}
Authorization: @{[ $http_req->header('Authorization') ]}


REQ
  print $sock $req, $http_req->content;

  my @parts = ( );
  while( <$sock> )
  {
    $_ =~ s{^\s+}{};
    $_ =~ s{\s+$}{};
    last if $_ eq '0';
    push @parts, $_;
  }# end while()

  close($sock);
  
  return HTTP::Response->parse( join "\n", @parts );  
}# end _raw_response()

1;# return true:

=pod

=head1 NAME

AWS::S3::Bucket - Object representation of S3 Buckets

=head1 SYNOPSIS

See L<The SYNOPSIS from AWS::S3|AWS::S3/SYNOPSIS> for usage details.

=head1 CONSTRUCTOR

Call C<new()> with the following parameters.

=head1 PUBLIC PROPERTIES

=head2 s3

Required.  An L<AWS::S3> object.

Read-only.

=head2 name

Required.  String.

The name of the bucket.

Read-only.

=head2 creation_date

String.  Returned from the S3 service itself.

Read-only.

=head2 acl

String.  Returns XML string.

Read-only.

B<TODO:> Implement setting the ACL properly.

See also L<PUT Bucket ACL|http://docs.amazonwebservices.com/AmazonS3/latest/API/index.html?RESTBucketPUTacl.html>

=head2 location_constraint

String.  Accepts valid location constraint values.

=over 4

=item * EU

=item * us-west-1

=item * us-west-2

=item * ap-southeast-1

=item * ap-northeast-1

=back

The default value is 'US'.

See also L<PUT Bucket|http://docs.amazonwebservices.com/AmazonS3/latest/API/index.html?RESTBucketPUT.html>

=head2 policy

Read-only.  String of JSON.

Looks something like this:

  {
    "Version":"2008-10-17",
    "Id":"aaaa-bbbb-cccc-dddd",
    "Statement" : [
      {
        "Effect":"Deny",
        "Sid":"1", 
        "Principal" : {
          "AWS":["1-22-333-4444","3-55-678-9100"]
        },
        "Action":["s3:*"],
        "Resource":"arn:aws:s3:::bucket/*",
      }
    ]
  }

See also L<GET Bucket Policy|http://docs.amazonwebservices.com/AmazonS3/latest/API/index.html?RESTBucketGETpolicy.html>

=head1 PUBLIC METHODS

=head2 files( page_size => $size, page_number => $number, [[marker => $marker,] pattern => qr/$pattern/ ] )

Returns a L<AWS::S3::FileIterator> object with the supplied arguments.

Use the L<AWS::S3::FileIterator> to page through your results.

=head2 file( $key )

Finds the file with that C<$key> and returns an L<AWS::S3::File> object for it.

=head1 SEE ALSO

L<The Amazon S3 API Documentation|http://docs.amazonwebservices.com/AmazonS3/latest/API/>

L<AWS::S3::Bucket>

L<AWS::S3::File>

L<AWS::S3::FileIterator>

L<AWS::S3::Owner>

=head1 AUTHOR

John Drago <jdrago_999@yahoo.com>

=head1 LICENSE AND COPYRIGHT

This software is Free software and may be used and redistributed under the same
terms as any version of perl itself.

Copyright John Drago 2011 all rights reserved.

=cut

