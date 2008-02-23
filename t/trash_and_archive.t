use Krang::ClassFactory qw(pkg);

use Test::More qw(no_plan);

use strict;
use warnings;

use Krang::ClassLoader 'Script';
use Krang::ClassLoader Session => qw(%session);
use File::Spec::Functions;
use Krang::ClassLoader Conf => qw(KrangRoot instance InstanceElementSet);
use Time::Piece;

use Krang::ClassLoader 'Test::Content';

BEGIN { use_ok(pkg('Story')) }

# use the TestSet1 instance, if there is one
foreach my $instance (pkg('Conf')->instances) {
    pkg('Conf')->instance($instance);
    if (InstanceElementSet eq 'TestSet1') {
        last;
    }
}


# use Krang::Test::Content to create sites.
my $creator = pkg('Test::Content')->new;

END {
    $creator->cleanup();
}

my $site = $creator->create_site(
                                 preview_url  => 'storytest.preview.com',
                                 publish_url  => 'storytest.com',
                                 preview_path => '/tmp/storytest_preview',
                                 publish_path => '/tmp/storytest_publish'
                                );

isa_ok($site, 'Krang::Site');

# create categories.
my $category = $creator->create_category();
isa_ok($category, 'Krang::Category');

# create some stories
my $s0 = $creator->create_story();
my $s1 = $creator->create_story();
my $s2 = $creator->create_story();
my $s3 = $creator->create_story();
my $s4 = $creator->create_story();

my @stories = ($s0, $s1, $s2, $s3, $s4);
my ($sid0,  $sid1,  $sid2,  $sid3,  $sid4)  = map { $_->story_id } @stories;
my ($slug0, $slug1, $slug2, $slug3, $slug4) = map { $_->slug     } @stories;

# initially neither archived nor trashed
is($_->archived, 0, "Story is not archived") for @stories;
is($_->trashed,  0, "Story is not trashed")  for @stories;

my @live = pkg('Story')->find();
is(scalar(@live), 5, "Five stories alive");

# test archiving
$s0->archive();
is($s0->archived, 1, "Story 1 is archived");
is($s0->trashed,  0, "Story 1 is not trashed");

@live = pkg('Story')->find();
is(scalar(@live), 4, "Four stories alive");

my @archived = pkg('Story')->find(include_live => 0, include_archived => 1);
is(scalar(@archived), 1, "One story archived");
is($archived[0]->story_id, $sid0, "Found correct archived story");

my @trashed = pkg('Story')->find(include_live => 0, include_trashed => 1);
is(scalar(@trashed), 0, "No stories trashed");

# find archived story by ID does not need the include_archived search option
my @found_by_id = pkg('Story')->find(story_id => $sid0);
is(scalar(@found_by_id), 1, "Archived Story found by ID without include_archived search option");

$s0->unarchive();
is($s0->archived, 0, "Story 1 is not archived");
is($s0->trashed,  0, "Story 1 is not trashed");

@live = pkg('Story')->find();
is(scalar(@live), 5, "Five stories alive");

my $count = pkg('Story')->find(count => 1);
is($count, 5, "Five stories alive (with count option)");

@archived = pkg('Story')->find(include_live => 0, include_archived => 1);
is(scalar(@archived), 0, "No stories archived");

$count = pkg('Story')->find(include_live => 0, include_archived => 1, count => 1);
is($count, 0, "No stories archived (with count option)");

@trashed = pkg('Story')->find(include_live => 0, include_trashed => 1);
is(scalar(@trashed), 0, "No stories trashed");

$count = pkg('Story')->find(include_live => 0, include_trashed => 1, count => 1);
is($count, 0, "No stories trashed (with count option)");

# test trashing
$s0->trash();
is($s0->trashed,  1, "Story 1 is trashed");
is($s0->archived, 0, "Story 1 is not archived");

@live = pkg('Story')->find();
is(scalar(@live), 4, "Four stories alive");

@trashed = pkg('Story')->find(include_live => 0, include_trashed => 1);
is(scalar(@trashed), 1, "One story trashed");
is($trashed[0]->story_id, $sid0, "Found correct trashed story");

$count = pkg('Story')->find(include_live => 0, include_trashed => 1, count => 1);
is($count, 1, "One story trashed (found with count option)");

@archived = pkg('Story')->find(include_live => 0, include_archived => 1);
is(scalar(@archived), 0, "No stories archived");

