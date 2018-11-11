#!/usr/bin/perl
#
# nb2ikiwiki --- a conversion script from NanoBlogger to ikiwiki
#
# Released under the HOT-BEVERAGE-OF-MY-CHOICE LICENSE: Bastian Rieck wrote
# this script. As long you retain this notice, you can do whatever you want
# with it. If we meet some day, and you feel like it, you can buy me a hot
# beverage of my choice in return.

use strict;
use warnings;

use HTML::WikiConverter::Markdown;
use Date::Manip;

my $input_directory = "data";
opendir(IN, $input_directory) or die "Unable to open input directory";

my @files = readdir(IN);

# Identify database files and store tags for the filenames; the tags are forced
# to become lowercase

my %tags = ();
foreach my $file (@files)
{
	if($file =~ m/\.db$/i && !($file eq "master.db"))
	{
		open(DB, $input_directory . "/" . $file) or die "Unable to open database file";

		my $category = lc(<DB>); # Category is always the first line of the file
		chomp($category);

		foreach my $article (<DB>)
		{
			# Ignore assignments of multiple tags, i.e. foo.txt>1,3. I only require the filename.
			$article =~ m/(.*\.txt).*/;

			if(exists($tags{$1}))
			{
				$tags{$1} .= $category . " ";
			}
			else
			{
				$tags{$1} = $category . " ";
			}
		}

		close(DB);
	}
}

# Process articles

my $wc = new HTML::WikiConverter(	dialect		=> 'Markdown',
					link_style	=> 'inline',
					image_style	=> 'inline',
					header_style	=> 'atx');

foreach my $file (@files)
{
	if($file =~ m/\.txt$/i)
	{
		open(ARTICLE, $input_directory . "/" . $file) or die "Unable to open article file";

		my $title	= <ARTICLE>; # not yet parsed
		my $author	= <ARTICLE>;
		my $date	= <ARTICLE>;
		my $desc	= <ARTICLE>;
		my $format	= <ARTICLE>;

		# Parse title string
		$title =~ m/TITLE:\s+(.*)\n$/;
		$title = $1;
		$title =~ s/\s+$//; # remove trailing whitespaces

		# Parse date string and convert it to a more readable form
		$date =~ m/DATE:\s+(.*)/;
		$date = $1;
		$date = &ParseDateString($date);
		$date = &UnixDate($date, "%Y-%m-%d %T");

		# This will store the lines that belong to the actual content
		# of the article
		my $raw_article;

		foreach my $line (<ARTICLE>)
		{
			# Article delimiters are hardcoded -- works for me...
			if($line =~ m/BODY\:$/ or $line =~ m/END(-){5}$/ or $line =~ m/(-){5}$/)
			{
				next;
			}

			$raw_article .= $line;
		}

		close(ARTICLE);

		# Full article is created by prepending the title and appendig
		# the stored tags

		my $formatted_article =	"[[!meta title=\""	. $title	. "\"]]\n" .
					"[[!meta date=\""	. $date		. "\"]]\n\n" .
					$wc->html2wiki($raw_article)		. "\n\n";

		# Only add tags when available
		if(exists($tags{$file}))
		{
			$formatted_article .= "[[!tag " . $tags{$file}	. "]]\n";
		}

		# Write formatted article to file; the filename is a sanitized
		# version of the article title.
		#
		# Note that subdirectories for each year are created.

		my $year = &UnixDate($date, "%Y");
		mkdir($year);

		open(OUT, ">" . $year . "/" . sanitize($title) . ".mdwn") or die "Unable to open article output file";
		print OUT $formatted_article;
		close(OUT);
	}
}

closedir(IN);

# Sanitizes a filename, following the example of Wordpress: 
# 	* Convert to lowercase
#	* Remove non-alphanumeric characters
#	* Replace spaces and dashes with underscores
#	* Replace adjacent underscores with a single underscore
#	* Remove a trailing underscore 

sub sanitize
{
	my ($file) = @_;
	my $sanitized = lc($file);

	$sanitized =~ s/[^0-9a-z_\- \t\n\r\f]//g;
	$sanitized =~ s/[\s\-]/_/g;
	$sanitized =~ s/__+/_/g;
	$sanitized =~ s/_$//;

	return($sanitized);
}
