package Perl::Critic::TooMuchCode;
use strict;
our $VERSION='0.10';
1;
__END__

=head1 NAME

Perl::Critic::TooMuchCode - perlcritic add-ons that generally check for dead code.

=head1 DESCRIPTION

This add-on of Perl::Critic is aiming for identifying trivial dead
code. Either the ones that has no use, or the one that produce no
effect. Having dead code floating around causes maintance burden. Some
might prefer not to generate them in the first place.

=head1 AUTHOR

Kang-min Liu <gugod@gugod.org>

=head1 LICENSE

MIT

=cut
