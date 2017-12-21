#!/usr/bin/perl -Iblib/lib -Iblib/arch -I../blib/lib -I../blib/arch
# 
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl confusion_table.t'

# Test file created outside of h2xs framework.
# Run this like so: `perl confusion_table.t'
#   Tom Northey <zcbtfo4@acrm18>     2013/09/20 11:45:52

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use warnings;

use Data::Dumper;

use lib ( '..' );
use Test::More qw( no_plan );
use confusionTableDummy;
BEGIN { use_ok( 'TCNUtil::confusion_table' ); }

#########################

# Insert your test code below, the Test::More module is used here so read
# its man page ( perldoc Test::More ) for help writing this test script.


my $obj = bless {}, 'test_item';

my $table = confusion_table->new( item_class => ref $obj );

can_ok( $table, 'print_table');

my $true_pos = datum->new( object => $obj, prediction => 1, value => 1 );

$table->add_datum($true_pos);

$table->print_table();

my $false_pos = datum->new( object => $obj, prediction => 1, value => 0 );

$table->add_datum($false_pos);

$table->print_table();

my $true_neg = datum->new( object => $obj, prediction => 0, value => 0 );

$table->add_datum($true_neg);

$table->print_table();

my $false_neg = datum->new( object => $obj, prediction => 0, value => 1 );

$table->add_datum($false_neg);

$table->print_table();

# Add data to test subs

$table->add_datum($false_pos);

for ( my $i = 0 ; $i < 2 ; ++$i ) {
    $table->add_datum($true_neg);
}

for ( my $j = 0 ; $j < 3 ; ++$j ) {
    $table->add_datum($false_neg);
}

$table->print_table();

is($table->predicted, 3, 'sub predicted' );
is($table->actual, 5, 'sub actual' );
is($table->true_pos, 1, 'sub true_pos' );
is($table->false_pos, 2, 'sub false_pos' );
is($table->false_neg, 4, 'sub false_neg' );
is($table->true_neg, 3, 'sub true_neg' );
is($table->total, 10, 'sub total' );
is($table->sensitivity, 0.2, 'sub sensitivity' );
is($table->specificity, 0.6, 'sub specificity' );
is($table->MCC, -0.218217890235992, 'sub MCC');
is($table->PPV, 0.333333333333333, 'sub PPV' );

ok($table->hash_all(), "hash_all ok");

# Test AUC function
is(confusion_table::AUC(getConfMatrices()), 0.5, "AUC works ok");

sub getConfMatrices {
    my @pairs = ([0,1], [0.25, 0.75], [0.5, 0.5], [0.75, 0.25], [1,0]);

    my @objects = ();
    
    foreach my $pair (@pairs) {
        my $obj = confusionTableDummy->new(specificity => $pair->[0],
                                           sensitivity => $pair->[1]);

        push(@objects, $obj);
    }

    return @objects;
}
