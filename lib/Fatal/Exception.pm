#!/usr/bin/perl -c

package Fatal::Exception;
use 5.006;
our $VERSION = 0.02;

=head1 NAME

Fatal::Exception - succeed or throw exception

=head1 SYNOPSIS

  use Fatal::Exception 'Exception::System' => qw< open close >;
  open FILE, "/nonexistent";   # throw Exception::System

  use Exception::Base 'Exception::My';
  sub juggle { ... }
  import Fatal::Exception 'Exception::My' => 'juggle';
  juggle;          # succeed or throw exception
  unimport Fatal::Exception 'juggle';
  juggle or die;   # restore original behavior

=head1 DESCRIPTION

L<Fatal::Exception> provides a way to conveniently replace functions which
normally return a false value when they fail with equivalents which raise
exceptions if they are not successful.  This is the same as Fatal module but
it throws L<Exception::Base> object on error.

=cut


use strict;
use warnings;


use Exception::Base
    'Exception::Fatal'              => { isa => 'Exception::Base' },
    'Exception::Fatal::Compilation' => { isa => 'Exception::Base' };


# Switch to enable dump for created wrapper functions
our $Debug;


# Cache for not fatalized functions. The key is "$sub".
our %Not_Fatalized_Functions;


# Cache for fatalized functions. The key is "$sub:$exception:$void".
our %Fatalized_Functions;


