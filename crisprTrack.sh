#!/usr/bin/env bash

source ~/.bashrc
source sh/functions

# Set up functions for file testing & error reporting.
function throw_error
{
	echo >&2 ERROR: $1
	exit 1
}


function test_file
{
	if 
		[ -f $1 ]
	then 
		echo "$1 detected."
	else  
		throw_error "$1 was not detected!"
	fi
}



function verify_index
{
 if 
   test ! -e $1
 then 
   cd ..
   rmdir $workdir
   throw_error "Bowtie index $1 doesn't exist!"
 elif 
   test ! -s $1
 then 
   cd ..
   rmdir $workdir
   throw_error "Bowtie index $1 is empty!"
 else
   echo "Index $1 verified."
 fi
}



function full_path ()
{
	DIR=`dirname $1`
	FILE=`basename $1`
	PATH="`cd \"$DIR\" 2>/dev/null && pwd -P || echo \"$DIR\"`/$FILE"
	echo $PATH
}



print_usage()
{
  cat <<EOF
Usage: ./crispr_track_driver.sh [options] -p <pamlist.fa> -s <length> input_genome.fa
	Options:
	-h	print this help message and exit
	-i	path to the index basename, if available
	-k	keep intermediate files that are deleted by default
	-l	an even number of lines to use per file when aligning 20mers
	-n	name
	-o	path to a FASTA file of off-target PAM sites
	-p	path to a FASTA file of on-target PAM sites (required)
	-s	length of the PAM substring or string (required)
	-v	print version and quit
EOF
}



print_version()
{
	cat <<EOF
1.0.0
EOF
}

# Define the path to the directory that 

PARENT=${PWD}

NAME="crisprs"
LINE_COUNT=5000000
KEEP=off

while getopts "hi:kl:n:o:p:s:v" OPTION
do
	case $OPTION in
    	h)
    		print_usage
    		exit 0
    		;;
    	i)
    		INDEX_INPUT=$OPTARG
    		;;
    	k)
    		KEEP=on
    		;;
    	l)
    		LINE_COUNT=$OPTARG
    		;;
    	n)
    		NAME=$OPTARG
    		;;
    	o)
    		OFFPAM=`full_path $OPTARG`
    		;;
    	p)
    		ONPAM=`full_path $OPTARG`
    		;;
    	s)
    		PAM_LENGTH=$OPTARG
    		;;
    	v)
    		print_version
    		exit 0
    		;;
    esac
done
shift $((OPTIND-1))



if [ $(( $LINE_COUNT % 2 )) -ne 0 ]
then 
	throw_error "-l must be an even integer"
elif [ $LINE_COUNT -le 0 ]
then
	throw_error "-l must be greater than 0"
fi 

test_file ${ONPAM}

if [ ! $PAM_LENGTH ]
then 
	throw_error "The length of the PAM must be specified by -s"
fi

GENOME_INPUT=$1


# Make sure the input file exists & contains data:

if test ! -f "$1"
then echo "$1 doesn't exist!"
  exit 1
elif test ! -s "$1"
then echo "$1 is empty!"
  exit 1
else
  echo "$1 detected."
fi



hash bedtools 2>/dev/null || throw_error "bedtools not found"
hash bowtie 2>/dev/null || throw_error "bowtie not found"
hash bowtie-build 2>/dev/null || throw_error "bowtie-build not found"
hash perl 2>/dev/null || throw_error "perl not found"
hash qsub 2>/dev/null || throw_error "qsub not found"


# convert the input file to an absolute path
GENOME=`full_path $GENOME_INPUT`

# Get the basename without the file extension
BASE=`basename $GENOME | perl -pe 's/\.[^.]+$//i'`


# If an index was provided, get the absolute path of that, too.
if [[ $INDEX_INPUT ]]
then
	FULL_INDEX=`full_path $INDEX_INPUT`
	
	verify_index ${FULL_INDEX}.1.ebwt*
	verify_index ${FULL_INDEX}.2.ebwt*
	verify_index ${FULL_INDEX}.rev.1.ebwt*
	verify_index ${FULL_INDEX}.rev.2.ebwt*
	
