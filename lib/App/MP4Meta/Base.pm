use 5.010;
use strict;
use warnings;

package App::MP4Meta::Base;

# ABSTRACT: Base class. Contains common functionality.

use Module::Load ();
use Try::Tiny;
use AtomicParsley::Command;

sub new {
    my $class = shift;
    my $args  = shift;
    my $self  = {};

    # the path to AtomicParsley
    $self->{'ap'} = AtomicParsley::Command->new( { ap => $args->{'ap'} } );

    # if true, replace file
    $self->{'noreplace'} = $args->{'noreplace'};

    # if true, print verbosely
    $self->{'verbose'} = $args->{'verbose'};

    # internet sources
    $self->{'sources'} = $args->{'sources'};

    # common attributes for a media file
    $self->{'genre'}     = $args->{'genre'};
    $self->{'title'}     = $args->{'title'};
    $self->{'coverfile'} = $args->{'coverfile'};

    bless( $self, $class );

    # create sources now so they are in scope for as long as we are
    $self->{'sources_objects'} = [];
    for my $source ( @{ $self->{'sources'} } ) {
        try {
            push( @{ $self->{'sources_objects'} },
                $self->_new_source($source) );
        }
        catch {
            say STDERR "could not load source: $_";
        };
    }

    return $self;
}

# Calls AtomicParsley and writes the tags to the file
sub _write_tags {
    my ( $self, $path, $tags ) = @_;

    my $tempfile = $self->{ap}->write_tags( $path, $tags, !$self->{noreplace} );

    if ( !$self->{ap}->{success} ) {
        return $self->{ap}->{'stdout_buf'}[0] // $self->{ap}->{'full_buf'}[0];
    }

    if ( !$tempfile ) {
        return "Error writing to file";
    }

    return;
}

# Converts 'THE_OFFICE' to 'The Office'
sub _clean_title {
    my ( $self, $title ) = @_;

    $title =~ s/(-|_)/ /g;
    $title =~ s/(?<=\w)\.(?=\w)/ /g;
    $title = lc($title);
    $title = join ' ', map( { ucfirst() } split /\s/, $title );

    return $title;
}

sub _new_source {
    my ( $self, $source ) = @_;
    my $module = 'App::MP4Meta::Source::' . $source;
    Module::Load::load($module);
    return $module->new;
}

1;

=head1 SYNOPSIS

  my $film = App::MP4Meta::Base->new( ap => 'path/to/ap' );
  $film->apply_meta( '/path/to/The_Truman_Show.m4v' );
  
=method new( %args )

Create new object. Takes the following arguments:

=for :list
* ap - Path to the AtomicParsley command. Optional.
* noreplace - If true, do not replace file, but save to temp instead