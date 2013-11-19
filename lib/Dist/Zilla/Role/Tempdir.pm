use strict;
use warnings;

package Dist::Zilla::Role::Tempdir;
BEGIN {
  $Dist::Zilla::Role::Tempdir::AUTHORITY = 'cpan:KENTNL';
}
{
  $Dist::Zilla::Role::Tempdir::VERSION = '0.01053723';
}

# ABSTRACT: Shell Out and collect the result in a DZ plug-in.

use Moose::Role;
use Digest::SHA;
use File::Tempdir;
use Path::Tiny qw(path);
use File::chdir;
use Path::Iterator::Rule;
use Dist::Zilla::File::InMemory;
use Dist::Zilla::Tempdir::Item;

use namespace::autoclean;



sub capture_tempdir {
  my ( $self, $code, $args ) = @_;

  $args = {} unless defined $args;
  $code = sub { }
    unless defined $code;

  my ($dzil);

  $dzil = $self->zilla;

  my ( $tempdir, $dir );
  $tempdir = File::Tempdir->new();
  $dir     = path( $tempdir->name );

  require Dist::Zilla::Tempdir::Item::State;

  my %input_files;

  for my $file ( @{ $dzil->files } ) {
    my $state = Dist::Zilla::Tempdir::Item::State->new(
      file           => $file,
      storage_prefix => $dir,
    );
    $state->write_out;
    $input_files{ $state->name } = $state;
  }
  {
    ## no critic ( ProhibitLocalVars )
    local $CWD = $dir;
    $code->();
  }

  my (@files) = Path::Iterator::Rule->new->file->all($dir);

  my %output_files;

  for my $file ( values %input_files ) {
    my $update_item = Dist::Zilla::Tempdir::Item->new( name => $_->name, file => $_->file, );
    $update_item->set_original;

    if ( not $file->on_disk ) {
      $update_item->set_deleted;
    }
    elsif ( $file->on_disk_changed ) {
      $update_item->set_modified;
      my %params = ( name => $file->name, content => $file->new_content );
      if ( Dist::Zilla::File::InMemory->can('encoded_content') ) {
        $params{encoded_content} = delete $params{content};
      }
      $update_item->file( Dist::Zilla::File::InMemory->new(%params) );
    }
    $output_files{ $file->name } = $update_item;
  }

  for my $filename (@files) {
    my $shortname = path($filename)->relative($dir);
    next if exists $output_files{$shortname};

    # FILE (N)ew
    my %params = ( name => $shortname, content => $shortname->slurp_raw );
    if ( Dist::Zilla::File::InMemory->can('encoded_content') ) {
      $params{encoded_content} = delete $params{content};
    }
    $output_files{$shortname} = Dist::Zilla::Tempdir::Item->new(
       name => $shortname,
      file => Dist::Zilla::File::InMemory->new(%params)
    );
    $output_files{$shortname}->set_new;
  }

  return values %output_files;
}


no Moose::Role;
1;

__END__

=pod

=head1 NAME

Dist::Zilla::Role::Tempdir - Shell Out and collect the result in a DZ plug-in.

=head1 VERSION

version 0.01053723

=head1 SYNOPSIS

  package #
    Dist::Zilla::Plugin::FooBar;

  use Moose;
  with 'Dist::Zilla::Role::Tempdir';
  with 'Dist::Zilla::Role::FileInjector';
  with 'Dist::Zilla::Role::InstallTool';

  sub setup_installer {
    my ( $self, $arg ) = @_ ;

    my ( @generated_files ) = $self->capture_tempdir(sub{
      system( $somecommand );
    });

    for ( @generated_files ) {
      if( $_->is_new && $_->name =~ qr/someregex/ ){
        $self->add_file( $_->file );
      }
    }
  }

This role is a convenience role for factoring into other plug-ins to use the power of Unix
in any plug-in.

If for whatever reason you need to shell out and run your own app that is not Perl ( i.e.: Java )
to go through the code and make modifications, produce documentation, etc, then this role is for you.

Important to note however, this role B<ONLY> deals with getting C<Dist::Zilla>'s state written out to disk,
executing your given arbitrary code, and then collecting the results. At no point does it attempt to re-inject
those changes back into L<< C<Dist::Zilla>|Dist::Zilla >>. That is left as an exercise to the plug-in developer.

=head1 METHODS

=head2 capture_tempdir

Creates a File::Tempdir and dumps the current state of Dist::Zilla's files into it.

Runs the specified code sub C<chdir>'ed into that C<tmpdir>, and captures the changed files.

  my ( @array ) = $self->capture_tempdir(sub{

  });

Response is an array of L<< C<::Tempdir::Item>|Dist::Zilla::Tempdir::Item >>

   [ bless( { name => 'file/Name/Here' ,
      status => 'O' # O = Original, N = New, M = Modified, D = Deleted
      file   => Dist::Zilla::Role::File object
    }, 'Dist::Zilla::Tempdir::Item' ) , bless ( ... ) ..... ]

Make sure to look at L<< C<Dist::Zilla::Tempdir::Item>|Dist::Zilla::Tempdir::Item >> for usage.

=head1 SEE ALSO

=over 4

=item * L<< C<Dist::Zilla::Tempdir::Item>|Dist::Zilla::Tempdir::Item >>

=back

=head1 AUTHOR

Kent Fredric <kentnl@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Kent Fredric.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
