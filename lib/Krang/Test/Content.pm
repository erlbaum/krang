package Krang::Test::Content;

=head1 NAME

Krang::Test::Content - a package to simplify content handling in Krang tests.

=head1 SYNOPSIS

  use Krang::Test::Content;

  my $creator = Krang::Test::Content->new();

  my $site = $creator->create_site(preview_url => 'preview.fluffydogs.com',
                                   publish_url => 'www.fluffydogs.com',
                                   preview_path => '/tmp/preview_dogs',
                                   publish_path => '/tmp/publish_dogs');

  my ($root) = Krang::Category->find(site_id => $site->site_id);

  my $poodle_cat = $creator->create_category(dir    => 'poodles',
                                             parent => $root->category_id,
                                             data   => 'Fluffy Poodles of the World');

  my $french_poodle_cat = $creator->create_category(dir    => 'french',
                                                    parent => $poodle_cat,
                                                    data   => 'French Poodles Uber Alles');

  my $media = $creator->create_media(category => $poodle_cat);

  my $story1 = $creator->create_story(category => [$poodle_cat, $french_poodle_cat],
                                      media    => [$media]);

  my $story2 = $creator->create_story(category     => [$poodle_cat, $french_poodle_cat],
                                      linked_story => [$story1],
                                      linked_media => [$media]);

  my $contributor = $creator->create_contrib();

  my $word = $creator->get_word();

  $creator->delete_item(item => $story);

  $creator->cleanup();


=head1 DESCRIPTION

Krang::Test::Content exists to simplify the process of writing tests for the more advanced subsystems of Krang.  Most test suites depend on content existing in the system to test against, and have been rolling their own content-creating routines.  This module exists to centralize a lot of that code in one place.  Additionally, it provides cleanup functionality, deleting everything that has been created using it.

This module is designed to work with the Default and TestSet1 element sets - it may or may not work with other element sets.

NOTE - It should be clear that this module assumes that the following modules are all in working order: L<Krang::Category>, L<Krang::Story>, L<Krang::Media>, L<Krang::Contrib>.

=cut

use strict;
use warnings;
use Carp;

use Imager;  # creating images
use File::Spec::Functions;
use File::Path;

use Krang::Conf qw(KrangRoot InstanceElementSet instance);
use Krang::Pref;
use Krang::Site;
use Krang::Category;
use Krang::Story;
use Krang::Media;
use Krang::Contrib;

use Krang::MethodMaker (new_with_init => 'new',
                        new_hash_init => 'hash_init');

use Krang::Log qw(debug info critical);

=head1 INTERFACE

=head2 METHODS

=over

=item C<< $creator = Krang::Test::Content->new() >>

Instantias a Krang::Test::Content object.  No arguments are needed/supported at this time.

new() will croak with an error if the InstanceElementSet is not C<Default> or C<TestSet1>.  At this time, those are the only element sets supported.

=cut

sub init {

    my $self = shift;
    my %args = @_;

    $self->hash_init(%args);

    $self->_init_words();

    return;
}



=item C<< $site = $creator->create_site() >>

Creates and returns a Krang::Site object.  If unsuccessful, it will croak.

B<Arguments:>

=over

=item preview_url

The url for the preview version of the site being created.

=item publish_url

The url for the publish version of the site being created.

=item preview_path

The filesystem path that correlates with the preview_url doc root.

=item publish_path

The filesystem path that correlates with the publish_url doc root.

=back

=cut

sub create_site {

    my $self = shift;
    my %args = @_;

    foreach (qw/preview_url publish_url preview_path publish_path/) {
        croak "create_site() missing required argument '$_'\n." unless exists($args{$_});
    }

    my $site = Krang::Site->new(preview_url  => $args{preview_url},
                                url          => $args{publish_url},
                                preview_path => $args{preview_path},
                                publish_path => $args{publish_path}
                               );
    $site->save();

    push @{$self->{stack}{site}}, $site;

    return $site;
}


=item C<< $category = $creator->create_category() >>

Creates and returns a Krang::Category object for the directory specified, underneath the parent category described by parent.  It will croak if unable to create the object.

B<Arguments:>

=over

=item parent

The parent category for this category.  This must be an integer corresponding to the ID of a valid Krang::Category object, or a Krang::Category object.

=item dir

String containing the directory to be created.  Randomly generated by default.

=item data

Content to put in the root element of the category.  Randomly generated by default.

=back

=cut

