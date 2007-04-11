package V2_100;
use strict;
use warnings;
use Krang::ClassLoader base => 'Upgrade';
use Krang::ClassLoader DB => 'dbh';
use Krang::Conf qw(KrangRoot);
use File::Spec::Functions qw(catfile);

# Add new krang.conf directive PreviewSSL
sub per_installation {
}

sub per_instance {
    my $self = shift;
    my $dbh = dbh();

    # add the 'use_autocomplete' preference
    $dbh->do(qq/
        INSERT INTO pref (id, value) VALUES ("use_autocomplete", "1");
    /);
    # add the 'message_timeout' preference
    $dbh->do(qq/
        INSERT INTO pref (id, value) VALUES ("message_timeout", "5");
    /);
}

1;
