#!/usr/bin/perl -w

use strict;
use Getopt::Declare;
use Cwd;
use File::Find;
use HTML::TreeBuilder;
use URI::URL qw(url);
use File::Copy;
use IO::File;

use vars qw($VERSION $BASE_URL $BACKUP $DIRECTORY @WANTED_TYPES);

$VERSION = (qw$Revision: 1.1 $)[1];

#Load the definition and grab the command-line parameters
my $opts = Getopt::Declare->new( do{ local $/; <DATA> } );

#Cycle through this directory, and all those underneath it
find(\&wanted, $DIRECTORY || getcwd);

#Parse each HTML file and make a backup
#of it using File::Copy::copy.
sub wanted {
  return unless $File::Find::name =~ /html?$/;

  #Extract Links from the file
  my $h = HTML::TreeBuilder->new;
  $h->parse_file($File::Find::name);

  my $link_elements = $h->extract_links(@WANTED_TYPES);
  return unless @$link_elements;

  #Grab each img src and re-write them so they are relative URL's
  foreach my $link_element (@$link_elements) {
    my $link    = shift @$link_element; #URL value
    my $element = shift @$link_element; #HTML::Element Object

    my $url = url($link)->canonical;
    next unless $url->can('host_port') and
      $BASE_URL->host_port eq $url->host_port;

    #Sigh.. The following is because extract_links() doesn't
    #tell you which attribute $link belongs to, except to say
    #it is the value of an attribute in $element.. somewhere.

    #Given the $link, find out which attribute it was for
    my ($attr) = grep {
      defined $element->attr($_) and $link eq $element->attr($_)
    } @{ $HTML::Tagset::linkElements{$element->tag} };

    #Re-write the attribute in the HTML::Element Tree
    #Note: $BASE_URL needs to be quoted here.
    $element->attr($attr, $url->path("$BASE_URL"));
  }

  #Make a backup of the file before over-writing it
  copy $File::Find::name => $File::Find::name.'.bak'
    if defined $BACKUP;

  #Save the updated file
  my $fh = IO::File->new($File::Find::name, O_RDWR)
    or die "Could not open $File::Find::name: $!";
  $fh->print($h->as_HTML);
}

