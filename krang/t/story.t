use Test::More qw(no_plan);
use strict;
use warnings;
use Krang;
use Krang::Category;
use Krang::Site;
use Krang::Contrib;
use Krang::Session qw(%session);

BEGIN { use_ok('Krang::Story') }

# creation should fail without required fields
my $story;
eval { $story = Krang::Story->new() };
ok($@);

# create a site and some categories to put stories in
my $site = Krang::Site->new(preview_url  => 'storytest.preview.com',
                            url          => 'storytest.com',
                            publish_path => '/tmp/storytest_publish',
                            preview_path => '/tmp/storytest_preview');
isa_ok($site, 'Krang::Site');
$site->save();
my ($root_cat) = Krang::Category->find(site_id => $site->site_id, dir => "/");
isa_ok($root_cat, 'Krang::Category');
$root_cat->save();

my @cat;
for (0 .. 10) {
    push @cat, Krang::Category->new(site_id   => $site->site_id,
                                    parent_id => $root_cat->category_id,
                                    dir       => 'test_' . $_);
    isa_ok($root_cat, 'Krang::Category');
    $cat[-1]->save();
}

# cleanup the mess
END {
    $_->delete for @cat;
    $site->delete;
}

# create new contributor object to test associating with stories
my $contrib = Krang::Contrib->new(prefix => 'Mr', first => 'Matthew', middle => 'Charles', last => 'Vella', email => 'mvella@thepirtgroup.com');
isa_ok($contrib, 'Krang::Contrib');
$contrib->contrib_type_ids(1,3);
$contrib->save();
END { $contrib->delete(); }

# create a new story
$story = Krang::Story->new(categories => [$cat[0], $cat[1]],
                           title      => "Test",
                           slug       => "test",
                           class      => "article");
is($story->title, "Test");
is($story->slug, "test");
is($story->class, "article");
is($story->element->name, "article");
my @story_cat = $story->categories();
is(@story_cat, 2);
is($story_cat[0], $cat[0]);
is($story_cat[1], $cat[1]);

# test contribs
eval { $story->contribs($contrib); };
like($@, qr/invalid/);
$contrib->selected_contrib_type(1);
$story->contribs($contrib);
is($story->contribs, 1);
is(($story->contribs)[0]->contrib_id, $contrib->contrib_id);

# test url production
ok($story->url);
is($story->urls, 2);
my $site_url = $cat[0]->site->url;
my $cat_url = $cat[0]->url;
like($story->url, qr/^$cat_url/);
like($story->url, qr/^$site_url/);
like($story->url, qr/^$cat_url\/test$/);

# set categories by id
$story->categories($cat[2]->category_id, 
                   $cat[3]->category_id, 
                   $cat[4]->category_id);
@story_cat = $story->categories();
is(@story_cat, 3);
is($story_cat[0]->category_id, $cat[2]->category_id);
is($story_cat[1]->category_id, $cat[3]->category_id);
is($story_cat[2]->category_id, $cat[4]->category_id);

# test category shortcut
is($story->category, $story_cat[0]);
my @urls = $story->urls;
is(@urls, 3);
$cat_url = $cat[2]->url;
like($urls[0], qr/^$cat_url/);
$cat_url = $cat[3]->url;
like($urls[1], qr/^$cat_url/);
$cat_url = $cat[4]->url;
like($urls[2], qr/^$cat_url/);

# url should change when slug is changed
my $old = $story->url;
$story->slug("foobar");
ok($old ne $story->url);
like($story->url, qr/foobar$/);

# test save
$story->save();
ok($story->story_id);

# cleanup later
END { $story->delete() }

# try loading
my $story2 = Krang::Story->load($story->{story_id});
isa_ok($story2, 'Krang::Story');

# basic fields survived?
for (qw( story_id
         version
         published_version
         class
         checked_out
         checked_out_by
         title
         slug
         notes
         cover_date
         publish_date
         priority )) {
    is($story->$_, $story2->$_, "$_ save/load");
}

# contribs made it?
is($story2->contribs, 1);
is(($story2->contribs)[0]->contrib_id, $contrib->contrib_id);

# categories and urls made it
is_deeply([ map { $_->category_id } $story->categories ],
          [ map { $_->category_id } $story2->categories ],
          "category save/load");

is_deeply([$story->urls], [$story2->urls], 'url save/load');

# element load
is($story->element->element_id, $story2->element->element_id);

# checkin/checkout
$story->checkin();
is($story->checked_out, 0);
is($story->checked_out_by, 0);

eval { $story->checkin() };
ok($@, 'double checkin fails');
is($story->checked_out, 0);
is($story->checked_out_by, 0);

eval { $story->save() };
like($@, qr/not checked out/);

$story->checkout();
is($story->checked_out, 1);
is($story->checked_out_by, $session{user_id});

# become someone else and try to checkout the story
{
    local $session{user_id} = $session{user_id} + 1;
    eval { $story->checkout };
    like($@, qr/already checked out/);
    eval { $story->checkin };
    ok($@);
    eval { $story->save() };
    like($@, qr/checked out/);
}
is($story->checked_out, 1);
is($story->checked_out_by, $session{user_id});

