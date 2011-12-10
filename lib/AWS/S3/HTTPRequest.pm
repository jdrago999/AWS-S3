
package 
AWS::S3::HTTPRequest;

use VSO;

use Carp 'confess';
use HTTP::Date 'time2str';
use MIME::Base64 qw(encode_base64);
use URI::Escape qw(uri_escape_utf8);
use URI::QueryParam;
use URI::Escape;
use Digest::HMAC_SHA1;


my $METADATA_PREFIX      = 'x-amz-meta-';
my $AMAZON_HEADER_PREFIX = 'x-amz-';
my %ok_methods = map { $_ => 1 } qw( DELETE GET HEAD PUT );

has 's3' => (
  is        => 'ro',
  required  => 1,
  isa       => 'AWS::S3',
);

has 'method' => (
  is        => 'ro',
  required  => 1,
  where     => sub { m{^(GET|PUT|HEAD|DELETE)$}i },
);

has 'path' => (
  is        => 'ro',
  required  => 1,
  isa       => 'Str',
);

has 'headers' => (
  is        => 'ro',
  required  => 1,
  isa       => 'HashRef',
  default   => sub { { } },
);

has 'content' => (
  is        => 'ro',
  required  => 1,
  isa       => 'Str|ScalarRef|CodeRef',
  default   => sub { '' },
);

has 'metadata' => (
  is        => 'ro',
  required  => 1,
  isa       => 'HashRef',
  default   => sub { { } },
);


# Make the HTTP::Request object:
sub http_request
{
  my $self     = shift;
  my $method   = $self->method;
  my $path     = $self->path;
  my $headers  = $self->headers;
  my $content  = $self->content;
  my $metadata = $self->metadata;

  my $http_headers = $self->_merge_meta( $headers, $metadata );

  $self->_add_auth_header( $http_headers, $method, $path )
    unless exists $headers->{Authorization};
  my $protocol = $self->s3->secure ? 'https' : 'http';
  my $uri = "$protocol://s3.amazonaws.com/$path";
  if( $path =~ m{^([^/?]+)(.*)} && _is_dns_bucket($1) )
  {
    $uri = "$protocol://$1.s3.amazonaws.com$2";
  }# end if()

  my $request = HTTP::Request->new( $method, $uri, $http_headers, $content );

  return $request;
}# end http_request()


sub query_string_authentication_uri
{
  my ( $self, $expires ) = @_;
  my $method  = $self->method;
  my $path    = $self->path;
  my $headers = $self->headers;

  my $aws_access_key_id     = $self->s3->access_key_id;
  my $aws_secret_access_key = $self->s3->secret_access_key;
  my $canonical_string = $self->_canonical_string( $method, $path, $headers, $expires );
  my $encoded_canonical
  = $self->_encode( $aws_secret_access_key, $canonical_string );

  my $protocol = $self->s3->secure ? 'https' : 'http';
  my $uri = "$protocol://s3.amazonaws.com/$path";
  if( $path =~ m{^([^/?]+)(.*)} && _is_dns_bucket($1) )
  {
    $uri = "$protocol://$1.s3.amazonaws.com$2";
  }# end if()
  
  $uri = URI->new($uri);
  $uri->query_param( AWSAccessKeyId => $aws_access_key_id );
  $uri->query_param( Expires        => $expires );
  $uri->query_param( Signature      => $encoded_canonical );

  return $uri;
}# end query_string_authentication_uri()


sub _add_auth_header
{
  my ( $self, $headers, $method, $path ) = @_;
  
  my $aws_access_key_id     = $self->s3->access_key_id;
  my $aws_secret_access_key = $self->s3->secret_access_key;

  if ( not $headers->header('Date') )
  {
    $headers->header( Date => time2str(time) );
  }# end if()
  
  my $canonical_string = $self->_canonical_string( $method, $path, $headers );
  my $encoded_canonical = $self->_encode( $aws_secret_access_key, $canonical_string );
  $headers->header(
    Authorization => "AWS $aws_access_key_id:$encoded_canonical"
  );
}# end _add_auth_header()


