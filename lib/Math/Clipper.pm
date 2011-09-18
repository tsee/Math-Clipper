package Math::Clipper;

use 5.008;
use strict;
use warnings;
use Carp qw(croak carp);
use Config;

use Exporter();
our $VERSION = '1.00';
our @ISA = qw(Exporter);

require XSLoader;
XSLoader::load('Math::Clipper', $VERSION);

# TODO: keep in sync with docs below and xsp/Clipper.xsp

our %EXPORT_TAGS = (
    cliptypes     => [qw/CT_INTERSECTION CT_UNION CT_DIFFERENCE CT_XOR/],
    #polytypes     => [qw/PT_SUBJECT PT_CLIP/],
    polyfilltypes => [qw/PFT_EVENODD PFT_NONZERO/],
    utilities => [qw/area offset is_counter_clockwise integerize_coordinate_sets unscale_coordinate_sets/],
);

$EXPORT_TAGS{all} = [ map { @$_ } values %EXPORT_TAGS ];
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();

my %intspecs = (
    '64' => {
            maxint    => 9223372036854775806,   # signed 64 bit int range: -9223372036854775808 to 9223372036854775807; BUT Clipper seems to only work up to 9223372036854775806
            maxdigits => 19
            },
    '53' => {
            maxint    => 9007199254740992, # signed 53 bit integer max, for integers stored in double precision floats
            maxdigits => 16
            },
    '32' => {
            maxint    => 1500000000,   # Clipper-imposed max when 64 bit integer math not enabled
            maxdigits => 10
            },
    );

my $is64safe = ((defined($Config{use64bitint})   && $Config{use64bitint}   eq 'define') || $Config{longsize}   >= 8 ) &&
               ((defined($Config{uselongdouble}) && $Config{uselongdouble} eq 'define') || $Config{doublesize} >= 10);

sub offset {
	my $polygons = shift;
	my $delta = shift;
	my $scale = @_ ? shift:100;
	my $scalevec=[$scale,$scale];
	my $polyscopy=[(map {[(map {[(map {$_*=$scalevec->[0]} @{$_})]} @{$_})]} @{$polygons})];
	my $ret = _offset($polyscopy,$delta*$scale);
	unscale_coordinate_sets($scalevec , $ret) if @$ret;
	return $ret;
	}

sub unscale_coordinate_sets { # to undo what integerize_coordinate_sets() does
    my $scale_vector=shift;
    my $coord_sets=shift;
    my $coord_count=scalar(@{$coord_sets->[0]->[0]});
    if (!ref($scale_vector)) {$scale_vector=[(map {$scale_vector} (0..$coord_count-1))];}
    foreach my $set (@{$coord_sets}) {
        foreach my $vector (@{$set}) {
            for (my $ci=0;$ci<$coord_count;$ci++) {
                $vector->[$ci] /= $scale_vector->[$ci] if $scale_vector->[$ci]; # avoid divide by zero
                }
            }
        }
    }

