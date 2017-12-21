#!/usr/bin/env perl
use strict;
use warnings;

@ARGV == 2 or Usage() and exit(1);
my $intPredResFile     = shift @ARGV;
my $toleranceLabelFile = shift @ARGV;
my %resID2PredLabel    = getResID2PredLabel($intPredResFile);
my %resID2TolLabel     = getResID2ToTolLabel($toleranceLabelFile);

my $tolerated = 1;
while (my ($resID, $tolLabel) = each %resID2TolLabel) {
    if ($tolLabel == $tolerated) {
        $resID2PredLabel{$resID} = '2:S';
    }
}

print join(":", $_, $resID2PredLabel{$_}) . "\n" foreach keys %resID2PredLabel;

sub getResID2ToTolLabel {
    my $toleranceLabelFile = shift @_;
    open(my $IN, "<", $toleranceLabelFile) or die "Cannot open file $toleranceLabelFile, $!";
    my %resID2TolLabel = ();
    while (my $line = <$IN>) {
        chomp $line;
        my ($resID, $label) = $line =~ /(.*):(.*)/;
        $resID2TolLabel{$resID} = $label;
    }
    close $IN;
    return %resID2TolLabel;
}

sub getResID2PredLabel {
    my $intPredResFile = shift @_;
    open(my $IN, "<", $intPredResFile) or die "Cannot open file $intPredResFile, $!\n";
    my %resID2PredLabel = ();
    my $reachedHeader = 0;
    while (my $line = <$IN>){
        if ($line =~ /inst/) {
            $reachedHeader = 1;
            next;
        }
        next if ! $reachedHeader;
        chomp $line;
        my @fields = split(/,/, $line);
        my $resID = $fields[-1];
        my $predLabel = $fields[2];
        $resID2PredLabel{$resID} = $predLabel;
    }
    close $IN;
    return %resID2PredLabel;
}

sub Usage {
    print <<EOF;
$0 intpred_residue_pred_file tolerance_labels_file
EOF
}
