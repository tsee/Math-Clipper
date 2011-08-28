use Math::Clipper ':all';
use Config;
use Test::More tests=>11;
use Test::Deep;

my $maxint_64=9223372036854775807; # or 9223372036854775808, but close enough
my $maxint_53=   9007199254740992; # for integers stored in double precision floats
my $maxint;

if ((defined($Config{use64bitint}) && $Config{use64bitint} eq "define") || $Config{longsize} >= 8) {
    $maxint=$maxint_64;
    }
else {
    $maxint=$maxint_53;
    }


#huge diamond, points at limits, as subject, do dummy ( shouldn't that be dumby? ) bool op, then is_deeply on first-and-only of result

my $big_diamond = [
    [-$maxint,1],
    [1,-$maxint],
    [$maxint,-1],
    [1,$maxint]
    ];

my $clipper = Math::Clipper->new;
$clipper->use_full_coordinate_range(1);
$clipper->add_subject_polygon($big_diamond);
my $result = $clipper->execute(CT_UNION);
is(scalar(@{$result}),1,'round-tripped polygon preserved. a');
#diag("\n\nreally?:\n".join("\n",map {"[$_->[0],$_->[1]]"} @{$result->[0]})."\nand\n".join("\n",map {"[$_->[0],$_->[1]]"} @{$big_diamond})."\n\n");
cmp_deeply($result->[0],bag(@{$big_diamond}),'round-tripped coords at integer limits preserved');
$clipper->clear;


my $A = [
#[-0.00000000000000000000000001234, -5.6799999999999999999999999999999999999999999999],
[-0.00000000000002               , -5.6799999999999999999999999999999999999999999999],
[ 0.00000000000000000000000001234,-56.788888888888888888888888888888888888888888888],
[ 0.00000000000000000000000001234, 56.7777777777777777777777777777777777777777777777]
];
my $Aexpect = [
#[ 0,  -5.6799999999999999999999999999999999999999999999 * 10**14],
[ -2,  -5.6799999999999999999999999999999999999999999999 * 10**14],
[ 0, -56.788888888888888888888888888888888888888888888  * 10**14],
[ 0,  56.7777777777777777777777777777777777777777777777 * 10**14]
];
my $A2expect = [
#[ 0,  -5.6799999999999999999999999999999999999999999999 * 10**14],
[ -0.00000000000002 * 10**29,  -5.6799999999999999999999999999999999999999999999 * 10**14],
[ 1234, -56.788888888888888888888888888888888888888888888  * 10**14],
[ 1234,  56.7777777777777777777777777777777777777777777777 * 10**14]
];
my $AexpectUnscaled = [
#[ 0,  -5.68],
[ -0.00000000000002,  -5.68],
[ 0, -56.78888888888889],
[ 0,  56.77777777777778]
];
my $B = [
[ 0.000000000001234, 567.70],
[ 0.000000000001234,-567.80],
[-0.000000000001234,- 56.79]
];


#not enough sig figs, even with int64, to hold original coords in integers
#so some coords become plain zero
my $Ac=clone($A);
my $scalevec=integerize_coordinate_sets({constrain=>1,bits=>53},$Ac);
$clipper->add_subject_polygon($Ac);
$result = $clipper->execute(CT_UNION);
is(scalar(@{$result}),1,'round-tripped polygon preserved. b');
#diag("\n\nreally?:\n".join("\n",map {"[$_->[0],$_->[1]]"} @{$result->[0]})."\nand\n".join("\n",map {"[$_->[0],$_->[1]]"} @{$Aexpect})."\n\n");
cmp_deeply($result->[0],bag(@{$Aexpect}),'lose smallest digits when integerized constrained');
unscale_coordinate_sets($scalevec,$result);
#diag("\n\nreally?:\n".join("\n",map {"[$_->[0],$_->[1]]"} @{$result->[0]})."\nand\n".join("\n",map {"[$_->[0],$_->[1]]"} @{$AexpectUnscaled})."\n\n");
cmp_deeply($result->[0],bag(@{$AexpectUnscaled}),'lose smallest digits when integerized constrained - unscaled');
$clipper->clear;

# use non-constrained scaling to preserve digits that wouldn't be preserved with constrained
$Ac=clone($A);
$scalevec=integerize_coordinate_sets({constrain=>0,bits=>53},$Ac);
$clipper->add_subject_polygon($Ac);
$result = $clipper->execute(CT_UNION);
is(scalar(@{$result}),1,'round-tripped polygon preserved. c');
#diag("\n\nreally?:\n".join("\n",map {"[$_->[0],$_->[1]]"} @{$result->[0]})."\nand\n".join("\n",map {"[$_->[0],$_->[1]]"} @{$A2expect})."\n\n");
cmp_deeply($result->[0],bag(@{$A2expect}),'keep smallest digits when integerized not constrained');
unscale_coordinate_sets($scalevec,$result);
#diag("\n\nreally?:\n".join("\n",map {"[$_->[0],$_->[1]]"} @{$result->[0]})."\nand\n".join("\n",map {"[$_->[0],$_->[1]]"} @{$A})."\n\n");
cmp_deeply($result->[0],bag(@{$A}),'keep smallest digits when integerized not constrained - unscaled');
$clipper->clear;

# two coordinate sets (polygons)
# scale-to-integer factors determined to handle all coords in both sets
$Ac=clone($A);
my $Bc=clone($B);
$scalevec=integerize_coordinate_sets({constrain=>0,bits=>53},[[1,2,3],[2,3,1],[3,2,1]],[[10,200,3000],[20,300,1000],[30,200,1000]]);
is_deeply($scalevec,[10**14,10**13,10**12],'scaling vector accommodates all polygon coordinates');

#unscaling coordinate sets
my $S=[
[1,2,3,4],
[5,6,7,8]
];
my $Sexpect=[
[10,20,30,40],
[50,60,70,80]
];
my $S2expect=[
[10,10, -6,400],
[50,30,-14,800]
];

unscale_coordinate_sets(1/10,[$S]);
is_deeply( $S , $Sexpect , 'uniform scale');
unscale_coordinate_sets([1,2,-5,0.1],[$S]);
is_deeply( $S , $S2expect , 'scale with vector');

sub clone {return [(map {[(@{$_})]} @{$_[0]})]}
