use Math::Clipper ':all';
use Config;
use Test::More tests=>14;
use Test::Deep;

my $maxint_64=9223372036854775806; # signed 64 bit int range: -9223372036854775808 to 9223372036854775807; BUT Clipper seems to only work up to 9223372036854775806
my $maxint_53=   9007199254740992; # for integers stored in double precision floats with 53 bit mantissa
my $maxint;

my $extraexp=0;
my $is64=0;
if ((defined($Config{use64bitint}) && $Config{use64bitint} eq "define") || $Config{longsize} >= 8) {
    $maxint=$maxint_64;
    $extraexp=3;
	$is64=1;
    }
else {
    $maxint=$maxint_53;
    }



#######################################
# huge diamond, points at limits, as
# subject, do dummy bool op, then 
# is_deeply on first-and-only of result

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



#######################################
# set up some test data and expected
# results

my $A = [
[-0.00000000000002               , -5.6799999999999999999999999999999999999999999999],
[ 0.00000000000000000000000001234,-56.788888888888888888888888888888888888888888888],
[ 0.00000000000000000000000001234, 56.7777777777777777777777777777777777777777777777]
];
my $Aexpect = [ # in 32 bit environment, we get 53 bit integers back from Clipper, in floats, which may be in sci. notation, or not
[ -0.00000000000002 * 10**(14+$extraexp),  -5.6799999999999999999999999999999999999999999999 * 10**(14+$extraexp)],
[ 0, -56.788888888888888888888888888888888888888888888  * 10**(14+$extraexp)],
[ 0,  56.7777777777777777777777777777777777777777777777 * 10**(14+$extraexp)]
];
my $A2expect = [
[ -0.00000000000002 * 10**(29+$extraexp),  -5.6799999999999999999999999999999999999999999999 * 10**(14+$extraexp)],
[ 1234, -56.788888888888888888888888888888888888888888888  * 10**(14+$extraexp)],
[ 1234,  56.7777777777777777777777777777777777777777777777 * 10**(14+$extraexp)]
];
my $Aexpect_string = [ # in 64 bit environment, we get real integers back from Clipper, expect always in integer form, no exponents
[ '-2'.(0 x $extraexp),         '-568'.('0' x (12+$extraexp))],
[ 0,                            '-5678'.('8' x (11+$extraexp)).'9'],
[ 0,                            '5677'.('7' x (11+$extraexp)).'8']
];
my $A2expect_string = [
[ '-2'.('0' x (15+$extraexp)),  '-568'.('0' x (12+$extraexp))],
[ 1234,                         '-5678'.('8' x (11+$extraexp)).'9'],
[ 1234,                         '5677'.('7' x (11+$extraexp)).'8']
];
my $AexpectUnscaled = [
[ -0.00000000000002,  -5.68],
[ 0, -56.78888888888889],
[ 0,  56.77777777777778]
];
my $B = [
[ 1000000000000001,  -1000000000000001],
[ 0.5, 0.4],
[-0.5,-0.4]
];
my $Bexpect = [
[ 1000000000000001,  -1000000000000001],
[ 1,  0],
[-1, 0]
];

if ($is64) {
    $Aexpect=$Aexpect_string;
    $A2expect=$A2expect_string;
    }



#######################################
# not enough sig figs, even with int64,
# to hold original coords in integers
# so some coords become plain zero
my $Ac=clone($A);
my $scalevec=integerize_coordinate_sets({constrain=>1},$Ac);
####diag("\n\nintegerized constrained:\ngot\n".join("\n",map {"[$_->[0],$_->[1]]"} @{$Ac})."\nexpected\n".join("\n",map {"[$_->[0],$_->[1]]"} @{$Aexpect})."\n\n");
cmp_deeply($Ac,bag(@{$Aexpect}),'lose smallest digits when integerized constrained');
$clipper->add_subject_polygon($Ac);
$result = $clipper->execute(CT_UNION);
is(scalar(@{$result}),1,'round-tripped polygon preserved. b');
####diag("\n\nintegerized constrained roundtripped:\ngot\n".join("\n",map {"[$_->[0],$_->[1]]"} @{$result->[0]})."\nexpected\n".join("\n",map {"[$_->[0],$_->[1]]"} @{$Aexpect})."\n\n");
cmp_deeply($result->[0],bag(@{$Aexpect}),'lose smallest digits when integerized constrained - roundtripped');
unscale_coordinate_sets($scalevec,$result);
#diag("\n\nintegerized constrained - unscaled:\n".join("\n",map {"[$_->[0],$_->[1]]"} @{$result->[0]})."\nand\n".join("\n",map {"[$_->[0],$_->[1]]"} @{$AexpectUnscaled})."\n\n");
cmp_deeply($result->[0],bag(@{$AexpectUnscaled}),'lose smallest digits when integerized constrained - unscaled');
$clipper->clear;



#######################################
# use non-constrained scaling to
# preserve digits that wouldn't be
# preserved with constrained
$Ac=clone($A);
$scalevec=integerize_coordinate_sets({constrain=>0},$Ac);
####diag("\n\nintegerized not constrained:\ngot\n".join("\n",map {"[$_->[0],$_->[1]]"} @{$Ac})."\nexpected\n".join("\n",map {"[$_->[0],$_->[1]]"} @{$A2expect})."\n\n");
cmp_deeply($Ac,bag(@{$A2expect}),'keep smallest digits when integerized not constrained');
$clipper->add_subject_polygon($Ac);
$result = $clipper->execute(CT_UNION);
is(scalar(@{$result}),1,'round-tripped polygon preserved. c');
####diag("\n\nintegerized not constrained roundtripped:\ngot\n".join("\n",map {"[$_->[0],$_->[1]]"} @{$result->[0]})."\nexpected\n".join("\n",map {"[$_->[0],$_->[1]]"} @{$A2expect})."\n\n");
cmp_deeply($result->[0],bag(@{$A2expect}),'keep smallest digits when integerized not constrained - roundtripped');
unscale_coordinate_sets($scalevec,$result);
#diag("\n\nintegerized not constrained - unscaled:\n".join("\n",map {"[$_->[0],$_->[1]]"} @{$result->[0]})."\nand\n".join("\n",map {"[$_->[0],$_->[1]]"} @{$A})."\n\n");
cmp_deeply($result->[0],bag(@{$A}),'keep smallest digits when integerized not constrained - unscaled');
$clipper->clear;



#######################################
# two coordinate sets (polygons)
# scale-to-integer factors determined
# to handle all coords in both sets
$scalevec=integerize_coordinate_sets({constrain=>0,bits=>53},[[1,2,3],[2,3,1],[3,2,1]],[[10,200,3000],[20,300,1000],[30,200,1000]]);
is_deeply($scalevec,[10**14,10**13,10**12],'scaling vector accommodates all polygon coordinates');



#######################################
# rounding of ones place for n < 1
my $Bc=clone($B);
$scalevec=integerize_coordinate_sets({constrain=>0,bits=>53},$Bc);
#diag("\n\nrounding:\ngot\n".join("\n",map {"[$_->[0],$_->[1]]"} @{$Bc})."\nexpected\n".join("\n",map {"[$_->[0],$_->[1]]"} @{$Bexpect})."\n\n");
cmp_deeply($Bc,bag(@{$Bexpect}),'rounding');


#######################################
# unscaling coordinate sets
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