# Export the wrapped functions to the caller
sub import {
    my $pkg = shift;
    my $exception = shift || return;

    throw Exception::Fatal::Compilation
          ignore_package => __PACKAGE__,
          message => 'Not enough arguments for "' . __PACKAGE__ . '->import"'
        unless @_;

    my $mod_version = $exception->VERSION || 0;
    if (not $mod_version) {
        eval "use $exception;";
        if ($@ ne '') {
            my $error = $@; $error =~ s/ at \(eval.*//s;
            throw Exception::Fatal::Compilation
                  ignore_package => __PACKAGE__,
                  message => "Cannot find \"$exception\" exception class: $error";
        }
    }

    my $callpkg = caller;
    my $void = 0;

    foreach my $arg (@_) {
        if ($arg eq ':void') {
            $void = 1;
        }
        else {
            my $sub = $arg =~ /::/
                    ? $arg
                    : $callpkg . '::' . $arg;
            (my $name = $sub) =~ s/^&?(.*::)?//;

            __make_fatal(
                exception=>$exception,
                name=>$name,
                pkg=>$callpkg,
                sub=>$sub,
                void=>$void,
	    );
        }
    }

    return 1;
};


# Restore the non fatalized functions to the caller
sub unimport {
    my $pkg = shift;

    my $callpkg = caller;

    foreach my $arg (@_) {
        next if ($arg eq ':void');

        my $sub = $arg =~ /::/
                ? $arg
                : $callpkg . '::' . $arg;
        (my $name = $sub) =~ s/^&?(.*::)?//;

        __make_not_fatal(
            name=>$name,
            pkg=>$callpkg,
            sub=>$sub
        );
    }
}


# Create the wrapper. Stolen from Fatal.
sub __make_fatal {
    # args:
    #   exception - exception class name
    #   name - base name of sub
    #   pkg  - current package name
    #   sub  - full name of sub
    #   void - is function called in scalar context?
    my(%args) = @_;

    # check args
    throw Exception::Fatal::Compilation
          message => 'Not enough arguments for "' . __PACKAGE__ . '->__make_fatal"'
        if grep { not defined } @args{qw< exception name pkg sub >};


    throw Exception::Fatal::Compilation
          ignore_package => __PACKAGE__,
          message => 'Bad subroutine name for "' . __PACKAGE__ . '": ' . $args{name}
        unless $args{name} =~ /^\w+$/;

    my($proto, $code_proto, $call, $core, $argvs);
    my $cache_key = "$args{sub}:$args{exception}:" . ($args{void} ? 1 : 0);
    no strict 'refs';
    if (defined $Fatalized_Functions{$cache_key} and defined $Not_Fatalized_Functions{$args{sub}}) {
        # already wrapped: restore from cache
        no warnings 'redefine';
        return *{ $args{sub} } = $Fatalized_Functions{$cache_key};
    }
    elsif (defined(&{$args{sub}}) and not eval { prototype "CORE::$args{name}" }) {
        # user subroutine
        $call = "&{\$" . __PACKAGE__ . "::Not_Fatalized_Functions{\"$args{sub}\"}}";
        $proto = prototype $args{sub};
        $Not_Fatalized_Functions{$args{sub}} = \&{$args{sub}}
            unless defined $Not_Fatalized_Functions{$args{sub}};
    }
    else {
        # CORE subroutine
        $core = 1;
        $call = "CORE::$args{name}";
        $proto = eval { prototype $call };

        # not found as CORE subroutine
        throw Exception::Fatal::Compilation
              ignore_package => __PACKAGE__,
              message => "\"$args{sub}\" is not a Perl subroutine"
            unless $proto;

        # create package's function
        if (not defined &{$args{sub}}) {
            # not package's function yet
            $argvs = __fill_argvs($proto);
            my $name = "__$args{name}__Fatal__Exception__not_wrapped";
            my $code = "package $args{pkg};\n"
                     . "sub $name ($proto) {\n"
                     .      __write_invocation(
		                (map { $_ => $args{$_} } qw< exception name void >),
                                argvs     => $argvs,
                                call      => $call,
                                orig      => 1,
			    )
                     . "}\n";
            print STDERR $code if $Debug;

            eval $code;
            if ($@ ne '') {
                my $error = $@; $error =~ s/ at \(eval.*//s;
                throw Exception::Fatal::Compilation
                      ignore_package => __PACKAGE__,
                      message => "Cannot create \"$args{sub}\" subroutine: $error";
            }

            my $sub = "$args{pkg}::$name";
            print STDERR "*{ $args{sub} } = \\&$sub;\n" if $Debug;
            no warnings 'redefine';
            *{ $args{sub} } = \&$sub;
        }

        $Not_Fatalized_Functions{$args{sub}} = \&{$args{sub}}
            unless defined $Not_Fatalized_Functions{$args{sub}};
    }

    if (defined $proto) {
        $code_proto = " ($proto)";
    } else {
        $code_proto = '';
        $proto = '@';
    }

    $argvs = __fill_argvs($proto) if not defined $argvs;

    # define new named subroutine (anonymous would be harder to debug from stacktrace)
    my $name = "__$args{name}__Fatal__Exception__$args{exception}" . ($args{void} ? '_void' : '') . "__wrapped";
    $name =~ tr/:/_/;
    my $code = "package $args{pkg};\n"
             . "sub $name$code_proto {\n"
             .      __write_invocation(
		        (map { $_ => $args{$_} } qw< exception name void >),
                        argvs     => $argvs,
                        call      => $call,
		    )
             . "}\n";
    print STDERR $code if $Debug;

    my $newsub = eval $code;
    if ($@ ne '') {
        my $error = $@; $error =~ s/ at \(eval.*//s;
        throw Exception::Fatal::Compilation
              ignore_package => __PACKAGE__,
              message => "Cannot create \"$args{sub}\" subroutine: $error";
    }

    my $sub = "$args{pkg}::$name";
    print STDERR "*{ $args{sub} } = \\&$sub;\n" if $Debug;
    
    no warnings 'redefine';
    return *{ $args{sub} } = $Fatalized_Functions{$cache_key} = \&$sub;
}


# Restore the not-fatalized function.
sub __make_not_fatal {
    # args:
    #   name - base name of sub
    #   pkg  - current package name
    #   sub  - full name of sub
    my(%args) = @_;

    # check args
    throw Exception::Fatal::Compilation
          message => 'Not enough arguments for "' . __PACKAGE__ . '->__make_non_fatal"'
        if grep { not defined } @args{qw< name pkg sub >};


    throw Exception::Fatal::Compilation
          ignore_package => __PACKAGE__,
          message => 'Bad subroutine name for "' . __PACKAGE__ . '": ' . $args{name}
        unless $args{name} =~ /^\w+$/;

    # not wrapped - do nothing
    return unless defined $Not_Fatalized_Functions{$args{sub}};

    no strict 'refs';
    no warnings 'redefine';

    return *{ $args{sub} } = $Not_Fatalized_Functions{$args{sub}};
}


# Fill argvs array based on function prototype. Stolen from Fatal.
sub __fill_argvs {
    my $proto = shift;

    my $n = -1;
    my (@code, @protos, $seen_semi);

    while ($proto =~ /\S/) {
        $n++;
        push(@protos,[$n,@code]) if $seen_semi;
        push(@code, $1 . "{\$_[$n]}"), next if $proto =~ s/^\s*\\([\@%\$\&])//;
        push(@code, "\$_[$n]"), next if $proto =~ s/^\s*([*\$&])//;
        push(@code, "\@_[$n..\$#_]"), last if $proto =~ s/^\s*(;\s*)?\@//;
        $seen_semi = 1, $n--, next if $proto =~ s/^\s*;//; # XXXX ????
        throw Exception::Fatal::Compile
              ignore_package => __PACKAGE__,
              message => "Unknown prototype letters: \"$proto\"";
    }
    push(@protos,[$n+1,@code]);
    return \@protos;
}


# Write subroutine invocation. Stolen from Fatal.
sub __write_invocation {
    # args:
    #   argvs - ref to prototypes stored as array of array of calling arguments
    #   call  - called sub full name
    #   exception - exception class name
    #   name  - base name of sub
    #   orig  - is function called as non-fatalized version?
    #   void  - is function called in scalar context?
    my(%args) = @_;

    # check args
    throw Exception::Fatal::Compilation
          ignore_package => __PACKAGE__,
          message => 'Not enough arguments for "' . __PACKAGE__ . '->__write_invocation"'
        if grep { not defined } @args{qw< argvs call exception name >};

    my @argvs = @{ $args{argvs} };

    if (@argvs == 1) {
        # No optional arguments
        my @argv = @{ $argvs[0] };
        shift @argv;
        return
            "    "
            . __one_invocation(
	        (map { $_ => $args{$_} } qw< call exception name orig void >),
                argv      => \@argv,
	      )
            . ";\n";
    }
    else {
        my $else = "    ";
        my (@out, @argv, $n);
        while (@argvs) {
            @argv = @{shift @argvs};
            $n = shift @argv;
            push @out, "${else}if (\@_ == $n) {\n";
            $else = "    }\n    els";
            push @out,
                "        return "
                . __one_invocation(
	    	    (map { $_ => $args{$_} } qw< call exception name orig void >),
                    argv      => \@argv,
		  )
                . ";\n";
        }
        push @out,
            "    }\n"
          . "    throw Exception::Fatal\n"
          . "          ignore_level => 1,\n"
          . "          message => \"$args{name}: Do not expect to get \" . scalar \@_ . \" arguments\";\n";
        return join '', @out;
    }
}


# Write subroutine invocation. Stolen from Fatal.
sub __one_invocation {
    # args:
    #   argv - ref to prototypes stored as array of calling arguments
    #   call - called sub full name
    #   exception - exception class name
    #   name - base name of sub
    #   orig - is function called as non-fatalized version?
    #   void - is function called in scalar context?
    my(%args) = @_;

    # check args
    throw Exception::Fatal::Compilation
          ignore_package => __PACKAGE__,
          message => 'Not enough arguments for "' . __PACKAGE__ . '->__one_invocation"'
        if grep { not defined } @args{qw< argv call exception name >};

    my $argv = join ', ', @{$args{argv}};
    if ($args{orig}) {
        return "$args{call}($argv)";
    }
    elsif ($args{void}) {
        return "(defined wantarray)\n"
             . "            ? $args{call}($argv)\n"
             . "            : $args{call}($argv)\n"
             . "                || throw $args{exception}\n"
             . "                         ignore_level => 1,\n"
             . "                         message => \"Can't $args{name}\"";
    }
    else {
        return "$args{call}($argv)\n"
             . "            || throw $args{exception}\n"
             . "                     ignore_level => 1,\n"
             . "                     message => \"Can't $args{name}\"";
    }
}


1;


__END__

=for readme stop

=head1 PREREQUISITIES

=over

=item *

L<Exception::Base> >= 0.12

=item *

L<Exception::System> >= 0.07

=back

=head1 IMPORTS

=over

=item use Fatal::Exception I<Exception> => I<function>, I<function>, ...

Replaces the original functions with wrappers which provide do-or-throw
equivalents.  You may wrap both user-defined functions and overridable CORE
operators (except exec, system which cannot be expressed via prototypes) in
this way.

If the symbol :void appears in the import list, then functions named later in
that import list raise an exception only when these are called in void
context.

You should not fatalize functions that are called in list context, because
this module tests whether a function has failed by testing the boolean truth
of its return value in scalar context.

If the exception class is not exist, its module is loaded with "use
I<Exception>" automatically.

=item unimport Fatal::Exception I<function>, I<function>, ...

Restores original functions for user-defined functions or replaces the
functions with do-without-die wrappers for CORE operators.

In fact, the CORE operators cannot be restored, so the non-fatalized
alternative is provided instead.

The functions can be wrapped and un-wrapped all the time.

=back

=head1 PERFORMANCE

The L<Fatal::Exception> module was benchmarked with other implementations. 
The results are following:

  ---------------------------------------------------------------
  | Module                      | Success       | Failure       |
  ---------------------------------------------------------------
  | eval/die                    |      263214/s |      234057/s |
  ---------------------------------------------------------------
  | Fatal                       |       98642/s |        8219/s |
  ---------------------------------------------------------------
  | Fatal::Exception            |      129152/s |        4932/s |
  ---------------------------------------------------------------

=head1 SEE ALSO

L<Fatal>, L<Exception::Base>, L<Exception::System>

=head1 TESTS

The module was tested with L<Test::Unit::Lite> and L<Devel::Cover>.

=head1 BUGS

If you find the bug, please report it.

=for readme continue

=head1 AUTHOR

Piotr Roszatycki E<lt>dexter@debian.orgE<gt>

=head1 LICENSE

Copyright (C) 2007 by Piotr Roszatycki E<lt>dexter@debian.orgE<gt>.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>
