use strict;
use warnings;
use Krang::Conf qw(KrangRoot FTPPort FTPAddress);
use Krang::Session qw(%session);
use Krang::Script;
use Krang::Category;
use Krang::Site;
use Krang::User;
use Krang::Media;
use Krang::Template;
use Krang::Session qw(%session);
use Krang::Test::Content;

use Net::FTP;
use IPC::Run qw(start);
use File::Spec::Functions qw(catfile);
use IO::Scalar;


# skip tests unless Apache running
BEGIN {
    unless (-e catfile(KrangRoot, 'tmp', 'krang_ftpd.pid')) {
        eval "use Test::More skip_all => 'Krang FTP server not running.';";
    } else {
        eval "use Test::More qw(no_plan);"
    }
    die $@ if $@;
}

my $creator = Krang::Test::Content->new;

END { $creator->cleanup() }

my @sites;

$sites[0] = $creator->create_site(preview_url  => 'preview.test.com',
                                  publish_url  => 'test.com',
                                  publish_path => KrangRoot.'/tmp/test_publish',
                                  preview_path => KrangRoot.'/tmp/test_preview'
                                 );

my ($root_cat) = Krang::Category->find(site_id => $sites[0]->site_id, dir => "/");
isa_ok($root_cat, 'Krang::Category', 'is Krang::Category');
$root_cat->save();

my @cat;
for (0 .. 10) {
    push @cat, $creator->create_category(
                                         dir     => 'test_' . $_,
                                         parent  => $root_cat->category_id
                                        );
}

# create a site and some categories to put media in
$sites[1] = $creator->create_site(preview_url  => 'preview.test2.com',
                                  publish_url  => 'test2.com',
                                  publish_path => KrangRoot.'/tmp/test2_publish',
                                  preview_path => KrangRoot.'/tmp/test2_preview'
                                 );

my ($root_cat2) = Krang::Category->find(site_id => $sites[1]->site_id, dir => "/");
isa_ok($root_cat2, 'Krang::Category', 'is Krang::Category');
$root_cat2->save();

my @cat2;
for (0 .. 10) {
    push @cat2, $creator->create_category(
                                          dir     => 'test2_' . $_,
                                          parent  => $root_cat2->category_id
                                         );

}


# set up Net::FTP session
my $ftp = Net::FTP->new(FTPAddress, Port => FTPPort, Timeout => 10);

# set up end block to kill connection at end
END { $ftp->quit; }

isa_ok($ftp, 'Net::FTP', 'is Net::FTP');

my $password = 'krangftptest';
my $user = $creator->create_user(password => $password);

is( $ftp->login( $user->login, $password ), '1', 'Login Test' );

my @auth_instances;
my @instances = Krang::Conf->instances();
foreach my $instance (@instances) {

    # set instance
    Krang::Conf->instance($instance);

    my $login_ok = Krang::User->check_auth($user->login,$password);

    if ($login_ok) {
       push @auth_instances, $instance;
    }        
}

Krang::Conf->instance($instances[0]);

my @listed_instances = $ftp->ls();

is ("@listed_instances", "@auth_instances", "FTPServer returned instances");

$ftp->cwd($instances[0]);

my @types = qw(media template);
my @ret_types = $ftp->ls();
is("@ret_types", "@types", "Type listing");

my @found_sites = Krang::Site->find(order_by => 'url');

my $sitenames = join(" ",(map { $_->url } @found_sites));

# go into media then templates and test
foreach my $type (@types) {
    $ftp->cwd($type);
    my @ret_sites = $ftp->ls();

    if ($type eq 'template') {
        my @templates = Krang::Template->find( category_id => undef);
        @templates = map { $_->filename } @templates;

        my $list = $sitenames;
        $list .= " @templates" if @templates; 
        is("@ret_sites", $list, "Site listing in $type");

         my $template_path = catfile(KrangRoot, 't','template','test.tmpl');
         is($ftp->put( $template_path ), 'test.tmpl', "Put template test.tmpl, not associated with category" );
         is($ftp->delete('test.tmpl'), 1, "Delete template test.tmpl");

    } else {
        is("@ret_sites", $sitenames, "Site listing in $type");
    }

    foreach my $site (@ret_sites) {
        next if ($site =~ /^\S*\.tmpl$/);
        $ftp->cwd($site);
        my @site_obj = Krang::Site->find(url => $site);
        isa_ok($site_obj[0], 'Krang::Site', "Krang::Site $site");
        my ($rc) = Krang::Category->find(site_id => $site_obj[0]->site_id, dir => "/");
        isa_ok($rc, 'Krang::Category', "Krang::Category");

        my @cat_list = Krang::Category->find(site_id => $site_obj[0]->site_id, parent_id => $rc->category_id);
        my $catnames = join(" ",(map { $_->dir } @cat_list));

        my $list_string = '';

        if ($type eq 'media') {
            my @existing_media = Krang::Media->find( category_id => $rc->category_id );
            my $medianames = join(" ",(map { $_->filename } @existing_media));

            if ($catnames) {
                $list_string = $catnames;
                $list_string .= " $medianames" if $medianames;
            } elsif ($medianames) {
                $list_string = $medianames; 
            }
        } else {
            my @existing_templates = Krang::Template->find( category_id => $rc->category_id );

            my $tnames = join(" ",(map { $_->filename } @existing_templates));

            if ($catnames) {
                $list_string = $catnames;
                $list_string .= " $tnames" if $tnames;
            } elsif ($tnames) {
                $list_string = $tnames; 
            }
        }
 
        my @ret_cats = $ftp->ls();
        is("@ret_cats", $list_string, "Category ls in site $site for type $type");

        # go into each category and create, get, put, delete media/template
        foreach my $cat (@cat_list) {
            my $cat_dir = $cat->dir;
            $ftp->cwd($cat_dir);
            $ftp->binary;
            if ($type eq 'media') {
                my $media_path = catfile(KrangRoot, 't','media','krang.jpg');
                is($ftp->put($media_path), 'krang.jpg', "Put media krang.jpg in category $cat_dir" );
                is($ftp->put($media_path), 'krang.jpg', "Put version 2 of media krang.jpg in category $cat_dir" ); 
                is($ftp->delete('krang.jpg'), 1, "Delete media krang.jpg in category $cat_dir");
            } else {
                my $template_path = catfile(KrangRoot, 't','template','test.tmpl');
                is($ftp->put( $template_path ), 'test.tmpl', "Put template test.tmpl in category $cat_dir" );
                is($ftp->delete('test.tmpl'), 1, "Delete template test.tmpl in category $cat_dir");
            }
            $ftp->cdup()
        }
        # back to site listings
        $ftp->cdup();
    }
    # back into type level
    $ftp->cdup();
}
