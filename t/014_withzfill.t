use strict;
use warnings;

use Math::Clipper ':all';
use Test::More tests => 8;

SKIP: {
    skip 'not compiled with z support', 5 unless Math::Clipper::has_z;

my $p1 = [
    [10,  0, 1],
    [10, 10, 2],
    [ 0, 10, 3],
    [ 0,  0, 4],
];

my $p2 = [
    [ 5,  5, 5],
    [15,  5, 6],
    [15, 15, 7],
    [ 5, 15, 8],
];

my $expect_none = [
    [10,  5, 0], # intersection
    [15,  5, 6],
    [15, 15, 7],
    [ 5, 15, 8],
    [ 5, 10, 0], # intersection
    [ 0, 10, 3],
    [ 0,  0, 4],
    [10,  0, 1],
];
my $expect_min = [map [@$_], @$expect_none];
$expect_min->[0]->[2] = 1;
$expect_min->[4]->[2] = 2;

my $expect_max = [map [@$_], @$expect_none];
$expect_max->[0]->[2] = 6;
$expect_max->[4]->[2] = 8;

my $expect_both_min = [map [@$_], @$expect_none];
$expect_both_min->[0]->[2] = (5 << 32) + 1;
$expect_both_min->[4]->[2] = (2 << 32) + 5;

my $expect_both_max = [map [@$_], @$expect_none];
$expect_both_max->[0]->[2] = (6 << 32) + 2;
$expect_both_max->[4]->[2] = (3 << 32) + 8;

my $expect_mean = [map [@$_], @$expect_none];
# Reproduce the zfill integer math that gives the mean of the interpolated Zs.
# The 0.5 is the interpolation factor - our intersecting edges cut each other
# at the half way point in the polygons set up above.
$expect_mean->[0]->[2] = int( ((5+int(0.5*(6-5))) + (2+int(0.5*(1-2))))/2 );
$expect_mean->[4]->[2] = int( ((3+int(0.5*(2-3))) + (8+int(0.5*(5-8))))/2 );

my $expect_both_uint32 = [map [@$_], @$expect_none];
# set these to whatever you get in a test run
# this test is just to catch when/if a new 
# Clipper version changes the order of points/zvals
# provided to the zfill callback
$expect_both_uint32->[0]->[2] = (5 << 32) + 2;
$expect_both_uint32->[4]->[2] = (3 << 32) + 8;

my $expect_all_uint16 = [map [@$_], @$expect_none];
# set these to whatever you get in a test run
# this test is just to catch when/if a new 
# Clipper version changes the order of points/zvals
# provided to the zfill callback
$expect_all_uint16->[0]->[2] = (5 << 48) + (6 << 32) + (2 << 16) + 1;
$expect_all_uint16->[4]->[2] = (3 << 48) + (2 << 32) + (8 << 16) + 5;


my $clipper = Math::Clipper->new;
$clipper->add_subject_polygon($p1);
$clipper->add_clip_polygon($p2);

#diag("1 in:\n".pfmt($p1)."\nin:\n".pfmt($p2)."\n\n");

my $result;

$result = $clipper->execute(CT_UNION,PFT_NONZERO,PFT_NONZERO,ZFT_NONE);
#diag("EXPECT:\n".pfmt($expect_none)."\nGOT:\n:\n".join("\nout:\n",map pfmt($_), @$result)."\n");
is_deeply($result->[0], $expect_none, 'zfill set intersections to zero');

$result = $clipper->execute(CT_UNION,PFT_NONZERO,PFT_NONZERO,ZFT_MIN);
#diag("EXPECT:\n".pfmt($expect_min)."\nGOT:\n".join("\nout:\n",map pfmt($_), @$result)."\n");
is_deeply($result->[0], $expect_min, 'zfill set intersections to min z');

$result = $clipper->execute(CT_UNION,PFT_NONZERO,PFT_NONZERO,ZFT_MAX);
#diag("EXPECT:\n".pfmt($expect_max)."\nGOT:\n".join("\nout:\n",map pfmt($_), @$result)."\n");
is_deeply($result->[0], $expect_max, 'zfill set intersections to max z');

$result = $clipper->execute(CT_UNION,PFT_NONZERO,PFT_NONZERO,ZFT_BOTH_MIN);
#diag("EXPECT:\n".pfmt($expect_both_min)."\nGOT:\n".join("\nout:\n",map pfmt($_), @$result)."\n");
is_deeply($result->[0], $expect_both_min, 'zfill set intersections to both min z');

$result = $clipper->execute(CT_UNION,PFT_NONZERO,PFT_NONZERO,ZFT_BOTH_MAX);
#diag("EXPECT:\n".pfmt($expect_both_max)."\nGOT:\n".join("\nout:\n",map pfmt($_), @$result)."\n");
is_deeply($result->[0], $expect_both_max, 'zfill set intersections to both max z');

$result = $clipper->execute(CT_UNION,PFT_NONZERO,PFT_NONZERO,ZFT_INTERPOLATE_MEAN);
#diag("EXPECT:\n".pfmt($expect_mean)."\nGOT:\n".join("\nout:\n",map pfmt($_), @$result)."\n");
is_deeply($result->[0], $expect_mean, 'zfill set intersections to mean z');

$result = $clipper->execute(CT_UNION,PFT_NONZERO,PFT_NONZERO,ZFT_BOTH_UINT32);
#diag("EXPECT:\n".pfmt($expect_both_uint32)."\nGOT:\n".join("\nout:\n",map pfmt($_), @$result)."\n");
#diag("decoded zs expected:\n",join("\n",map {intersection_z1($_).",".intersection_z2($_)} map {$_->[2]} @{$expect_both_uint32}),"\ndecoded zs got:\n",join("'\n",map {intersection_z1($_).",".intersection_z2($_)} map {$_->[2]} @{$result->[0]}),"\n");
is_deeply($result->[0], $expect_both_uint32, 'zfill set intersections to two Int32s in the Int64 Z');

$result = $clipper->execute(CT_UNION,PFT_NONZERO,PFT_NONZERO,ZFT_ALL_UINT16);
#diag("EXPECT:\n".pfmt($expect_all_uint16)."\nGOT:\n".join("\nout:\n",map pfmt($_), @$result)."\n");
#diag("decoded zs expected:\n",join("\n",map {inter16_z1($_).",".inter16_z2($_).",".inter16_z3($_).",".inter16_z4($_)} map {$_->[2]} @{$expect_all_uint16}),"\ndecoded zs got:\n",join("'\n",map {inter16_z1($_).",".inter16_z2($_).",".inter16_z3($_).",".inter16_z4($_)} map {$_->[2]} @{$result->[0]}),"\n");
is_deeply($result->[0], $expect_all_uint16, 'zfill set intersections to four Int16s in the Int64 Z');

sub pfmt {
    my $polygon = shift;
    return join("\n",map {'['.join(', ',@$_).']'} @$polygon);
}

sub intersection_z1 { return ($_[0] >> 32) & 0x7FFFFFFF; }
sub intersection_z2 { return  $_[0]        & 0xFFFFFFFF; }

sub inter16_z1 { return ($_[0] >> 48) & 0xFFFF; }
sub inter16_z2 { return ($_[0] >> 32) & 0xFFFF; }
sub inter16_z3 { return ($_[0] >> 16) & 0xFFFF; }
sub inter16_z4 { return  $_[0]        & 0xFFFF; }

}

__END__
