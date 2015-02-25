#!/usr/bin/env bash

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


# function test_variable
# {
# 	if
# 		[ ! $1 ]
# 	then
# 		print_usage
# 		throw_error "required file or option is missing"
# 	fi
# }


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


source ~/.bashrc


# Input:
# * FASTA of the genome (preferably UCSC, I suppose, if that's where the tracks end up)
# * Name, without spaces, of the working directory. If none given, default to "crisprTrack"


print_usage()
{
  cat <<EOF
Usage: ./crispr_track_driver.sh [options] input_genome.fa
	Options:
	-h	print this help message and exit
	-i	path to the index basename, if available
	-n	name
	-v	print version and quit
EOF
}



print_version()
{
	cat <<EOF
0.1.0
EOF
}


NAME="crisprTrack"


while getopts "hi:n:v" OPTION
do
	case $OPTION in
    	h)
    		print_usage
    		exit 0
    		;;
    	i)
    		INDEX_INPUT=$OPTARG
    		;;
    	n)
    		NAME=$OPTARG
    		;;
    	v)
    		print_version
    		exit 0
    		;;
    esac
done
shift $((OPTIND-1))



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



# Programs needed:
# * bedtools
# * bowtie

hash bedtools 2>/dev/null || throw_error "bedtools not found"
hash bowtie 2>/dev/null || throw_error "bowtie not found"
hash bowtie-build 2>/dev/null || throw_error "bowtie-build not found"
hash perl 2>/dev/null || throw_error "perl not found"

# convert the input file to an absolute path
GENOME=`full_path $GENOME_INPUT`

# Get the basename without the file extension
BASE=`basename $GENOME | perl -pe 's/\.[^.]+$//i'`


# If an index was provided, get the absolute path of that, too.
if [[ $INDEX_INPUT ]]
then
	FULL_INDEX=`full_path $INDEX_INPUT`
	
	verify_index ${FULL_INDEX}.1.ebwt
	verify_index ${FULL_INDEX}.2.ebwt
	verify_index ${FULL_INDEX}.3.ebwt
	verify_index ${FULL_INDEX}.4.ebwt
	verify_index ${FULL_INDEX}.rev.1.ebwt
	verify_index ${FULL_INDEX}.rev.2.ebwt
	
fi


### If there's a good way to make it so this doesn't need to run in this directory, do it.

# Verify that the name does not have blanks

echo $NAME | grep -q [[:blank:]] && throw_error "'NAME' can't have blanks"


# Make a working directory

WORKDIR=$PWD/Workdir_${NAME}_$JOB_ID

if [ -d $WORKDIR ] ; then throw_error "$WORKDIR already exists!"; fi

mkdir $WORKDIR
cd $WORKDIR




# If there's already an index provided, just use that. If there isn't, make one
# and put it in the working directory.


if [[ ! $FULL_INDEX ]]
then
	
	echo "Creating an index of the whole FASTA input..."
	mkdir indexes
	cd indexes
	
	../../sh/build_genome_index.sh $GENOME ${BASE}_genomeIndex
		
	FULL_INDEX=${PWD}/${BASE}_genomeIndex
	
	cd ..
	
	verify_index ${FULL_INDEX}.1.ebwt
	verify_index ${FULL_INDEX}.2.ebwt
	verify_index ${FULL_INDEX}.3.ebwt
	verify_index ${FULL_INDEX}.4.ebwt
	verify_index ${FULL_INDEX}.rev.1.ebwt
	verify_index ${FULL_INDEX}.rev.2.ebwt
	
fi

# Identify all NGG sites in the genome

echo ""
echo "Identifying all NGG sites & fetching 12mer sequence..."

../sh/get_all_12mer_seq.sh \
	${FULL_INDEX} \
	../input/pamlist.fa \
	${GENOME} \
	${BASE}_pamlist_12mers_noneg.tabseq

test_file ${BASE}_pamlist_12mers_noneg.tabseq.gz


# Identify all NAG sites in the genome

echo ""
echo "Identifying all NAG sites & fetching 12mer sequence..."

../sh/get_all_12mer_seq.sh \
	${FULL_INDEX} \
	../input/naglist.fa \
	${GENOME} \
	${BASE}_naglist_12mers_noneg.tabseq

test_file ${BASE}_naglist_12mers_noneg.tabseq.gz


# Make an NGG FASTA file that represents each sequence only once, and that does
# not contain any sequences with ambiguous bases. This file will be used as the
# alignment query; as such, this does not need to be repeated for the NAG
# entires.

../sh/make_12mer_query_fasta.sh \
	${BASE}_pamlist_12mers_noneg.tabseq.gz \
	${BASE}_pamlist_12mers_noneg_1each_noN.fa

test_file ${BASE}_pamlist_12mers_noneg_1each_noN.fa.gz





echo "Finished."

exit 0;
