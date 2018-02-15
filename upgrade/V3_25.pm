package V3_25;
use strict;
use warnings;
use Krang::ClassFactory qw(pkg);
use Krang::ClassLoader base => 'Upgrade';
use Krang::ClassLoader DB   => 'dbh';

sub per_instance {
    my ($self, %args) = @_;
    # nothing yet
}

sub per_installation {
    my ($self, %args) = @_;
    # remove old files
    $self->remove_files(
        qw{
            src/Bit-Vector-6.3.tar.gz
            src/Imager-0.72.tar.gz
            src/JSON-Any-1.17.tar.gz
            src/Linux-Pid-0.03.tar.gz
            src/Unicode-Normalize-1.04.tar.gz
        };
    );

}

1;
