
package
AWS::S3::Signer;

use VSO;
use HTTP::Request::Common;
use HTTP::Date 'time2str';
use MIME::Base64 qw(encode_base64);
use URI::Escape qw(uri_escape_utf8);
use URI::QueryParam;
use URI::Escape;
use URI;
use Digest::HMAC_SHA1;
use Digest::MD5 'md5';

my $METADATA_PREFIX      = 'x-amz-meta-';
my $AMAZON_HEADER_PREFIX = 'x-amz-';

enum 'AWS::S3::HTTPMethod' => [qw( HEAD GET PUT POST DELETE )];

has 's3' => (
  is        => 'ro',
  isa       => 'AWS::S3',
  required  => 1,
);

has 'method' => (
  is        => 'ro',
  isa       => 'AWS::S3::HTTPMethod',
  required  => 1,
);

has 'bucket_name' => (
  is        => 'ro',
  isa       => 'Str',
  required  => 1,
  lazy      => 1,
  default   => sub {
    my $s = shift;
    if( my ($name) = $s->uri->host =~ m{^(.+?)\.s3\.amazonaws} )
    {
      return $name;
    }
    else
    {
      return '';
    }# end if()
  }
);

has 'uri' => (
  is        => 'ro',
  isa       => 'URI',
  required  => 1,
  coerce    => 1,
);

coerce 'URI'
  => from 'Str'
  => via  { URI->new($_) };

#has 'headers' => (
#  is        => 'ro',
#  isa       => 'HTTP::Headers',
#  required  => 1,
#  lazy      => 1,
#  default   => sub { HTTP::Headers->new }
#);

has 'headers' => (
  is        => 'ro',
  isa       => 'ArrayRef[Str]',
  required  => 1,
  lazy      => 1,
  default   => sub { [ ] },
);

has 'date' => (
  is        => 'ro',
  isa       => 'Str',
  required  => 1,
  default   => sub {
    time2str(time)
  }
);

has 'string_to_sign' => (
  is        => 'ro',
  isa       => 'Str',
  required  => 1,
  lazy      => 1,
  default   => sub {
    my $s = shift;
    
    join "\n", (
      $s->method,
      $s->content_md5,
      $s->content ? $s->content_type : '',
      $s->date || '',
      (
        join "\n", grep { $_ } ( $s->canonicalized_amz_headers, $s->canonicalized_resource )
      )
    );
  }
);

has 'canonicalized_amz_headers' => (
  is        => 'ro',
  isa       => 'Str',
  lazy      => 1,
  default   => sub {
    my $s = shift;
    
    # Add the x-amz-* headers if they don't already exist:
#    if( my $md5 = $s->content_md5 )
#    {
#      $s->headers->header( 'x-amz-content-md5' => $md5 );
#      $s->headers->header( 'content-md5' => $md5 );
#    }# end if()

    my @h = @{ $s->headers };
    my %out = ( );
    while( my ($k,$v) = splice(@h, 0, 2) )
    {
      $k = lc($k);
      if( exists $out{$k} )
      {
        $out{$k} = [ $out{$k} ] unless ref($out{$k});
        push @{ $out{$k} }, $v;
      }
      else
      {
        $out{$k} = $v;
      }# end if()
    }# end while()
    
    my @parts = ( );
    while( my ($k, $v) = each %out )
    {
      if( ref($out{$k}) )
      {
        push @parts, _trim($k) . ':' . join( ',', map { _trim($_) } @{ $out{$k} } );
      }
      else
      {
        push @parts, _trim($k) . ':' . _trim($out{$k});
      }# end if()
    }# end while()
    
    return join "\n", @parts;
  }
);

has 'canonicalized_resource' => (
  is        => 'ro',
  isa       => 'Str',
  lazy      => 1,
  default   => sub {
    my $s = shift;
    my $str = $s->bucket_name ? '/' . $s->bucket_name . $s->uri->path : $s->uri->path;
    
    if( my ($resource) = ($s->uri->query||'') =~ m{[&]*(acl|website|location|policy|delete|lifecycle)(?!\=)} )
    {
      $str .= '?' . $resource;
    }# end if()
    return $str;
  }
);

has 'content_type' => (
  is        => 'ro',
  isa       => 'Str',
  required  => 1,
  default   => sub {
    my $s = shift;
    return '' if $s->method eq 'GET';
    return '' unless $s->content;
    return 'text/plain';
  }
);

has 'content_md5' => (
  is        => 'ro',
  isa       => 'Str',
  required  => 1,
  default   => sub {
    my $s = shift;
    return '' unless my $type = $s->content;
    return encode_base64(md5( ${$s->content} ), '');
  }
);

has 'content' => (
  is        => 'ro',
  isa       => 'Maybe[ScalarRef]',
  required  => 0,
);

has 'content_length' => (
  is        => 'ro',
  isa       => 'Int',
  required  => 0,
  lazy      => 1,
  default   => sub { length(${shift->content}) }
);

has 'signature' => (
  is        => 'ro',
  isa       => 'Str',
  required  => 1,
  lazy      => 1,
  default   => sub {
    my $s = shift;
    my $hmac = Digest::HMAC_SHA1->new( $s->s3->secret_access_key );
    $hmac->add(
      $s->string_to_sign()
    );
    return encode_base64( $hmac->digest, '' );
  }
);


sub auth_header
{
  my $s = shift;
  
  return 'AWS ' . $s->s3->access_key_id . ':' . $s->signature;
}# end auth_header()


sub _trim
{
  my ($value) = @_;
  $value =~ s/^\s+//;
  $value =~ s/\s+$//;
  return $value;
}# end _trim()


sub _urlencode
{
  my ($unencoded ) = @_;
  return uri_escape_utf8( $unencoded, '^A-Za-z0-9_-' );
}# end _urlencode()

1;# return true:

