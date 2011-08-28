use Math::Clipper ':all';
use Test::More tests=>3;

my $ccw = [
[0,0],
[4,0],
[4,4],
[0,4]
];
my $cw = [
[0,0],
[0,4],
[4,4],
[4,0]
];
my $tricky = [
[0,0],
[40,40],
[40,0],
[0,41]
];

ok(   Math::Clipper::is_counter_clockwise($ccw)    , 'is_ccw on a counter-clockwise polygon');
ok( ! Math::Clipper::is_counter_clockwise($cw)     , 'is_ccw on a clockwise polygon');
ok(   Math::Clipper::is_counter_clockwise($tricky) , 'is_ccw on a bowtie polygon');