sub integerize_coordinate_sets {
    my %opts=();
    if (ref($_[0]) =~ /HASH/) {%opts=%{(shift)};}
    $opts{constrain} =  1 if !defined($opts{constrain});
    $opts{bits}      = ($is64safe ? 64 : 53) if !defined($opts{bits});
	if ($opts{bits} == 64 && !$is64safe) {$opts{bits} = 53; carp "Integerize to 64 bits requires both long long and long double underlying Perl's default integer and double types. Using 53 bits instead.";}
    $opts{margin} =  0 if !defined($opts{margin});

    # assume all coordinate vectors (points) have same number of coordinates; get that count from first one
    my $coord_count=scalar(@{$_[0]->[0]});

    # return this with scaled data, so user can "unscale" Clipper results
    my @scale_vector;
    
    # deal with each coordinate "column" (eg. x column, y column, ... possibly more)
    for (my $ci=0;$ci<$coord_count;$ci++) {
        my $maxc=$_[0]->[0]->[$ci];
        my $max_exp;

        # go through all the coordinate sets, looking just at the current column
        foreach my $set (@_) {
            # for each "point"
            foreach my $vector (@{$set}) {
                # looking for the maximum magnitude
                if ($maxc<abs($vector->[$ci]) + $opts{margin}) {$maxc=abs($vector->[$ci]) + $opts{margin};}
                # looking for the maximum exponent, when coords are in scientific notation
                if (sprintf("%.20e",$vector->[$ci] + ($vector->[$ci]<0?-1:1)*$opts{margin}) =~ /[eE]([+-])0*(\d+)$/) {
                    my $exp1 = eval($1.$2);
                    if ($vector->[$ci] && (!defined($max_exp) || $max_exp<$exp1)) {$max_exp=$exp1} 
                    }
                else {croak "some coordinate didn't look like a number: ",$vector->[$ci]}
                }
            }

        # Set scale for this coordinate column to the largest value that will convert the
        # larges coordinate in the set to near the top of the available integer range.
        # There's never any question of how much precision the user wants -
        # we just always give as much as possible, within the integer limit in effect (53 bit or 64 bit)

        $scale_vector[$ci]=10**(-$max_exp + ($intspecs{$opts{bits}}->{maxdigits} - 1));

        if ($maxc * $scale_vector[$ci] > $intspecs{$opts{bits}}->{maxint}) {
            # Both 53 bit and 64 bit integers
            # have max values near 9*10**(16 or 19).
            # So usually you have 16 or 19 digits to use. 
            # But if your scaled-up max values enter the
            # zone just beyond the integer max, we'll only
            # scale up to 15 or 18 digit integers instead.

            $scale_vector[$ci]=10**(-$max_exp + ($intspecs{$opts{bits}}->{maxdigits} - 2));

            }
        }
    
    # If the "constrain" option is set false,
	# scaling is independent for each
    # coordinate column - all the Xs get one scale
    # all the Ys something else - to take the greatest
    # advantage of the available integer domain.
    # But if the "constrain" option is set true, we use
    # the minimum scale from all the coordinate columns.
    # The minimum scale is the one that will work
    # for all columns, without overflowing our integer limits.
    if ($opts{constrain}) {
        my $min_scale=(sort {$a<=>$b} @scale_vector)[0];
        @scale_vector = map {$min_scale} @scale_vector;
        }

    # Scale the original data
    foreach my $set (@_) {
        foreach my $vector (@{$set}) {
            for (my $ci=0;$ci<$coord_count;$ci++) {
                $vector->[$ci] *= $scale_vector[$ci];
                if (abs($vector->[$ci] < 1)) {$vector->[$ci] = sprintf("%.1f",$vector->[$ci]/10)*10;}
                }
            }
        }

    return \@scale_vector;
    }

1;
__END__

=head1 NAME

Math::Clipper - Polygon clipping in 2D

=head1 SYNOPSIS

 use Math::Clipper ':all';

 my $clipper = Math::Clipper->new;

 $clipper->add_subject_polygon( [ [-100,  100], [  0, -200], [100, 100] ] );
 $clipper->add_clip_polygon(    [ [-100, -100], [100, -100], [  0, 200] ] );
 my $result = $clipper->execute(CT_DIFFERENCE);
 # $result is now a reference to an array of three triangles

 $clipper->clear();
 # all data from previous operation cleared
 # object ready for reuse


 # Example with floating point coordinates:
 # Clipper requires integer input. 
 # These polygons won't work.

 my $poly_1 = [
               [-0.001, 0.001],
               [0, -0.002],
               [0.001, 0.001]
              ];
 my $poly_2 = [
               [-0.001, -0.001],
               [0.001, -0.001],
               [0, 0.002]
              ];

 # But we can have them automatically scaled up (in place) to a safe 32 bit integer range

 my $scale = integerize_coordinate_sets( $poly_1 , $poly_2 );
 $clipper->add_subject_polygon( $poly_1 );
 $clipper->add_clip_polygon(    $poly_2 );
 my $result = $clipper->execute(CT_DIFFERENCE);
 # to convert the results (in place) back to the original scale:
 unscale_coordinate_sets( $scale, $result );

 # Example using 32 bit integer math instead of 53 or 64
 # (less precision, a bit faster)
 my $clipper32 = Math::Clipper->new;
 $clipper32->use_full_coordinate_range(0);
 my $scale32 = integerize_coordinate_sets( { bits=>32 } , $poly_1 , $poly_2 );
 $clipper32->add_subject_polygon( $poly_1 );
 $clipper32->add_clip_polygon(    $poly_2 );
 my $result32 = $clipper->execute(CT_DIFFERENCE);
 unscale_coordinate_sets( $scale32, $result32 );


