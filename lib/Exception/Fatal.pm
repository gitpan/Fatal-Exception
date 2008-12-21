#!/usr/bin/perl -c

package Exception::Fatal;

=head1 NAME

Exception::Fatal - Thrown when core function has a fatal error

=head1 SYNOPSIS

  use Exception::Fatal;

  eval {
      open my $fh, '/etc/passwd', '+badmode';
  };
  if ($@) {
      my $e = Exception::Fatal->catch;
      $e->throw( message => 'Cannot open', function => 'open' );
  };

=head1 DESCRIPTION

This class is an L<Exception::Died> exception thrown when core function has a
trappable fatal error.

=for readme stop

=cut

use 5.006;
use strict;
use warnings;

our $VERSION = 0.04;


use Exception::Base 0.21 (
    'Exception::Fatal' => {
        isa       => 'Exception::Died',
        has       => 'function',
        message   => 'Unknown function failed',
    },
);


1;


__END__

=begin umlwiki

= Class Diagram =

[                    <<exception>>
                    Exception::Fatal
 ----------------------------------------------------
 +message : Str = "Unknown function failed" {rw, new}
 +function : Str                            {rw, new}
 ----------------------------------------------------
                                                     ]

[Exception::Fatal] ---|> [Exception::Died]

=end umlwiki

=head1 BASE CLASSES

=over

=item *

L<Exception::Died>

=back

=head1 ATTRIBUTES

This class provides new attributes.  See L<Exception::Base> for other
descriptions.

=over

=item message : Str = "Unknown function failed" {rw}

Contains the message of the exception.  This class overrides the default value
from L<Exception::Base> class.

=item function : Str {rw}

Contains the name of function which failed with fatal error.

=back

=head1 SEE ALSO

L<Exception::Died>, L<Exception::Fatal>, L<Fatal::Exception>.

=head1 BUGS

If you find the bug, please report it.

=for readme continue

=head1 AUTHOR

Piotr Roszatycki E<lt>dexter@debian.orgE<gt>

=head1 LICENSE

Copyright (C) 2008 by Piotr Roszatycki E<lt>dexter@debian.orgE<gt>.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>
