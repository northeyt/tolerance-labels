#!/usr/bin/env perl
# get_tolerance_labels.pl --- get tolerance labels and assess performance
# Author: Tom Northey
# Created: 24 Sep 2013
# Version: 0.01

use warnings;
use strict;

use FindBin qw($Bin);
use lib "$Bin/../lib/";

use Carp;
use Getopt::Long;
use Storable;

use pdb;
use pdb::get_files;
use TCNUtil::confusion_table;

use classifier;
use patchlib;
use run_classifier;

## INITIALIZATION #############################################################
###############################################################################

my $in;
my $p;
my $g = 0;
my $r = 0;
my $out;
my $inFileIsResLabelFormat;
my $inFileIsPDBFileList;
my $inFileIsPDBChainList;
my $labelResFromFile;
my $predictionsOnly;
my $formatOutputForIntPred;

GetOptions('in=s',  \$in,
           'p=s',   \$p,
           'g',     \$g,
           'r',     \$r,
           'out=s', \$out,
           'l',     \$inFileIsResLabelFormat,
           'd',     \$inFileIsPDBFileList,
           'c',     \$inFileIsPDBChainList,
           'f',     \$labelResFromFile,
           'x',     \$predictionsOnly,
           'i' ,    \$formatOutputForIntPred
       );

# Check mand. options and that ARGV has args (classifer input files)
Usage() if ! ($in && $p && @ARGV);

# Init antigen objects
my @antigens
    = $inFileIsResLabelFormat ? test_classifier::input::parse_antigens_from_reslabel_file($in)
    : $inFileIsPDBFileList    ? test_classifier::input::get_antigens_from_PDB_file_list($in)
    : $inFileIsPDBChainList   ? test_classifier::input::get_antigens_from_PDB_chain_list($in)
    : test_classifier::input::parse_antigens($in);

my %pdbResID2Label = test_classifier::input::getPDBResID2LabelFromFile($in)
    if $labelResFromFile;

croak "No antigen parsed from input file $in" if ! @antigens;
print @antigens . " antigen parsed from input file\n";

# Init patchlib
print "Parsing patchlib dump ...";
my $patchlib  = parse_patchlib_dump($p);
print " done\n";

# Get classifiers from input
my @classifiers = ();

if ($r) {
    # Input files are .classifiers output from gen_algo_v3
    foreach my $input_file (@ARGV) {
        push(@classifiers, parse_GA_output($input_file));
    }
}
else {
    # Input files are "dumps" - i.e. a file containing only an eval-able string
    # e.g. [['D'],['W','S'],['R','P','L','G'],['E','T','V','F']]
    @classifiers = map { parse_classifier_dump($_) } @ARGV;
}

croak "No classifiers were produced from input file(s)!" if ! @classifiers;
print @classifiers . " classifiers to be tested\n";

# Init csv arrays and out files
my $header
    = [ qw( id true_pos true_neg false_pos false_neg sensitivity specificity
            PPV MCC ) ];

my @confusion_tables = qw(confusion_table_patch confusion_table_all_residues
                          confusion_table_surf_residues);
my %results = map { $_ => [] } @confusion_tables;

my %out_fh = ();

if (! $predictionsOnly) {
    foreach my $table (keys %results) {
        my $out_dir = defined $out ? $out . '/' : '';
        my $out_file = "$out_dir$table.results";
        open(my $OUT, '>', $out_file) or die "Cannot open file file '$out_file'";
        $out_fh{$table} = $OUT;
    }
}

## MAIN #######################################################################
###############################################################################

# Ref to test_classifier object
my $test;

my $i = 1;
foreach my $classifier (@classifiers) {
    print "Classifying using group scheme $i\n";
    # Init test_classifier object if first loop, else set new classifier
    if (! $test) {
        $test = test_classifier->new(antigen_array   => [@antigens],
                                     patchlib        => $patchlib,
                                     classifier      => $classifier,
                                     cluster => $g,
                                 );
        $test->pdbResID2LabelHref(\%pdbResID2Label) if $labelResFromFile;
    }
    else {
        $test->classifier($classifier);
    }
    
    $test->run();
    save_results($test, \%results, $header);

    printSummaries($test) if ! $predictionsOnly;

    print "Writing results to output files\n";
    # Print per-instance prediction output from each confusion table
    foreach my $table (@confusion_tables) {
        my $FH = prepareInstanceOutFile($test, $table, $out, $predictionsOnly,
                                        $formatOutputForIntPred);
        
        foreach my $datum (@{$test->$table->data()}) {
            my $instance = $datum->object();
            my $instanceStr
                = ref $instance eq 'test_patch' ? $instance->patch->id()
                : ref $instance eq 'pdbresid' ? $instance->{pdbresid}
                : croak "Unrecognised instance $instance!\n";

            my $outString = join(",", ($instanceStr, $datum->prediction()));
            $outString .= "," . $datum->value() if ! $predictionsOnly;
            $outString = formatOutputForIntPred($outString) if $formatOutputForIntPred;
            print {$FH} "$outString\n";
        }
        close $FH;
    }
    ++$i;
}

