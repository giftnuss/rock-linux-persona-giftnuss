#!/usr/bin/perl -w

use English;
use strict;

if (not defined $ARGV[0] or not chdir $ARGV[0]) {
	print "\nUsage: $0 rootdir [min-pkgcount] [dir-regex]\n\n";
	print "E.g.: $0 build/ref0818-2.1.0-DEV-x86-reference-expert\n\n";
	exit 1;
}

shift @ARGV;

my $minpkgcount = 0;
my $dirregex;

if (defined $ARGV[0] and $ARGV[0] =~ /^[0-9]+$/) {
	$minpkgcount = $ARGV[0];
	shift @ARGV;
}

if (defined $ARGV[0]) {
	$dirregex = $ARGV[0];
	shift @ARGV;
}

my %baddirs;
my %badcount;
my %badpkgs;

while (<var/adm/dep-debug/*>) {
	/.*\/(\S+)/;
	my $p = $1;
	my %dirdep;
	my %filedep;

	next if $p eq "rock-debug";

	open P, $_ or die $!;
	while (<P>) {
		chomp;
		my ($d, $f) = split /: /;
		next if $d =~ /-dirtree$/;

		if ($dirregex ne "") {
			next if $f !~ /$dirregex/;
		}

		if (-d $f) {
			$dirdep{$d}{$f} = 1;
		} else {
			$filedep{$d} = 1;
		}
	}
	close P;

	foreach (keys %filedep) {
		delete $dirdep{$_};
	}

	foreach my $d (keys %dirdep) {
		foreach (keys %{$dirdep{$d}}) {
			$baddirs{$d}{$_}++;
			$badpkgs{$d}{$p}++;
		}
		$badcount{$d}++;
	}
}

foreach my $d (keys %badcount) {
	next if $badcount{$d} < $minpkgcount;
	print "\nFound pure dir dependencies to $d ($badcount{$d}):\n";
	foreach (keys %{$badpkgs{$d}}) {
		print "\tpkg\t$badpkgs{$d}{$_}\t$_\n";
	}
	foreach (keys %{$baddirs{$d}}) {
		print "\tdir\t$baddirs{$d}{$_}\t$_\n";
	}
}

print "\n";
exit 0;

