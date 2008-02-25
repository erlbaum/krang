package Krang::Trash;
use Krang::ClassFactory qw(pkg);
use strict;
use warnings;

use Krang::ClassLoader Session => qw(%session);
use Krang::ClassLoader DB      => qw(dbh);
use Krang::ClassLoader Log     => qw(debug);
use Krang::ClassLoader 'Story';
use Krang::ClassLoader 'Media';
use Krang::ClassLoader 'Template';
use Carp qw(croak);

# static part of SQL query
our $QUERY;

=head1 NAME

Krang::Trash - data broker for TrashBin CGI

=head1 SYNOPSIS

  use Krang::ClassLoader 'Trash';

  # get a list of objects on the current user's workspace
  @objects = pkg('Trash')->find();

  # get just the first 10, sorting by url:
  @objects = pkg('Trash')->find(limit    => 10,
                                offset   => 0,
                                order_by => 'url');

=head1 DESCRIPTION

This module provides a find() method which returns all objects
living in the trashbin.

=head1 INTERFACE

=over

=item C<< @objects = Krang::Trash->find() >>

=item C<< $count = Krang::Trash->find(count => 1) >>

Finds stories, media and templates currently living the trashbin.  The
returned array will contain Krang::Story, Krang::Media and
Krang::Template objects (but see the class method
C<register_find_sql()>).

Since the returned objects do not share single ID-space, the standard
C<ids_only> mode is not supported.

Available search options are:

=over

=item count

Return just a count of the results for this query.

=item limit

Return no more than this many results.

=item offset

Start return results at this offset into the result set.

=item order_by

Output field to sort by.  Defaults to 'type' which sorts stories
first, then media and finally templates.  Other available settings are
'date', 'title', 'url' and 'id'.

=item order_desc

Results will be in sorted in ascending order unless this is set to 1
(making them descending).

=back

=cut

sub find {
    my $pkg  = shift;
    my %args = @_;
    my $dbh  = dbh();

    my $user_id = $ENV{REMOTE_USER};

    croak "Krang::Trash: No user ID found" unless $user_id;

    # get search parameters out of args, leaving just field specifiers
    my $order_by = delete $args{order_by} || 'type';
    my $order_dir = delete $args{order_desc} ? 'DESC' : 'ASC';
    my $limit  = delete $args{limit}  || 0;
    my $offset = delete $args{offset} || 0;
    my $count  = delete $args{count}  || 0;

    # an order_by of type really means type,class,id.  Go figure.
    $order_by = "type $order_dir,class,id" if $order_by eq 'type';

    # built at INIT time
    my $query = $QUERY;

    # mix in order_by
    $query .= " ORDER BY $order_by $order_dir " if $order_by and not $count;

    # default secondary order_by to ID
    $query .= ",id ASC" unless $order_by eq 'id' or $order_by =~ /,/;

    # add LIMIT clause, if any
    if ($limit) {
        $query .= $offset ? " LIMIT $offset, $limit" : " LIMIT $limit";
    } elsif ($offset) {
        $query .= " LIMIT $offset, -1";
    }

    debug(__PACKAGE__ . "::find() SQL: " . $query);

    # execute the search
    my $sth = $dbh->prepare($query);
    $sth->execute($user_id);

    # return just a count if requested
    if ($count) {
        my $results = $sth->fetchall_arrayref;
        $sth->finish;
        return scalar @$results;
    }

    # get results
    my $results = $sth->fetchall_arrayref();
    $sth->finish;

    # build lists of IDs for each class to load
    my %object_ids_for = ();
    for my $row (@$results) {
        my ($id, $type) = @$row;
        debug("StoryID: $id");
        push @{$object_ids_for{$type}}, $id;
    }

    # load objects
    my %objects_for = ();
    for my $type (keys %object_ids_for) {
        if (@{$object_ids_for{$type}}) {
            my $pkg = ucfirst($type);
            my $id  = $type . '_id';

            $objects_for{$type} =
              {map { ($_->$id => $_) } pkg($pkg)->find($id => $object_ids_for{$type})};
        }
    }

    # put them into the desired order
    my @objects = ();
    for my $row (@$results) {
        my ($id, $type) = @$row;
        push @objects, $objects_for{$type}{$id};
    }

    return @objects;
}

# Default query for Krang's core objects
$QUERY = <<SQL;
(
SELECT s.story_id AS id,
       'story' AS type,
       sc.url,
       s.cover_date AS date,
       s.title AS title,
       class,
       ucpc.may_see
 FROM  story AS s
 LEFT JOIN story_category AS sc
        ON s.story_id = sc.story_id
 LEFT JOIN user_category_permission_cache AS ucpc
        ON sc.category_id = ucpc.category_id
 WHERE sc.ord = 0
 AND   ucpc.user_id = ?
 AND   s.trashed = 1
 AND   ucpc.may_see = 1
)
SQL
##UNION
##
##(SELECT media_id AS id,
##        'media' AS type,
##        url,
##        creation_date AS date,
##        title,
##        '' as class
## FROM media
## WHERE checked_out_by = ?)
##
##UNION
##
##(SELECT template_id AS id,
##        'template' as type,
##        url,
##        creation_date AS date,
##        filename AS title,
##        '' as class
## FROM template
## WHERE checked_out_by = ?)
##SQL

=item C<< pkg('Trash')->register_find_sql(sql => $sql) >>

This class method allows custom objects other than Krang's core
objects Story, Media and Template to register with the trashbin's
find() method.  It should be called in a BEGIN block!

The only argument C<sql> takes the SQL query required for finding
those objects in the trashbin.

B<Example for a custom object named "Mailing">

This example follows the usual naming convention, the moniker of the
objects' class being the name of the table holding these objects, and
the ID name being the concatenation of the table name plus one
underscore plus the string 'id'.  We also assume the presence of a
boolean column named 'trashed', which is supposed to be set to true if
the object currently lives in the trashbin.

 Class:   Krang::Mailing
 Table:   mailing

 BEGIN {

     pkg('Trash')->register_find_sql(sql => <<SQL);
 SELECT mailing_id AS id,
        'mailing' AS type,
        url
        mailing_date as date,
        subject AS title
        '' as class
 FROM mailing
 WHERE trashed = 1
 SQL

 }

=cut

sub register_find_sql {
    my ($pkg, %args) = @_;

    $QUERY .= 'UNION (' . $args{sql} . ')';
}

1;

=back

=cut

