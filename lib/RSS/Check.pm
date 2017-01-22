package RSS::Check;

use Mojo::UserAgent;

my $ua = Mojo::UserAgent->new();

sub read {
  my ($class, $url) = @_;

  my %rss = parse($url, $ua->get($url));

  bless \%rss, $class;
}

sub parse {
  my ($url, $tx) = @_;

  my $dom = $tx->res->dom;

  if ($dom->children->first->tag eq 'feed') { return parse_atom($dom); }

  if ($dom->children->first->tag eq 'rss') { return parse_rss($dom); }

  if ($dom->children->first->tag eq 'rdf:RDF') { return parse_rdf($dom); }

  die "Not an Atom or RSS feed in $url\n";
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



1;
