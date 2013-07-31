use strict;
use warnings;

use Math::Clipper ':all';
use Test::More tests => 1;

SKIP: {
    skip 'not compiled with z support', 1 unless Math::Clipper::has_z;

my $p1 = [
    [ 50,   0,   -2], # Clipper treats Z as a signed 64 bit int
    [ 20,  10,   0xFFFFFFFF], # max unsigned 32 bit int
    [-10,   0,   0],
    [ 20, -10,    1],
];

my $clipper = Math::Clipper->new;
$clipper->add_subject_polygon($p1);
my $result = $clipper->execute(CT_UNION,PFT_NONZERO,PFT_NONZERO,ZFT_NONE);
#diag("out:\n".join("\nout:\n",map pfmt($_), @$result)."\n");
is_deeply($result->[0], $p1, 'z coordinate passed through');

sub pfmt {
    my $polygon = shift;
    return join("\n",map {'['.join(', ',@$_).']'} @$polygon);
}

}
__END__
