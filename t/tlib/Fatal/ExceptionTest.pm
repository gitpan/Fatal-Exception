package Fatal::ExceptionTest;

use strict;
use warnings;

use base 'Test::Unit::TestCase';

use Fatal::Exception;

# non-CORE functions from own package
sub sub_test1 {
    return shift();
}

# non-CORE functions outer own package
{
    package Fatal::ExceptionTest::Package1;
    sub sub_test2 {
        return shift();
    }
}

# Should be before import test. Test::Unit can't sort subs' names.
sub test____sane {
    my $self = shift;

    local *FOO;

    my $file = __FILE__;
    eval 'open FOO, "<", "$file"';
    $self->assert_equals('', $@);
    $self->assert_matches(qr/^package/, scalar(<FOO>));

    eval 'close FOO';
    $self->assert_equals('', $@);

    eval 'opendir FOO, "."';
    $self->assert_equals('', $@);

    eval 'close FOO';
    $self->assert_equals('', $@);

    eval 'sub_test1 undef';
    $self->assert_equals('', $@);

    eval 'Fatal::ExceptionTest::Package1::sub_test2 undef';
    $self->assert_equals('', $@);
}

sub test_import {
    my $self = shift;

    local *FOO;

    # empty args
    eval 'Fatal::Exception->import()';
    $self->assert_equals('', $@);
    eval 'Fatal::Exception->unimport()';
    $self->assert_equals('', $@);

    # not enough args
    eval 'Fatal::Exception->import("open")';
    $self->assert_matches(qr/Not enough arguments/, $@);

    # not such exception
    eval 'Fatal::Exception->import("Exception::Fatal::import::NotFound", "open")';
    $self->assert_matches(qr/Cannot find/, $@);

    # not such function
    eval 'Fatal::Exception->import("Exception::Fatal", "notsuchfunction$^T$$")';
    $self->assert_matches(qr/is not a Perl subroutine/, $@);

    # first wrapping
    eval 'use Exception::Base "Exception::Fatal::import::Test1"';
    $self->assert_equals('', $@);
    eval 'Fatal::Exception->import("Exception::Fatal::import::Test1", "open", "sub_test1", "Fatal::ExceptionTest::Package1::sub_test2", ":void", "opendir")';
    $self->assert_equals('', $@);

    my $file = __FILE__;
    eval 'open FOO, "<", "$file"';
    $self->assert_equals('', $@);
    $self->assert_matches(qr/^package/, scalar(<FOO>));

    eval 'close FOO';
    $self->assert_equals('', $@);

    # : too many args
    eval 'open 1, 2, 3, 4, 5';
    $self->assert_not_equals('', $@);
    $self->assert_equals('Exception::Fatal', ref $@);

    # : wrapped void=0
    eval 'open FOO, "<", "/doesnotexists$^T$$"';
    $self->assert_not_equals('', $@);
    $self->assert_equals('Exception::Fatal::import::Test1', ref $@);

    # : wrapped void=1 in array context
    eval 'opendir FOO, "/doesnotexists$^T$$"';
    $self->assert_not_equals('', $@);
    $self->assert_equals('Exception::Fatal::import::Test1', ref $@);

    # : wrapped void=1 in scalar context
    eval 'my $ret1 = opendir FOO, "/doesnotexists$^T$$"';
    $self->assert_equals('', $@);

    # : wrapped non-core, our package
    eval 'sub_test1 undef';
    $self->assert_not_equals('', $@);
    $self->assert_equals('Exception::Fatal::import::Test1', ref $@);

    # : wrapped non-core, not our package
    eval 'Fatal::ExceptionTest::Package1::sub_test2 undef';
    $self->assert_not_equals('', $@);
    $self->assert_equals('Exception::Fatal::import::Test1', ref $@);

    # re-wrapping, another exception
    eval 'use Exception::Base "Exception::Fatal::import::Test2"';
    $self->assert_equals('', $@);
    eval 'Fatal::Exception->import("Exception::Fatal::import::Test2", "open", "sub_test1", "Fatal::ExceptionTest::Package1::sub_test2", ":void", "opendir")';
    $self->assert_equals('', $@);

    # : wrapped void=0
    eval 'open FOO, "<", "/doesnotexists$^T$$"';
    $self->assert_not_equals('', $@);
    $self->assert_equals('Exception::Fatal::import::Test2', ref $@);

    # : wrapped void=1 in array context
    eval 'opendir FOO, "/doesnotexists$^T$$"';
    $self->assert_not_equals('', $@);
    $self->assert_equals('Exception::Fatal::import::Test2', ref $@);

    # : wrapped void=1 in scalar context
    eval 'my $ret1 = opendir FOO, "/doesnotexists$^T$$"';
    $self->assert_equals('', $@);

    # : wrapped non-core, our package
    eval 'sub_test1 undef';
    $self->assert_not_equals('', $@);
    $self->assert_equals('Exception::Fatal::import::Test2', ref $@);

    # : wrapped non-core, not our package
    eval 'Fatal::ExceptionTest::Package1::sub_test2 undef';
    $self->assert_not_equals('', $@);
    $self->assert_equals('Exception::Fatal::import::Test2', ref $@);

    # re-wrapping, the same exception
    eval 'Fatal::Exception->import("Exception::Fatal::import::Test2", "open", "sub_test1", "Fatal::ExceptionTest::Package1::sub_test2", ":void", "opendir")';
    $self->assert_equals('', $@);

    # : wrapped void=0
    eval 'open FOO, "<", "/doesnotexists$^T$$"';
    $self->assert_not_equals('', $@);
    $self->assert_equals('Exception::Fatal::import::Test2', ref $@);

    # : wrapped void=1 in array context
    eval 'opendir FOO, "/doesnotexists$^T$$"';
    $self->assert_not_equals('', $@);
    $self->assert_equals('Exception::Fatal::import::Test2', ref $@);

    # : wrapped void=1 in scalar context
    eval 'my $ret1 = opendir FOO, "/doesnotexists$^T$$"';
    $self->assert_equals('', $@);

    # : wrapped non-core, our package
    eval 'sub_test1 undef';
    $self->assert_not_equals('', $@);
    $self->assert_equals('Exception::Fatal::import::Test2', ref $@);

    # : wrapped non-core, not our package
    eval 'Fatal::ExceptionTest::Package1::sub_test2 undef';
    $self->assert_not_equals('', $@);
    $self->assert_equals('Exception::Fatal::import::Test2', ref $@);

    # un-wrap some functions
    eval 'Fatal::Exception->unimport("open", "sub_test1", ":void", "notexists$^T$$")';

    # : un-wrapped
    eval 'open FOO, "<", "/doesnotexists$^T$$"';
    $self->assert_equals('', $@);

    # : un-wrapped
    eval 'sub_test1 undef';
    $self->assert_equals('', $@);
    
    # : wrapped
    eval 'opendir FOO, "/doesnotexists$^T$$"';
    $self->assert_not_equals('', $@);
    $self->assert_equals('Exception::Fatal::import::Test2', ref $@);

    # : wrapped non-core, not our package
    eval 'Fatal::ExceptionTest::Package1::sub_test2 undef';
    $self->assert_not_equals('', $@);
    $self->assert_equals('Exception::Fatal::import::Test2', ref $@);
    
    # un-wrap un-wrapped
    eval 'Fatal::Exception->unimport("open", "sub_test1", ":void", "notexists$^T$$")';

    # : un-wrapped
    eval 'open FOO, "<", "/doesnotexists$^T$$"';
    $self->assert_equals('', $@);

    # : un-wrapped
    eval 'sub_test1 undef';
    $self->assert_equals('', $@);

    # : wrapped
    eval 'opendir FOO, "/doesnotexists$^T$$"';
    $self->assert_not_equals('', $@);
    $self->assert_equals('Exception::Fatal::import::Test2', ref $@);

    # : wrapped non-core, not our package
    eval 'Fatal::ExceptionTest::Package1::sub_test2 undef';
    $self->assert_not_equals('', $@);
    $self->assert_equals('Exception::Fatal::import::Test2', ref $@);
    
    # re-wrapping un-wrapped
    eval 'Fatal::Exception->import("Exception::Fatal::import::Test2", "open", "sub_test1", "Fatal::ExceptionTest::Package1::sub_test2", ":void", "opendir")';
    $self->assert_equals('', $@);

    # : wrapped void=0
    eval 'open FOO, "<", "/doesnotexists$^T$$"';
    $self->assert_not_equals('', $@);
    $self->assert_equals('Exception::Fatal::import::Test2', ref $@);

    # : wrapped void=1 in array context
    eval 'opendir FOO, "/doesnotexists$^T$$"';
    $self->assert_not_equals('', $@);
    $self->assert_equals('Exception::Fatal::import::Test2', ref $@);

    # : wrapped void=1 in scalar context
    eval 'my $ret1 = opendir FOO, "/doesnotexists$^T$$"';
    $self->assert_equals('', $@);

    # : wrapped non-core, our package
    eval 'sub_test1 undef';
    $self->assert_not_equals('', $@);
    $self->assert_equals('Exception::Fatal::import::Test2', ref $@);

    # : wrapped non-core, not our package
    eval 'Fatal::ExceptionTest::Package1::sub_test2 undef';
    $self->assert_not_equals('', $@);
    $self->assert_equals('Exception::Fatal::import::Test2', ref $@);
}

1;