fi



# Verify that the name does not have blanks

echo $NAME | grep -q [[:blank:]] && throw_error "'NAME' can't have blanks"


# Make a working directory

WORKDIR=$PWD/Workdir_${NAME}_$JOB_ID

if [ -d $WORKDIR ] ; then throw_error "$WORKDIR already exists!"; fi

mkdir $WORKDIR
cd $WORKDIR

mkdir indexes


# If there's already an index provided, just use that. If there isn't, make one
# and put it in the working directory.


if [[ ! $FULL_INDEX ]]
then
	
	echo "Creating an index of the whole FASTA input..."
	cd indexes
	
	../../sh/build_index.sh $GENOME ${BASE}_genomeIndex
		
	FULL_INDEX=${PWD}/${BASE}_genomeIndex
	
	cd ..
	
	verify_index ${FULL_INDEX}.1.ebwt*
	verify_index ${FULL_INDEX}.2.ebwt*
	verify_index ${FULL_INDEX}.rev.1.ebwt*
	verify_index ${FULL_INDEX}.rev.2.ebwt*
	
fi



# Count the number of PAM entries to be checked (and, if applicable, the number
# of off-target PAM entries). This assumes that, during the first FASTA splits,
# each post-split file contains a single entry.

PAM_COUNT=`cat ${ONPAM} | wc -l | awk '{print $1/2}'`

if [ ${OFFPAM} ]
then
	NAG_COUNT=`cat ${OFFPAM} | wc -l | awk '{print $1/2}'`
fi



# Prepare to identify all NGG sites in the genome in parallel

echo ""
echo "Splitting the NGG input..."

PAMSPLIT_QSUB=`qsub \
	-cwd \
	-V \
	../sh/split_wrapper.sh \
	PAMinput \
	2 \
	${ONPAM} \
	on`

PAMSPLIT_ID=`echo $PAMSPLIT_QSUB | head -1 | cut -d' ' -f3`

echo "PAM split job ID is ${PAMSPLIT_ID}."



echo ""
echo "Identifying all NGG sites & fetching 12mer sequence..."

PAMFIND_QSUB=`qsub \
	-cwd \
	-V \
	-l mem_free=8G \
	-hold_jid ${PAMSPLIT_ID} \
	-t 1-${PAM_COUNT}:1 \
	-tc 8 \
	../sh/get_all_12mer_seq_array.sh \
	${PWD}/processed_PAMinput \
	${PWD}/split_PAMinput \
	${FULL_INDEX} \
	${GENOME} \
	${PAM_LENGTH}`

PAMFIND_ID=`echo $PAMFIND_QSUB | head -1 | cut -d' ' -f3 | cut -d. -f1`

echo "NGG alignment job ID is ${PAMFIND_ID}."



# Merge the split files back together

echo ""
echo "Merging the NGG files..."

PAMMERGE_QSUB=`qsub \
	-cwd \
	-V \
	-l mem_free=256M \
	-hold_jid ${PAMFIND_ID} \
	../sh/merge.sh \
	${PWD}/processed_PAMinput \
	${PWD}/split_PAMinput \
	${BASE}_pamlist_12mers_noneg.tabseq \
	${KEEP}`

PAMMERGE_ID=`echo $PAMMERGE_QSUB | head -1 | cut -d' ' -f3`

echo "PAM merge job ID is ${PAMMERGE_ID}."



# If a set of "offtarget PAMs" was specified, identify those, too. The idea is
# that these are sites at which cutting is possible, but sub-optimal.
# Therefore, one would want to take them into account when counting potential
# off-targets, but would not want them reported as good CRISPR candidates. For
# Cas9, the canonical PAM is NGG, and a lower degree of cutting occurs at NAG
# PAMs; as such "nag" appears in the variables and filenames referring to
# off-target PAM sites.

