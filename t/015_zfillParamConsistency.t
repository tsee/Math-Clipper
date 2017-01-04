use strict;
use warnings;

use Math::Clipper ':all';
use List::Util qw(max min);
use Test::More tests => 28128;

SKIP: {
    skip 'not compiled with z support', 28128 unless Math::Clipper::has_z;

my $pi = 3.141592653589793238462643383279502884197169399375105820974944592308;

my $clipper = Math::Clipper->new();

my $scale = 1000000;

# SEE COMMENTS AT END FOR ILLUSTRATION OF HOW THESE
# INTERSECTING TEST SQUARES ARE USED.

# two overlapping counter clockwise squares
my $p1_ccw = [
    [ 0,  0, 1],
    [10,  0, 2],
    [10, 10, 3],
    [ 0, 10, 4],
];
my $p2_ccw = [
    [ 5,  5, 5],
    [15,  5, 6],
    [15, 15 ,7],
    [ 5, 15 ,8],
];

# Make copies of those squares, but clockwise, still starting on the
# same point, and with z values reassigned to match the new sequence.
# Make sure you make fresh copies of every point and it's coords.

my $p1_cw = [[@{$p1_ccw->[0]}],(map [@$_], reverse @{$p1_ccw}[1 .. $#{$p1_ccw}])];
$p1_cw->[$_]->[2] = ($_ + 1) for (0 .. $#{$p1_cw});
my $p2_cw = [[@{$p2_ccw->[0]}],(map [@$_], reverse @{$p2_ccw}[1 .. $#{$p2_ccw}])];
$p2_cw->[$_]->[2] = ($_ + 5) for (0 .. $#{$p2_cw});

# These are our expected intersection arrangements for all four
# combinations of the ccw and cw squares - the intersection point
# and a pair of Z values representing the edges that intersect.

#                              point zinds zinds    point zinds zinds
my $intersections_ccw_ccw = [[[10,5],[2,3],[5,6]],[[5,10],[3,4],[8,5]]];
my $intersections_ccw_cw  = [[[10,5],[2,3],[8,5]],[[5,10],[3,4],[5,6]]];
my $intersections_cw_ccw  = [[[10,5],[3,4],[5,6]],[[5,10],[2,3],[8,5]]];
my $intersections_cw_cw   = [[[10,5],[3,4],[8,5]],[[5,10],[2,3],[5,6]]];

# See comments at end that illustrate these test rotations.
# The first two should cover the 4 possible edge combinations.
# The second two should duplicate those 4 edge combo cases,
# but with different edges, in different quandrants.

my @test_rotations = ( -$pi/4,   $pi/4,
                      3*$pi/4, 5*$pi/4 );


# Now we set up a bunch of test where we use different combinations
# of those clockwise and counterclockwise wound intersecting polygons,
# rotating the tests (and expected intersection results) into several
# positions, to make sure that Clipper provides consistent, or at
# least predictable, edge point data to zfill functions. We'll also 
# test whether our zfill functions that do similar things (like 
# returning min/max z values) are consistent with each other.

# First, a small set of tests:

# Often we achieve our polygon boolean operations by using an
# appropriate winding convention on our input polygons, putting them
# all in Clippers "subject" collection, and executing a UNION with
# an appropriate fill type set for the "subjects". These tests are
# for those four UNION+FILLTYPE cases.
my $windcombos_for_allinsubj = [
    [[ map {rot_case([$p1_ccw,$p2_ccw],[],$intersections_ccw_ccw,$_)} @test_rotations], 'ccw,ccw'],
    [[ map {rot_case([$p1_ccw,$p2_cw ],[],$intersections_ccw_cw ,$_)} @test_rotations], 'ccw,cw' ],
    [[ map {rot_case([$p1_cw ,$p2_ccw],[],$intersections_cw_ccw ,$_)} @test_rotations], 'cw,ccw' ],
    [[ map {rot_case([$p1_cw ,$p2_cw ],[],$intersections_cw_cw  ,$_)} @test_rotations], 'cw,cw'  ]
];

docaseset($_->[0], [CT_UNION,PFT_POSITIVE,0], 'UNION (all in subjects), POSITIVE, '.$_->[1]) for @$windcombos_for_allinsubj;
docaseset($_->[0], [CT_UNION,PFT_NEGATIVE,0], 'UNION (all in subjects), NEGATIVE, '.$_->[1]) for @$windcombos_for_allinsubj;
docaseset($_->[0], [CT_UNION,PFT_NONZERO ,0], 'UNION (all in subjects), NONZERO, ' .$_->[1]) for @$windcombos_for_allinsubj;
docaseset($_->[0], [CT_UNION,PFT_EVENODD ,0], 'UNION (all in subjects), EVENODD, ' .$_->[1]) for @$windcombos_for_allinsubj;


# Then, many more tests

# Test all clip types, with every combo of subject and clip
# poly fill type.
#
# 64 cases times however many polygon winding combos and
# test rotations we have - something like 2048 cases.
#
# Some will have no results, but do you really want to figure which
# for that many cases? Just run everything.
#
# Mainly we're looking for consistency in:
# * what Clipper provides to zfill functions
#   - edges/points always have same geometric arrangement
# * what our own zfill functions do

my $windcombos = [
    [[ map {rot_case([$p1_ccw],[$p2_ccw],$intersections_ccw_ccw,$_)} @test_rotations], 'ccw,ccw'],
    [[ map {rot_case([$p1_ccw],[$p2_cw ],$intersections_ccw_cw ,$_)} @test_rotations], 'ccw,cw' ],
    [[ map {rot_case([$p1_cw ],[$p2_ccw],$intersections_cw_ccw ,$_)} @test_rotations], 'cw,ccw' ],
    [[ map {rot_case([$p1_cw ],[$p2_cw ],$intersections_cw_cw  ,$_)} @test_rotations], 'cw,cw'  ]
];

for my $ct ('UNION','DIFFERENCE','INTERSECTION','XOR') {
    for my $spft ('POSITIVE','NEGATIVE','NONZERO','EVENODD') {
        for my $cpft ('POSITIVE','NEGATIVE','NONZERO','EVENODD') {
            for my $windcombo (@$windcombos) {
                docaseset($windcombo->[0], 
                      # clipper options
                      [eval('CT_'.$ct),
                       eval('PFT_'.$spft),
                       eval('PFT_'.$cpft)
                      ],
                      # case set label
                      "$ct, $spft, $cpft, " . $windcombo->[1]
               );
           }
        }
    }
}


sub docaseset {
    my $cases = shift;
    my $clipper_exe_options = shift;
    my $case_set_name = shift;

    foreach my $case (@$cases) {
        my $subjects = $case->[0];
        my $clips    = $case->[1];
        my @expect_intersections = @{$case->[2]};
        my $case_name = $case->[3];

        #diag("\n#################################\n",
        #     "CASE: ",$case_set_name,", ",$case_name);

        # point_data array is 1-based index, since default Z value for intersections
        # is 0, which would be ambiguous if we had specific point data at index 0
        my @point_data = (0, (sort {$a->[2]<=>$b->[2]} (map @$_, (@$subjects, @$clips))));

        # make sure we've setup correctly - ensure each point's 
        # Z value corresponds to the point's index in point_data array
        ok(0 == scalar( grep {$point_data[$_]->[2] != $_} (1 .. $#point_data) ),"bad Z value setup");

        my @scaled_subjects = map [map [$_->[0]*$scale,$_->[1]*$scale,$_->[2]], @$_], @$subjects;
        my @scaled_clips    = map [map [$_->[0]*$scale,$_->[1]*$scale,$_->[2]], @$_], @$clips;

        # with zfill ZFT_ALL_UINT16 - gives us all four edge point
        # values available to the zfill callback for each intersection
        # - use to to check Clipper's consistancy of edge end point
        # order, and then to check consistancy with our other zfill
        # functions.
        $clipper->add_subject_polygons(\@scaled_subjects);
        $clipper->add_clip_polygons(\@scaled_clips) if scalar(@scaled_clips) > 0;
        my $results = $clipper->execute(@$clipper_exe_options,ZFT_ALL_UINT16);
        $clipper->clear();
        @$results = map [map [$_->[0]/$scale,$_->[1]/$scale,$_->[2]], @$_], @$results;
        my @results_without_z = map [map [@{$_}[0,1]], @$_], @$results;

        # with zfill ZFT_BOTH_MAX_FLAGS
        $clipper->add_subject_polygons(\@scaled_subjects);
        $clipper->add_clip_polygons(\@scaled_clips) if scalar(@scaled_clips) > 0;
        my $results_ZFT_BOTH_MAX_FLAGS = $clipper->execute(@$clipper_exe_options,ZFT_BOTH_MAX_FLAGS);
        $clipper->clear();
        @$results_ZFT_BOTH_MAX_FLAGS = map [map [$_->[0]/$scale,$_->[1]/$scale,$_->[2]], @$_], @$results_ZFT_BOTH_MAX_FLAGS;
        is_deeply(\@results_without_z,[map [map [@{$_}[0,1]], @$_], @$results_ZFT_BOTH_MAX_FLAGS],'same intersections for same input, ZFT_ALL_UINT16 vs ZFT_BOTH_MAX_FLAGS');
        
        # with zfill ZFT_BOTH_MAX
        $clipper->add_subject_polygons(\@scaled_subjects);
        $clipper->add_clip_polygons(\@scaled_clips) if scalar(@scaled_clips) > 0;
        my $results_ZFT_BOTH_MAX = $clipper->execute(@$clipper_exe_options,ZFT_BOTH_MAX);
        $clipper->clear();
        @$results_ZFT_BOTH_MAX = map [map [$_->[0]/$scale,$_->[1]/$scale,$_->[2]], @$_], @$results_ZFT_BOTH_MAX;
        is_deeply(\@results_without_z,[map [map [@{$_}[0,1]], @$_], @$results_ZFT_BOTH_MAX],'same intersections for same input, ZFT_ALL_UINT16 vs ZFT_BOTH_MAX');

        # with zfill ZFT_BOTH_MIN
        $clipper->add_subject_polygons(\@scaled_subjects);
        $clipper->add_clip_polygons(\@scaled_clips) if scalar(@scaled_clips) > 0;
        my $results_ZFT_BOTH_MIN = $clipper->execute(@$clipper_exe_options,ZFT_BOTH_MIN);
        $clipper->clear();
        @$results_ZFT_BOTH_MIN = map [map [$_->[0]/$scale,$_->[1]/$scale,$_->[2]], @$_], @$results_ZFT_BOTH_MIN;
        is_deeply(\@results_without_z,[map [map [@{$_}[0,1]], @$_], @$results_ZFT_BOTH_MIN],'same intersections for same input, ZFT_ALL_UINT16 vs ZFT_BOTH_MIN');

        # with zfill ZFT_MAX
        $clipper->add_subject_polygons(\@scaled_subjects);
        $clipper->add_clip_polygons(\@scaled_clips) if scalar(@scaled_clips) > 0;
        my $results_ZFT_MAX = $clipper->execute(@$clipper_exe_options,ZFT_MAX);
        $clipper->clear();
        @$results_ZFT_MAX = map [map [$_->[0]/$scale,$_->[1]/$scale,$_->[2]], @$_], @$results_ZFT_MAX;
        is_deeply(\@results_without_z,[map [map [@{$_}[0,1]], @$_], @$results_ZFT_MAX],'same intersections for same input, ZFT_ALL_UINT16 vs ZFT_MAX');

        # with zfill ZFT_MIN
        $clipper->add_subject_polygons(\@scaled_subjects);
        $clipper->add_clip_polygons(\@scaled_clips) if scalar(@scaled_clips) > 0;
        my $results_ZFT_MIN = $clipper->execute(@$clipper_exe_options,ZFT_MIN);
        $clipper->clear();
        @$results_ZFT_MIN = map [map [$_->[0]/$scale,$_->[1]/$scale,$_->[2]], @$_], @$results_ZFT_MIN;
        is_deeply(\@results_without_z,[map [map [@{$_}[0,1]], @$_], @$results_ZFT_MIN],'same intersections for same input, ZFT_ALL_UINT16 vs ZFT_MIN');

        my @intersection_inds;
        for (my $polyi=0;$polyi<@$results;$polyi++) {
            for (my $pointi=0;$pointi<@{$results->[$polyi]};$pointi++) {
                push(@intersection_inds, [$polyi,$pointi]) if extract_all_uint16($results->[$polyi]->[$pointi]->[2]);
            }
        }

        my @result_intersections =
            grep $_->[2], map [$_->[0],$_->[1],extract_all_uint16($_->[2])], 
            #map {warn "x: ",$_->[0],"\n";$_}
            map @$_, @$results;
        my @result_intersections_ZFT_BOTH_MAX_FLAGS = 
            grep $_->[2], map [$_->[0],$_->[1],extract_both_max_flags($_->[2])], 
            #map {warn "x: ",$_->[0],"\n";$_}
            map @$_, @$results_ZFT_BOTH_MAX_FLAGS;
        my @result_intersections_ZFT_BOTH_MAX = 
            grep $_->[2], map [$_->[0],$_->[1],extract_both($_->[2])], 
            #map {warn "x: ",$_->[0],"\n";$_}
            map @$_, @$results_ZFT_BOTH_MAX;
        my @result_intersections_ZFT_BOTH_MIN = 
            grep $_->[2], map [$_->[0],$_->[1],extract_both($_->[2])], 
            #map {warn "x: ",$_->[0],"\n";$_}
            map @$_, @$results_ZFT_BOTH_MIN;
        my @result_intersections_ZFT_MAX = 
            map $results_ZFT_MAX->[$_->[0]]->[$_->[1]],
            #map {warn "x: ",$results_ZFT_MAX->[$_->[0]]->[$_->[1]]->[0],"\n";$results_ZFT_MAX->[$_->[0]]->[$_->[1]]}
            @intersection_inds;
        my @result_intersections_ZFT_MIN = 
            map $results_ZFT_MIN->[$_->[0]]->[$_->[1]],
            #map {warn "x: ",$results_ZFT_MIN->[$_->[0]]->[$_->[1]]->[0],"\n";$results_ZFT_MIN->[$_->[0]]->[$_->[1]]}
            @intersection_inds;

        SKIP: {
            skip 'no clipper results', 6, unless scalar(@result_intersections); 
    
            foreach my $result_intersection (@result_intersections) {
                my ($edge1,$edge2) = @{$result_intersection->[2]};
                my ($e1boti,$e1topi) = @$edge1;
                my ($e2boti,$e2topi) = @$edge2;
                ok(0==scalar(grep {$_ < 1 || $_ > $#point_data} ($e1boti,$e1topi,$e2boti,$e2topi)),'Z value within point data index range');
                my ($e1bot,$e1top,$e2bot,$e2top) = map $point_data[$_], ($e1boti,$e1topi,$e2boti,$e2topi);
                # Remember that Clipper's notion of "top" is _lower_ Y values,
                # because it's developed for a y-axis increases down, computer
                # graphics context.
                ok($e1bot->[1] >= $e1top->[1],'edge 1 bottom point Y <= top point Y');
                ok($e2bot->[1] >= $e2top->[1],'edge 2 bottom point Y <= top point Y');
                # not sure about these
                # question is, does edge 1 always start at the bottom on the same side of edge 2 bottom?
                # we hope so
                ok($e1bot->[0] <= $e2bot->[0],'edge 1 bottom point X <= edge 2 bottom point X');
                ok($e1top->[0] >= $e2top->[0],'edge 1 top point X >= edge 2 top point X');
            }

            foreach my $expected_intersection (@expect_intersections) {
                my @matching_result_intersection_indeces =
                    grep { #diag("diff abs(",$_->[0],"-",$expected_intersection->[0]->[0],"), abs(",$_->[1],"-",$expected_intersection->[0]->[1],")\n");
                             abs($result_intersections[$_]->[0]-$expected_intersection->[0]->[0]) < 0.001
                          && abs($result_intersections[$_]->[1]-$expected_intersection->[0]->[1]) < 0.001
                    } (0 .. $#result_intersections);
               ok(scalar(@matching_result_intersection_indeces) > 0,'matched at least one result intersection with expected coords ('.scalar(@matching_result_intersection_indeces).')');
               #foreach my $result_intersection (@matching_result_intersections) {
               foreach my $result_intersection_index (@matching_result_intersection_indeces) {
                   my $result_intersection = $result_intersections[$result_intersection_index];
                   my ($expect_edge1,$expect_edge2) = @{$expected_intersection}[1,2];
                   my ($result_edge1,$result_edge2) = @{$result_intersection->[2]};

                   my $expect_edge1_high_index = max @$expect_edge1;
                   my $expect_edge2_high_index = max @$expect_edge2;
                   my $result_edge1_high_index = max @$result_edge1;
                   my $result_edge2_high_index = max @$result_edge2;

                   my $expect_edge1_low_index  = min @$expect_edge1;
                   my $expect_edge2_low_index  = min @$expect_edge2;
                   my $result_edge1_low_index  = min @$result_edge1;
                   my $result_edge2_low_index  = min @$result_edge2;

                   ok(   ($result_edge1_high_index == $expect_edge1_high_index && $result_edge1_low_index == $expect_edge1_low_index)
                      || ($result_edge1_high_index == $expect_edge2_high_index && $result_edge1_low_index == $expect_edge2_low_index),
                      'edge1 in result corresponds to input edge for intersection' );
                   ok(   ($result_edge2_high_index == $expect_edge1_high_index && $result_edge2_low_index == $expect_edge1_low_index)
                      || ($result_edge2_high_index == $expect_edge2_high_index && $result_edge2_low_index == $expect_edge2_low_index),
                      'edge1 in result corresponds to input edge for intersection' );

                   # Prob not needed here in these tests - more towward what I need these
                   # tests to demonstrate, before I work with this:
                   my ($e1boti,$e1topi,$e2boti,$e2topi) = (@$result_edge1,@$result_edge2);
                   
                   # Thinking in y-axis goes up frame ("bot" is then "top" visually)
                   # edge1 could be said to go from e1bot at top left to
                   # e1top at bottom right.
                   # We want to know if e1bot at the top left corresponds to the
                   # point that $result_edge1_high_index refers to.
                   # This along with knowing the winding of the input polygons
                   # will let us do, uh, things, that we've almost forgotten about in setting all test stuff up.
                   my $result_edge1_high_index_is_left = $e1boti == $result_edge1_high_index ? 1:0;
                   
                   # so in zfill, can say if edge1bot's z val (index into ordered point data array)
                   # is > edge1top's z val, then high-index-is-left is true
                   # and then you can pass the highest z val from those two edge ends along witht the flag that says whether it was on the left end of edge1
                   # which is the same as saying it was on the "bot" end of edge1. ahhhh......
                   
                   # For similar isleft test for edge2, we use "top edge", because
                   # it goes from our top ("bot") right to bottom ("top") left.
                   my $result_edge2_high_index_is_left = $e2topi == $result_edge2_high_index ? 1:0;

                   # Yeah - that and input winding can give you your "info" marking logic.

                   my $result_intersection_both_max_flags = $result_intersections_ZFT_BOTH_MAX_FLAGS[$result_intersection_index];
                   my $bmf_e1        = $result_intersection_both_max_flags->[2]->[0]->[0];
                   my $bmf_e1_isleft = $result_intersection_both_max_flags->[2]->[0]->[1];
                   my $bmf_e2        = $result_intersection_both_max_flags->[2]->[1]->[0];
                   my $bmf_e2_isleft = $result_intersection_both_max_flags->[2]->[1]->[1];
                   is($bmf_e1       ,$result_edge1_high_index,'ZFT_BOTH_MAX_FLAGS edge 1 high index consistent '.$bmf_e1.','.$result_edge1_high_index);
                   is($bmf_e1_isleft,$result_edge1_high_index_is_left,'ZFT_BOTH_MAX_FLAGS edge 1 flag consistent '.$bmf_e1_isleft.','.$result_edge1_high_index_is_left);
                   is($bmf_e2       ,$result_edge2_high_index,'ZFT_BOTH_MAX_FLAGS edge 2 high index consistent '.$bmf_e2.','.$result_edge2_high_index);
                   is($bmf_e2_isleft,$result_edge2_high_index_is_left,'ZFT_BOTH_MAX_FLAGS edge 2 flag consistent '.$bmf_e2_isleft.','.$result_edge2_high_index_is_left);

                }
            }

        }
    }
}

# helper to set up lots of tests
sub rot_case {
    my ($subjects,$clips,$intersections,$rot) = @_;
    return [
        [ map [map [rotate2d([0,0],[$_->[0],$_->[1]], $rot), $_->[2]], @$_], @$subjects ],
        [ map [map [rotate2d([0,0],[$_->[0],$_->[1]], $rot), $_->[2]], @$_], @$clips    ],
        [ map [[rotate2d([0,0],[$_->[0]->[0],$_->[0]->[1]], $rot)], @{$_}[1 .. $#{$_}]], @$intersections],
        $rot*(180/$pi) .' deg' # to append to case label
    ];
}

sub rotate2d {
    my $origin=shift;
    my $point=shift;
    my $angle=shift;
    my $dx=($point->[0]-$origin->[0]);
    my $dy=($point->[1]-$origin->[1]);
    #{a c-b d, a d+b c}
    return ($origin->[0] + ($dx*cos($angle) - $dy*sin($angle)),
            $origin->[1] + ($dx*sin($angle) + $dy*cos($angle)));
    }

}

# polygon as string for printing 
sub pfmt {
    my $polygon = shift;
    return join("\n",map {'['.join(', ',@$_).']'} @$polygon);
}

# These functions decode multiple values we store in 
# the single 64-bit Z value of intersection points
# in some of our zfill functions.

sub inter16_z1 { return ($_[0] >> 48) & 0xFFFF; }
sub inter16_z2 { return ($_[0] >> 32) & 0xFFFF; }
sub inter16_z3 { return ($_[0] >> 16) & 0xFFFF; }
sub inter16_z4 { return  $_[0]        & 0xFFFF; }

sub extract_all_uint16 {
    my $z = shift;
    return (($z >> 16) != 0)
      ? [
         [inter16_z1($z),inter16_z2($z)],
         [inter16_z3($z),inter16_z4($z)]
        ]
      : undef;
}

sub extract_both_max_flags {
    my $z = shift;
    return (($z >> 32) != 0)
      ? [
         [($z >> 32) & 0x7FFFFFFF,  $z               >> 63],
         [ $z        & 0x7FFFFFFF, ($z & 0xFFFFFFFF) >> 31]
        ]
      : undef;
}
sub extract_both {
    my $z = shift;
    return (($z >> 32) != 0)
      ? [ ($z >> 32) & 0xFFFFFFFF, $z & 0xFFFFFFFF ]
      : undef;
}

=cut

Four edge intersection cases in two polygon intersections.

For cases 1 and 2,
the -45 deg, ccw ccw squares.

        4       8
      #   #   #   #
    #       #       #
  #       #   #       #
1       5       3       7
  #       #   #       #
    #       #       #
      #   #   #   #
        2       6

For cases 3 and 4,
the +45 deg, ccw ccw squares.

        7
      #   #
    #       #
  #           #
8       3       6
  #   #   #   #
    #       #
  #   #   #   #
4       5       2
  #           #
    #       #
      #   #
        1

All the basic standard Clipper behavior tests use at least these two
setups. (We also can test rotations +135 deg and +225 deg, where
the edge cases within Clipper are redundant, but happening with
different edges.)

Numbers are Z values at corner points.

Corner point Z numbers wind around the opposite way when using
clockwise versions of the squares.

The behavior we expect from Clipper is that at each intersection it 
provides the zfill callback with edge1 and edge2 points like so:

edge 1 --> a           d
             #       #
               #   #
                 #
               #   #
             #       #
edge 2 --> c           b

The left side of edge 1 should always have a larger Y value than the
the left side of edge 2.

The edge end points a,b,c and d are ideally end points from our input
polygons that we can identify by the Z values we assigned them.

Our tests here try to ensure that Clipper presents points
a,b,c, and d to zfill call back functions in a consistent way, and
that Z values we set in our various zfill functions are consistent -
which may depend on Clipper's consistency.
=cut


__END__
