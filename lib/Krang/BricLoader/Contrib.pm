package Krang::BricLoader::Contrib;

=head1 NAME

Krang::BricLoader::Contrib - yields Krang::Contributor object from
Bricolage input

=head1 SYNOPSIS

 my @contributors = Krang::BricLoader::Contrib(path => $xmlfile);
	OR
 my $contributor  = Krang::BricLoader::Contrib(object => $hashref);

 # add contributor to a dataset $set
 $set->add(object => $contributor);

 # associate contributor with story $story
 $set->add(object => $contributor, from => $story);

 # retrieve the contributor_id or type based on a hash of lookup values
 my %person = (prefix => 'Mr.',
	       fname  => 'Really',
	       mname  => 'Prolific',
	       lname  => 'Author',
	       suffix => 'III',
	       type   => 'Writer');
 $contributor = Krang::BricLoader::Contrib->lookup(\%person) or
		    die("No matching contributor found!");

=head1 DESCRIPTION



=cut

# make sure we can load Bricolage :)
use File::Spec::Functions qw(catdir catfile splitpath);

BEGIN {
    unshift @INC, catdir($ENV{BRICOLAGE_ROOT}, 'lib');
    eval "use Bric;";
    die <<MSG if $@;
######################################################################

Cannot load Bricolage.

Error message:

$@

######################################################################
MSG
}

#
# Pragmas/Module Dependencies
##############################
# Pragmas
##########
use strict;
use warnings;

# External Modules
###################
use Carp qw(verbose croak);
use Data::Dumper;
use File::Path qw(mkpath rmtree);
use File::Temp qw(tempdir);
use Time::Piece;
use XML::Simple qw(XMLin);

# Bricloage Modules
use Bric::Util::Grp::Parts::Member::Contrib;
use Bric::Biz::Person;

# Internal Modules
###################
use Krang::Conf qw(KrangRoot);
use Krang::Pref;

#
# Package Variables
####################
# Constants
############
use constant FIELDS => qw(contrib_id
			  prefix
			  first
			  middle
			  last
			  suffix
			  email
			  phone
			  bio
			  url);

# Globals
##########

# Lexicals
###########
my %contribs;
my $id = 1;
my %name_map = (fname => 'first',
                lname => 'last',
                mname => 'middle');


=head1 INTERFACE

=over


=item C<< @contributors = Krang::BricLoader::Contrib->new(obj => $href) >>

=item C<< @contributors = Krang::BricLoader::Contrib->new(path => $xml) >>

Constructs an array of Contributor pseudo-objects from either a hash ref or
xml file.

=cut

sub new {
    my $self = my $pkg = shift;
    my %args = @_;
    my $obj = $args{obj};
    my $path = $args{path};
    my (@contribs, $ref);

    if ($obj) {
        croak("Value with 'obj' arg must be a HASHREF.")
          unless (ref $obj && ref $obj eq 'HASH');
        push @$ref, $obj;
    } elsif ($path) {
        # set tmpdir
        $self->{dir} = tempdir(DIR => catdir(KrangRoot, 'tmp'));

        croak("File '$path' not found on the system!") unless -e $path;
        my $base = (splitpath($path))[2];
        my $new_path = catfile($self->{dir}, $base);
        link($path, $new_path);

        $ref = XMLin($new_path,
                     forcearray => ['contributor'],
                     keyattr => 'hobbittses');
        unlink($new_path);
    } else {
        croak("A non-null value must be passed with either the 'obj' or " .
              "'path' argument to this constructor!");
    }

    for my $c(@$ref) {
        $c = bless $c, $pkg;

        # lookup contrib
        $c = $c->_lookup_contrib;

        push @contribs, $c;
    }

    return @contribs;
}


=item C<< $count = Krang::BricLoader::Contrib->get_contrib_count() >>

Returns the number of contributor objects generated by this module.

=cut

sub get_contrib_count {return scalar keys %contribs;}


=item C<< (@contributors || $contribs) = Krang::BricLoader::Contrib->load() >>

Loads contributor objects via the Bricloage API.

=cut

sub load {
    my $pkg = shift;
    my %map = reverse %name_map;
    my (@contribs, %persons, %types);

    $persons{$_->get_id} = $_ for Bric::Biz::Person->list;
    $types{$_->get_id} = $_->get_name
      for Bric::Util::Grp::Person->list({all => 1});

    for (Bric::Util::Grp::Parts::Member::Contrib->list) {
        my $grp_id = $_->get_grp->get_id;
        next if $grp_id == 1;

        my $tmp = bless({},$pkg);

        # contrib type info
        $tmp->{contrib_id} = $_->get_id;
        $tmp->_set_type($types{$grp_id});

        my $p = $persons{$_->get_obj_id} or
          die "No object for: $_->{obj_id}\n";

        # contact info
        for my $c($p->get_contacts) {
            my $type = $c->get_type;
            next unless $type =~ /phone|email/i;
            $type =~ s/^.+ (\S+)$/lc $1/e;
            $tmp->{$type} = $c->get_value;
        }

        # name fields
        for my $f(qw/prefix first middle last suffix/) {
            my $meth = "get_" . (exists $map{$f} ? $map{$f} : $f);
            $tmp->{$f} = $p->$meth;
        }

        # custom fields
        my $hash = $_->get_attr_hash;
        if (ref $hash) {
            for my $k(keys %$hash) {
                $tmp->{lc $k} = $hash->{$k};
            }
        }

        # add to contrib hash
        $contribs{$tmp->_get_hash_key} = $tmp;

        push @contribs, $tmp;
    }

    return wantarray ? @contribs : \@contribs;
}


