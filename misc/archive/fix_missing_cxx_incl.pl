#!/usr/bin/perl -w
#
# Newer gcc versions come with c++ headers that do not include that many
# standard c headers. So many packages need a lot of additional #include
# statements to compile. This script helps automating the effort of fixing
# such packages by detecting the most common cases and adding the missing
# #include statements.
#
# Usage example:
# find -name '*.cpp' -o -name '*.cc' | xargs perl fix_missing_cxx_incl.pl

use strict;
use English;

foreach my $file (@ARGV)
{
	my @lines = ( );
	my %inc_found = ( );
	my %inc_needs = ( );

	open(F, "<$file") || die $!;
	while (<F>) {
		push @lines, $_;
		$inc_found{$1} = 1 if /^ *#\s*include\s*<(.*?)>/;
		$inc_needs{"string.h"} = 1 if /str(len|n?cpy|n?(case)?cmp|sep|r?chr)/;
		$inc_needs{"string.h"} = 1 if /mem(set|cpy|r?chr)/;
		$inc_needs{"stdlib.h"} = 1 if /atoi/;
	}
	close(F);

	my $found_missing_inc = 0;
	foreach my $i (keys %inc_needs) {
		next if exists $inc_found{$i};
		$found_missing_inc = 1;
	}

	next unless $found_missing_inc;

	if (! -f "$file.orig") {
		open(F, ">$file.orig") || die $!;
		foreach (@lines) {
			print F $_;
		}
		close(F);
	}

	open(F, ">$file") || die $!;
	my $did_inc_dump = 0;
	my $in_comment = 0;
	foreach (@lines) {
		$in_comment = 1 if /^\s*\/\*/;
		if (!$did_inc_dump && !$in_comment && /^\s*([^#\s]|#\s*if)/ && !/^\s*\/\//) {
			foreach my $i (keys %inc_needs) {
				next if exists $inc_found{$i};
				print F "#include <$i>\n";
			}
			$did_inc_dump = 1;
		}
		$in_comment = 0 if /\*\//;
		print F $_;
	}
	close(F);
}