if [ ${OFFPAM} ]
then

	# Identify all NAG sites in the genome

	echo ""
	echo "Splitting the NAG input..."

	NAGSPLIT_QSUB=`qsub \
		-cwd \
		-V \
		../sh/split_wrapper.sh \
		NAGinput \
		2 \
		${OFFPAM} \
		on`

	NAGSPLIT_ID=`echo $NAGSPLIT_QSUB | head -1 | cut -d' ' -f3`

	echo "NAG split job ID is ${NAGSPLIT_ID}."



	echo ""
	echo "Identifying all NAG sites & fetching 12mer sequence..."

	NAGFIND_QSUB=`qsub \
		-cwd \
		-V \
		-l mem_free=8G \
		-hold_jid ${NAGSPLIT_ID} \
		-t 1-${NAG_COUNT}:1 \
		-tc 8 \
		../sh/get_all_12mer_seq_array.sh \
		${PWD}/processed_NAGinput \
		${PWD}/split_NAGinput \
		${FULL_INDEX} \
		${GENOME}\
		${PAM_LENGTH}`

	NAGFIND_ID=`echo $NAGFIND_QSUB | head -1 | cut -d' ' -f3 | cut -d. -f1`

	echo "NAG alignment job ID is ${NAGFIND_ID}."



	# Merge the split files back together

	echo ""
	echo "Merging the NAG files..."

	NAGMERGE_QSUB=`qsub \
		-cwd \
		-V \
		-l mem_free=256M \
		-hold_jid ${NAGFIND_ID} \
		../sh/merge.sh \
		${PWD}/processed_NAGinput \
		${PWD}/split_NAGinput \
		${BASE}_naglist_12mers_noneg.tabseq \
		${KEEP}`

	NAGMERGE_ID=`echo $NAGMERGE_QSUB | head -1 | cut -d' ' -f3`

	echo "NAG merge job ID is ${NAGMERGE_ID}."

else
	
	# If there are no off-target PAMs defined, create an empty "dummy file" to
	# pass to subsequent commands.
	
	touch ${BASE}_naglist_12mers_noneg.tabseq
	
	gzip ${BASE}_naglist_12mers_noneg.tabseq
	
fi

# Make an NGG FASTA file that represents each sequence only once, and that does
# not contain any sequences with ambiguous bases. This file will be used as the
# alignment query; as such, this does not need to be repeated for the NAG
# entires.

echo ""
echo "Making a FASTA file of all NGG-associated 12mers..."

PAM12FASTA_QSUB=`qsub \
	-cwd \
	-V \
	-l mem_free=1G \
	-hold_jid ${PAMMERGE_ID} \
	../sh/make_12mer_query_fasta_qsub.sh \
	${BASE}_pamlist_12mers_noneg.tabseq.gz \
	${BASE}_pamlist_12mers_noneg_1each_noN.fa`

PAM12FASTA_ID=`echo $PAM12FASTA_QSUB | head -1 | cut -d' ' -f3`

echo "PAM 12mer query FASTA job ID is ${PAM12FASTA_ID}."

# Output is ${BASE}_pamlist_12mers_noneg_1each_noN.fa.gz



# Make a FASTA of all NGG and NAG sites, indicating how often each shows up as
# a CRISPR target. This file will be used to make the bowtie index.

echo ""
echo "Making a FASTA file of all NGG- and NAG-associated 12mers..."

INDEX12FASTA_QSUB=`qsub \
	-cwd \
	-V \
	-l mem_free=1G \
	-hold_jid ${PAMMERGE_ID},${NAGMERGE_ID} \
	../sh/make_index_fasta_qsub.sh \
	${BASE}_pamlist_12mers_noneg.tabseq.gz \
	${BASE}_naglist_12mers_noneg.tabseq.gz \
	${BASE}_pam_nag_12mercounts_allsites.fa`

INDEX12FASTA_ID=`echo $INDEX12FASTA_QSUB | head -1 | cut -d' ' -f3`

echo "PAM + NAG 12mer index FASTA job ID is ${INDEX12FASTA_ID}."

# Output is ${BASE}_pam_nag_12mercounts_allsites.fa



# Build the NGG/NAG index in the indexes subdirectory.

echo ""
echo "Making the 12mer index..."

