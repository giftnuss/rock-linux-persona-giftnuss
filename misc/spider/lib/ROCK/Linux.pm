package ROCK::Linux;
# Abstract: something that works with ROCK Linux

use strict;
use warnings;
use utf8;
use 5.010;
use Cwd;
use IO qw/Dir File Pipe/;
use File::Basename ();

use base 'Exporter';

our @EXPORT = qw/
    pkg_refresh
    pkg_change_download
    apply_copypatch
    apply_pkg_update
    apply_cksumpatch
    download
/;
our ($DIR,$SCRIPTS);

BEGIN {
   $DIR ||= $ENV{'ROCK_BASE'} || do {
     my $dn = \&File::Basename::dirname;
     my $file = __FILE__;
     $file = $dn->($file) for 1..5; $file
   };
   $SCRIPTS = "$DIR/scripts";

   IO::Dir->new($SCRIPTS) or die("Error reading scripts dir: $!");
   my $patch = `which patch`;
   chomp $patch;
   sub PATCH { "$patch -p0" }
};

sub CREATE_PKGUPDPATCH { "$SCRIPTS/Create-PkgUpdPatch" }
sub CREATE_CKSUMPATCH { "$SCRIPTS/Create-CkSumPatch" }
sub CREATE_COPYPATCH { "$SCRIPTS/Create-CopyPatch" }
sub DOWNLOAD { "$SCRIPTS/Download" }

sub pkg_refresh {
    my ($pkg,$version) = @_;
    apply_pkg_update($pkg,$version);
    apply_copypatch($pkg);
    download($pkg);
    apply_cksumpatch($pkg);
}

sub apply_pkg_update {
    my ($pkg,$version) = @_;
    my $cmd = CREATE_PKGUPDPATCH . " $pkg~$version";
    _apply_cmd($cmd);
}

sub apply_copypatch {
    my ($pkg) = @_;
    my $cmd = CREATE_COPYPATCH . " package/*/$pkg";
    _apply_cmd($cmd);
}

sub apply_cksumpatch {
    my ($pkg) = @_;
    my $cmd = CREATE_CKSUMPATCH . " $pkg";
    _apply_cmd($cmd);
}

sub _apply_cmd {
    my ($cmd) = @_;
    my ($read,$write) = map  { IO::Pipe->new } 0..1;
    $read->reader($cmd);
    $write->writer(PATCH);
    while(<$read>) {
        print $write $_;
    }
}

sub download {
    my ($pkg) = @_;
    system(DOWNLOAD . " $pkg");
}

sub desc_file {
    my ($pkg) = @_;
    my $path = `ls package/*/$pkg/$pkg.desc`;
    if($? != 0) {
        die("Package $pkg not found!");
    }
    chomp $path;
    return $path;
}

sub pkg_change_download {
    my ($pkg,$file,$path) = @_;
    my $desc = desc_file($pkg);
    my $read = IO::File->new($desc,'r') or die($!);
    my @lines = <$read>;
    $read->close;
    my $change;
    for my $i (0..$#lines) {
        my $line = $lines[$i];
        $line =~ /^(\[D\])\s+(\S+)\s+(\S+)\s(.+)$/ or next;
        my ($pre,$ck,$fn,$pn) = ($1,$2,$3,$4);
        last if $file eq $fn && $path eq $pn;
        die("multiple downloads not supported")
            if defined($change);
        $change = 0;
        my @n = ($pre);
        if($file eq $fn || !defined($file)) {
            push @n, $ck, $fn;
        }
        else {
            push @n, '0', $file;
            $change++;
        }
        if($path eq $pn || !defined($path)) {
            push @n, $pn, "\n";
        }
        else {
            push @n, $path, "\n";
            $change++;
        }
        return unless $change;
        $lines[$i] = join " ", @n;
    }
    my $write = IO::File->new($desc,"w") or die($!);
    $write->print($_) for @lines;
}

1;

__END__

