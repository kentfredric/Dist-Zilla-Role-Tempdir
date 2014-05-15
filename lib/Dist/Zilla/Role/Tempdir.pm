use strict;
use warnings;

package Dist::Zilla::Role::Tempdir;

# ABSTRACT: Shell Out and collect the result in a DZ plug-in.

# AUTHORITY

use Moose::Role;
use Path::Tiny qw(path);
use Dist::Zilla::Tempdir::Dir;
use namespace::autoclean;

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

=cut

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


=cut

sub capture_tempdir {
  my ( $self, $code, $args ) = @_;

  $args = {} unless defined $args;
  $code = sub { }
    unless defined $code;

  my $tdir = Dist::Zilla::Tempdir::Dir->new();

  my $dzil = $self->zilla;

  for my $file ( @{ $dzil->files } ) {
    $tdir->add_file($file);
  }

  $tdir->run_in($code);

  $tdir->update_input_files;
  $tdir->update_disk_files;

  return $tdir->all_output_files;
}

=head1 SEE ALSO

=over 4

=item * L<< C<Dist::Zilla::Tempdir::Item>|Dist::Zilla::Tempdir::Item >>

=back

=cut

no Moose::Role;
1;

