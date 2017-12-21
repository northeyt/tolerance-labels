#!/acrm/usr/local/bin/perl
# 
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test_performance.t'

# Test file created outside of h2xs framework.
# Run this like so: `perl test_performance.t'
#   Tom Northey <zcbtfo4@acrm18>     2013/09/17 12:28:24

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use warnings;

use lib ( '../lib' );
use patchlib;
use classifier;
use pdb::automatic_patches;
use pdb::patch_desc;

use GLOBAL qw( rm_trail one2three_lc );
use Carp;
use Data::Dumper;

use Test::More qw( no_plan );
BEGIN { use_ok( 'test_patch' ); }

#########################

# Insert your test code below, the Test::More module is used here so read
# its man page ( perldoc Test::More ) for help writing this test script

# Init patchlib
open( my $fh, '<', 'patchlib_dump' );

my $dump;

{
    local $/;
    $dump = <$fh>;
}

close $fh;

my $patchlib = eval $dump;

# Init classifier
my @sets = ( ['Y','K','E'], ['P','A','Q','D','N'], ['G','H','I','M','C','L','W','R','V','F'], ['S','T'] );

my %cl_arg
    = ( sets => [@sets],
        num_sets => 4 );


my $classifier = classifier->new(%cl_arg);

$patchlib->set_classifier($classifier);
$patchlib->translate();

# Init antigen patches, get test patch
my %autopatch_args
    = (pdb_code => '2ybr',
       chain_id => 'C',
       radius   => 8,
       patch_type => 'contact' );

my $autop = automatic_patches->new(%autopatch_args);

# Init chain object

my %chain_args
    = (pdb_code => '2ybr',
       chain_id => 'C',
       pdb_file => $autop->pdb_file,
       xmas_file => 'pdb2ybr.xmas',
   );

my $chain = chain->new(%chain_args);


my @epitope_seqRes
    =  qw( 7 14 15 16 17 18 19 22 24 27 42 43 44 45 );

# Get atom objects for epitope

my $epitope_chain = 'C';
my @atoms = get_atoms($chain, @epitope_seqRes);

# Get a epitope and non-epitope patch

my $patch;
my $non_epi_patch;
my $patchlib_patch;
my $not_patchlib_patc;

my $strings = join "|", @epitope_seqRes;
my $re      = qr/$strings/;

foreach my $p( $autop->get_patches ) {
    if ( $p->summary =~ /C:7/ ){
        $patch = $p;
    }
    else {
        unless ($p->summary =~ m{ :($re) }xms) {
            $non_epi_patch = $p;
        }
    }

    # Patch C.7 has porder found in patchlib dump
    if ( $p->summary() =~ /<patch C\.7>/) {
        $patchlib_patch = $p;
    }
    last if $patch && $non_epi_patch && $patchlib_patch;
}

# Init test_patch obj

my %tpatch_arg = ( patch => $patch,
                   parent => $chain,
                   patchlib => $patchlib,
                   classifier => $classifier,
                   epitope_atom_array => [ @atoms ], );

my $t_patch = test_patch->new(%tpatch_arg);

# Ensure that patch lib is translated
$t_patch->patchlib->set_classifier($t_patch->classifier);

can_ok($t_patch, '_is_epitope' );

is($t_patch->_is_epitope, 1, "_is_epitope flags an epitope patch");

$t_patch->patch($non_epi_patch);

is($t_patch->_is_epitope, 0, "_is_epitope flags a non-epitope patch");

can_ok($t_patch, '_test_patch' );

sub get_atoms {
    my($chain, @seqRes) = @_;

    my $chain_id = $chain->chain_id;
    my $atom_index = $chain->atom_index;
    my $atom_array = $chain->atom_array;

    my @all_atoms = ();
    
    foreach my $num (@seqRes) {
        my @atoms = values %{ $atom_index->{$chain_id}->{$num} };
        push(@all_atoms, @atoms);
    }
    return @all_atoms;    
}
