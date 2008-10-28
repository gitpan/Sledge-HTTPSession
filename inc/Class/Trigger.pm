#line 1
package Class::Trigger;

use strict;
use vars qw($VERSION);
$VERSION = "0.12";

use Carp ();

my (%Triggers, %TriggerPoints);

sub import {
    my $class = shift;
    my $pkg = caller(0);

    $TriggerPoints{$pkg} = { map { $_ => 1 } @_ } if @_;

    # export mixin methods
    no strict 'refs';
    my @methods = qw(add_trigger call_trigger last_trigger_results);
    *{"$pkg\::$_"} = \&{$_} for @methods;
}

sub add_trigger {
    my $proto = shift;

    my $triggers = __fetch_triggers($proto);

    my %params = @_;
    my @values = values %params;
    if (@_ > 2 && (grep { ref && ref eq 'CODE' } @values) == @values) {
        Carp::croak "mutiple trigger registration in one add_trigger() call is deprecated.";
    }

    if ($#_ == 1 && ref($_[1]) eq 'CODE') {
        @_ = (name => $_[0], callback => $_[1]);
    }

    my %args = ( name => undef, callback => undef, abortable => undef, @_ );
    my $when = $args{'name'};
    my $code = $args{'callback'};
    my $abortable = $args{'abortable'};
    __validate_triggerpoint( $proto, $when );
    Carp::croak('add_trigger() needs coderef') unless ref($code) eq 'CODE';
    push @{ $triggers->{$when} }, [ $code, $abortable ];

    1;
}


sub last_trigger_results {
    my $self = shift;
    my $result_store = ref($self) ? $self : ${Class::Trigger::_trigger_results}->{$self};
    return $result_store->{'_class_trigger_results'};
}

sub call_trigger {
    my $self = shift;
    my $when = shift;

    my @return;

    my $result_store = ref($self) ? $self : ${Class::Trigger::_trigger_results}->{$self};

    $result_store->{'_class_trigger_results'} = [];

    if (my @triggers = __fetch_all_triggers($self, $when)) { # any triggers?
        for my $trigger (@triggers) {
            my @return = $trigger->[0]->($self, @_);
            push @{$result_store->{'_class_trigger_results'}}, \@return;
            return undef if ($trigger->[1] and not $return[0]); # only abort on false values.
        }
    }
    else {
        # if validation is enabled we can only add valid trigger points
        # so we only need to check in call_trigger() if there's no
        # trigger with the requested name.
        __validate_triggerpoint($self, $when);
    }

    return scalar @{$result_store->{'_class_trigger_results'}};
}

sub __fetch_all_triggers {
    my ($obj, $when, $list, $order) = @_;
    my $class = ref $obj || $obj;
    my $return;
    unless ($list) {
        # Absence of the $list parameter conditions the creation of
        # the unrolled list of triggers. These keep track of the unique
        # set of triggers being collected for each class and the order
        # in which to return them (based on hierarchy; base class
        # triggers are returned ahead of descendant class triggers).
        $list = {};
        $order = [];
        $return = 1;
    }
    no strict 'refs';
    my @classes = @{$class . '::ISA'};
    push @classes, $class;
    foreach my $c (@classes) {
        next if $list->{$c};
        if (UNIVERSAL::can($c, 'call_trigger')) {
            $list->{$c} = [];
            __fetch_all_triggers($c, $when, $list, $order)
                unless $c eq $class;
            if (defined $when && $Triggers{$c}{$when}) {
                push @$order, $c;
                $list->{$c} = $Triggers{$c}{$when};
            }
        }
    }
    if ($return) {
        my @triggers;
        foreach my $class (@$order) {
            push @triggers, @{ $list->{$class} };
        }
        if (ref $obj && defined $when) {
            my $obj_triggers = $obj->{__triggers}{$when};
            push @triggers, @$obj_triggers if $obj_triggers;
        }
        return @triggers;
    }
}

sub __validate_triggerpoint {
    return unless my $points = $TriggerPoints{ref $_[0] || $_[0]};
    my ($self, $when) = @_;
    Carp::croak("$when is not valid triggerpoint for ".(ref($self) ? ref($self) : $self))
        unless $points->{$when};
}

sub __fetch_triggers {
    my ($obj, $proto) = @_;
    # check object based triggers first
    return ref $obj ? $obj->{__triggers} ||= {} : $Triggers{$obj} ||= {};
}

1;
__END__

#line 349

