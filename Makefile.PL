use 5.010;
use strict;

use ExtUtils::MakeMaker;

WriteMakefile(
    NAME => 'Log::Wrapper',
    VERSION_FROM => 'lib/Log/Wrapper.pm',
    AUTHOR       => 'Andrey Asyakin <asan999@gmail.com>',

    PREREQ_PM   => {
        'common::sense' => 0,
    }
);

