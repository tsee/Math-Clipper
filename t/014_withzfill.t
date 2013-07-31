use strict;
use warnings;

use Math::Clipper ':all';
use Test::More tests => 5;

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
$expect_max->[0]->[2] = 5;
$expect_max->[4]->[2] = 8;

my $expect_mean = [map [@$_], @$expect_none];
$expect_mean->[0]->[2] = 3;
$expect_mean->[4]->[2] = 5;

my $expect_both_uint32 = [map [@$_], @$expect_none];
$expect_both_uint32->[0]->[2] = (1 << 32) + 5;
$expect_both_uint32->[4]->[2] = (8 << 32) + 2;

my $clipper = Math::Clipper->new;
$clipper->add_subject_polygon($p1);
$clipper->add_clip_polygon($p2);

#diag("1 in:\n".pfmt($p1)."\nin:\n".pfmt($p2)."\n\n");

my $result = $clipper->execute(CT_UNION,PFT_NONZERO,PFT_NONZERO,ZFT_NONE);
#diag("out:\n".join("\nout:\n",map pfmt($_), @$result)."\n");
is_deeply($result->[0], $expect_none, 'zfill set intersections to zero');

$result = $clipper->execute(CT_UNION,PFT_NONZERO,PFT_NONZERO,ZFT_MIN);
#diag("out:\n".join("\nout:\n",map pfmt($_), @$result)."\n");
is_deeply($result->[0], $expect_min, 'zfill set intersections to min z');

$result = $clipper->execute(CT_UNION,PFT_NONZERO,PFT_NONZERO,ZFT_MAX);
#diag("out:\n".join("\nout:\n",map pfmt($_), @$result)."\n");
is_deeply($result->[0], $expect_max, 'zfill set intersections to max z');

$result = $clipper->execute(CT_UNION,PFT_NONZERO,PFT_NONZERO,ZFT_MEAN);
#diag("out:\n".join("\nout:\n",map pfmt($_), @$result)."\n");
is_deeply($result->[0], $expect_mean, 'zfill set intersections to mean z');

$result = $clipper->execute(CT_UNION,PFT_NONZERO,PFT_NONZERO,ZFT_BOTH_UINT32);
#diag("out:\n".join("\nout:\n",map pfmt($_), @$result)."\n");
is_deeply($result->[0], $expect_both_uint32, 'zfill set intersections to mean z');


sub pfmt {
    my $polygon = shift;
    return join("\n",map {'['.join(', ',@$_).']'} @$polygon);
}

}

__END__