sub create_category {

   my $self = shift;
   my %args = @_;

   croak "create_category() missing required argument 'parent'\n." unless exists($args{parent});

   my $parent = $args{parent};
   my $dir    = $args{dir} || $self->get_word();
   my $data   = $args{data} || $self->get_word();

   my $parent_id;

   ref($parent) ? ($parent_id = $parent->category_id()) : ($parent_id = $parent);

   my $category = Krang::Category->new(dir => $dir, parent_id => $parent_id);

   $category->element()->data($data);
   $category->save();

   push @{$self->{stack}{category}}, $category;

   return $category;

}



=item C<< $media = $creator->create_media() >>

Creates and returns a Krang::Media object underneath the category specified.  It will croak if unable to create the object.

B<Arguments:>

=over

=item category

A single Krang::Category object, to which the Media object will belong.

=item title

Title for the image.  Randomly generated by default.

=item filename

Image filename.  Randomly generated by default.

=item caption

Image caption.  Randomly generated by default.

=item x_size

An integer specifying how wide the image will be.  By default, the image will be between 50-350 pixels wide.

=item y_size

An integer specifying how tall the image will be.  By default, the image will be between 50-350 pixels tall.

=item format

Must be one of (I<jpg, png, gif>).  Determines the format of the image.  If not specified, it will randomly choose one of the three formats.


=back

=cut

sub create_media {

   my $self = shift;
   my %args = @_;

   my $category = $args{category} || croak "create_media() missing required argument 'category'\n.";

   my $x   = $args{x_size} || int(rand(300) + 50);
   my $y   = $args{y_size} || int(rand(300) + 50);
   my $fmt = $args{format} ||(qw(jpg png gif))[int(rand(3))];
   my $title = $args{title} || join(' ', map { $self->get_word() } (0 .. 5));
   my $fname = $args{filename} || $self->get_word();
   my $caption = $args{caption} || join(' ', map { $self->get_word() } (0 .. 5)); 


   my $img = Imager->new(xsize => $x,
                         ysize => $y,
                         channels => 3,
                        );

   # fill with a random color
   $img->box(color => Imager::Color->new(map { int(rand(255)) } 1 .. 3),
             filled => 1);

   # draw some boxes and circles
   for (0 .. (int(rand(8)) + 2)) {
       if ((int(rand(2))) == 1) {
           $img->box(color =>
                     Imager::Color->new(map { int(rand(255)) } 1 .. 3),
                     xmin => (int(rand($x - ($x/2))) + 1),
                     ymin => (int(rand($y - ($y/2))) + 1),
                     xmax => (int(rand($x * 2)) + 1),
                     ymax => (int(rand($y * 2)) + 1),
                     filled => 1);
       } else {
           $img->circle(color =>
                        Imager::Color->new(map { int(rand(255)) } 1 .. 3),
                        r => (int(rand(100)) + 1),
                        x => (int(rand($x)) + 1),
                        'y' => (int(rand($y)) + 1));
       }
   }


   $img->write(file => catfile(KrangRoot, "tmp", "tmp.$fmt"));
   my $fh = IO::File->new(catfile(KrangRoot, "tmp", "tmp.$fmt"))
     or die "Unable to open tmp/tmp.$fmt: $!";

   # Pick a type
   my %media_types = Krang::Pref->get('media_type');
   my @media_type_ids = keys(%media_types);
   my $media_type_id = $media_type_ids[int(rand(scalar(@media_type_ids)))];

   # create a media object
   my $media = Krang::Media->new(title      => $title,
                                 filename   => $fname . ".$fmt",
                                 caption    => $caption,
                                 filehandle => $fh,
                                 category_id => $category->category_id,
                                 media_type_id => $media_type_id,
                                );
   $media->save;

   unlink(catfile(KrangRoot, "tmp", "tmp.$fmt"));

   $media->checkin();

   push @{$self->{stack}{media}}, $media;

   return $media;
}

=item C<< $story = $creator->create_story() >>

Creates and returns a Krang::Story object, underneath the categories specified.  It will croak if unable to create the object.  The story will already be saved & checked-in.

By default, the story will be a single page, with a title, deck, header, and three paragraphs.

B<Arguments:>

=over

=item category

An array reference containing Krang::Category objects under which the story will appear.  This is the only required argument, and there must be at least one entry in the array.

=item linked_stories

An array reference containing Krang::Story objects.  Each Story object in the array will be linked to in the new story.

=item linked_media

An array reference containing Krang::Media objects.  Each Media object in the array will be linked to in the new story.

=item pages

