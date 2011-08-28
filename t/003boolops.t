use Math::Clipper ':all';
use Test::More tests=>7;

my $ai = [
[-900359890780731,536870912000000],
[0,-1073741824000000],
[900359890780731,536870912000000]
];
my $bi = [
[-900359890780731,-536870912000000],
[900359890780731,-536870912000000],
[0,1073741824000000]
];


my $clipper = Math::Clipper->new;
$clipper->use_full_coordinate_range(1);
$clipper->add_subject_polygon($ai);
$clipper->add_clip_polygon($bi);
my $result = $clipper->execute(CT_DIFFERENCE);
ok(
  scalar(@{$result})==3,
  'DIFFERENCE should give three polygons'
  );
ok(
  3 == (grep {$_ > 1.6112567856380e+029 && $_ < 1.6112567856399e+029} map {Math::Clipper::area($_)} @{$result}) ,
  'DIFFERENCE areas are reasonable'
  );

$clipper->clear();
$clipper->add_subject_polygon($ai);
$clipper->add_clip_polygon($bi);
$result = $clipper->execute(CT_UNION);
ok(
  scalar(@{$result})==1,
  'UNION should give one polygon'
  );
ok(abs(Math::Clipper::area($result->[0]) - 1.93350814275746e+030) < 0.00000000000005e+030,
  'UNION area is reasonable'
  );

$clipper->clear();
$clipper->add_subject_polygon($ai);
$clipper->add_clip_polygon($bi);
$result = $clipper->execute(CT_XOR);
my $xorasum=0;
map {$xorasum+=Math::Clipper::area($_)} @{$result};
# xor of test gives two polygons, each with two shared points between triangles, but that might
# not be reliable or desired. It's a Clipper issue though, and might change with new versions
# so don't want to count result polygons for xor
ok(abs($xorasum-(2*4.83377035682448e+029)) < 0.00000000000005e+029,
  'XOR area is reasonable'
  );

$clipper->clear();
$clipper->add_subject_polygon($ai);
$clipper->add_clip_polygon($bi);
$result = $clipper->execute(CT_INTERSECTION);
ok(
  scalar(@{$result})==1,
  'INTERSECTION should give one polygon'
  );
ok(abs(Math::Clipper::area($result->[0]) - 9.66754071383342e+029) < 0.00000000000005e+029,
  'INTERSECTION area is reasonable'
  );