MAKE12INDEX_QSUB=`qsub \
	-cwd \
	-V \
	-l mem_free=4G \
	-hold_jid ${INDEX12FASTA_ID} \
	../sh/build_index_wrapper.sh \
	${WORKDIR}/${BASE}_pam_nag_12mercounts_allsites.fa \
	${BASE}_pam_nag_12mercounts_allsites`

MAKE12INDEX_ID=`echo $MAKE12INDEX_QSUB | head -1 | cut -d' ' -f3`

echo "PAM + NAG 12mer build-index job ID is ${MAKE12INDEX_ID}."

# Output is ${WORKDIR}/indexes/${BASE}_pam_nag_12mercounts_allsites.1.ebwt,
# etc., unless it ends in .ebwtl



# Map 12mers with bowtie, using -v 1. This detects the number of
# potentially-cutting CRISPRs for which the seed region is fewer than 2
# mismatches different.

# Set the $TYPE variable

TYPE='12mer'

# Split the query FASTA

echo ""
echo "Splitting the NGG 12mer FASTA input..."

SPLIT12MER_QSUB=`qsub \
	-cwd \
	-V \
	-l mem_free=256M \
	-hold_jid ${PAM12FASTA_ID} \
	../sh/split_wrapper.sh \
	${TYPE} \
	${LINE_COUNT} \
	${WORKDIR}/${BASE}_pamlist_12mers_noneg_1each_noN.fa.gz \
	${KEEP}`

SPLIT12MER_ID=`echo $SPLIT12MER_QSUB | head -1 | cut -d' ' -f3`

echo "12mer split job ID is ${SPLIT12MER_ID}."



# Align

echo ""
echo "Counting NGG 12mer offtargets via alignment..."

ALIGN12MER_WRAPPER_QSUB=`qsub \
	-cwd \
	-V \
	-hold_jid ${SPLIT12MER_ID},${MAKE12INDEX_ID} \
	../sh/find_offtargets_array_wrapper.sh \
	${PARENT}/sh/find_12mer_offtargets_array.sh \
	${TYPE} \
	${WORKDIR}/processed_12mer \
	${WORKDIR}/split_12mer \
	${WORKDIR}/indexes/${BASE}_pam_nag_12mercounts_allsites`

ALIGN12MER_WRAPPER_ID=`echo $ALIGN12MER_WRAPPER_QSUB | head -1 | cut -d' ' -f3`

echo "${TYPE} alignment and counting WRAPPER job ID is ${ALIGN12MER_WRAPPER_ID}."


# Output is ${OUTDIR_PATH}/split_${NUMBER}_12merofftarg.gz



# Merge


echo ""
echo "Counting NGG 12mer offtargets..."

MERGE12MER_WRAPPER_QSUB=`qsub \
	-cwd \
	-V \
	-hold_jid ${ALIGN12MER_WRAPPER_ID} \
	../sh/merge_wrapper.sh \
	${TYPE} \
	${WORKDIR}/align_${TYPE}_ID \
	${WORKDIR}/processed_12mer \
	${WORKDIR}/split_12mer \
	${BASE}_pamlist_12mers_offtargets \
	${KEEP}`

MERGE12MER_WRAPPER_ID=`echo $MERGE12MER_WRAPPER_QSUB | head -1 | cut -d' ' -f3`

echo "${TYPE} merge WRAPPER job ID is ${MERGE12MER_WRAPPER_ID}."

# Output is {BASE}_pamlist_12mers_offtargets.gz



echo ""
echo "Fetching the sequence of all NGG-associated 20mers..."

PAM20MERSEQ_QSUB=`qsub \
	-cwd \
	-V \
	-l mem_free=4G \
	-hold_jid ${PAMMERGE_ID} \
	../sh/make_20mer_seq_qsub.sh \
	${BASE}_pamlist_12mers_noneg.tabseq.gz \
	${GENOME} \
	${BASE}_pamlist_20mers_noneg.tabseq \
	${KEEP}`

PAM20MERSEQ_ID=`echo $PAM20MERSEQ_QSUB | head -1 | cut -d' ' -f3`

echo "PAM 20mer sequence fetch job ID is ${PAM20MERSEQ_ID}."


