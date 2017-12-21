package patchlib;

use Data::Dumper;
use strict;
use warnings;
our $AUTOLOAD;
use Carp;
#use DBI;

# Class data and methods
{
    # A list of all attributes with default values and read/write/required
    #properties
    my %_attribute_properties = (
        _array        => [ [], 'read.write' ],
        _hash         => [ {}, 'read.noinit'],
        _include      => [ {}, 'read.write' ],
        _exclude      => [ {}, 'read.write' ],
        _classifier   => [ {}, 'read.write' ],
    );
        
    # Global variable to keep count of existing objects
    my $_count = 0;

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
	$_attribute_properties{$attribute}[0];
    }

    sub _get_dbh {
        my $dbname = "zcbtfo4";
        my $dbhost = "acrm8";

        my $dbh = DBI->connect("dbi:Pg:dbname=$dbname;host=$dbhost");
        croak "Could not connect to database" if(!$dbh);

        return $dbh;
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

    # Create array of patches using _search
    $self->{_array} = [$self->_search()];
    
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

    # Return the attribute value
    my $ref = ref $self->{$attribute};
    
    return  $ref eq 'ARRAY' ? @{ $self->{$attribute} }
          : $ref eq 'HASH'  ? %{ $self->{$attribute} }
          : $self->{$attribute}
          ;
}

sub DESTROY {
}

# Other methods.  They do not fall into the same form as the majority handled by AUTOLOAD

sub _search {

    my($self) = @_;

    my %include = $self->get_include;
    my %exclude = $self->get_exclude;

    # Form strings to be appended
    my $size
        =  exists $include{size} ? "length(patch_order)=$include{size}"
         : exists $exclude{size} ? "length(patch_order)!=$exclude{size}"
         : '' 
         ;
                     
    my $source
        =  exists $include{source} ? "source_taxid='$include{source}'"
         : exists $exclude{source} ? "source_taxid!='$exclude{source}'"
         : ''
         ;
    
    my @pdbids =  exists $include{pdbids} ? @{ $include{pdbids} }
                : ('')
                ;
              
    my $dbh = $self->_get_dbh;

    my $sql = "SELECT patch_order FROM new_patch";
    
    if ($source) {
        $sql .= " WHERE $source";
    }

    if ($size) {
        $sql .= $source ? " AND $size" : " WHERE $size" ; 
    }
    
    my @patches;
    
    foreach my $pdbid (@pdbids) {

        my $pdb_code;
        my $chain_id;
        if (length $pdbid == 5) {
             $pdb_code = substr($pdbid, 0, 4);
             $chain_id = substr($pdbid, 4, 1);
        }
        else {
            # pdbID is a modelID and modelID can be used to identify patches,
            # as a model only has one chain
            $pdb_code = $pdbid;
        }
        
        my $loop_sql = $sql;
        
        if ($pdbid ne '') {
            $loop_sql
                .= ($source || $size) ? " AND pdb='$pdb_code'"
                : " WHERE pdb='$pdb_code'";
             
            $loop_sql .= " AND chain_id='$chain_id'" if defined $chain_id;
        }
        
        my $sth = $dbh->prepare($loop_sql);

        
        if ($sth->execute) {
            while ( my($porder) = $sth->fetchrow_array ) {
                push(@patches, $porder);
            }
        }
        else {
            croak "Something went wrong trying to query the new_patch table";
        }
    }
    
    return @patches;
        
}

# Translates patchlib array using sets of a classifier
sub translate {
    my($self) = @_;

    # If object classifier not defined, copy array
    if (ref $self->get_classifier eq '') {
        my %hash = ();
        $hash{$_}++ foreach $self->get_array;
        $self->{_hash} = {%hash};

        return %hash;
    }

    if (ref $self->get_classifier eq 'classifier') {
        my %hash = ();

        foreach my $patch ($self->get_array) {
            my $tr_patch = $self->get_classifier->translate_patch($patch);

            ++$hash{$tr_patch}; # Important for classifier performance
                                # validation
        }
        
        $self->{_hash} = { %hash };
        
        return %hash;        
    }
    else {
        croak "object classifier attribute is not a valid classifier object";
    }    
}

1;

