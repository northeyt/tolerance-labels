package classifier;

use strict;
use warnings;
our $AUTOLOAD;
use Carp;

use Data::Dumper;
use Test::Deep::NoTest;

# Class data and methods
{
   
    # A list of all attributes with default values and read/write/required
    #properties
    my %_attribute_properties = (
        _id          => [ \&_gen_id, 'read.write' ],
        _sets        => [ [],	'read.write'],
        _num_sets    => [ '', 'read.write.required'],
        _sets_hash   => [ {}, 'read.noinit' ],
        _performance => [ [], 'read.write' ],
    );
        
    # Global variable to keep count of existing objects
    my $_count = 0;
    # Global variable for _gen_id
    my $id_count = 0;

    sub _gen_id {
        return ++$id_count;
    }
   
    # Return a list of all attributes
    sub _all_attributes {
    	keys %_attribute_properties;
    }

    # Check if a given property is set for a given attribute
    sub _permissions {
        my($self, $attribute, $permissions) = @_;
	$_attribute_properties{$attribute}[1] =~ /$permissions/;
    }

    # Return the default value for a given attribute
    sub _attribute_default {
    	my($self, $attribute) = @_;
        if (ref $_attribute_properties{$attribute}->[0] eq 'CODE') {
            return &{ $_attribute_properties{$attribute}->[0] };
        }
	$_attribute_properties{$attribute}[0];
    }

    # Manage the count of existing objects
    sub get_count {
        $_count;
    }
    sub _incr_count {
        ++$_count;
    }
    sub _decr_count {
        --$_count;
    }
}

# The constructor method
# Called from class, e.g. $obj = Gene->new();
sub new {
    my ($class, %arg) = @_;
    # Create a new object
    my $self = bless {}, $class;

    foreach my $attribute ($self->_all_attributes()) {
        # E.g. attribute = "_name",  argument = "name"
        my($argument) = ($attribute =~ /^_(.*)/);
	# If explicitly given
	if (exists $arg{$argument}) {
	    $self->{$attribute} = $arg{$argument};
	# If not given, but required
	}elsif($self->_permissions($attribute, 'required')) {
	    croak("No $argument attribute as required");
	# Set to the default
	}else{
	    $self->{$attribute} = $self->_attribute_default($attribute);
	}
    }

    # Check number of sets is allowed and generate sets if needed
    if (@ { $self->{_sets} } ) {
        croak "Number of sets passed exceeds passed num_sets"
            if scalar @{ $self->{_sets} } > $self->{_num_sets};
                  
    }
    else {
        my @sets = _random_sets( $self->{_num_sets} );
        $self->{_sets} = [@sets];
    }

    # Test sets are complete
    are_sets_complete( $self->get_sets() );
    
    # Create sets hash
    $self->{_sets_hash} = { _make_sets_hash( @{ $self->{_sets} } ) };

    $class->_incr_count();
    return $self;
}

# The clone method
# All attributes will be copied from the calling object, unless
# specifically overridden
# Called from an exisiting object, e.g. $cloned_obj = $obj1->clone();
sub clone {
    my ($caller, %arg) = @_;
    # Extract the class name from the calling object
    my $class = ref($caller);
    # You can only call "clone" from an object, not the class
    unless ($class) {
        carp "Need an existing object to clone";
	return;
    }
    # Create a new object
    my $self = bless {}, $class;

    foreach my $attribute ($self->_all_attributes()) {
        # E.g. attribute = "_name",  argument = "name"
        my($argument) = ($attribute =~ /^_(.*)/);
	# If explicitly given
	if (exists $arg{$argument}) {
	    $self->{$attribute} = $arg{$argument};
        }
        # Assign new id
        elsif ($attribute eq '_id') {
            $self->{$attribute} = _gen_id();
	# Otherwise copy attribute of new object from the calling object
	}else{
            $self->{$attribute} = $caller->{$attribute};
	}
    }
    $self->_incr_count();
    return $self;
}



