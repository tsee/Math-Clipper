package Math::Clipper;

use 5.008;
use strict;
use warnings;
use Carp 'croak';

use Exporter();
our $VERSION = '0.01';
our @ISA = qw(Exporter);

require XSLoader;
XSLoader::load('Math::Clipper', $VERSION);

# TODO: keep in sync with docs below and xsp/Clipper.xsp

our %EXPORT_TAGS = (
    cliptypes     => [qw/CT_INTERSECTION CT_UNION CT_DIFFERENCE CT_XOR/],
    #polytypes     => [qw/PT_SUBJECT PT_CLIP/],
    polyfilltypes => [qw/PFT_EVENODD PFT_NONZERO/],
);

$EXPORT_TAGS{all} = [ map { @$_ } values %EXPORT_TAGS ];
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();


1;
__END__

=head1 NAME

Math::Clipper - Polygon clipping in 2D

=head1 SYNOPSIS

  use Math::Clipper ':all';
  my $clipper = Math::Clipper->new;
  
  # Add the polygon to-be-clipped
  $clipper->add_subject_polygon(
    [ [$x1, $y1],
      [$x2, $y2],
      ...
    ],
  );

  # Add the polygon that defines the clipping
  $clipper->add_clip_polygon(
    [ [$x1, $y1],
      [$x2, $y2],
      ...
    ],
  );
  
  # Run the clipping operation
  my $result = $clipper->execute(CT_INTERSECTION);
  # $result is array ref containing 0 or more
  # polygons (themselves array refs as above) that represent
  # the intersection between the subject and the clipping
  # polygon(s)

=head1 DESCRIPTION

C<Clipper> is a C++ (and Delphi) library that implements
polygon clipping.

=head2 Exports

The module optionally exports a few constants to your
namespace. Standard L<Exporter> semantics apply
(including the C<:all> tag).

The list of exportable constants is comprised of
the clip operation types (which should be self-explanatory):

    CT_INTERSECTION
    CT_UNION
    CT_DIFFERENCE
    CT_XOR

Additionally, there are constants that set the polygon fill type
during the clipping operation:

    PFT_EVENODD
    PFT_NONZERO

=head1 CONVENTIONS

When the documentation refers to a I<polygon>, this
technically means a reference to an array of points
in 2D space. Such points are, in turn,
represented by an array (reference) containing two
numbers: The I<X> and I<Y> coordinates. An example
of this would be for a 1x1 square:

  [ [0, 0],
    [1, 0],
    [1, 1],
    [0, 1] ]

Furthermore, a poly-polygon (which is the name that C<Clipper>
uses) is a set of polygons, represented (again) by an array
(reference) containing 0 or more polygons.

=head1 METHODS

=head2 new

Constructor that takes no arguments returns a new
C<Math::Clipper> object.

=head2 add_subject_polygon

Adds a(nother) polygon to the set of polygons that
will be clipped.

=head2 add_clip_polygon

Adds a(nother) polygon to the set of polygons that
define the clipping operation.

=head2 add_subject_poly_polygon

Works the same as C<add_subject_polygon> but
adds a whole set of polygons (a poly-polygon in C<Clipper>
terminology).

=head2 add_clip_poly_polygon

Works the same as C<add_clip_polygon> but
adds a whole set of polygons (a poly-polygon in C<Clipper>
terminology).

=head2 execute

Performs the actual clipping operation.
Returns the result as a poly-polygon (cf. L</CONVENTIONS>).

Parameters: the type of the clipping operation defined
by one of the constants (C<CF_*>).

Additionally, you may define the polygon fill types (C<PFT_*>)
of the subject and clipping polygons as second and third parameters
respectively. By default, even-odd filling (C<PFT_EVENODD>) will be
used.

=head2 clear

For reuse of a C<Math::Clipper> object, you can call the
C<clear> method to remove all stashed polygons.

=head2 set_force_orientation

Quoting the C<Clipper> documentation:

  The ForceOrientation property is only useful when operating on simple
  polygons. It ensures that the simple polygons that result from a
  TClipper.Execute() calls will have clockwise 'outer' and counter-clockwise
  'inner' (or 'hole') polygons. If ForceOrientation == false, then the
  polygons returned in the solution will have undefined orientation.<br>
  The only disadvantage in setting ForceOrientation = true is it will result
  in a very minor penalty (~10%) in execution speed. (Default == true)

=head2 get_force_orientation

Returns the state of the C<ForceOrientation> property.

=head1 SEE ALSO

The SourceForge project page of Clipper:

L<http://sourceforge.net/projects/polyclipping/>

=head1 AUTHOR

The Perl module was written by:

Steffen Mueller, E<lt>smueller@cpan.orgE<gt>

But the underlying library C<Clipper> was written by
Angus Johnson. Check the SourceForge project page for
contact information.

=head1 COPYRIGHT AND LICENSE

The C<Math::Clipper> module is

Copyright (C) 2010 by Steffen Mueller

but we are shipping a copy of the C<Clipper> C++ library, which
is

Copyright (C) 2010 by Angus Johnson.

C<Math::Clipper> is available under the same
license as C<Clipper> itself. This is the C<boost> license:

  Boost Software License - Version 1.0 - August 17th, 2003
  http://www.boost.org/LICENSE_1_0.txt
  
  Permission is hereby granted, free of charge, to any person or organization
  obtaining a copy of the software and accompanying documentation covered by
  this license (the "Software") to use, reproduce, display, distribute,
  execute, and transmit the Software, and to prepare derivative works of the
  Software, and to permit third-parties to whom the Software is furnished to
  do so, all subject to the following:
  
  The copyright notices in the Software and this entire statement, including
  the above license grant, this restriction and the following disclaimer,
  must be included in all copies of the Software, in whole or in part, and
  all derivative works of the Software, unless such copies or derivative
  works are solely in the form of machine-executable object code generated by
  a source language processor.
  
  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE, TITLE AND NON-INFRINGEMENT. IN NO EVENT
  SHALL THE COPYRIGHT HOLDERS OR ANYONE DISTRIBUTING THE SOFTWARE BE LIABLE
  FOR ANY DAMAGES OR OTHER LIABILITY, WHETHER IN CONTRACT, TORT OR OTHERWISE,
  ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
  DEALINGS IN THE SOFTWARE.

=cut
