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

    # Story 0 should be gone
    my $sid0  = $stories[0]->story_id;
    my $found = $dbh->selectall_arrayref(<<SQL);
SELECT * FROM trash
WHERE  object_type = 'story'
AND    object_id   = $sid0
SQL
    is(@$found, 0, "Story $sid0 has been pruned.");

    # Story 12 should be there
    my $sid12 = $stories[12]->story_id;
    $found = $dbh->selectall_arrayref(<<SQL);
SELECT * FROM trash
WHERE  object_type = 'story'
AND    object_id   = $sid12
SQL
    is(@$found, 1, "Found Story $sid12 in Trash.");

    # restore them to live
    pkg('Trash')->restore(object => $_) for @stories;

    # stories' trashed flag should be 0
    is($_->trashed, 0, "Story's trashed flag is zero after restore") for @stories;

    ### test exceptions on restore
    #
    diag("");
    diag("1. Test restoring slug-provided story when its URL is occupied by another story");
    diag("");
    $story = $stories[0];
    my $sid = $story->story_id;
    $story->trash;

    # should be trashed
    is($story->trashed, 1, "Story $sid lives in trash");

    # create another story of type 'article' with the same URL
    my $dupe = pkg('Story')->new(
        categories => [$story->categories],
        title      => $story->title,
        slug       => $story->slug,
        class      => $story->class->name
    );
    $dupe->save;

    diag("Created another story having a slug with the same URL as Story $sid");

    # try to restore our story
    diag("Try to restore Story $sid - should throw Krang::Story::DuplicateURL exception");
    eval { pkg('Trash')->restore(object => $story) };
    isa_ok($@, 'Krang::Story::DuplicateURL');
    is(ref($@->stories), 'ARRAY', "Stories array of Krang::Story::DuplicateURL exception is set");
    is($dupe->url, ${$@->stories}[0]{url}, "Our dupe found in exception's story list");
    _verify_flag_status($story, 1);

    # delete dupe and try again
    $dupe->delete;
    eval { pkg('Trash')->restore(object => $story) };
    ok(!$@) and diag "After deleting dupe, restoring Story $sid was successful";
    _verify_flag_status($story);

    diag("");
    diag("2. Test story restoring when story's URL is occupied by a category");
    diag("");
    $story->trash;

    # should be trashed again
    is($story->trashed, 1, "Story $sid lives in trash again");

    # create category having the story's URL
    my $dupe_cat = pkg('Category')->new(
        site_id   => $site->site_id,
        parent_id => $story->category->category_id,
        dir       => $story->slug
    );
    $dupe_cat->save;
    my $cid = $dupe_cat->category_id;

    (my $cat_url = $dupe_cat->url) =~ s{/$}{};
    is($cat_url, $story->url, "Created category $cid with same URL as Story $sid");

    diag("Try to restore the story - should throw a Krang::Story::DuplicateURL exception");
    eval { pkg('Trash')->restore(object => $story) };
    isa_ok($@, 'Krang::Story::DuplicateURL');
    is(ref($@->categories), 'ARRAY',
        "Categories array of Krang::Story::DuplicateURL exception is set");
    is(
        $dupe_cat->url,
        ${$@->categories}[0]{url},
        "Our category $cid found in exception's category list"
    );
    _verify_flag_status($story, 1);

    # delete dupe and try again
    $dupe_cat->delete;
    eval { pkg('Trash')->restore(object => $story) };
    ok(!$@) and diag "After deleting dupe category $cid, restoring Story $sid was successful";
    _verify_flag_status($story);

    diag("");
    diag("3. Test restoring slugless story when its URL is occupied by another story");
    diag("");

    # create ab slugless story
    $story = pkg('Story')->new(
        categories => [$cat[1]],
        title      => 'Slugless',
        class      => 'article',
        slug       => ''
    );
    $story->save;
    unshift @stories, $story;
    $sid = $story->story_id;
    $story->trash;

    # should be trashed
    is($story->trashed, 1, "Story $sid lives in trash");

    # create another story of type 'article' with the same URL
    $dupe = pkg('Story')->new(
        categories => [$story->categories],
        title      => $story->title,
        slug       => $story->slug,
        class      => $story->class->name
    );
    $dupe->save;
    my $did = $dupe->story_id;

    diag("Created another slugless story $did with the same URL as Story $sid");

    # try to restore our story
    diag("Try to restore Story $sid - should throw Krang::Story::DuplicateURL exception");
    eval { pkg('Trash')->restore(object => $story) };
    isa_ok($@, 'Krang::Story::DuplicateURL');
    is(ref($@->stories), 'ARRAY', "Stories array of Krang::Story::DuplicateURL exception is set");
    is($dupe->url, ${$@->stories}[0]{url}, "Our dupe Story $did found in exception's story list");
    _verify_flag_status($story, 1);

    # delete dupe and try again
    $dupe->delete;
    eval { pkg('Trash')->restore(object => $story) };
    ok(!$@) and diag "After deleting dupe story $did, restoring Story $sid was successful";
    _verify_flag_status($story);

    diag("");
    diag("4. Test restoring without restore permission");
    diag("");
    $story->trash;

    # should be trashed
    is($story->trashed, 1, "Story $sid lives in trash");

    # setup group with desk permissions
    my $group = pkg('Group')->new(
        name           => 'Has no restore permissions',
        asset_story    => 'read-only',
        asset_media    => 'read-only',
        asset_template => 'read-only',
    );
    $group->save();
    END { $group->delete }

    # put a user into this group
    my $user = pkg('User')->new(
        login     => 'bob',
        password  => 'bobspass',
        group_ids => [$group->group_id],
    );
    $user->save();
    END { $user->delete }

    {
        diag("We are now a user without restore permissions");
        local $ENV{REMOTE_USER} = $user->user_id;

        diag("Trying to restore Story $sid - should throw a Krang::Story::NoRestoreAccess exception"
        );

        # fetch it again, so that may_edit flag is correctly set on $story object
        my ($story) = pkg('Story')->find(story_id => $sid);

        eval { pkg('Trash')->restore(object => $story) };

        isa_ok($@, 'Krang::Story::NoRestoreAccess');
        _verify_flag_status($story, 1);
    }

}

sub _verify_flag_status {
    my ($story, $trashed) = @_;
    my $sid = $story->story_id;
    is($story->checked_out,    0, "Story $sid flag checked_out    0");
    is($story->checked_out_by, 0, "Story $sid flag checked_out_by 0");
    is($story->trashed, ($trashed ? 1 : 0), "Story $sid flag trashed        " . ($trashed ? 1 : 0));
}

END { $dbh->do("DELETE FROM trash") }