$count = pkg('Story')->find(include_live => 0, include_archived => 1, count => 1);
is($count, 0, "No stories archived (with count option)");

# find trashed story by ID does not need the include_trashed search option
@found_by_id = pkg('Story')->find(story_id => $sid0);
is(scalar(@found_by_id), 1, "Trashed Story found by ID without include_trashed search option");

$s0->untrash();
is($s0->archived, 0, "Story 1 is not archived");
is($s0->trashed,  0, "Story 1 is not trashed");

@live = pkg('Story')->find();
is(scalar(@live), 5, "Five stories alive");

@trashed = pkg('Story')->find(include_live => 0, include_trashed => 1);
is(scalar(@trashed), 0, "No stories trashed");

@archived = pkg('Story')->find(include_live => 0, include_archived => 1);
is(scalar(@archived), 0, "No stories archived");

@trashed = pkg('Story')->find(include_live => 0, include_trashed => 1, ids_only => 1);
is(scalar(@trashed), 0, "No stories trashed (with ids_only option)");

@archived = pkg('Story')->find(include_live => 0, include_archived => 1, ids_only => 1);
is(scalar(@archived), 0, "No stories archived (with ids_only option)");

# test trashing of previously archived story
$s0->archive();
$s1->archive();
$s2->trash();

is($s0->archived, 1, "Story 1 is archived");
is($s1->archived, 1, "Story 2 is archived");

@live = pkg('Story')->find();
is(scalar(@live), 2, "Two stories alive");

@archived = pkg('Story')->find(include_live => 0, include_archived => 1);
is(scalar(@archived), 2, "Two stories archived");

@trashed = pkg('Story')->find(include_live => 0, include_trashed => 1);
is(scalar(@trashed), 1, "One story trashed");
is($trashed[0]->story_id, $sid2, "Found correct trashed story");

$s1->trash();

is($s1->trashed,  1, "Story 2 is trashed");
is($s1->archived, 1, "Story 2 still has archived flag (to restore it later to archive)");

@live = pkg('Story')->find();
is(scalar(@live), 2, "Two stories alive");

@archived = pkg('Story')->find(include_live => 0, include_archived => 1);
is(scalar(@archived), 1, "One story archived");
is($archived[0]->story_id, $sid0, "Found correct archived story");

@trashed = pkg('Story')->find(include_live => 0, include_trashed => 1);
is(scalar(@trashed), 2, "Two stories trashed");

$s1->untrash();

is($s1->trashed,  0, "Story 2 no longer trashed");
is($s1->archived, 1, "Story 2 again archived");

@live = pkg('Story')->find();
is(scalar(@live), 2, "Two stories alive");

@archived = pkg('Story')->find(include_live => 0, include_archived => 1);
is(scalar(@archived), 2, "Two stories archived");

@trashed = pkg('Story')->find(include_live => 0, include_trashed => 1);
is(scalar(@trashed), 1, "One story trashed");
is($trashed[0]->story_id, $sid2, "Found correct trashed story");

$s1->unarchive();

is($s1->trashed,  0, "Story 2 not trashed");
is($s1->archived, 0, "Story 2 not archived");

@live = pkg('Story')->find();
is(scalar(@live), 3, "Three stories alive");

@archived = pkg('Story')->find(include_live => 0, include_archived => 1);
is(scalar(@archived), 1, "One story archived");
is($archived[0]->story_id, $sid0, "Found correct archived story");

@trashed = pkg('Story')->find(include_live => 0, include_trashed => 1);
is(scalar(@trashed), 1, "One story trashed");

# test creation of story with same URL as archived story
$s0->archive();
is($s0->archived, 1, "Story 1 is archived");

my $dup00 = '';
eval { $dup00 = $creator->create_story(slug => $slug0) };
ok(not($@), "Dup 1 of Story 1 created");

# archive dup00 and try to create dup01
$dup00->archive();
is($dup00->archived, 1, "Dup 1 of Story 1 archived");

my $dup01 = '';
eval { $dup01 = $creator->create_story(slug => $slug0) };
ok(not($@), "Dup 2 of Story 1 created");

eval { $s0->unarchive() };
isa_ok($@, 'Krang::Story::DuplicateURL');

eval { $dup00->unarchive() };
isa_ok($@, 'Krang::Story::DuplicateURL');

