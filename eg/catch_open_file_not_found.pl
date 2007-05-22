#!/usr/bin/perl -I../lib

use strict;
use warnings;

use Exception::Base
    'Exception::IO' => { isa => 'Exception::System' };


sub func1 {
    my $file = shift;

    use Fatal::Exception
        'Exception::IO' => 'open';

    open my($fh), $file;
}


sub func2 {
    try Exception::Base eval {
        func1('/filenotfound');
    };
    
    if (catch Exception::IO my $e) {
        warn "Caught IO exception with error " . $e->{errname}
           . "\nFull stack trace:\n\n" . $e->stringify;
    }
}


func2(2);