Determines how many pages will exist in the story.  Each page will contain a header and 3 paragraphs.  By Default, one page is created.

=item C<< title => 'Confessions of a Poodle Lover' >>

The title for the story being created.  By default, a randomly-generated title will be used.

=item C<< deck => 'Why fluffy dogs make me happy' >>

The deck for the story being created.  By default, a randomly-generated deck will be used.

=item C<< header => 'In the beginning' >>

The first header in the story.  By default, a randomly-generated header will be used.

This header only applies to the first page.  If more than one page is being created in this story, subsuquent pages will have randomly-generated headers.

=item C<< paragraph => [$p1, $p2, $p3, $p4] >>

The paragraph content for the paragraphs on the first page.  One paragraph will be created for each element in the list reference passed in.  By default, three randomly-generated paragraphs will be created.

This only applies to the first page of a story - additional pages will have three randomly-generated paragraphs each.

=back

=cut

sub create_story {

    my $self = shift;
    my %args = @_;

    my $categories = $args{category} || croak "create_media() missing required argument 'category'\n.";
    croak "'category' argument must be a list of Krang::Category objects'\n" 
      unless ref($categories) eq 'ARRAY';

    my $title = $args{title} || join(' ', map { $self->get_word() } (0 .. 5));
    my $deck  = $args{deck} || join(' ', map { $self->get_word() } (0 .. 5));
    my $head  = $args{header} || join(' ', map { $self->get_word() } (0 .. 5));
    my $paras = $args{paragraph} || undef;

    my $slug_id;
    do {
        $slug_id = int(rand(16777216));
    } until (!exists($self->{slug_id_list}{$slug_id}));

    $self->{slug_id_list}{$slug_id} = 1;

    my $story = Krang::Story->new(categories => $categories,
                                  title      => $title,
                                  slug       => 'TEST-SLUG-' . $slug_id,
                                  class      => "article");


    # add some content
    $story->element->child('deck')->data($deck);

    my $page = $story->element->child('page');

    $page->child('header')->data($head);
    $page->child('wide_page')->data(1);

    if (defined($paras)) {
        foreach (@$paras) {
            $page->add_child(class => "paragraph", data => $_);
        }
    } else {
        for (1..3) {
            my $paragraph = join(' ', map { $self->get_word() } (0 .. 20));
            $page->add_child(class => "paragraph", data => $paragraph);
        }
    }

    # add storylink if it exists
    if ($args{linked_stories}) {
        foreach (@{$args{linked_stories}}) {
            $self->link_story($story, $_);
        }
    }

    # add medialink if it exists
    if ($args{linked_media}) {
        foreach (@{$args{linked_media}}) {
            $self->link_media($story, $_);
        }
    }

    $story->save();

    $story->checkin();

    push @{$self->{stack}{story}}, $story;

    return $story;

}


=item C<< $contributor = $creator->create_contrib() >>

Creates and returns a Krang::Contrib object.  All the parameters that can be used in creating a Krang::Contrib object can be passed in here, or will be randomly generated.

B<Arguments:>

=over

=item prefix

=item first

=item middle

=item last

=item suffix

=item email

=item phone

=item bio

=item url

=back

=cut

sub create_contrib {

    my $self = shift;
    my %args = @_;

    my %c_args;

    foreach (qw/first middle last/) {
        $c_args{$_} = $args{$_} || $self->get_word();
    }

    $c_args{prefix} = $args{prefix} || 'Mr.';
    $c_args{suffix} = $args{suffix} || 'Jr.';
    $c_args{email}  = $args{email}  || sprintf("%s\@%s.com", $self->get_word, $self->get_word);
    $c_args{bio}    = $args{bio}    || join(' ', map { $self->get_word() } (0 .. 20));
    $c_args{url}    = $args{url}    || sprintf("http://www.%s.com", $self->get_word());

    my %contrib_types = Krang::Pref->get('contrib_type');

    my $contrib = Krang::Contrib->new(%c_args);

    # add contrib types - let's make them all 3.
    $contrib->contrib_type_ids(keys %contrib_types);

    $contrib->save();

    push @{$self->{stack}{contrib}}, $contrib;

    return $contrib;



}


=item C<< $word = get_word() >>

This subroutine creates all the random text content for the module - each call returns a randomly-chosen word from the source - either /usr/dict/words or /usr/share/dict/words.

=cut

sub get_word {
    my $self = shift;

    return lc $self->{words}[int(rand(scalar(@{$self->{words}})))];
}

=item C<< $creator->delete_item(item => $krang_object) >>

