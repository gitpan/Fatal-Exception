#!/usr/bin/perl
use ExtUtils::MakeMaker;
use strict;

WriteMakefile (
    NAME            => 'Fatal::Exception',
    VERSION_FROM    => 'lib/Fatal/Exception.pm', # finds $VERSION
    dist            => { COMPRESS => 'gzip -9f', SUFFIX => 'gz' },
    PMLIBDIRS       => [ 'lib' ],
    PREREQ_PM       => {
        'Exception::Base'       => 0.07,
        'Exception::System'     => 0.06,
	'Test::Unit::Lite'      => 0,
    },
    AUTHOR          => 'Piotr Roszatycki <dexter@debian.org>',
    ABSTRACT        => 'Succeed or throw exception',
);


package MY;

sub metafile {
    my $self = shift;
    my $inject = << "END";
name: $self->{DISTNAME}
abstract: $self->{ABSTRACT}
version: $self->{VERSION}
author:
  - $self->{AUTHOR}
license: perl
distribution_type: module
requires:
  perl: 5.006
  Exception::Base: 0.07
  Exception::System: 0.06
build_requires:
  Test::Unit::Lite: 0
urls:
  license: http://dev.perl.org/licenses/
meta-spec:
  version: 1.3
  url: http://module-build.sourceforge.net/META-spec-v1.3.html
generated_by: $self->{AUTHOR}
END

    $inject = join "\n\t",  map { '$(NOECHO) $(ECHO) \''.$_.'\' >> META_new.yml' }
                            split /(?:\012\015?|\015\012?)/, $inject;

    my $t = $self->SUPER::metafile_target(@_);
    my $echoCmd = '$(NOECHO) $(ECHO) \'--- #YAML:1.0\' > META_new.yml';
    my $mvCmd = q|-$(NOECHO) $(MV)|;
    my $pat = '(Generating META.yml\n\t).*' . quotemeta($mvCmd);
    $t =~ s/$pat/$1$echoCmd\n\t$inject\n\t$mvCmd/s;
    return $t;
}

1;