=item C<<($contrib || undef) = Krang::BricLoader::Contributor->lookup($obref)>>

Returns a reference to the Contrib object matching the supplied criteria or
undef

=cut

sub lookup {
    my ($pkg, $obj) = @_;

    return $contribs{_get_hash_key($obj)} ||
      $contribs{_get_hash_key($obj,1)} ||
        undef;
}


=item C<< $contributor->serialize_xml() >>

Serialize as XML.  See Krang::DataSet for details.

=cut

sub serialize_xml {
    my ($self, %args) = @_;
    my ($writer, $set) = @args{qw(writer set)};
    local $_;

    # open up <contrib> linked to schema/contrib.xsd
    $writer->startTag('contrib',
                      "xmlns:xsi" =>
                      "http://www.w3.org/2001/XMLSchema-instance",
                      "xsi:noNamespaceSchemaLocation" =>
                      'contrib.xsd');

    # basic fields
    $writer->dataElement($_ => $self->{$_}) for (FIELDS);

    # contrib types
    $writer->dataElement(contrib_type => $self->{contrib_type_name});

    # all done
    $writer->endTag('contrib');
}


sub DESTROY {
    my $self = shift;
    rmtree($self->{dir}) if $self->{dir};
}


=back

=cut



# Private Methods
##################
# lookup contributor type and add it if necessary
sub _add_contrib_type {
    my $opt = ucfirst(lc shift);

    croak("Contributor type is NULL!") if $opt eq "";

    my %contrib_types = reverse Krang::Pref->get('contrib_type');
    return ($contrib_types{$opt}, 0) if exists $contrib_types{$opt};

    # maybe we have a plural
    (my $singular = $opt) =~ s/s$//;
    return ($contrib_types{$singular}, 1) if exists $contrib_types{$singular};

    my @values = sort {$b <=> $a} values %contrib_types;
    my $start = $values[0] + 1;

    return (Krang::Pref->add_option('contrib_type', $opt), 0);
}

# dump contributors
sub _dump {
    my $self = shift;
    return Data::Dumper->Dump([\%contribs],['contribs']);
}

# builds hash-key from name fields
sub _get_hash_key {
    my ($self, $singular) = @_;
    my $key;

    my @fields = exists $self->{first} ? sort values %name_map :
      sort keys %name_map;

    for (@fields) {
        my $val = ref $self->{$_} ? '' : lc $self->{$_};
        $key .= "_$val";
    }

    my $type = lc(exists $self->{contrib_type_name} ?
                  $self->{contrib_type_name} : $self->{type});
    $type =~ s/s$// if $singular;

    $key .= "_$type" ;

    return $key;
}

# look up contributor
sub _lookup_contrib {
    my $self = shift;
    my $key = $self->_get_hash_key;
    my $tmp;

    if (my $contrib = $contribs{$key}) {
        return $contrib;
    }

    if (my $contrib = $contribs{$self->_get_hash_key(1)}) {
        return $contrib;
    } else {
        return $self->_map;
    }
}

# set up contributor necessary fields
sub _map {
    my ($self) = @_;

    # set id
    $self->{contrib_id} = $id++;

    # set first, middle, and last
    while (my($k, $v) = each %name_map) {
        $self->{$v} = ref $self->{$k} ? "" : delete $self->{$k};
    }

    # set contributor type
    $self->_set_type(delete $self->{type});

    # add contributor to lookup hash
    $contribs{$self->_get_hash_key} = $self;

    return $self;
}

# set contributor type
sub _set_type {
    my ($self, $type) = @_;
    my ($id, $singular) = _add_contrib_type($type);
    $self->{contrib_type_id} = $id;
    $type =~ s/s$//i if $singular;
    $self->{contrib_type_name} = ucfirst lc $type;
}



my $quip = <<QUIP;
since feeling is first
who pays any attention
to the syntax of things
will never wholly kiss you;

wholly to be a fool
while Spring is in the world

my blood approves,
and kisses are a better fate
than wisdom
lady i swear by all flowers.  Don't cry
- the best gesture of my brain is less than
your eyelids' flutter which says

we are for each other; then
laugh, leaning back in my arms
for life's not a paragraph

And death i think is no parenthesis

--e. e. cummings
QUIP
