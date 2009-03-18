#!/usr/bin/perl -w
#
# Usage: ./checkstages.pl config/default/packages

use strict;

while (<>) {
	@_ = split /\s+/;
	my ($stages, $pkg) = ($_[1], $_[4]);

#	next if $stages =~ /^0123456789$/;
	next if $stages =~ /^.1-------.$/;
	next if $stages =~ /^..2------.$/;
	next if $stages =~ /^..-3-----.$/;
	next if $stages =~ /^..---5---.$/;
	next if $stages =~ /^..-----7-.$/;

	print "Bad stages pattern: $stages $pkg\n";
}

