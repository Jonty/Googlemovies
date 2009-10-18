#!/usr/bin/perl
use warnings;
use strict;

use LWP::Simple;
use HTML::Entities;
use HTML::TreeBuilder;
use XML::Writer;

# Otherwise we can get complaints when unicode is output
binmode STDOUT, ':utf8';

# Fetch the postcode to use from the args
my $postcode = join '', @ARGV;
$postcode =~ s/\s+//;

if (!$postcode) {
    print "No postcode passed in arguments!\n";
    exit;
}

my $googleurl = "http://www.google.com/movies?near=";
my $url = $googleurl.$postcode;
my $response = get($googleurl.$postcode);

if (!defined $response) {
    print "Failed to fetch movie times, did you pass a valid postcode?\n";
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

        # If we're in a movies block and we find a new theatre, close
        $xml->endTag() if $xml->in_element('Movies');

        # If we're starting a new Theater block, we need to end the old one
        $xml->endTag() if $xml->in_element('Theater');

        $xml->startTag('Theater');
        $xml = parse_cinema($xml, $cinema);

    } elsif (my @movierows = $row->look_down('_tag', 'td', valign => 'top')) {

        # If we're not in a movies block, we need to start one
        $xml->startTag('Movies') unless $xml->in_element('Movies');

        $xml = parse_movies($xml, @movierows);
    }
}

$xml->endTag() if $xml->in_element('Movies');   # Movies
$xml->endTag() if $xml->in_element('Theater');  # Theater

$xml->endTag(); # MovieTimes
$xml->end();

# Tada!
print $out;


sub parse_cinema {
    my ($xml, $cinema) = @_;

    my $name = ($cinema->look_down('_tag', 'b'))[0]->as_text;
    $name =~ s/&nbsp;/ /g; # Because Myth can't handle the UTF8 representation of &nbsp
    $name = decode_entities($name);
    $xml->dataElement('Name', $name);

    my $address = ($cinema->look_down('_tag', 'font'))[0]->as_HTML;
    $address =~ s/&nbsp;/ /g;
    $address = decode_entities($address);
    $address =~ m/>(.*) - [^<]+</;
    $xml->dataElement('Address', $1);

    return $xml;
}

sub parse_movies {
    my $xml = shift;
    my @movierows = @_;

    foreach my $movierow (@movierows) {
        my $movie = ($movierow->look_down('_tag', 'font'))[0]->as_HTML;

        if ($movie) {
            $movie =~ s/&nbsp;/ /g;
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

    return $xml;
}
