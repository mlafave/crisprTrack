#!/usr/bin/perl

use strict;
use warnings;


chomp (my $k = $ARGV[0]);

my @base = qw/A C G T/;

my @kmer = @base;
my @new_kmer;

for ( my $i = 0; $i < $k - 1; $i++ ){
	
	# Look through each kmer so far
	
	for my $kmer (@kmer){
		
		# Add another base
		
		for my $base (@base){
			
			push @new_kmer, ${kmer}.${base};
			
		}
		
	}
	
	@kmer = @new_kmer;
	@new_kmer = ();
	
}

for my $kmer (@kmer){
	print "$kmer\n";
}

exit;
