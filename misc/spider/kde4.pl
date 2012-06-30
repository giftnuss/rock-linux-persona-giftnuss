#!/usr/bin/perl

use strict;
use warnings;
use utf8;

use 5.010;

use FindBin;
use lib $FindBin::Bin . '/lib';

use ROCK::Linux;

use IO::Dir;
use IO::File;
use Mojo::Client;

my $version = $ARGV[0] || 'list';

my $hive = $ROCK::Linux::DIR . '/package/kde4';

if($version eq 'list') {
    my $d = IO::Dir->new($hive) or die($!);
    while (defined(my $p = $d->read)) {
       my $fh = IO::File->new("$hive/$p/$p.desc","r") or next;
       my ($pkgversion) = map { chomp; s/^\[V\] //; $_ } 
           grep { /\[V\]/ } <$fh>;
       say "$p $pkgversion";
    }
}

my $url = 'http://www.kde.org/info/' . $version . '.php';

my $client = Mojo::Client->new;

my $res = $client->get($url)->res;

if($res->is_status_class(200)) {
    my $dom = $res->dom;
    for my $e ($dom->find("td a")->each) {
        my $text = $e->text;
        $text =~ /^(.*)-(.*)$/ or next;
        my ($name,$version) = ($1,$2);
        my $dwnl = $e->attrs->{'href'};
        $dwnl =~ /(.*\/)(.*)$/;
        my ($path,$file) = ($1,$2);
        
        my $pkg = "${name}4";
        apply_pkg_update($pkg,$version);
        pkg_change_download($pkg,$file,$path);
    }
}
#->dom->at('title')->text;

