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

    _update_config();
}

sub _update_config {
    # add the new EnableFTP directive if we need to
    open(CONF, '<', catfile(KrangRoot, 'conf', 'krang.conf'))
      or die "Unable to open conf/krang.conf: $!";
    my $conf = do { local $/; <CONF> };
    close(CONF);

    # already has a EnableFTP setting?
    return if $conf =~ /^\s*EnableFTP/m;

    # write out conf and add the new line
    open(CONF, '>', catfile(KrangRoot, 'conf', 'krang.conf'))
      or die "Unable to open conf/krang.conf: $!";
    print CONF $conf;
    print CONF <<END;
EnableFTP 1
END
    close(CONF);
}

1;