if [ "$KEEP" = "off" ]
then
	echo ""
	echo "Removing the 12mer NGG tabseq file..."

	qsub \
		-cwd \
		-V \
		-hold_jid ${PAM12FASTA_ID},${INDEX12FASTA_ID},${PAM20MERSEQ_ID} \
		../sh/rm_qsub.sh \
		${BASE}_pamlist_12mers_noneg.tabseq.gz
fi



echo ""
echo "Fetching the sequence of all NAG-associated 20mers..."

# If -o is not specified, ${NAGMERGE_ID} won't exist. Normally that's not a
# problem, because -hold_jid is usually waiting on PAM AND NAG files, but this
# one is ONLY NAG. As a result, you have to skip this submission if you don't
# have -o. The lack of ${NAG20MERSEQ_ID} won't be a problem, as it never
# appears alone.

if [ ${OFFPAM} ]
then

	NAG20MERSEQ_QSUB=`qsub \
		-cwd \
		-V \
		-l mem_free=4G \
		-hold_jid ${NAGMERGE_ID} \
		../sh/make_20mer_seq_qsub.sh \
		${BASE}_naglist_12mers_noneg.tabseq.gz \
		${GENOME} \
		${BASE}_naglist_20mers_noneg.tabseq \
		${KEEP}`

	NAG20MERSEQ_ID=`echo $NAG20MERSEQ_QSUB | head -1 | cut -d' ' -f3`

	echo "NAG 20mer sequence fetch job ID is ${NAG20MERSEQ_ID}."

fi



if [ "$KEEP" = "off" ]
then
	echo ""
	echo "Removing the 12mer NAG tabseq file..."

	qsub \
		-cwd \
		-V \
		-hold_jid ${INDEX12FASTA_ID},${NAG20MERSEQ_ID} \
		../sh/rm_qsub.sh \
		${BASE}_naglist_12mers_noneg.tabseq.gz
fi



echo ""
echo "Making a FASTA file of all NGG- and NAG-associated 20mers..."

INDEX20FASTA_QSUB=`qsub \
	-cwd \
	-V \
	-l mem_free=1G \
	-hold_jid ${PAM20MERSEQ_ID},${NAG20MERSEQ_ID} \
	../sh/make_index_fasta_qsub.sh \
	${BASE}_pamlist_20mers_noneg.tabseq.gz \
	${BASE}_naglist_20mers_noneg.tabseq.gz \
	${BASE}_pam_nag_20mercounts_allsites.fa`

INDEX20FASTA_ID=`echo $INDEX20FASTA_QSUB | head -1 | cut -d' ' -f3`

echo "PAM + NAG 20mer index FASTA job ID is ${INDEX20FASTA_ID}."

# Output is ${BASE}_pam_nag_20mercounts_allsites.fa

echo ""
echo "Removing the 20mer NAG tabseq file..."

qsub \
	-cwd \
	-V \
	-hold_jid ${INDEX20FASTA_ID} \
	../sh/rm_qsub.sh \
	${BASE}_naglist_20mers_noneg.tabseq.gz

# No job needs to wait on that, so there's no need to capture the job ID.


echo ""
echo "Making the 20mer index..."



MAKE20INDEX_QSUB=`qsub \
	-cwd \
	-V \
	-l mem_free=75G \
	-hold_jid ${INDEX20FASTA_ID} \
	../sh/build_index_wrapper.sh \
	${WORKDIR}/${BASE}_pam_nag_20mercounts_allsites.fa \
	${BASE}_pam_nag_20mercounts_allsites`

MAKE20INDEX_ID=`echo $MAKE20INDEX_QSUB | head -1 | cut -d' ' -f3`

echo "PAM + NAG 20mer build-index job ID is ${MAKE20INDEX_ID}."



echo ""
echo "Removing N-entries from the NGG 20mer tabseq & capitalizing..."

PAM20MERCAP_QSUB=`qsub \
	-cwd \
	-V \
	-l mem_free=1G \
	-hold_jid ${PAM20MERSEQ_ID} \
	../sh/capitalize_rmN_tabseq_qsub.sh \
	${BASE}_pamlist_20mers_noneg.tabseq.gz \
	${BASE}_pamlist_20mers_noneg_upper_sort.tabseq \
	${KEEP}`

