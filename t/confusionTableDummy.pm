# dummy class used in confusion_table.t
package confusionTableDummy;

use Moose;

has 'specificity' => (
    isa => 'Num',
    is => 'rw',
);

has 'sensitivity' => (
    isa => 'Num',
    is => 'rw',
);

1;
