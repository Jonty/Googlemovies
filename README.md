GoogleMovies
============

GoogleMovies.pl is a dataprovider for the MythTV MythMovies movie times listing plugin.

It uses the google.com/movies data, which is pretty much worldwide. This is useful because
the default MythMovies dataprovider only works in the US.

Google have a habit of changing the page layout about once a month, so you'll probably need
to download a new version of this script from time to time. If you feel adventurous, set up
a `git pull` on a daily cronjob for uninterrupted use.


Installation
------------

1. Drop the perl script somewhere on your MythTV machine.
2. chmod +x googlemovies.pl
3. In the MythMovies settings change the path to the script, make sure you leave the
%z after the script path. It should look something like '/usr/local/bin/googlemovies.pl %z'
when you finish.
4. Enter your postcode, or a city name in the location box.
5. Done!
