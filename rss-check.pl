#!/usr/bin/perl

use strict;
use warnings;
use utf8;

use File::HomeDir;
use Getopt::Long;
use List::Util qw/ any /;
use Mojo::JSON qw/ decode_json encode_json /;
use RSS::Check;

our $VERSION = '0.01';

my $enc = 'iso-8859-1';
if (defined $ENV{LANG} and $ENV{LANG} =~ /\.utf-?8$/i) { $enc = 'UTF-8'; }
binmode STDOUT, ":encoding($enc)";

GetOptions(
    'help|h'       => \my $help,
    'version|v'    => \my $version,
    'data-dir|d=s' => \my $data_dir,
    'add|a=s'      => \my $add,
);

sub show_copy {
    print <<"COPY";
Copyright © 2017. Andreas Guldstrand.
COPY
}

sub show_ver {
    print <<"VERSION";
$0 $VERSION

VERSION
}

sub show_usage {
    show_ver();

    print <<"USAGE";
$0 [options]

  --help|-h              Show usage.
  --version|-v           Show version.
  --data-dir|-d <dir>    Use <dir> to store data. Defaults to "~/.rss-check".
  --add|-a <url>         Add <url> to subscriptions.

USAGE
}

if ($version) { show_ver(); show_copy(); exit 0; }

if ($help) { show_usage(); show_copy(); exit 0; }

$data_dir //= File::HomeDir->my_home() . "/.rss-check";
my $sub_file = $data_dir . '/subscriptions';

mkdir $data_dir or die "Could not create directory $data_dir: $!\n" unless -d $data_dir;

if ($add) {
  my @subscriptions = get_subscriptions();

  if (any { $_->{url} eq $add } @subscriptions) {
    die "Already subscribed to $add.\n";
  }

  my $id = 0;
  $id = $subscriptions[-1]->{id} + 1 if @subscriptions;
  unlink "$data_dir/$id" if -e "$data_dir/$id";
  my $sub = { id => $id, url => $add };
  push @subscriptions, $sub;

  write_subscriptions(@subscriptions);

  get_updates($sub);

  exit;
}

my @subscriptions = get_subscriptions();

for my $sub (@subscriptions) { get_updates($sub); }
exit;

sub fopen {
  my ($fn, $mode) = @_;
  $mode //= 'r';
  open my $fh, ($mode eq 'w' ? '>' : '<'), $fn or die "Could not open $fn: $!\n";
  return $fh;
}

sub slurp {
  my $fn = shift;
  my $fh = fopen $fn;
  local $/;
  return readline $fh;
}

sub get_subscriptions {
  return if not -e $sub_file;
  return if not -s $sub_file;

  return @{ decode_json slurp $sub_file };
}

sub write_subscriptions {
  my $fh = fopen($sub_file, 'w');
  print {$fh} encode_json [ @_ ];
}

sub get_updates {
  my $sub = shift;
  my $feed_file = "$data_dir/$sub->{id}";

  my $last_id;
  if (-e $feed_file) {
    $last_id = slurp($feed_file);
  }

  my $rss = RSS::Check->read($sub->{url});

  my @articles = $rss->until($last_id);

  printf "%s: %s\n", $rss->{title}, $_->{title} for @articles;

  my $fh = fopen($feed_file, 'w');
  print {$fh} $rss->last_id;
}
