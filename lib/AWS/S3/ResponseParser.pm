
package AWS::S3::ResponseParser;

use Moose;
use XML::LibXML;
use XML::LibXML::XPathContext;

has 'expect_nothing' => (
    is       => 'ro',
    isa      => 'Bool',
    required => 1,
    default  => 0,
    trigger  => sub {
        my ( $self, $expect_nothing, $oldValue ) = @_;
        if ( $expect_nothing ) {
            my $code = $self->response->code;
            if ( $code =~ m{^2\d\d} && !$self->response->content ) {
                return; # not sure what jdrago wanted this to do originally
            }
            else {
                if ( $self->_parse_errors() ) {
                    # die $self->friendly_error();
                }
                else {
                    return;
                }
            }
        }
    }
);

has 'response' => (
    is       => 'ro',
    isa      => 'HTTP::Response',
    required => 1,
);

has 'type' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has 'libxml' => (
    is       => 'ro',
    isa      => 'XML::LibXML',
    required => 1,
    default  => sub { return XML::LibXML->new() },
);

has 'error_code' => (
    is       => 'rw',
    isa      => 'Str',
    required => 0,
);

has 'error_message' => (
    is       => 'rw',
    isa      => 'Str',
    required => 0,
);

has 'xpc' => (
    is       => 'ro',
    isa      => 'XML::LibXML::XPathContext',
    required => 0,
    lazy    => 1,
    clearer => '_clear_xpc',
    default => sub {
        my ( $self ) = @_;

        my $src = $self->response->content;
        return unless $src =~ m/^[[:space:]]*</s;
        my $doc = $self->libxml->parse_string( $self->response->content );

        my $xpc = XML::LibXML::XPathContext->new( $doc );
        $xpc->registerNs( 's3', 'http://s3.amazonaws.com/doc/2006-03-01/' );

        return $xpc;
    }
);

has 'friendly_error' => (
    is       => 'ro',
    isa      => 'Maybe[Str]',
    lazy     => 1,
    required => 0,
    default  => sub {
        my $s = shift;

        return unless $s->error_code || $s->error_message;
        $s->type . " call had errors: [" . $s->error_code . "] " . $s->error_message;
    }
);

sub _parse_errors {
    my ( $s ) = @_;

    my $src = $s->response->content;

    # Do not try to parse non-xml:
    unless ( $src =~ m/^[[:space:]]*</s ) {
        ( my $code = $src ) =~ s/^[[:space:]]*\([0-9]*\).*$/$1/s;
        $s->error_code( $code );
        $s->error_message( $src );
        return 1;
    }    # end unless()

    $s->_clear_xpc;
    if ( $s->xpc->findnodes( "//Error" ) ) {
        $s->error_code( $s->xpc->findvalue( "//Error/Code" ) );
        $s->error_message( $s->xpc->findvalue( "//Error/Message" ) );
        return 1;
    }    # end if()

    return 0;
}    # end _parse_errors()

__PACKAGE__->meta->make_immutable;