Attempts to delete the item created.

Any errors thrown by the item itself will not be trapped - they will be passed on to the caller.

If the delete is unsuccessful, it will leave a critical message in the log file and croak.

=cut

sub delete_item {

    my $self = shift;
    my %args = @_;

    my $item = $args{item} || return;

    my @front;
    # remove item from the stack
    if ($item->isa('Krang::Site')) {
        while (my $site = shift @{$self->{stack}{site}}) {
            if ($site->site_id == $item->site_id) {
                last;
            }
            push @front, $site;
        }
        # attempt to delete
        eval { $item->delete(); };
        if (my $e = $@) {
            # put it back on the stack & throw the error.
            unshift @{$self->{stack}{site}}, @front, $item;
            croak($e);
        }
        unshift @{$self->{stack}{site}}, @front;

    } elsif ($item->isa('Krang::Category')) {
        while (my $cat = shift @{$self->{stack}{category}}) {
            if ($cat->category_id == $item->category_id) {
                last;
            }
            push @front, $cat;
        }
        # attempt to delete
        eval { $item->delete(); };
        if (my $e = $@) {
            # put it back on the stack & throw the error.
            unshift @{$self->{stack}{category}}, @front, $item;
            croak($e);
        }
        unshift @{$self->{stack}{category}}, @front;


    } elsif ($item->isa('Krang::Media')) {
        while (my $media = shift @{$self->{stack}{media}}) {
            if ($media->media_id == $item->media_id) {
                last;
            }
            push @front, $media;
        }
        # attempt to delete
        eval { $item->delete(); };
        if (my $e = $@) {
            # put it back on the stack & throw the error.
            unshift @{$self->{stack}{media}}, @front, $item;
            croak($e);
        }
        unshift @{$self->{stack}{media}}, @front;


    } elsif ($item->isa('Krang::Story')) {
        while (my $story = shift @{$self->{stack}{story}}) {
            if ($story->story_id == $item->story_id) {
                last;
            }
            push @front, $story;
        }
        # attempt to delete
        eval { $item->delete(); };
        if (my $e = $@) {
            # put it back on the stack & throw the error.
            unshift @{$self->{stack}{story}}, @front, $item;
            croak($e);
        }
        unshift @{$self->{stack}{story}}, @front;

    } elsif ($item->isa('Krang::Contrib')) {
        while (my $contrib = shift @{$self->{stack}{contrib}}) {
            if ($contrib->contrib_id == $item->contrib_id) {
                last;
            }
            push @front, $contrib;
        }
        # attempt to delete
        eval { $item->delete(); };
        if (my $e = $@) {
            # put it back on the stack & throw the error.
            unshift @{$self->{stack}{contrib}}, @front, $item;
            croak($e);
        }
        unshift @{$self->{stack}{contrib}}, @front;

    }

    return;

}


=item C<< $creator->cleanup() >>

Attempts to delete everything that has been created by the Krang::Test::Content object.  A stack of everything created by the object is maintained internally, and that stack is used to determine the order in which content is destroyed (e.g. Last Hired, First Fired).

Will log a critical error message and croak if unsuccessful.

=cut

sub cleanup {
    my $self = shift;

    foreach (qw/contrib media story category site/) {
        if (exists($self->{stack}{$_})) {
            while (my $obj = pop @{$self->{stack}{$_}}) {
                debug(__PACKAGE__ . '->cleanup() deleting object: ' . ref($obj));
                $obj->delete();
            }
        }
    }

}


=back

=head1 TODO

Write it.

=head1 SEE ALSO

L<Krang::Category>, L<Krang::Story>, L<Krang::Media>, L<Krang::Contrib>

=cut


sub _init_words {

    my $self = shift;

    open(WORDS, "/usr/dict/words")
      or open(WORDS, "/usr/share/dict/words")
        or croak "Can't open /usr/dict/words or /usr/share/dict/words: $!";
    while (<WORDS>) {
        chomp;
        push @{$self->{words}}, $_;
    }
    srand (time ^ $$);  # sets random seed.

}



# create a storylink in $story to $dest
sub _link_story {

    my $self = shift;

    my ($story, $dest) = @_;

    my $page = $story->element->child('page');

    $page->add_child(class => "leadin", data => $dest);

}


# create a medialink in $story to $media.
sub _link_media {

    my $self = shift;

    my ($story, $media) = @_;

    my $page = $story->element->child('page');

    $page->add_child(class => "photo", data => $media);

}



1;
