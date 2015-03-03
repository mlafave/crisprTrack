#!/usr/bin/env bash

source ~/.bashrc

# Intended to create the run_find_20mer_offtargets.sh script on the fly, based
# on the number of files the NGG 20mer FASTA had been split into. The template
# should be a file in which the first three lines are the same as this script
# (so this script can be its own template, for example).
# find_20mer_offtargets.sh is intended to be run within the
# offtarget_20mer_counts directory that is itself within the working directory,
# but run_find_20mer_offtargets.sh resides in the working directory. However,
# run_find_20mer_offtargets.sh is actually RUN from the parent directory. It
# also needs to know the full path of the working directory so the script it
# writes can cd into it from the parent directory after the first driver is
# done.


TEMPLATE=$1
SPLIT_FILE_COUNT=$2
INDEX=$3
JOB_ID=$4

head -3 ${TEMPLATE} \
	| awk -v FILES="${SPLIT_FILE_COUNT}" \
	-v INDEX="${INDEX}" \
	-v PWD="${PWD}" \
	-v JOB="${JOB_ID}" \
	'{ print }END{ print "qsub -hold_jid "JOB" -cwd -V -l mem_free=4G -t 1-"FILES":1 -tc 8 sh/find_20mer_offtargets.sh "PWD" "INDEX }' \
	> run_find_20mer_offtargets.sh

chmod 755 run_find_20mer_offtargets.sh

exit 0
