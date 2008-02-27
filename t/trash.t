use Krang::ClassFactory qw(pkg);
use Test::More qw(no_plan);
use strict;
use warnings;
use Krang::ClassLoader 'Script';
use Krang::ClassLoader 'Site';
use Krang::ClassLoader 'Category';
use Krang::ClassLoader Conf => qw(InstanceElementSet);
use Krang::ClassLoader DB   => qw(dbh);

# use the TestSet1 instance, if there is one
foreach my $instance (pkg('Conf')->instances) {
    pkg('Conf')->instance($instance);
    if (InstanceElementSet eq 'TestSet1') {
        last;
    }
}

# allow 12 items in trash
BEGIN {
    my $trash = qq{TrashMaxItems "12"\n};
    my $fh    = IO::Scalar->new(\$trash);
    $Krang::Conf::CONF->read($fh);
}

BEGIN { use_ok(pkg('Trash')) }

my $dbh = dbh();

# create a site and some categories to put stories in
my $site = pkg('Site')->new(
    preview_url  => 'storytest.preview.com',
    url          => 'storytest.com',
    publish_path => '/tmp/storytest_publish',
    preview_path => '/tmp/storytest_preview'
);
isa_ok($site, 'Krang::Site');
$site->save();
END { $site->delete() }
my ($root_cat) = pkg('Category')->find(site_id => $site->site_id, dir => "/");
isa_ok($root_cat, 'Krang::Category');
$root_cat->save();

my @cat;
for (0 .. 20) {
    push @cat, pkg('Category')->new(
        site_id   => $site->site_id,
        parent_id => $root_cat->category_id,
        dir       => 'test_' . $_
    );
    $cat[-1]->save();
}

# cleanup the mess
END {
    $_->delete for @cat;
}

SKIP: {
    skip('Story tests only work for TestSet1', 1)
      unless (InstanceElementSet eq 'TestSet1');

    # create 12 stories
    my @stories;
    for my $n (0 .. 11) {
        my $story = pkg('Story')->new(
            categories => [$cat[$n]],
            title      => "Test$n",
            slug       => "test$n",
            class      => "article"
        );
        $story->save();
        push(@stories, $story);
    }
    END { $_->delete for @stories }

    # move them to the trashbin (may hold TrashMaxItems, set to 12)
    $_->trash, sleep 1 for @stories;

    # test trash find with stories
    my @trash = pkg('Trash')->find();

    ok(not grep { not defined $_ } @trash);

    foreach my $story (@stories) {
        ok(grep { $story->story_id == $_->{id} } @trash);
    }

    # verify that they have entries in the trash table
    for my $story (@stories) {
        my $story_id = $story->story_id;
        my $found    = $dbh->selectall_arrayref(<<SQL);
SELECT * FROM trash
WHERE  object_type = 'story'
AND    object_id   = $story_id
SQL
        is(@$found, 1, "Found Story $story_id in trash");
    }

    # create one more store and trash it
    my $story = pkg('Story')->new(
        categories => [$cat[1]],
        title      => "TestX",
        slug       => "testX",
        class      => "article"
    );
    $story->save();
    my $story_id = $story->story_id;
    push(@stories, $story);
    $story->trash();

    # Story 1 should be gone
    my $found = $dbh->selectall_arrayref(<<SQL);
SELECT * FROM trash
WHERE  object_type = 'story'
AND    object_id   = 1
SQL
    is(@$found, 0, "Story 1 has been pruned.");

    # Story 13 should be there
    $found = $dbh->selectall_arrayref(<<SQL);
SELECT * FROM trash
WHERE  object_type = 'story'
AND    object_id   = 13
SQL
    is(@$found, 1, "Found Story 13 in Trash.");

##    # restore a story and make sure it's gone from the trashbin
##    $stories[0]->untrash;
##    @trash = pkg('Trash')->find();
##    ok(not grep { $_->{id} == $stories[0]->story_id } @trash);

}

END { $dbh->do("DELETE FROM trash") }