# Generate a canonical string for the given parameters.
# The 'expires' param is optional and is only used by query string authentication.
sub _canonical_string
{
  my ( $self, $method, $path, $headers, $expires ) = @_;
  
  my %interesting_headers = ();
  while( my ( $key, $value ) = each %$headers )
  {
    my $lk = lc $key;
    if (
      $lk eq 'content-md5'  ||
      $lk eq 'content-type' ||
      $lk eq 'date'         ||
      $lk =~ /^$AMAZON_HEADER_PREFIX/
    )
    {
      $interesting_headers{$lk} = $self->_trim($value);
    }# end if()
  }# end while()

  # these keys get empty strings if they don't exist
  $interesting_headers{'content-type'} ||= '';
  $interesting_headers{'content-md5'}  ||= '';

  # just in case someone used this.  it's not necessary in this lib.
  $interesting_headers{'date'} = ''
    if $interesting_headers{'x-amz-date'};

  # if you're using expires for query string auth, then it trumps date
  # (and x-amz-date)
  $interesting_headers{'date'} = $expires
    if $expires;

  my $buf = "$method\n";
  foreach my $key ( sort keys %interesting_headers )
  {
    if( $key =~ /^$AMAZON_HEADER_PREFIX/ )
    {
      $buf .= "$key:$interesting_headers{$key}\n";
    }
    else
    {
      $buf .= "$interesting_headers{$key}\n";
    }# end if()
  }# end foreach()

  # don't include anything after the first ? in the resource...
  $path =~ /^([^?]*)/;
  $buf .= "/$1";

  # ...unless there is an acl or torrent parameter
  if( $path =~ /[&?]acl($|=|&)/ )
  {
    $buf .= '?acl';
  }
  elsif( $path =~ /[&?]torrent($|=|&)/ )
  {
    $buf .= '?torrent';
  }
  elsif( $path =~ /[&?]location($|=|&)/ )
  {
    $buf .= '?location';
  }# end if()

  return $buf;
}# end _canonical_string()


# Finds the hmac-sha1 hash of the canonical string and the aws secret access key and then
# base64 encodes the result (optionally urlencoding after that).
sub _encode
{
  my ( $self, $aws_secret_access_key, $str, $do_urlencode ) = @_;
  
  my $hmac = Digest::HMAC_SHA1->new( $aws_secret_access_key );
  $hmac->add($str);
  my $b64 = encode_base64( $hmac->digest, '' );
  if( $do_urlencode )
  {
    return $self->_urlencode($b64);
  }
  else
  {
    return $b64;
  }# end if()
}# end _encode()


# EU buckets must be accessed via their DNS name. This routine figures out if
# a given bucket name can be safely used as a DNS name.
sub _is_dns_bucket
{
  my $bucketname = $_[0];

  if( length $bucketname > 63 )
  {
    return 0;
  }
  
  if( length $bucketname < 3 )
  {
    return;
  }# end if()
  
  return 0 unless $bucketname =~ m{^[a-z0-9][a-z0-9.-]+$};
  
  my @components = split /\./, $bucketname;
  
  foreach my $c (@components)
  {
    return 0 if $c =~ m{^-};
    return 0 if $c =~ m{-$};
    return 0 if $c eq '';
  }# end for()
  
  return 1;
}# end _is_dns_bucket()


# Generates an HTTP::Headers object given one hash that represents http
# headers to set and another hash that represents an object's metadata.
sub _merge_meta
{
  my ( $self, $headers, $metadata ) = @_;
  
  $headers  ||= {};
  $metadata ||= {};

  my $http_header = HTTP::Headers->new;
  while( my ( $k, $v ) = each %$headers )
  {
    $http_header->header( $k => $v );
  }# end while()
  while ( my ( $k, $v ) = each %$metadata )
  {
    $http_header->header( "$METADATA_PREFIX$k" => $v );
  }# end while()
  
  return $http_header;
}# end _merge_meta()


sub _trim
{
  my ( $self, $value ) = @_;
  $value =~ s/^\s+//;
  $value =~ s/\s+$//;
  return $value;
}# end _trim()


sub _urlencode
{
  my ( $s, $unencoded ) = @_;
  return uri_escape_utf8( $unencoded, '^A-Za-z0-9_-' );
}# end _urlencode()

1;# return true:


