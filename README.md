## To generate tolerance labels for human-antibody antigen:

```
./scripts/get_tolerance_labels.pl -in my_chain.list -c -p data/human_TSL.dump -out my_out_dir/ -i -x data/human_best_grouping_scheme.dat
```

To generate tolerance labels for mouse-antibody antigen:

```
./scripts/get_tolerance_labels.pl -in my_chain.list -c -p data/human_TSL.dump -out my_out_dir/ -i -x data/human_best_grouping_scheme.dat
```

If you have a list of PDB files rather than PDB codes, change the -c option to -d

```
./scripts/get_tolerance_labels.pl -in my_file.list -d -p data/human_TSL.dump -out my_out_dir/ -i -x data/human_best_grouping_scheme.dat
```

Input format example for list of PDB chains:

1a2y C
2qza A B

Input format example list of PDB files:

path/to/1a2y.pdb C
path/to/2qza.pdb A B

## Combining tolerance labels with IntPred

There are three steps involved.

First run IntPred like so

```
path/to/IntPred/bin/runIntPred.pl -f pdb -p out_patch_dir/ -o intpred.preds -c test.intpred.in
```

Where `test.intpred.in`  is formatted for IntPred (run runIntPred.pl with -h option for more details).
Change -f option to file if test.intpred.in lists file paths rather than pdb codes.

Then run

```
path/to/IntPred/bin/transformPatch2ResiduePred.pl -c intpred.preds out_patch_dir/ class1.confusion_table_all_residues.instances 
```

Where `class1.confusion_table_all_residues.instances` is the output from get_tolerance_labels.pl

Finally, use filter_intpred_labels.pl to filter IntPred predictions.

```
./scripts/filter_intpred_labels.pl residue.preds class1.confusion_table_all_residues.instances
```

where `residue.preds` is the output from transformPatch2ResiduePred.pl
