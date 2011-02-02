#!/usr/bin/perl

use utf8;
use CGI::Carp 'fatalsToBrowser';

use lib '../../../files/lib';

use Mojolicious::Lite;
use Mojo::Client;
use Data::Dumper;
use Text::Wrap ();

my $freshmeat = {
    apitoken => 'Ox Ox Ox OxOx Ox Ox',
    requestroot => 'http://freshmeat.net/projects'
};

sub license_from_list {
    my ($list) = @_;
    my $default = 'TODO: License';
    
    my %map = (
	Apache => 'OpenSource',
	GPL => 'GPL',
	GPL2 => 'GPL',
	GPLv3 => 'GPL',
	LGPL => 'LGPL',
	FDL => 'FDL',
	MPL => 'MPL',
	MIT => 'MIT',
	BSD => 'BSD',
	'BSD Original' => 'BSD',
	DLJ => 'DLJ',
        OpenSource => 'OpenSource',
        'Free-to-use' => 'Free-to-use',
        Commercial => 'Commercial',
        'IBM-Public-License' => 'IBM-Public-License'
    );
    my $license;
    foreach my $lic (@$list) {
        $license = $map{$lic};
	last if $license;
    }
    return $license || $default;
}

sub category_from_taglist {
    my ($list) = @_;
    my $default = 'TODO: Category';

    my %map = (
	archive => 'archive',
	base => 'base',
	crypto => 'crypto',
	configuration => 'configuration',
	database => 'database',
	kde => 'desktop/kde',
	kde4 => 'desktop/kde4',
	enlightenment => 'desktop/enlightenment',
	gnome => 'desktop/gnome',
	xfce => 'desktop/xfce',
	development => 'development',
	'software development' => 'development',
	interpreters => 'interpreters',
	documentation => 'documentation',
	editor => 'editor',
	education => 'education',
	emulator => 'emulator',
	filesystem => 'filesystem',
	font => 'font',
	game => 'game',
	icon => 'icon',
	login => 'login',
        multimedia => 'multimedia',
	sound => 'multimedia',
	audio => 'multimedia',
	speech => 'multimedia',
        network => 'network',
        office => 'office',
        printing => 'printing',
        scientific => 'scientific',
        screensaver => 'screensaver',
        security => 'security',
        server => 'server',
	'http servers' => 'server',
	'proxy Servers' => 'server',
        shell => 'shell',
        text => 'text',
        theme => 'theme',
        tool => 'tool',
        toy => 'toy',
        windowmanager => 'windowmanager',
        religion => 'religion'
    );
    my $category;
    foreach my $tag 
      ( map { lc } 
	map { split /\// } @$list) {
        $category = $map{$tag};
	last if $category;
    }
    return "extra/$category" if $category;
    return $default;
}

sub homepage_from_list {
    my ($list) = @_;
    my $default = 'TODO: URL';
    
    my %map = (
        'Web Site' => 1,
	'Website' => 1,
	'Homepage' => 1
    );
    my $url;
    foreach my $link (@$list) {
	if(defined($map{$link->{'label'}})) {
	    $url = resolve_redirect(
		$link->{'redirector'});
	    $url = $link->{'host'} unless $url;
	}
	last if $url;
    }
    return $url || $default;
}

sub download_from_list {
    my ($list) = @_;
    my $default = "TODO: Download";

    my %map = (
	'Download' => 1,
        'Tar/GZ' => 1,
	'Direct Download' => 1
    );
    my $download;
    foreach my $link (@$list) {
	if(defined($map{$link->{'label'}})) {
	    $download = resolve_redirect(
		$link->{'redirector'});
	}
	last if $download;
    }
    
    if($download) {
        $download =~ /^(.*\/)(.*)$/;
	return "0 $2 $1";
    }
    return $default;
}

sub resolve_redirect {
    my ($url) = @_;
    my $client = Mojo::Client->new();
    my $rd = $client->get($url)->res;
    if($rd->is_status_class(300)) {
        return scalar $rd->headers->location;
    }
}

sub version_from_download {
    my ($download) = @_;
    my $default = 'TODO: Version';

    return $default if $download =~ /^TODO/;
    my ($num,$file,$url) = split(/ /,$download);
    $file =~ /.*-([\d.]+)\.(tar|tgz|zip).*$/i;
    return $1 || $default;
}

sub freshmeat_fetch {
    my ($self,$code) = @_;
    my $client = Mojo::Client->new();
    my $url = $freshmeat->{'requestroot'} 
            . "/$code.json";
    my $response = $client->get
      (
	  $url .
	  "?auth_code=" . $freshmeat->{'apitoken'}
      )->res;
      
    if($response->code == 200) {
	my $prj = $response->json->{'project'};
	unless($prj) {
	    die "Invalid response";
	}
	$self->stash('title',$prj->{'oneliner'});
	$self->stash('description',$prj->{'description'});
        $self->stash('url',
	    homepage_from_list(
		$prj->{'approved_urls'}));
        if(exists($prj->{'user'}) &&
	    exists($prj->{'user'}->{'display_name'})) {
	  $self->stash('author',
	      $prj->{'user'}->{'display_name'}
		. " {freshmeat release}");
	}
	else {
	    $self->stash('author', 'TODO: Author');
	}
	$self->stash('category',
	    category_from_taglist($prj->{'tag_list'}));
	$self->stash('license',
	    license_from_list($prj->{'license_list'}));
	$self->stash('download',
	    download_from_list($prj->{'approved_urls'}));
	$self->stash('version',
	    version_from_download(
		$self->stash->{'download'}));
	
	$self->stash('dump' => Dumper($prj));
    }
    else {
	# 404 - not found
	die "Response code " . $response->code;
    }
}

get #route
      '/:lang/:service/:code' => 
    # defaults
      {
        lang => 'en',
        service => 'fm',
        code => ''
      } => 
    # action  
 sub 
 {
   my $self = shift;
   my $lang = $self->param('lang');
   my $service = $self->param('service');
   my $code = $self->param('code') ||
       $self->req->param('code');

   if($code) {
      eval {
         freshmeat_fetch($self,$code);
         $self->render
	     (
	         template => 'desc',
	         format => 'txt',
		 charset => 'utf-8'
	     );
      };
      if($@) {
	  $self->res->code(404);
	  $self->res->message($@);
      }
   }
   else {
      $self->render
	 (
	     template => "page"
         )
   }
 } => 'main';

app->log->level('error');
app->types->type('txt' => 'text/plain; charset=utf-8');
app->start(cgi =>'');

__DATA__

@@ exception.html.ep
%layout "page";
Fehler:
<%= dumper $self->stash('exception'); %>

@@ page.html.ep
%layout "page";
<form method="get">
  <label for="code">Freshmeat Project:</label>
  <input type="text" name="code" size="20">
  <input type="submit">
</form>

@@ layouts/page.html.ep
<!doctype html>
<html>
<head>
  <title>ROCK Linux Package Generator</title>
</head>
<body>
  <%= content %>
</body>
</html>
 
@@ desc.txt.ep
  
[I] <%= $title %>

% local $Text::Wrap::columns = 72;
<%== Text::Wrap::fill("[T] ","[T] ",$description) %>

[U] <%= $url %>

[A] <%== $author %>
[M] TODO: Maintainer

[C] <%= $category %>
  
[L] <%= $license %>
[S] TODO: Status
[V] <%= $version %>
[P] X -----5---9 800.000
  
[D] <%= $download %>


  
