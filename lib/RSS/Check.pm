package RSS::Check;

use strict;
use warnings;

use Mojo::UserAgent;

my $ua = Mojo::UserAgent->new();

sub read {
  my ($class, @subs) = @_;

  my @results;

  my @batches;
  my $batch_num = 0;
  my $count = 0;
  for my $sub (@subs) {
    push @{ $batches[$batch_num] }, $sub;
    $count++;
    if ($count == 4) { $count = 0; $batch_num++; }
  }

  foreach my $batch (@batches) {
    my $num = @{ $batch };
    my $count = 0;
    foreach my $sub (@{ $batch }) {
      $ua->get($sub->{url}, sub {
        my ($ua, $tx) = @_;
        my %rss = parse($tx->res->dom);

        if (%rss) { push @results, bless({%rss, sub => $sub}, $class); }
        else { warn "Not a valid feed: $sub->{url}\n"; }

        Mojo::IOLoop->stop if ++$count == $num;
     });
    }
    Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
  }

  return @results;
}

sub parse {
  my $dom = shift;

  my $first = $dom->children->first;

  return                  if not defined $first;

  return parse_atom($dom) if $first->tag eq 'feed';
  return parse_rss($dom)  if $first->tag eq 'rss';
  return parse_rdf($dom)  if $first->tag eq 'rdf:RDF';

  return;
}

sub parse_atom {
  my $dom = shift;

  my $title = $dom->at('feed > title')->all_text;

  my @articles = @{ $dom->find('feed > entry')->map(sub {
    +{
       title => $_->at('title')->all_text,
       content => $_->at('content')->all_text,
       id => $_->at('id')->all_text,
    }}) };

  return title => $title, articles => \@articles;
}

sub parse_rss {
  my $dom = shift;

  my $title = $dom->at('rss > channel > title')->all_text;

  my @articles = @{ $dom->find('rss > channel > item')->map(sub {
    my $t = $_->at('title'); $t = $t->all_text if defined $t;
    my $c = $_->at('description'); $c = $c->all_text if defined $c;
    my $i = $_->at('guid'); $i = $i->all_text if defined $i;
    +{
       title => $t // '',
       content => $c // '',
       id => $i // $_,
    }}) };

  return title => $title, articles => \@articles;
}

sub parse_rdf {
  my $dom = shift;

  my $title = $dom->at('rdf\:RDF > channel > title')->all_text;

  my @articles = @{ $dom->find('rdf\:RDF > item')->map(sub {
    my $t = $_->at('title'); $t = $t->all_text if defined $t;
    my $c = $_->at('description'); $c = $c->all_text if defined $c;
    my $i = $_->attr('rdf:about');
    +{
       title => $t // '',
       content => $c // '',
       id => $i // $_,
    }}) };

  return title => $title, articles => \@articles;
}

sub until {
  my $rss = shift;
  my $id = shift;

  my @res;

  foreach my $article (@{ $rss->{articles} }) {
    last if length $id and $id eq $article->{id};
    push @res, $article;
  }

  return @res;
}

sub last_id {
  my $rss = shift;

  my @articles = @{ $rss->{articles} };

  return '' unless @articles;

  return $articles[0]->{id};
}

sub sub {
  my $rss = shift;

  return $rss->{sub};
}

1;
