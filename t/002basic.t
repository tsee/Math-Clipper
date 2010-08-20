use strict;
use warnings;

use Test::More tests => 1+6+3*2;

use constant EPS => 1.e-9;
sub approx_eq {
  return ($_[0]+EPS() < $_[1] && $_[0]-EPS() > $_[1]);
}

use Math::Clipper qw/:all/;
pass();


foreach my $const (
    qw/CT_INTERSECTION CT_UNION CT_DIFFERENCE CT_XOR/,
    #qw/PT_SUBJECT PT_CLIP/,
    qw/PFT_EVENODD PFT_NONZERO/,
    )
{
  ok(defined eval $const);
}

SCOPE: {
  my $c = Math::Clipper->new;
  isa_ok($c, 'Math::Clipper');
  $c->add_subject_polygon(
    [
      [0., 0.],
      [1., 0.],
      [1., 1.],
      [0., 1.],
    ],
  );

  $c->add_clip_polygon(
    [
      [0., 0.],
      [0.5, 0.],
      [0.5, 1.],
      [0., 1.],
    ],
  );

  my $ppoly = $c->execute(CT_INTERSECTION);
  ok(ref($ppoly) eq 'ARRAY');
  is_deeply($ppoly,
    [[
      [ '0.5', '0' ],
      [ '0.5', '1' ],
      [ '0', '1' ],
      [ '0', '0' ]
    ]]
  );
}

SCOPE: {
  my $c = Math::Clipper->new;
  isa_ok($c, 'Math::Clipper');
  $c->add_subject_polygon(
    [
      [0., 0.],
      [1., 0.],
      [1., 1.],
      [0., 1.],
    ],
  );

  $c->add_clip_polygon(
    [
      [5., 0.],
      [5.5, 0.],
      [5.5, 1.],
      [5., 1.],
      [6., 2.],
      [8., 3.],
      [10., 4.],
      [12., 5.],
      [14., 6.],
      [16., 7.],
    ],
  );

  my $ppoly = $c->execute(CT_INTERSECTION);
  ok(ref($ppoly) eq 'ARRAY');
  is_deeply($ppoly, [] );
}

