package Krang::Trash;
use Krang::ClassFactory qw(pkg);
use strict;
use warnings;

use Krang::ClassLoader Session => qw(%session);
use Krang::ClassLoader DB      => qw(dbh);
use Krang::ClassLoader Log     => qw(debug);
use Krang::ClassLoader History => qw(add_history);
use Krang::ClassLoader Conf    => qw(TrashMaxItems);

use Time::Piece;
use Time::Piece::MySQL;
use UNIVERSAL::moniker;
use Carp qw(croak);

use constant TRASH_OBJECT_FIELDS => qw(
  id
  type
  title
  class
  url
  date
  version
  may_see
  may_edit
  forth_col
  linkto
);

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
    my $results = $sth->fetchall_arrayref;
    $sth->finish;

    # maybe return the count
    return scalar @$results if $count;

    # return a list of hashrefs
    my @objects = ();

    for my $row (@$results) {
        my $obj = {};

        @{$obj}{(TRASH_OBJECT_FIELDS)} = @$row;

        push @objects, $obj;
    }

    return @objects;
}

# Default query for Krang's core objects
# Order matters since this forms our Trash object fassade
$QUERY = <<SQL;
(
SELECT s.story_id    AS id,
       'story'       AS type,
       title,
       class,
       sc.url        AS url,
       s.cover_date  AS date,
       version,
       ucpc.may_see  AS may_see,
       ucpc.may_edit AS may_edit,
       ''            AS forth_col,
       1             AS linkto
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

The only argument C<sql> represents the SQL query to find those
objects in the trashbin.

B<Example for a custom object named "Mailing">

The SQL select command forms a fassade, mapping asset fields to trash
object fields.  Order matters!  All fields must be present, though
they might contain the empty string (as the 'class' field in the
example below.

Also assumed is the presence of a boolean column named 'trashed',
which is supposed to be set to true if the object currently lives in
the trashbin.

 Class:   Krang::Mailing
 Table:   mailing

 BEGIN {

     pkg('Trash')->register_find_sql(sql => <<SQL);
 SELECT mailing_id   AS id,
        'mailing'    AS type,
        subject      AS title,
        ''           AS class,
        url          AS url,
        mailing_date AS date,
        ''           AS version,
        someperm     AS may_see,
        otherperm    AS may_edit,
        ''           AS forth_col,  # this is media's thumbnail column
        1            AS linkto      # format the URL as a link
 FROM mailing
 WHERE trashed = 1
 SQL

 }

=cut

sub register_find_sql {
    my ($pkg, %args) = @_;

    $QUERY .= 'UNION (' . $args{sql} . ')';
}

=item C<< pkg('Trash')->store(object => $story) >>

=item C<< pkg('Trash')->store(object => $media) >>

=item C<< pkg('Trash')->store(object => $template) >>

=item C<< pkg('Trash')->store(object => $other) >>

This method moves object to the trash on the database level.  It is
called by the object's trash() method.

=cut

sub store {
    my ($self, %args) = @_;

    my $object  = $args{object};
    my $type    = $object->moniker;
    my $id_meth = $object->id_meth;
    my $id      = $object->$id_meth;

    my $dbh = dbh();

    # set object's trashed flag
    my $query = <<SQL;
UPDATE $type
SET    trashed  = 1
WHERE  $id_meth = ?
SQL

    debug(__PACKAGE__ . "::store() SQL: " . $query . " ARGS: $id");

    $dbh->do($query, undef, $id);

    # memo in trash table
    $query = <<SQL;
REPLACE INTO trash (object_type, object_id, timestamp)
VALUES (?,?,?)
SQL

    my $t    = localtime();
    my $time = $t->mysql_datetime();

    debug(__PACKAGE__ . "::store() SQL: " . $query . " ARGS: $type, $id, " . $time);

    $dbh->do($query, undef, $type, $id, $time);

    # prune the trash
    $self->prune();
}

=item C<< pkg('Trash')->prune() >>

Prune the trash, deleting the oldest entries, leaving TrashMaxItems.

This class method is currently called at the end of each object delete
(i.e. when moving an object into the trash).

=over

=item Potential Security Hole

Users without admin_delete permission may delete assets by creating
bogus objects and pushing them into the trash, thus causing prune() to
permanently delete trashed objects!

=back

=cut

sub prune {
    my ($self) = @_;

    return unless TrashMaxItems;

    my $max = TrashMaxItems;
    my $dbh = dbh();

    # did we reach the limit
    my $query = "SELECT * from trash ORDER BY timestamp ASC LIMIT ?";

    debug(__PACKAGE__ . "::prune() SQL: " . $query . " ARGS: " . ($max + 1));

    my $sth = $dbh->prepare($query);
    $sth->execute($max + 1);
    my $result = $sth->fetchall_arrayref;
    $sth->finish;

    return unless $result;

    return if scalar(@$result) < $max + 1;

    # second item is the oldest we will keep so we have at least one item to delete
    my $datelimit = $result->[1][2];

    # get object_type and object_id of items to be deleted
    $query = "SELECT object_type, object_id from trash WHERE timestamp < ?";

    debug(__PACKAGE__ . "::prune() SQL: " . $query . " ARGS: $datelimit");

    $sth = $dbh->prepare($query);
    $sth->execute($datelimit);
    $result = $sth->fetchall_arrayref;

    return unless $result;

    # delete from object table
    for my $item (@$result) {
        my $type = $item->[0];
        my $id   = $item->[1];
        my $pkg  = pkg(ucfirst($type));

        # potential security hole!
        eval {

            # delete from object table
            my ($object) = $pkg->find($type . '_id' => $id);
            $object->checkin if $object->checked_out;
            local $ENV{REMOTE_USER} = 1;
            $pkg->delete($id);

            # delete from trash
            my $query = "DELETE FROM trash WHERE object_type = ? AND object_id = ?";
            debug(__PACKAGE__ . "::prune() SQL: " . $query . " ARGS: $type, $id");
            $dbh->do($query, undef, $type, $id);
        };
        debug(__PACKAGE__ . "::prune() - ERROR: " . $@) if $@;
    }
}

=item C<< pkg('Trash')->delete(object => $story) >>

=item C<< pkg('Trash')->delete(object => $media) >>

=item C<< pkg('Trash')->delete(object => $template) >>

=item C<< pkg('Trash')->delete(object => $other) >>

Deletes the specified object from the trashbin, i.e. deletes it
permanently from the database.  The object must implement a method
named C<delete()>.

=cut

sub delete {
    my ($self, %args) = @_;

    $args{object}->delete;

    $self->_delete_from_trash_table(%args);
}

=item C<< pkg('Trash')->restore(object => $story) >>

=item C<< pkg('Trash')->restore(object => $media) >>

=item C<< pkg('Trash')->restore(object => $template) >>

=item C<< pkg('Trash')->restore(object => $other) >>

Restores the specified object from the trashbin back to live.  The
object must implement a method named C<untrash()>.

=cut

sub restore {
    my ($self, %args) = @_;

    $args{object}->untrash;

    $self->_delete_from_trash_table(%args);
}

sub _delete_from_trash_table {
    my ($self, %args) = @_;

    my $object  = $args{object};
    my $id_meth = $object->id_meth;
    my $id      = $object->$id_meth;
    my $dbh     = dbh();

    my $query = "DELETE FROM trash WHERE object_type = ? AND object_id = ?";

    debug(  __PACKAGE__
          . "::delete() SQL: "
          . $query
          . " ARGS: "
          . $object->moniker . ', '
          . $object->$id_meth);

    $dbh->do($query, undef, $object->moniker, $object->$id_meth);
}

1;

=back

=cut