if (! $predictionsOnly) {
    # Print results to out files
    foreach my $table (keys %results) {
        my $results = $results{$table};
        print {$out_fh{$table}} join(',', @{$header}) . "\n";
        
        foreach my $row (@{$results}) {
            print {$out_fh{$table} } join(',', @{$row}) . "\n"; 
        }
    }
}

## SUBROUTINES ################################################################
###############################################################################


sub printSummaries {
    my $test = shift;
    
    print "RESULTS:\n";
    
    print "Test Unit - Patches:\n";
    $test->confusion_table_patch->print_all();
    
    print "Test Unit - Residue\n";
    $test->confusion_table_all_residues->print_all();
    
    print "Test Unit - Surface Residue\n";
    $test->confusion_table_surf_residues->print_all();
    
    print "ERRORS:\n";
    print "$_\n" foreach @{ $test->errors };
}

# Opens a new file in the given results dir and writes header.
# Returns a file handle
sub prepareInstanceOutFile {
    my $test = shift;
    my $tableName = shift;
    my $outDir = shift;
    my $predictionsOnly = shift;
    my $formatOutputForIntPred = shift;
    
    my $classID = $test->classifier->get_id();
    my $outFname  = defined $out ? $out . '/' : '';
    $outFname .= join(".", ("class$classID", $tableName, "instances"));
    
    open(my $OUT, ">", $outFname) or die "Cannot open file $outFname, $!";
    # Print header
    if (! $formatOutputForIntPred){
        print {$OUT} $predictionsOnly ? "instance,prediction\n" : "instance,prediction,value\n";
    }
    return $OUT;
}


sub save_results {
    my($test, $results_h, $header_arr) = @_;
    
    # Get results from each table
    foreach my $table ( keys %{ $results_h } ) {
        my $table_results = { $test->$table->hash_all(printable => 1) };

        my @values = ();

        # Order results (values) by header order
        for my $j ( 0 .. @{$header_arr} - 1  ) {

            my $field = $header_arr->[$j];

            # Take field 'id' as classifier id
            if ($field eq 'id') {
                push( @values, $test->classifier->get_id() );
                next;
            }
            
            my $value;
            my $ret
                = eval {
                    # Results are hashed by field
                    $value = $table_results->{$field};
                    1; };
            
            croak "$field was not returned by confusion table $table"
                if ! $ret;
            
            push(@values, $value);
        }
        push( @{ $results_h->{$table} }, \@values );
    }
}

# Parses a .classifiers file output from gen_algo_v3.pl
# returns an array of classifier objects 
sub parse_GA_output {
    my $file = shift or die "parse_GA_output must be passed a filename";

    open(my $IN, '<', $file) or die "Cannot open input file $file, $!";

    my @classifiers  = ();

    # Skip header line
    my $line = <$IN>;
    
    while ($line = <$IN>) {
        
        my @fields = split(/\s*\|\s*/, $line);

        # Build classifier object from set string in third field
        push( @classifiers, classifier_from_sets_string($fields[3]) );
    }

    die "No classifiers were parsed from input file $file" if ! @classifiers;

    return @classifiers;
}

sub parse_classifier_dump {
    my($file) = @_;
    open(my $fh, '<', $file )
        or die "Cannot open input classifier file $file - $!";
    return map {classifier_from_sets_string($_)} <$fh>;
}

sub classifier_from_sets_string {
    my $string = shift;

    my $sets = eval $string;
    croak "No sets parsed from input classifier file"
        if ! $sets;

     my $classifier = classifier->new(sets => $sets,
                                      num_sets => scalar @{$sets});

    return $classifier;
}


sub parse_patchlib_dump {
    my($file) = @_;
        
    open(my $fh, '<', $file)
        or die "Cannot open input patchlib dump file $file - $!";

    my $data;
    {
        local $/;
        $data = <$fh>;
    }
    close $fh;
    my $VAR1;
    eval $data;
    my $patchlib = $VAR1;
    if (! $patchlib) {
        $patchlib = eval {retrieve($file)};
        croak "Unable to retrieve patchlib, $@" if ! $patchlib;
    }

    return $patchlib;
}

sub formatOutputForIntPred {
    my $string = shift;
    my ($pdbID, $resID, $label) = split(/[.,]/, $string);
    my $chainID = chop($pdbID);
    my $pdbCode = $pdbID;
    return join(":", $pdbCode, $chainID, $resID, $label);
}

sub Usage {
    print <<EOF;
$0 USAGE:
[ -in <antigen input file> [d|c] -p <patchlib> -out <dir> -grlx ] classifier_input_files

-in  : input antigen file (output from get_IEDB_epitopes)

-d   : in file is a list of PDB file paths with optional chainIDs, e.g.
        1a2y.pdb C

-c   : in file is a list of of PDB chain IDs, e.g.
        1a2y B C

-p   : patchlib (Data dump)

-g   : clustering mode: patch is predicted positive if patch center is within
       16A of another positive prediction

-out : out dir for results files

-r   : read classifier_input_files as output files from gen_algo_v3.pl

-l   : read antigen input file as a residue .labels file

-f   : read residue labels from residue .labels file

-x   : output predicted labels only

-i   : format output for IntPred

EOF
    
    exit;
}
