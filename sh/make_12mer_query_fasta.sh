#!/usr/bin/env bash

source ~/.bashrc

# Intended to isolate the NGG 12mers that don't have ambiguous bases, and make
# a FASTA file using one entry per different sequence. This FASTA file will be
# used as input for the alignmer to identify how often each 12mer appears in
# the genome within 0 or 1 mismatches.

TWELVEMERS=$1
OUTPUT=$2

gunzip -c ${TWELVEMERS} \
	| cut -f2 \
	| tr "[:lower:]" "[:upper:]" \
	| awk '$0 !~ /N/' \
	| sort -u \
	| awk '{s++; print ">pam"s"\n"$0}' \
	| gzip -c > ${OUTPUT}.gz


exit 0
