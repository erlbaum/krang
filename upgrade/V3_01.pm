package V3_01;
use strict;
use warnings;
use Krang::ClassLoader base => 'Upgrade';
use Krang::ClassLoader DB => 'dbh';
use Krang::Conf qw(KrangRoot);
use File::Spec::Functions qw(catfile);

sub per_installation {
}

sub per_instance {
    my $self = shift;

    $self->_wipe_slugs_from_cover_stories();
}

# remove slugs from stories that subclass Cover 
# (since slugs will now be optional for all types)
sub _wipe_slugs_from_cover_stories {

    my ($self) = @_;

    my @types_that_subclass_cover =
	grep { pkg('ElementLibrary')->top_level(name => $_)->isa('Krang::ElementClass::Cover') }
            pkg('ElementLibrary')->top_levels;

    my $dbh = dbh();
    my $sql = qq/update story set slug="" where story.class=?/;
    my $sth = $dbh->prepare($sql);
    
    foreach my $type (@types_that_subclass_cover) {
	print "Cleaning slugs from stories of type '$type'... ";
	$sth->execute($type);
	print "DONE\n";
    }
}

1;