# This takes the place of such accessor definitions as:
#  sub get_attribute { ... }
# and of such mutator definitions as:
#  sub set_attribute { ... }
sub AUTOLOAD {
    my ($self, $newvalue) = @_;

    my ($operation, $attribute) = ($AUTOLOAD =~ /(get|set)(_\S+)$/);
    
    # Is this a legal method name?
    unless($operation && $attribute) {
        croak "Method name $AUTOLOAD is not in the recognized form (get|set)_attribute\n";
    }
    unless(exists $self->{$attribute}) {
        croak "No such attribute $attribute exists in the class "
              . ref($self);
    }

    # Turn off strict references to enable "magic" AUTOLOAD speedup
    no strict 'refs';

    # AUTOLOAD accessors
    if($operation eq 'get') {
        
        # Complain if you can't get the attribute
	unless($self->_permissions($attribute, 'read')) {
	    croak "$attribute does not have read permission";
	}

        # Install this accessor definition in the symbol table
	*{$AUTOLOAD} = sub {
	    my ($self) = @_;
	    unless($self->_permissions($attribute, 'read')) {
	        croak "$attribute does not have read permission";
	    }

            my $ref = ref $self->{$attribute};
            
            return  $ref eq 'ARRAY' ? @{ $self->{$attribute} } 
                  : $ref eq 'HASH'  ? %{ $self->{$attribute} }
                  : $self->{$attribute}
                  ;
        };

    # AUTOLOAD mutators
    }elsif($operation eq 'set') {

        # Complain if you can't set the attribute
	unless($self->_permissions($attribute, 'write')) {
	    croak "$attribute does not have write permission";
	}

	# Set the attribute value
        $self->{$attribute} = $newvalue;

        # Install this mutator definition in the symbol table
	*{$AUTOLOAD} = sub {
   	    my ($self, $newvalue) = @_;
	    unless($self->_permissions($attribute, 'write')) {
	        croak "$attribute does not have write permission";
	    }
	    $self->{$attribute} = $newvalue;
        };
    }

    # Turn strict references back on
    use strict 'refs';

    my $ref = ref $self->{$attribute};
    
    # Return the attribute value
    return  $ref eq 'ARRAY' ? @{ $self->{$attribute} } 
          : $ref eq 'HASH'  ? %{ $self->{$attribute} }
          : $self->{$attribute}
          ;
}

# When an object is no longer being used, this will be automatically called
# and will adjust the count of existing objects
sub DESTROY {
    my($self) = @_;
    $self->_decr_count();
}

# Other methods.  They do not fall into the same form as the majority handled
# by AUTOLOAD

sub mutate {
    my ($self) = @_;

    croak "$self is not a classifier object!\n"
        if ref $self ne 'classifier';

    # Check required
    
    my @sets = $self->get_sets();
    croak "Set array for classifier object $self is not intialized"
        if ! @sets;

    croak "Set array does not contain 20 amino acids"
        if ! are_sets_complete(@sets);
    
    # Get random source and target indices
    # Source array must have > 1 element
    my $i = 'NULL';
    
    until ($i ne 'NULL') {
        my $rand_i = int rand @sets;
       
        if ( scalar @{ $sets[$rand_i] } > 1 ){
            $i = $rand_i;
        }
    }

    # Target array must not equal source array
    my $j = 'NULL';

    until ($j ne 'NULL') {
        my $rand_j = int rand @sets;
        if ($rand_j ne $i) {
            $j = $rand_j;
        }
    }

    # Get random element from source index
    my $e = $sets[$i]->[ int rand @{ $sets[$i] } ];

    # Remove element from source and push to target
    @{ $sets[$i] } = grep { $_ ne $e } @{ $sets[$i] };
    push( @{ $sets[$j] }, $e);

    
    croak "Sets became incomplete during mutation process"
        if ! are_sets_complete(@sets); 

    # Reset object attributes
    $self->{_sets} = [@sets];
    $self->{_sets_hash} = { _make_sets_hash(@sets) };
    
    return @sets;
    
}