=head1 DESCRIPTION

C<Clipper> is a C++ (and Delphi) library that implements
polygon clipping.

=head2 Exports

The module optionally exports a few constants to your
namespace. Standard L<Exporter|Exporter> semantics apply
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

I<INTEGERS>: Clipper 4.x works with polygons with integer coordinates.
Data in floating point format will need to be scaled appropriately
to be converted to the available integer range before polygons are
added to a clipper object. (Scaling utilities are provided here.)

A I<Polygon> is represented by a reference to an array of 2D points.
A I<Point> is, in turn, represented by a reference to an array containing two
numbers: The I<X> and I<Y> coordinates. A 1x1 square polygon example:

  [ [0, 0],
    [1, 0],
    [1, 1],
    [0, 1] ]

Sets of polygons, as returned by the C<execute> method, 
are represented by an array reference containing 0 or more polygons.

Clipper also has a polygon type that explicitly associates an outer polygon with
any additional polygons that describe "holes" in the filled region of the
outer polygon. This is called an I<ExPolygon>. The data structure for 
an I<ExPolygon> is as follows,:

  { outer => [ <polygon> ],
    holes => [ 
               [ <polygon> ],
               [ <polygon> ],
               ...
             ]
  
  }

The "fill type" of a polygon refers to the strategy used to determine
which side of a polygon is the inside, and whether a polygon represents
a filled region, or a hole. You may optionally specify the fill type of
your subject and clip polygons when you call the C<execute> method.

When you specify the NONZERO fill type, the winding order of
polygon points determines whether a polygon is filled, or represents a hole.
Clipper uses the convention that counter clockwise wound polygons 
are filled, while clockwise wound polygons represent holes. This
strategy is more explicit, but requires that you manage winding order of all polygons.

The EVENODD fill type strategy uses a test segment, with it's start point inside a polygon,
and it's end point out beyond the bounding box of all polygons in question. All intersections 
between the segment and all polygons are calculated. If the intersection
count is odd, the inner-most (if nested) polygon containing the segment's start point is considered to be
filled. When the intersection count is even, that polygon is considered to be a hole.

For an example case in which NONZERO and EVENODD produce different results see 
L<NONZERO vs. EVENODD> section below.

=head1 METHODS

=head2 new

Constructor that takes no arguments returns a new
C<Math::Clipper> object.

=head2 use_full_coordinate_range

Clipper uses either 32 bit or 64 bit integers internally. As of version 4.3.0, 64 bit integer math is used by default.

Pass true to C<use_full_coordinate_range> to tell Clipper to use 64 bit math internally. 
Pass false to tell Clipper to use 32 bit math.

    $clipper->use_full_coordinate_range(0); # use 32 bit math

A typical Perl that supports 32 bit integers, can alternatively store 53 bit integers as floating point 
numbers. Some Perls are built to support 64 bit integers directly. To use the full range of either 53 
bit or 64 bit integers, pass "true" to the  C<use_full_coordinate_range> method.

    $clipper->use_full_coordinate_range(1); # default for Clipper 4.3.0

This will cost you a bit of time ( perhaps 15% more) but will give you the full signed integer range for your coordinates. For 64 bit, that's +/-9,223,372,036,854,775,807. For 53 bit it's +/-9,007,199,254,740,992.

When 64 bit math is not enabled within Clipper, coordinate values will be limited to +/-1,500,000,000.

Call this method before doing anything else with your new Clipper object.

=head2 add_subject_polygon

Adds a(nother) polygon to the set of polygons that
will be clipped.

=head2 add_clip_polygon

Adds a(nother) polygon to the set of polygons that
define the clipping operation.

=head2 add_subject_polygons

Works the same as C<add_subject_polygon> but
adds a whole set of polygons.

=head2 add_clip_polygons

Works the same as C<add_clip_polygon> but
adds a whole set of polygons.

=head2 execute

