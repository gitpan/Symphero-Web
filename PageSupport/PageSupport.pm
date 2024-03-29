package Symphero::PageSupport;
require 5.005;
use strict;

require DynaLoader;

use vars qw(@ISA $VERSION);

@ISA = qw(DynaLoader);

$VERSION = '0.2';

bootstrap Symphero::PageSupport $VERSION;

# Preloaded methods go here.

1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Symphero::PageSupport - Fast text collection for Symphero::Objects::Page

=head1 SYNOPSIS

  use Symphero::PageSupport;

=head1 DESCRIPTION

This is very specific module oriented to support fast text adding
for Symphero displaying engine. Helps a lot with template processing,
especially when template splits into thousands or even milions of
pieces.

The idea is to have one long buffer that extends automatically and a
stack of positions in it that can be pushed/popped when application
need new portion of text.

=head2 EXPORT

None.

=head1 AUTHOR

Andrew Maltsev, <amaltsev@valinux.com>

=head1 SEE ALSO

perl(1).

=cut
