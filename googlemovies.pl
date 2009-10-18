#!/usr/bin/perl
use warnings;
use strict;

use LWP::Simple;
use HTML::Entities;
use HTML::TreeBuilder;

# Otherwise we can get complaints when unicode is output
binmode STDOUT, ':utf8';

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


print <<HEAD;
<?xml version="1.0" encoding="utf-8"?>
<MovieTimes>
HEAD

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

print <<END;
</Movies>
</Theater>
</MovieTimes>
END


my $cinemaCount = 0;
sub parse_cinema {
    my $cinema = shift;

    # We need to end the previous cinema block if we hit a new one
    if ($cinemaCount++ > 0) {
        print "</Movies>\n</Theater>\n";
    }

    print "<Theater>\n";

    my $name = decode_entities(($cinema->look_down('_tag', 'b'))[0]->as_text);
    print "<Name>$name</Name>\n";

    my $address = decode_entities(($cinema->look_down('_tag', 'font'))[0]->as_HTML);
    $address =~ m/>(.*) - [^<]+</;
    print "<Address>$1</Address>\n";

    print "<Movies>\n";
}

sub parse_movies {
    my @movierows = @_;

    foreach my $movierow (@movierows) {
        my $movie = ($movierow->look_down('_tag', 'font'))[0]->as_HTML;

        if ($movie) {
            $movie = decode_entities($movie);
            $movie =~ s/&nbsp;/ /g;

            print "<Movie>\n";

            if ($movie =~ /<b.*?>(.*)<\/b>/i) {
                print "<Name>$1</Name>\n";
            }

            if ($movie =~ /Rated\s+(\w+)/i) {
                print "<Rating>$1</Rating>\n";
            }

            if ($movie =~ /<br(?: \/)?>[^\w\s]*([\w\s]+)[^-]*-\s*/i) {
                print "<RunningTime>$1</RunningTime>\n";
            }

            if ((my $showtimes) = ($movie =~ /^.*<br \/>(.*)<\/font>/i)) {
                $showtimes =~ s/\s+/, /g;
                print "<ShowTimes>$showtimes</ShowTimes>\n";
            }

            print "</Movie>\n";
        }
    }
}