PAM20MERCAP_ID=`echo $PAM20MERCAP_QSUB | head -1 | cut -d' ' -f3`

echo "PAM capitalization and rm N job ID is ${PAM20MERCAP_ID}."

# Output is ${BASE}_pamlist_20mers_noneg_upper_sort.tabseq.gz



if [ "$KEEP" = "off" ]
then
	echo ""
	echo "Removing the 20mer NGG tabseq file..."

	qsub \
		-cwd \
		-V \
		-hold_jid ${INDEX20FASTA_ID},${PAM20MERCAP_ID} \
		../sh/rm_qsub.sh \
		${BASE}_pamlist_20mers_noneg.tabseq.gz
fi



echo ""
echo "Making a FASTA file of all NGG-associated 20mers..."

PAM20FASTA_QSUB=`qsub \
	-cwd \
	-V \
	-l mem_free=1G \
	-hold_jid ${PAM20MERCAP_ID} \
	../sh/make_20mer_query_fasta_qsub.sh \
	${BASE}_pamlist_20mers_noneg_upper_sort.tabseq.gz \
	${BASE}_pamlist_20mers_noneg_1each_noN.fa`

PAM20FASTA_ID=`echo $PAM20FASTA_QSUB | head -1 | cut -d' ' -f3`

echo "PAM query FASTA job ID is ${PAM20FASTA_ID}."

# Output is ${BASE}_pamlist_20mers_noneg_1each_noN.fa



# Set type

TYPE='20mer'

# Split the query FASTA

echo ""
echo "Splitting the NGG 20mer FASTA input..."

SPLIT20MER_QSUB=`qsub \
	-cwd \
	-V \
	-l mem_free=256M \
	-hold_jid ${PAM20FASTA_ID} \
	../sh/split_wrapper.sh \
	${TYPE} \
	${LINE_COUNT} \
	${WORKDIR}/${BASE}_pamlist_20mers_noneg_1each_noN.fa \
	${KEEP}`

SPLIT20MER_ID=`echo $SPLIT20MER_QSUB | head -1 | cut -d' ' -f3`

echo "20mer split job ID is ${SPLIT20MER_ID}."



# Align

echo ""
echo "Counting NGG 12mer offtargets via alignment..."

ALIGN20MER_WRAPPER_QSUB=`qsub \
	-cwd \
	-V \
	-hold_jid ${SPLIT20MER_ID},${MAKE20INDEX_ID} \
	../sh/find_offtargets_array_wrapper.sh \
	${PARENT}/sh/find_20mer_offtargets_array.sh \
	${TYPE} \
	${WORKDIR}/processed_20mer \
	${WORKDIR}/split_20mer \
	${WORKDIR}/indexes/${BASE}_pam_nag_20mercounts_allsites`

ALIGN20MER_WRAPPER_ID=`echo $ALIGN20MER_WRAPPER_QSUB | head -1 | cut -d' ' -f3`

echo "${TYPE} alignment and counting WRAPPER job ID is ${ALIGN20MER_WRAPPER_ID}."

# Output is ${OUTDIR_PATH}/split_${NUMBER}_20merofftarg.gz



echo ""
echo "Combining 12 and 20mer offtarget info into one BED file..."

END_QSUB=`qsub \
	-cwd \
	-V \
	-hold_jid ${MERGE12MER_WRAPPER_ID},${ALIGN20MER_WRAPPER_ID} \
	../sh/crispr_track_end_driver_wrapper.sh \
	merge_12mer_ID \
	align_20mer_ID \
	${WORKDIR}/processed_20mer \
	${WORKDIR}/split_20mer \
	${BASE} \
	${NAME} \
	${JOB_ID} \
	${KEEP}`

END_ID=`echo $END_QSUB | head -1 | cut -d' ' -f3`

echo "The BED-making end WRAPPER job ID is ${END_ID}."



echo ""
echo "Main driver finished."

exit 0
