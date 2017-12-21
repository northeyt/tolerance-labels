package test_patch;

use Moose;
use Moose::Util::TypeConstraints;

use Carp;

use TCNUtil::types;
use pdb::patch_desc;

has 'patch' => (
    is => 'rw',
    isa => 'patch',
    required => 1,
);

has 'parent' => (
    is => 'rw',
    isa => 'chain',
    required => 1,
);

has 'patchlib' => (
    is => 'rw',
    isa => 'patchlib',
    required => 1,
);

has 'classifier' => (
    is => 'rw',
    isa => 'classifier',
    required => 1,
);

has 'epitope_atom_array' => (
    is => 'rw',
    isa => 'ArrayRef[atom]',
    predicate => 'has_epitope_atom_array',
);

has 'is_epitope' => (
    is => 'ro',
    isa => 'Bool',
    lazy => 1,
    builder => '_is_epitope'
);


has 'test' => (
    is => 'ro',
    isa => 'Bool', # ie  pos or negative prediction
    builder => '_test_patch',
    lazy => 1,
);

sub _is_epitope {
    my $self = shift;

    croak "No epitope_atom_array has been set"
        if ! $self->has_epitope_atom_array();
    
    my %patch_serials
        = map { $_->{serial} => 1 } @{ $self->patch->atom_array() };

    my %epitope_serials
        = map { $_->{serial} => 1 } @{ $self->epitope_atom_array() };
    
    # Test to see if there is an overlap in atom serials
    foreach my $epi_serial (keys %epitope_serials) {
        if ( exists $patch_serials{$epi_serial} ) {
            return 1;
        }
    }
                                     
    return 0;
}

sub _test_patch {
    my $self = shift;

    my $patch      = $self->patch;
    my $parent     = $self->parent;
    my $patchlib   = $self->patchlib; # MAKE SURE YOU RUN TRANS BEFORE COMP
    my $classifier = $self->classifier;
    
    my $patch_desc = pdb::patch_desc->new(patch  => $patch,
                                     parent => $parent,);

    my @porders = $patch_desc->patch_order();
   
    foreach my $porder (@porders) {
        my $tr_patch   = $classifier->translate_patch($porder);

        # If any patch order is not found in patchlib, return true
        return 1 if ! exists {$patchlib->get_hash}->{$tr_patch};
    }

    # Return false, all porders were found in patchlib
    return 0;
}

1;
__END__

=head1 NAME

test_classifier - Perl extension for blah blah blah

=head1 SYNOPSIS

   use test_classifier;
   blah blah blah

=head1 DESCRIPTION

Stub documentation for test_classifier, 

Blah blah blah.

=head2 EXPORT

None by default.

=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

Tom Northey, E<lt>zcbtfo4@acrm18E<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2013 by Tom Northey

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.2 or,
at your option, any later version of Perl 5 you may have available.

=head1 BUGS

None reported... yet.

=cut
