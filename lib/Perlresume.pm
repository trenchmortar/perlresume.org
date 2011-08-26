package Perlresume;
use Dancer ':syntax';
use Dancer::Plugin::Database;
use Perlresume::MetaCPAN;

our $VERSION = '0.1';

my $mcpan = Perlresume::MetaCPAN->new;

get '/' => sub {
    if (my $author = params->{author}) {
        return redirect '/' . $author;
    }

    my $authors = load_last_searches();

    template 'index' => {authors => $authors};
};

get '/:author' => sub {
    my $id = uc params->{author};

    my $cpan_profile = $mcpan->fetch_author($id);

    if (!$cpan_profile) {
        status 'not_found';
        return template 'not_found';
    }

    my $author = find_or_create($cpan_profile);
    $author->{updated} = time;
    $author->{views}++;
    my $views = $author->{views};
    update_author($author);

    template 'resume' => {
        title => $cpan_profile->{asciiname}
        ? $cpan_profile->{asciiname}
        : $cpan_profile->{name},
        %$cpan_profile,
        %$author
    };
};

true;

sub find_or_create {
    my ($author) = @_;

    if (my $author =
        database->quick_select('resume', {pauseid => $author->{pauseid}}))
    {
        return $author;
    }

    my $name = $author->{asciiname} ? $author->{asciiname} : $author->{name};

    database->quick_insert('resume',
        {pauseid => $author->{pauseid}, name => $name, updated => time});

    return {pauseid => $author->{pauseid}, views => 0};
}

sub update_author {
    my ($author) = @_;

    database->quick_update('resume', {pauseid => $author->{pauseid}},
        $author);
}

sub load_last_searches {
    my $sth = database->prepare(
        'SELECT pauseid, name FROM resume ORDER BY updated DESC LIMIT 10',
    );
    $sth->execute;

    my $authors =
      [map { {pauseid => $_->[0], name => $_->[1]} }
          @{$sth->fetchall_arrayref}];

    return $authors;
}
