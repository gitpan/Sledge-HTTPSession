#line 1
package Class::Trigger;

use strict;
use vars qw($VERSION);
$VERSION = "0.10";

use Class::Data::Inheritable;
use Carp ();

sub import {
    my $class = shift;
    my $pkg = caller(0);

    # XXX 5.005_03 isa() is broken with MI
    unless ($pkg->can('mk_classdata')) {
	no strict 'refs';
	push @{"$pkg\::ISA"}, 'Class::Data::Inheritable';
    }

    $pkg->mk_classdata('__triggers');
    $pkg->mk_classdata('__triggerpoints');

    $pkg->__triggerpoints({ map { $_ => 1 } @_ }) if @_;

    # export mixin methods
    no strict 'refs';
    my @methods = qw(add_trigger call_trigger);
    *{"$pkg\::$_"} = \&{$_} for @methods;
}

sub add_trigger {
    my $proto = shift;

    # should be deep copy of the hash: for inheritance
    my $old_triggers = __fetch_triggers($proto) || {};
    my %triggers = __deep_dereference($old_triggers);
    while (my($when, $code) = splice @_, 0, 2) {
	__validate_triggerpoint($proto, $when);
	Carp::croak('add_trigger() needs coderef') unless ref($code) eq 'CODE';
	push @{$triggers{$when}}, $code;
    }
    __update_triggers($proto, \%triggers);
}

sub call_trigger {
    my $self = shift;
    return unless my $all_triggers = __fetch_triggers($self); # any triggers?
    my $when = shift;
    if (my $triggers = $all_triggers->{$when}) {
	for my $trigger (@$triggers) {
	    $trigger->($self, @_);
	}
    }
    else {
	# if validation is enabled we can only add valid trigger points
	# so we only need to check in call_trigger() if there's no
	# trigger with the requested name.
	__validate_triggerpoint($self, $when);
    }
}

sub __validate_triggerpoint {
    return unless my $points = $_[0]->__triggerpoints;
    my ($self, $when) = @_;
    Carp::croak("$when is not valid triggerpoint for ".(ref($self) ? ref($self) : $self))
	unless $points->{$when};
}

sub __fetch_triggers {
    my $proto = shift;
    # check object based triggers first
    return (ref $proto and $proto->{__triggers}) || $proto->__triggers;
}

sub __update_triggers {
    my($proto, $triggers) = @_;
    if (ref $proto) {
	# object attributes
	$proto->{__triggers} = $triggers;
    }
    else {
	# class data inheritable
	$proto->__triggers($triggers);
    }
}

sub __deep_dereference {
    my $hashref = shift;
    my %copy;
    while (my($key, $arrayref) = each %$hashref) {
	$copy{$key} = [ @$arrayref ];
    }
    return %copy;
}

1;
__END__

#line 276

