
package AWS::S3;

use VSO;
use Carp 'confess';
use LWP::UserAgent::Determined;
use HTTP::Response;
use IO::Socket::INET;
use Class::Load 'load_class';

use AWS::S3::ResponseParser;
use AWS::S3::Owner;
use AWS::S3::Bucket;


our $VERSION = '0.019';

has 'access_key_id' => (
  is    => 'ro'
);

has 'secret_access_key' => (
  is    => 'ro'
);

has 'secure' => (
  is      => 'ro',
  isa     => 'Int',
  lazy    => 1,
  default => sub { 0 },
);

has 'ua' => (
  is      => 'ro',
  default => sub { LWP::UserAgent::Determined->new }
);


sub request
{
  my ($s, $type, %args) = @_;
  
  my $class = "AWS::S3::Request::$type";
  load_class($class);
  return $class->new( s3 => $s, %args )->http_request;
}# end request()


sub owner
{
  my ($s) = @_;
  
  my $type = 'ListAllMyBuckets';
  my $req = $s->request( $type,
    bucket  => '',
  );
  
  my $parser = AWS::S3::ResponseParser->new(
    response        => $s->ua->request( $req ),
    type            => $type,
    expect_nothing  => 0,
  );
  
  my $xpc = $parser->xpc;
  
  return AWS::S3::Owner->new(
    id            => $xpc->findvalue('//s3:Owner/s3:ID'),
    display_name  => $xpc->findvalue('//s3:Owner/s3:DisplayName'),
  );
}# end owner()


sub buckets
{
  my ($s) = @_;
  
  my $type = 'ListAllMyBuckets';
  my $req = $s->request( $type,
    bucket  => '',
  );
  
  my $parser = AWS::S3::ResponseParser->new(
    response        => $s->ua->request( $req ),
    type            => $type,
    expect_nothing  => 0,
  );
  
  my $xpc = $parser->xpc;
  my @buckets = ( );
  foreach my $node ( $xpc->findnodes('.//s3:Bucket') )
  {
    push @buckets, AWS::S3::Bucket->new(
      name          => $xpc->findvalue('.//s3:Name', $node ),
      creation_date => $xpc->findvalue('.//s3:CreationDate', $node),
      s3            => $s,
    );
  }# end foreach()
  
  return @buckets;
}# end buckets()


sub bucket
{
  my ($s, $name) = @_;
  
  my ($bucket) = grep { $_->name eq $name } $s->buckets
    or return;
  $bucket;
}# end bucket()


sub add_bucket
{
  my ($s, %args) = @_;
  
  my $type = 'CreateBucket';
  my $req = $s->request( $type, bucket => $args{name} );
  
  my $parser = AWS::S3::ResponseParser->new(
    response        => $s->_raw_response( $req ),
    type            => $type,
    expect_nothing  => 1,
  );
  
  if( my $msg = $parser->friendly_error() )
  {
    die $msg;
  }# end if()
  
  return $s->bucket( $args{name} );
}# end add_bucket()


sub _raw_response
{
  my ($s, $http_req) = @_;
  
  my ($host, $uri) = $http_req->uri =~ m{://(.+?)(/.?)$};
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
    last unless length($_);
  }# end while()

  close($sock);
  
  return HTTP::Response->parse( join "\n", @parts );  
}# end _raw_response()


1;# return true:

=pod

=head1 NAME

AWS::S3 - Lightweight interface to Amazon S3 (Simple Storage Service)

=head1 SYNOPSIS

  use AWS::S3;
  
  my $s3 = AWS::S3->new(
    access_key_id     => 'E654SAKIASDD64ERAF0O',
    secret_access_key => 'LgTZ25nCD+9LiCV6ujofudY1D6e2vfK0R4GLsI4H',
  );
  
  # Add a bucket:
  my $bucket = $s3->add_bucket(
    name    => 'foo-bucket',
  );
  
  # Set the acl:
  $bucket->acl( 'private' );
  
  # Add a file:
  my $new_file = $bucket->add_file(
    key       => 'foo/bar.txt',
    contents  => \'This is the contents of the file',
  );
  
  # You can also set the contents with a coderef:
  # Coderef should eturn a reference, not the actual string of content:
  $new_file = $bucket->add_file(
    key       => 'foo/bar.txt',
    contents  => sub { return \"This is the contents" }
  );
  
  # Get the file:
  my $same_file = $bucket->file( 'foo/bar.txt' );
  
  # Get the contents:
  my $scalar_ref = $same_file->contents;
  print $$scalar_ref;
  
  # Update the contents with a scalar ref:
  $same_file->contents( \"New file contents" );
  
  # Update the contents with a code ref:
  $same_file->contents( sub { return \"New file contents" } );
  
  # Delete the file:
  $same_file->delete();
  
  # Iterate through lots of files:
  my $iterator = $bucket->files(
    page_size   => 100,
    page_number => 1,
  );
  while( my @files = $iterator->next_page )
  {
    warn "Page number: ", $iterator->page_number, "\n";
    foreach my $file ( @files )
    {
      warn "\tFilename (key): ", $file->key, "\n";
      warn "\tSize: ", $file->size, "\n";
      warn "\tETag: ", $file->etag, "\n";
      warn "\tContents: ", ${ $file->contents }, "\n";
    }# end foreach()
  }# end while()
  
  # You can't delete a bucket until it's empty.
  # Empty a bucket like this:
  while( my @files = $iterator->next_page )
  {
    map { $_->delete } @files;
    
    # Return to page 1:
    $iterator->page_number( 1 );
  }# end while()
  
  # Now you can delete the bucket:
  $bucket->delete();

=head1 DESCRIPTION

AWS::S3 attempts to provide an alternate interface to the Amazon S3 Simple Storage Service.

B<NOTE:> Until AWS::S3 gets to version 1.000 it will not implement the full S3 interface.

B<Disclaimer:> Several portions of AWS::S3 have been adopted from L<Net::Amazon::S3>.

B<NOTE:> AWS::S3 is NOT a drop-in replacement for L<Net::Amazon::S3>.

B<TODO:> CloudFront integration.

=head1 CONSTRUCTOR

Call C<new()> with the following parameters.

=head2 access_key_id

Required.  String.

Provided by Amazon, this is your access key id.

=head2 secret_access_key

Required.  String.

Provided by Amazon, this is your secret access key.

=head2 secure

Optional.  Boolean.

Default is C<0>

=head2 ua

Optional.  Should be an instance of L<LWP::UserAgent> or a subclass of it.

Defaults to creating a new instance of L<LWP::UserAgent::Determined>

=head1 PUBLIC PROPERTIES

=head2 access_key_id

String.  Read-only

=head2 secret_access_key

String.  Read-only.

=head2 secure

Boolean.  Read-only.

=head2 ua

L<LWP::UserAgent> object.  Read-only.

=head2 owner

L<AWS::S3::Owner> object.  Read-only.

=head1 PUBLIC METHODS

=head2 buckets

Returns an array of L<AWS::S3::Bucket> objects.

=head2 bucket( $name )

Returns the L<AWS::S3::Bucket> object matching C<$name> if found.

Returns nothing otherwise.

=head2 add_bucket( name => $name )

Attempts to create a new bucket with the name provided.

On success, returns the new L<AWS::S3::Bucket>

On failure, dies with the error message.

See L<AWS::S3::Bucket> for details on how to use buckets (and access their files).

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

