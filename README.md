crisprTrack
===========

crisprTrack identifies putative 20-mer CRISPR/Cas9 targets in a given genome,
and outputs a BED file that can be used for visualization. It is based on
user-defined protospacer-adjacent motif (PAM) sites, and can be instructed to
avoid defined sub-optimal PAMs. The BED output is intended to be viewed on the
UCSC Genome Browser (http://genome.ucsc.edu/), as it uses the 'useScore' track
attribute to provide darker shading to targets with fewer predicted off-target
sites.


Requirements
------------

Earlier versions of the following programs may work; the versions here are
those used in the initial design of crisprTrack, and therefore will work.

* bedtools v2.17.0
* bowtie v1.1.1 
* bowtie-build v1.1.1 (earlier versions may work, but if you're using a genome larger than about 1.5 Gigabases, make sure you're using a version that can use 64-bit indexes. The index of all relevant 20-mers can become much larger than the index of the genome itself.)
* perl v5.8.8
* qsub (GE 6.2u5)


This program is designed to be run using the qsub system in an SGE environment,
and is arranged such that certain operations are run in parallel. 

Memory: The memory requirements tend to be defined largely by the indexing and
alignment steps for the 20mers. In order to be conservative, memory
requirements sufficient for detecting NGG CRISPR targets in a reasonably large
genome (the mm10 mouse genome) have been hard-coded into the driver and wrapper
scripts. If your system is unable to handle request for at least 109 GB of RAM,
and if you're using a genome smaller than that of the mouse, then you may want
to modify the `-l mem_free` requests of the relevant `qsub` statments. Note
that it is important that you do have sufficient RAM for your genome of
interest, however - running out of memory during the 20mer alignment step is
not guaranteed to generate an error message, so you may not notice that the
final output is incomplete.


Steps taken by the program
--------------------------

The general philosophy behind this analysis is twofold. First, it assumes that
20mer targets adjacent to PAM sites listed in the FASTA file defined by the
`-p` option are likely to cut & therefore desirable. Second, it assumes that
the PAM sites listed in the FASTA defined by the `-o` option are less likely to
cut, and therefore not ideal targets. However, because the `-o` PAMs still
MIGHT result in cutting, they must be taken into account when investigating
possible off-target sites. Within the variables and temporary files used by the
program, the `-p` files usually have "pam" in the name, while `-o` files have
"nag" in the name (crisprTrack was originally designed to work only for NGG
on-targets and NAG off-targets). The specific lengths and number of mismatches
allowed are derived from Hsu et al., 2013 (http://dx.doi.org/10.1038/nbt.2647).

crisprTrack begins by creating a working directory within the crisprTrack
directory; to insure nothing is overwritten, the `$JOB_ID` assigned by the
queueing system is incorporated into the name of the working directory. It then
begins identifying all `-p` and `-o` sites in the user-submitted genome. It
next creates an index of all 12mers adjacent to `-p` or `-o` sites, and a FASTA
file only containing the 12mers adjacent to the `-p` sites. This query FASTA is
used in an alignment against the 12mer index allowing for one (or fewer)
mismatch. The number of hits (minus one, for the self-alignment) indicates the
number of potential off-targets based solely on the 12mer "seed" region. Note
that this is merely an approximation of off-target activity, but in general,
lower numbers suggest a lower potential to cut off-target. 

The full 20mer sequence of all potential targets is analyzed in parallel to the
above steps. As before, both `-p` and `-o`-adjacent 20mers are used to build an
index, and only the `-p`-adjacent 20mers are used as the alignment query. With
the exception of the 0-mismatch self-hit, any hits with fewer than 3 mismatches
along the entire length of the target cause that target to be discarded.

The two datasets are combined such that the output BED contains only 20mer
targets with no offtargets with fewer than 3 mismatches. The number of seed
alignments with fewer than 2 mismatches is indicated by an integer in the name
field.

Note that the `-o` option is not required. If a file is not defined for `-o`,
the off-target steps are skipped.


Running the script
------------------

	qsub crisprTrack.sh [options] -p <pamlist.fa> -s <PAM length> input.fa

The `input.fa` file is a single FASTA file representing the sequence of all the
chromosomes of interest. crisprTrack was written with the assumption that
chromosome entries begin with "chr", such that the output BED is ready to use
on the UCSC browser.

Options:

`-h`:  Print a help message with this list of options and exit

`-i`:  The path to the genome index basename, if available. For example, if
your index were named `danio_rerio.Zv9.70.1.ebwt`, `danio_rerio.Zv9.70.2.ebwt`,
etc., you would enter `danio_rerio.Zv9.70`. If the index files were in another
directory, you would enter the `/path/to/directory/danio_rerio.Zv9.70`. If no
index is provided, a new index will be created from the FASTA input, and will
be kept in the `indexes/` directory within the working directory.

`-k`:  Keep the intermediate files that are deleted by default. Some files are
still deleted to save space. Intended for debugging. Default: off.

`-l`:  An even number of lines to use per file when splitting the 12mer and
20mer inputs. Lower numbers lead to more alignment jobs with fewer lines per
input file (speeding things up unless the time to load the index dominates);
higher numbers have the opposite effect. In order to avoid taking up too many
resources at once, crisprTrack is hard-coded to use no more than 8 cores at a
time for a given job, so adjustments to `-l` may not result in linear speedup.
Note that this value MUST be a positive, even integer. Default: 5000000.

`-n`:  A name (without whitespace) used in the name of the working directory and
the "description" track attribute of the BED file. Default: "crisprs".

`-o`:  The path to a FASTA file of off-target PAM sites. These are PAMs at which
CRISPR cutting MIGHT occur, but for which such cutting would be suboptimal (for
example, the NAG sites of SpCas9, as opposed to the NGG sites). Any type of
site you want removed from the result should be entered here. As with `-p`, the
search sequence must be at least 4 bp long; if the PAM itself is less than 3 bp
long, this can be accounted for with `-s`.

`-p`:  The path to a FASTA file of on-target PAM sites (required). The 20mers
returned by crisprTrack will be a subset of all 20mers adjacent to the PAM
sites in this file. As with `-o`, the search sequence must be at least 4 bp
long; if the PAM itself is less than 3 bp long, this can be accounted for with
`-s`.

`-s`:  The length of the PAM sequence substring (required). This value should
include ambiguous bases. It assumes that the search sequences defined by `-p`
(and `-o`, if used) are as short as possible - that is, PAMs of length 4 or
less all have search sequences of length 4, and PAMs of length 5 or more have a
search sequence equal in length to the PAM itself. For example, the SpCas9 PAM
is NGG, meaning that the sequences in `-p` would be 4 bp long, but since NGG
itself is only 3 bp long, you'd use `-s 3`. Conversely, the T. denticola Cas9
PAM is 6 bp long (NAAAAN), so you'd use 6 bp sequences in the `-p` file, and
use `-s 6`.

`-v`:  Print the version number and exit

Only `-p` and `-s` are required, though `-i` can speed things up if your genome
already has a bowtie index, `-l` can be used to increase or decrease the
parallelization of the alignments, and `-n` helps keep track of multiple runs.


Generating on-target/off-target input
-------------------------------------

crisprTrack requires a FASTA file of on-target PAM sites, and will optionally
accept an additional FASTA file of off-target PAM sites. Please refer to the
following information to simplify the creation of these files. 

* On- and off-target search sequences must be the same length, and must be at
least 4 bp long. The PAM itself can be shorter than 4 bp; if it is, it must
occupy the 3'-most bases of the 4-mer.
* One way to generate the necessary sequences is to generate all possible
k-mers of a given length, and then to use egrep (or some other means of using a
regular expression) to pull out only the sequences in which you are interested.
The `list_kmers.pl` script (located in the `input/` directory) has been
provided to help with this. It takes as input the sequence length (k) and
reports a list of all k-mers of that length.
* If using both on- and off-target PAMs, compare the two files to make sure the
same sequence does not show up in both. For example, the T. denticola on-target
PAM is NAAAAN, and one of the off-target PAMs is NAAANC (see
http://dx.doi.org/10.1038/nmeth.2681). Six-mers of the form NAAAAC (AAAAAC,
CAAAAC, etc.) are consistent with both, and should be removed from one of the
input lits (presumably removed from the off-target list), either manually or by
using `join -v` after sorting both lists.
* Once your list(s) contains no duplicate entries, convert it/them to FASTA
file(s) with uniquely-named entries. For example, `awk '{i++; print
">PAM"i"\n"$1}'` can be used to create a FASTA file of PAM sites.

For example, if you wanted to recreate the SpCas9 input, you would need to
create an on-target file of NGG sites (to be submitted with `-p`) and an
off-target file of NAG sites (to be submitted with `-o`). crisprTrack needs at
least 4 bp to do the alignment that identifies the sites of interest, so the
NGG sites could be made like this:

	./list_kmers.pl 4 | egrep '..GG' | awk '{i++; print ">PAM"i"\n"$1}' > pamlist.fa

and the NAG sites would be:

	./list_kmers.pl 4 | egrep '..AG' | awk '{i++; print ">NAG"i"\n"$1}' > naglist.fa


Understanding the output
------------------------

The output is a gzipped BED file named
`${BASE}_pamlist_20mer_no20offtarg_scored.bed.gz`, in which `${BASE}` is the
basename of the original FASTA input. The first few lines will look like this:

	track name=crispr517148 type=bed description="FriZfishTest" useScore=1
	chr1	2093	2113	TAACTCTTGTGGAAATAAAG_2489	43.3698	-
	chr1	2104	2124	ACTGCTTCAAATAACTCTTG_1117	209.54	-
	chr1	2156	2176	GACGAGCGTCTCATTTAGAC_674	417.238	+

The first line is the "track" line, which provides certain metadata to the
genome browser. Two fields (type=bed and useScore=1) are static. The "name"
field will be the word "crispr" followed by the `$JOB_ID` assigned by the SGE
queueing system. The "description" field will be the same as the name defined
with the `-n` option.

The remainder of the file is a standard BED file. The first column indicates
the chromosome, the second is the 0-based start of the 20mer, the third is the
1-based end of the 20mer, and the sixth is the orientation of the 20mer. The
fourth column indicates the sequence of the 20mer (5' to 3', regardless of
orientation), an underscore, and the number of "seed off-targets" - that is,
the number of potentially-cuttable 12mers that were fewer than two mismatches
different from the 12mer seed of the 20mer in question. Again, this is not a
direct measure of the number of off-targets, but lower numbers suggest the
20mer is less likely to cut off-target. The fifth column uses the number from
the fourth column to generate a score between 0 and 1000. By itself, the score
is meaningless - its only function is to alter the shading of the 20mer when
viewed in the genome browser (by means of useScore=1). Twentymers with lower
seed off-targets have higher scores, and higher scores have darker shading;
when choosing between two 20mer targets, you may wish to prefer the darker.

One other thing about the output: a single run of the program results in many
qsub jobs, and that number grows with larger genomes or increasingly ambiguous
PAM sequences. As such, if you use the qsub -M option to alert you when jobs
begin or end, be advised that crisprTrack can result in a lot of email.


Testing the program
-------------------

	qsub crispr_track_driver_more-parallel.sh -n Example -p input/pamlist.fa -o input/naglist.fa -s 3 example.fa

The output (a gzipped BED file inside a newly-created working directory
beginning with `Workdir_Example_...`) should match `expected_output.bed.gz` in
every respect except one. The "name" field on the first line of the
uncompressed BED file is "crispr000000" in the example file; in your file, the
six zeros should be replaced with the `$JOB_ID` assigned to crisprTrack upon
using qsub.