Performs the actual clipping operation.
Returns the result as a reference to an array of polygons.

    my $result = $clipper->execute( CT_UNION );

Parameters: the type of the clipping operation defined
by one of the constants (C<CF_*>).

Additionally, you may define the polygon fill types (C<PFT_*>)
of the subject and clipping polygons as second and third parameters
respectively. By default, even-odd filling (C<PFT_EVENODD>) will be
used.

    my $result = $clipper->execute( CT_UNION, PFT_EVENODD, PFT_EVENODD );

=head2 ex_execute

Like C<execute>, performs the actual clipping operation, but
returns a reference to an array of ExPolygons. (see L</CONVENTIONS>)

=head2 clear

For reuse of a C<Math::Clipper> object, you can call the
C<clear> method to remove all polygons and internal data from previous clipping operations.

=head1 UTILITY FUNCTIONS

=head2 integerize_coordinate_sets

Takes an array of polygons and scales all point coordinates so that the values
will fit in the integer range available. Returns an array reference containing the scaling factors
used for each coordinate column. The polygon data will be scaled in-place. The scaling vector is returned
so you can "unscale" the data when you're done, using C<unscale_coordinate_sets>.

    my $scale_vector = integerize_coordinate_sets( $poly1 , $poly2 , $poly3 );

The main purpose of this function is to convert floating point coordinate data to integers.
As of Clipper version 4, only integer coordinate data is allowed. This helps make the 
intersection algorithm robust, but it's a bit inconvenient if your data is in floating point format.

This utility function is meant to make it easy to convert your data to Clipper-friendly integers, while
retaining as much precision as possible. When you're done with your clipping operations, you can use the
C<unscale_coordinate_sets> function to scale results back to your original scale.

Convert all your polygons at once, with one call to C<integerize_coordinate_sets>, before loading the
polygons into your clipper object. The scaling factors need to be calculated so that all
polygons involved fit in the available integer space.

By default, the scaling is uniform between coordinate columns (e.g., the X values are scaled by the same
factor as the Y values) making all the scaling factors returned the same. In other words, by default, the aspect ratio
between X and Y is constrained.

Options may be passed in an anonymous hash, as the first argument, to override defaults.
If the first argument is not a hash reference, it is taken instead as the first polygon to be scaled.

    my $scale_vector = integerize_coordinate_sets( {
                                                    constrain => 0, # don't do uniform scaling
                                                    bits => 32     # use the +/- 1,500,000,000 integer range
                                                    },
                                                    $poly1 , $poly2 , $poly3
                                                 );