sub are_sets_complete {
    my @sets = @_;

    my @acids = qw(Q W E R T Y I P A S D F G H K L C V N M);

    my %acid_hash = ();
    
    foreach my $acid (@acids) {
        ++$acid_hash{$acid};
    }

    my $i = 0;
  
    foreach my $set (@sets) {
        foreach my $element ( @{$set} ) {
            croak "Unrecognized amino acid $element in set array"
                if ! exists $acid_hash{$element};

            croak "Amino acid $element seen more than once in set array"
                if $acid_hash{$element} > 1;

            ++$acid_hash{$element};
            ++$i;
        }
    }
      return $i == 20 ? 1 : 0;
}

sub _random_sets {
    my ($num_sets) = @_;

    croak "Number of sets passed to random_sets must > 0 and <= 20"
        if $num_sets < 1 || $num_sets > 20;
    
    my @acids = qw(Q W E R T Y I P A S D F G H K L C V N M);

    my @sets;
    
    # Choose x acids to fill x sets
    for (my $i = 0 ; $i < $num_sets ; ++$i ) {
        my $rand_j = rand int @acids;
        $sets[$i] = [ $acids[$rand_j] ];
        splice (@acids, $rand_j, 1);
    }

    # Randomly assign remaining acids to sets
    for (my $i = 0 ; $i < @acids ; ++$i) {
        my $rand_j = rand int @sets;
        push( @{ $sets[$rand_j] }, $acids[$i] );
    }
    
    # Check sets are complete
    croak "random_sets created incomplete sets"
        if ! are_sets_complete @sets;

    return @sets;
}

sub _make_sets_hash {
    my(@sets) = @_;

    my %h = ();

    for (my $i = 0 ; $i < @sets ; ++$i ) {
        for ( my $j = 0 ; $j < @{ $sets[$i] } ; ++$j ) {
            $h{ $sets[$i]->[$j] } = $i;
        }
    }
    return %h;
}

sub translate_patch {
    my($self, $patch) = @_;

    my %hash = $self->get_sets_hash();
    my $tr_patch = $patch;
    
    for ( my $i = 0 ; $i < length $patch ; ++$i ) {
        substr($tr_patch, $i, 1) = num2let( $hash{ substr($patch, $i, 1) } );
    }

    croak "Something went wrong trying to translate patch $patch with hash "
        . Dumper \%hash  
            if length $tr_patch ne length $patch;

    my $stand_rep
        = substr($tr_patch, 0, 1) . stand_rep( substr($tr_patch, 1) );
    
    return $stand_rep;
    
}

sub num2let {
    my($num) = @_;

    my %num2let = (
        0 => 'A',
        1 => 'B',
        2 => 'C',
        3 => 'D',
        4 => 'E',
        5 => 'F',
        6 => 'G',
        7 => 'H',
        8 => 'I',
        9 => 'J',
        10 => 'K',
        11 => 'L',
        12 => 'M',
        13 => 'N',
        14 => 'O',
        15 => 'P',
        16 => 'Q',
        17 => 'R',
        18 => 'S',
        19 => 'T',
        20 => 'U',
    );

    exists  $num2let{$num} ? return $num2let{$num}
          : croak "Invalid value $num passed to num2let";

}

sub stand_rep {
    my($string) = @_;

    my $double_str = $string . $string;
    my $stand_rep = '';

    for ( my $i = 0 ; $i < length $string ; ++$i ) {
        if ( substr($double_str, $i, length $string) gt $stand_rep ) {
            $stand_rep = substr($double_str, $i, length $string );
        }
    }

    croak "Something went wrong running stand_rep"
        if length $stand_rep ne length $string;
    
    return $stand_rep;
}

# Returns true if self and given test classifiers sets are identical
sub sets_are_identical {
    my $self = shift;
    my $test_classifier = shift
        or die "set_are_identical must be passed a classifier to compare sets against";

    croak "$test_classifier is not a classifier! set_are_identical must be passed a classifier"
        if ref $test_classifier ne 'classifier';

    # Test equality of self and given test classifier sets
    if ( eq_deeply([$self->get_sets()], [$test_classifier->get_sets()]) ) {
        return 1;
    }
    else {
        return 0;
    }
}


1;
