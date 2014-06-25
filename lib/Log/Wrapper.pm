package Log::Wrapper;

use common::sense;

use Scalar::Util qw/set_prototype/;

# use Log::Wrapper;
#
# use Log::Wrapper qw/WARN/;
#
# use Log::Wrapper
#   level   => INFO,
#   -nocolor,
#   -set_defaults,
#   methods => {
#       ERROR => 133
#       -crit => { level => 7, color => 233 },
#   }
#       



my $LOGGER;
sub logger() { $LOGGER }


my $LEVEL;
my %DEF_METHODS = (
    debug => 245,
    info  =>   7,
    warn  => 223,
    error => 197,
    fatal => 105,
);
my %DEF_LEVELS;
{   my $l = 0;
    %DEF_LEVELS = map { $_ => ++$l } qw/debug info warn error fatal/; 
}

sub C_ESCAPE(;$) { defined $_[0] ? "\\e[38;5;$_[0]m" : "\\e[0m" }
    
my @reinit_modules;

sub import {
    my $class  = shift;
    my $caller = caller;



    $LOGGER ||= Log::Wrapper::Log->new();

    my $args = $class->build_args(@_); 

    if ( $args->{setdefault} ) {
        die 'inapproptiate time for overload defaults' if defined $LEVEL;
    }

    if ( $args->{level}) {
        die 'inapproriate time for set level' if defined $LEVEL;
        $LEVEL = $DEF_METHODS{$args->{level}} || 0;
    }
    unless (defined $LEVEL) {
        $LEVEL = 0;
    }



    *{"$caller\::_W_LOGGER"} = \$LOGGER;
    eval qq[
        sub $caller\::_inject_eval {
            eval \$_[1]; 
            die \$@ if \$@;
        }
    ];

    my $nocolor = $args->{nocolor} ? 1 : 0;
    my $reset = C_ESCAPE;
    my $single = $args->{single_arg};

    foreach my $method ( keys %{$args->{methods}} ) {
        my $uc_method = uc $method;
        if ( $LEVEL > $DEF_LEVELS{$method} ) {
            eval qq[
                sub $caller\::$uc_method() {}
            ];
        }
        else {
            my $code;
            if ($nocolor) {
                $code = qq[
                    sub $caller\::$uc_method(@) {
                        \$::_W_LOGGER->$method(@_);
                    }
                ];
            }
            else {
                my $color = $args->{methods}{$method}; 
                unless ( defined $color ) {
                    $code = qq[
                        sub $caller\::$uc_method(@) {
                            \$::_W_LOGGER->$method(@_);
                        }
                    ];
                } else {
                    $color = C_ESCAPE $color;
                    my $l_args = $single ? qq["$color\@_$reset"]
                                        : qq["$color", \@_, "$reset"];
                    $code = qq[
                       sub $caller\::$uc_method(@) {
                            \$::_W_LOGGER->$method($l_args);
                        }
                    ];

                    $caller->_inject_eval($code);
                }
            }

        }
    }

    $class->inject_autoload($caller, $single) if $args->{autoload};

    push @reinit_modules, $caller;

}

sub init {
    my ($class, $logger) = (shift, shift);

    die 'already initialized' if $LOGGER && ref $LOGGER ne 'Log::Wrapper::Log';
    die 'logger required' unless $logger;

    $LOGGER = $logger;
    foreach my $caller ( @reinit_modules ) {
        *{"$caller\::_W_LOGGER"} = \$LOGGER;
    }
}

sub inject_autoload {
    my ($class, $caller, $single) = @_;

    my $caller_cref = $caller->can('AUTOLOAD');
    unless ($caller_cref) {
        eval "
            package $caller;
            our \$AUTOLOAD;
        ";
    }

    our $AUTOLOAD;
    *{"$caller\::AUTOLOAD"} = sub {
        if ( $AUTOLOAD =~ /:([^:_]+)_?(\d{1,3})?$/ ) {
            my $method = $1;
            my $color  = $2;
            if ( $method =~ /^[A-Z]+$/ ) {
                my ($orig) = grep uc $_ eq $method, keys %DEF_METHODS;
                my $color  = Log::Wrapper::C_ESCAPE($color);
                my $reset  = Log::Wrapper::C_ESCAPE();

                my $code = qq[
                    sub $method(@) {
                        say 'aaa';
                        \$::_W_LOGGER->$orig("$color\@_$reset");
                    }
                ];
                say $code; 
                $caller->_inject_eval($code);
                die $@ if $@;

                shift;
                goto &$method;
            }
        }

        $caller_cref->(@_) if $caller_cref;
    };
}


sub build_args {
    my $class = shift;

    unless (@_) {
        return { methods => {%DEF_METHODS} };
    }

    my %args;
    my @methods;
    while (@_) {
        $_ = shift;
        if ( s/^-// ) {
            $args{$_} = 1;
        }
        else {
            push @methods, shift;
        }
    }


    if (@methods) {
        while (my $meth = shift @methods) {
            my $color;
            if ( @methods && $methods[0] =~ /^\d+$/ ) {
                $color = shift @methods;
            }
            else {
                $color = $DEF_METHODS{$meth} || undef;                
            }

            $args{methods}{$meth} = $color;
        }
    }

    if ( $args{setdefault} ) {
        %DEF_METHODS = %{$args{methods}};
        my $l = 0;
        %DEF_LEVELS = map { $_ => ++$l } @methods;
    }

    unless ( keys %{$args{methods}} ) {
        $args{methods} = {%DEF_METHODS};
    }

    return \%args;
}



package Log::Wrapper::Log;

sub new {
    bless my $self = {}, shift;
}

our $AUTOLOAD;
sub AUTOLOAD {
    my $self = shift;

    my ($method) = $AUTOLOAD =~ /([^:]+)$/;

    say "$AUTOLOAD @_";
}


1;
