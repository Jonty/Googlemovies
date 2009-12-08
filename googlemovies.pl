#!/usr/bin/perl
use warnings;
use strict;

use LWP::Simple;
use HTML::Entities;
use HTML::TreeBuilder;
use XML::Writer;

# fetch url, change it if you have to, i.e. google.com to google.de
my $googleurl = "http://www.google.com/movies?near=";

# set to 1 to fetch only first page  with result
my $fetch_pages = 10;

# Otherwise we can get complaints when unicode is output
binmode STDOUT, ':utf8';

# Fetch the postcode/location to use from the args
# You can also use city name, "New York", "London"
my $location = join '+', @ARGV; # join args with '+' to be able to pass i.e. "New+York" in the url

if (!$location) {
    print "No postcode/location passed in arguments!\n";
    exit;
}

my $out = '';
my $xml = new XML::Writer(
    OUTPUT => $out, 
    DATA_MODE => 1, 
    DATA_INDENT => 2 
);

$xml->xmlDecl();
$xml->startTag('MovieTimes');

my $start = 0;
parse_html(fetch_html($googleurl.$location));

$xml->endTag(); # MovieTimes
$xml->end();

# Tada!
print $out;

sub fetch_html {
    my $response = get(shift() . '&start='.$start);

    if (!defined $response) {
        print "Failed to fetch movie times, did you pass a valid postcode?\n";
        exit;
    }

    return $response;
}

sub parse_html {
    my $tree = HTML::TreeBuilder->new();
    $tree->parse(shift);
    $tree->eof;

    my @rows = $tree->look_down('_tag', 'div', class => 'theater');
    foreach my $row (@rows) {
        $xml->startTag('Theater');
        $xml = parse_cinema($xml, $row);

        my @movierows = $row->look_down('_tag', 'div', class => 'movie');
        $xml->startTag('Movies');
        $xml = parse_movies($xml, @movierows);
        $xml->endTag(); # Movies

        $xml->endTag(); # Theater
    }

    if (--$fetch_pages > 0)  {
        my $url = parse_navbar($tree);
        if ($url) {
            parse_html(fetch_html($url)) if $url;
        }
    }
}

sub parse_navbar {
    my $tree = shift;
    my $next_start = $start+10;
    my $return_url;
    my $rooturl = $googleurl;
    $rooturl =~s/^(http:...*?)(\/.*)$/$1/i;

    # look for a link with 'start=$nextstart'
    if (my $navbar = $tree->look_down('_tag', 'div', id => 'navbar')) {
        my @links = $navbar->look_down('_tag', 'a');
        foreach my $a (@links) {
            if ($a->attr('href') =~/^\/movies\?.*start=$next_start$/) {
                if ($a->attr('href') !~/^http:/) {
                    $return_url = $rooturl.$a->attr('href');
                } else {
                    $return_url = $a->attr('href');
                }
                $start = $next_start;
                last;
            }
        }
    }
    return $return_url;
}

sub parse_cinema {
    my ($xml, $cinema) = @_;

    my $name = ($cinema->look_down('_tag', 'h2', class => 'name'))[0]->as_text;
    $name =~ s/[\xC2\xA0]+//g; # Myth can't handle UTF8 nbsp
    $xml->dataElement('Name', $name);

    my $address = ($cinema->look_down('_tag', 'div', class => 'info'))[0]->as_text;
    $address =~ s/[\xC2\xA0]+//g; # Myth can't handle UTF8 nbsp
    $xml->dataElement('Address', $address);

    return $xml;
}

sub parse_movies {
    my $xml = shift;

    foreach my $movierow (@_) {
        $xml->startTag('Movie');

        my $name = ($movierow->look_down('_tag', 'div', class => 'name'))[0]->as_text;
        $xml->dataElement('Name', $name);

        my $info = ($movierow->look_down('_tag', 'span', class => 'info'))[0]->as_text;
        if ($info) {
            if ($info =~ /Rated\s+(\w+)/i) {
                $xml->dataElement('Rating', $1);
            }

            if ($info =~ /(\d+hr\s+\d+min)/i) {
                $xml->dataElement('RunningTime', $1);
            }
        }

        my $showtimes = ($movierow->look_down('_tag', 'div', class => 'times'))[0]->as_text;
        if ($showtimes) {
            $showtimes =~ s/[\xC2\xA0]+//g; # Myth can't handle UTF8 nbsp
            $showtimes =~ s/\s+/, /g;
            $xml->dataElement('ShowTimes', $showtimes);
        }

        $xml->endTag(); #Movie
    }

    return $xml;
}
