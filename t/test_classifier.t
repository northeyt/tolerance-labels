#!/usr/bin/env perl

use strict;
use warnings;

use lib ( 'lib/' );
use patchlib;
use classifier;
use pdb::get_files;

use TCNUtil::GLOBAL qw( rm_trail one2three_lc );
use Carp;
use Data::Dumper;

use Test::More qw( no_plan );
BEGIN { use_ok( 'run_classifier' ); }

#########################

# Insert your test code below, the Test::More module is used here so read
# its man page ( perldoc Test::More ) for help writing this test script

# Init patchlib
open( my $fh, '<', 't/patchlib_dump' );

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

my $antigens_file = 't/test_antigen.input';

my @antigens = test_classifier::input::parse_antigens($antigens_file);
# Init test_classifier object
my $test
    = test_classifier->new( antigen_array   => [ $antigens[0] ],
                            patchlib        => $patchlib,
                            classifier      => $classifier,
                            cluster => 1,
                        );

is( ! @{$test->errors} ? 1 : 0, 1, "No BUILDER errors" );

ok( $test->run(), "run works ok"  );
