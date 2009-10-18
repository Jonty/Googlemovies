#!/usr/bin/perl
use warnings;
use strict;

use LWP::Simple;
use HTML::Entities;
use HTML::TreeBuilder;
use XML::Writer;


# Fetch the postcode to use from the args
my $postcode = join '', @ARGV;
$postcode =~ s/\s+//;

my $googleurl = "http://www.google.com/movies?near=";
my $url = $googleurl.$postcode;
my $response = get($googleurl.$postcode);

if (!defined $response) {
    print "Failed to fetch movie times, did you pass a valid postcode?";
    exit;
}

my $tree = HTML::TreeBuilder->new();
$tree->parse($response);
$tree->eof;


my $out = '';
my $xml = new XML::Writer(
    OUTPUT => $out, 
    DATA_MODE => 1, 
    DATA_INDENT => 4
);

$xml->xmlDecl();
$xml->startTag('MovieTimes');

# The table isn't well structured, so we need to switch between
# cinemas and movies as we come across them
my @rows = $tree->look_down('_tag', 'tr', valign => 'top'); 
foreach my $row (@rows) {
    if (my $cinema = $row->look_down('_tag', 'td', colspan => '4')) {
        parse_cinema($cinema);
    } elsif (my @movierows = $row->look_down('_tag', 'td', valign => 'top')) {
        parse_movies(@movierows);
    }
}

$xml->endTag(); # Movies
$xml->endTag(); # Theater
$xml->endTag(); # MovieTimes
$xml->end();

# Otherwise we can get complaints when unicode is output
binmode STDOUT, ':utf8';

# Tada!
print $out;


my $cinemaCount = 0;
sub parse_cinema {
    my $cinema = shift;

    # We need to end the previous cinema block if we hit a new one
    if ($cinemaCount++ > 0) {
        $xml->endTag(); #Movies
        $xml->endTag(); #Theater
    }

    $xml->startTag('Theater');

    my $name = decode_entities(($cinema->look_down('_tag', 'b'))[0]->as_text);
    $xml->dataElement('Name', $name);

    my $address = decode_entities(($cinema->look_down('_tag', 'font'))[0]->as_HTML);
    $address =~ m/>(.*) - [^<]+</;
    $xml->dataElement('Address', $1);

    $xml->startTag('Movies');
}

sub parse_movies {
    my @movierows = @_;

    foreach my $movierow (@movierows) {
        my $movie = ($movierow->look_down('_tag', 'font'))[0]->as_HTML;

        if ($movie) {
            $movie = decode_entities($movie);
            $xml->startTag('Movie');

            if ($movie =~ /<b.*?>(.*)<\/b>/i) {
                $xml->dataElement('Name', $1);
            }

            if ($movie =~ /Rated\s+(\w+)/i) {
                $xml->dataElement('Rating', $1);
            }

            if ($movie =~ /<br(?: \/)?>[^\w\s]*([\w\s]+)[^-]*-/i) {
                $xml->dataElement('RunningTime', $1);
            }

            if ((my $showtimes) = ($movie =~ /^.*<br \/>(.*)<\/font>/i)) {
                $showtimes =~ s/\s+/, /g;
                $xml->dataElement('ShowTimes', $showtimes);
            }

            $xml->endTag(); #Movie
        }
    }
}