The C<bits> option can be 32, 53, or 64. The default will be 53 or 64, depending on whether your
Perl uses 64 bit integers AND long doubles by default. (The scaling involves math with native doubles,
so it's not enough to just have 64 bit integers.)

Be sure to set the C<bits> option to 32 when you have told Clipper
to use 32 bit integer math internally, using the C<use_full_coordinate_range> method.

The C<constrain> option is a boolean. Default is true. When set to false, each
column of coordinates (X, Y) will be scaled independently. This may be useful
when the domain of the X values is very much larger or smaller than the domain
of the Y values, to get better resolution for the smaller domain. The different scaling
factors will be available in the returned scaling vector (array reference).

This utility will also operate on coordinates with three or more dimensions. Though the context here
is 2D, be aware of this if you happen to feed it 3D data. Large domains in the higher dimensions
could squeeze the 2D data to nothing if scaling is uniform.

=head2 unscale_coordinate_sets

This undoes the scaling done by C<integerize_coordinate_sets>. Use this on the polygons returned
by the C<execute> method. Pass the scaling vector returned by C<integerize_coordinate_sets>, and 
the polygons to "unscale". The polygon coordinates will be updated in place.

    unscale_coordinate_sets($scale,$clipper_result);

=head2 offset

Takes a reference to an array of polygons, a positive or negative offset dimension, and, optionally, a scaling factor.

The polygons will use the NONZERO fill strategy, so filled areas and holes can be specified by polygon winding order. 

A positive offset dimension makes filled polygons grow outward, and their holes shrink.
A negative offset makes polygons shrink and their holes grow.

Coordinates will be multiplied by the scaling factor before the offset operation and the results divided by the scaling factor.
The default scaling factor is 100. Setting the scaling factor higher will result in more points and smoother contours in the offset results.

Returns a new set of polygons, offset by the given dimension.

    my $offset_polygons = offset($polygon, 5.5); # offset by 5.5
        or
    my $offset_polygons = offset($polygon, 5.5, 1000); # smoother results, proliferation of points

B<WARNING: >As you increase the scaling factor, the number of points grows quickly, and will happily consume all of your RAM.
Large offset dimensions also contribute to a proliferation of points.

Floating point data in the input is acceptable - in that case, the scaling factor also 
determines how many decimal digits you'll get in the results. It is not necessary,
and generally not desirable to use C<integerize_coordinate_sets> to prepare data for this function.

When doing negative offsets, you may find the winding order of the results to be the opposite 
of what you expect. Check it and change it if winding order is important in your application.

=head2 area

Returns the signed area of a single polygon.
A counter clockwise wound polygon area will be positive.
A clockwise wound polygon area will be negative.
Coordinate data should be integers.

    $area = area($polygon);

=head2 is_counter_clockwise

Determine if a polygon is wound counter clockwise. Returns true if it is, false if it isn't. Coordinate data should be integers.

    $poly = [ [0, 0] , [2, 0] , [1, 1] ]; # a counter clockwise wound polygon
    $direction = is_counter_clockwise($poly);
    # now $direction == 1

=head1 NONZERO vs. EVENODD

Consider the following example:

    my $p1 = [ [0,0], [200000,0], [200000,200000]             ];   # CCW
    my $p2 = [ [0,200000], [0,0], [200000,200000]             ];   # CCW
    my $p3 = [ [0,0], [200000,0], [200000,200000], [0,200000] ];   # CCW

    my $clipper = Math::Clipper->new;
    $clipper->add_subject_polygon($p1);
    $clipper->add_clip_polygons([$p2, $p3]);
    my $result = $clipper->execute(CT_UNION, PFT_EVENODD, PFT_EVENODD);

C<$p3> is a square, and C<$p1> and C<$p2> are triangles covering two halves of the C<$p3> area.
The C<CT_UNION> operation will produce different results if C<PFT_EVENODD> or C<PFT_NONZERO>
are used. This is because of the strategy used by Clipper to identify overlapping regions.

Let's see the thing in detail: C<$p2> and C<$p3> are the clip polygons. C<$p2> overlaps half of C<$p3>. 
With the C<PFT_EVENODD> hole detection method, how many polygons overlap in a gievn area determines 
whether that area is a hole or a filled region. If an odd number of polygons overlap there, it's a 
filled region. If an even number, it's a hole/empty region. So with C<PFT_EVENODD>, winding order 
doesn't matter. What matters is where things overlap.

So using C<PFT_EVENODD>, and considering C<$p2> and C<$p3> as the set of clipping polygons, the fact that 
C<$p2> overlaps half of C<$p3> means that the region where they overlap is empty. In effect, in this example, 
the set of clipping polygons ends up defining the same shape as the subject polygon C<$p1>. So the union 
is just the union of two identical polygons.

When you switch it to use C<PFT_NONZERO>, the set of clipping polygons is understood as two filled 
polygons, because of the winding order. The area where they overlap is considered filled, just 
because there is at least one filled polygon in that area. This is a good example of how C<PFT_NONZERO> 
is more explicit, and perhaps more intuitive.

=head1 SEE ALSO

The SourceForge project page of Clipper:

L<http://sourceforge.net/projects/polyclipping/>

=head1 VERSION

This module was built around, and includes, Clipper version 4.3.0.

=head1 AUTHOR

The Perl module was written by:

Steffen Mueller (E<lt>smueller@cpan.orgE<gt>) and
Mike Sheldrake

But the underlying library C<Clipper> was written by
Angus Johnson. Check the SourceForge project page for
contact information.

=head1 COPYRIGHT AND LICENSE

The C<Math::Clipper> module is

Copyright (C) 2010, 2011 by Steffen Mueller

Copyright (C) 2011 by Mike Sheldrake


but we are shipping a copy of the C<Clipper> C++ library, which
is

Copyright (C) 2010, 2011 by Angus Johnson.

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
