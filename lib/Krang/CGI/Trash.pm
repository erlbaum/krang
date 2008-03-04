package Krang::CGI::Trash;
use Krang::ClassFactory qw(pkg);
use strict;
use warnings;

=head1 NAME

Krang::CGI::Trash - the trashbin controller

=head1 SYNOPSIS

None.

=head1 DESCRIPTION

This application manages Krang' trashbin.

=head1 INTERFACE

=head2 Run-Modes

=over 4

=cut

use Krang::ClassLoader Log => qw(debug);
use Krang::ClassLoader 'HTMLPager';
use Krang::ClassLoader Widget  => qw(format_url);
use Krang::ClassLoader Message => qw(add_message add_alert);

use UNIVERSAL::moniker;
use Carp qw(croak);

use Krang::ClassLoader base => 'CGI';

sub setup {
    my $self = shift;
    $self->start_mode('find');
    $self->mode_param('rm');
    $self->tmpl_path('Trash/');
    $self->run_modes(
        [
            qw(
              find
              goto_view
              delete_checked
              restore_checked
              )
        ]
    );
}

=item find

Find assets living in the trashbin. This is the default runmode and it
requires no parameters.

=cut

sub find {
    my $self     = shift;
    my $query    = $self->query;
    my $template = $self->load_tmpl(
        "trash.tmpl",
        associate         => $query,
        die_on_bad_params => 0,
        loop_context_vars => 1,
        global_vars       => 1
    );

    # admin delete permission
    my %admin_permissions = pkg('Group')->user_admin_permissions();
    my $admin_may_delete  = $admin_permissions{admin_delete};
    $template->param(admin_may_delete => $admin_may_delete);

    # category-specific restore permission
    my %asset_permissions = pkg('Group')->user_asset_permissions();
    my $asset_may_restore = grep { $asset_permissions{$_} eq 'edit' }
      keys %asset_permissions;
    $template->param(asset_may_restore => $asset_may_restore);

    # maybe show list checkbox
    $template->param(show_list_checkbox => 1)
      if $admin_may_delete or $asset_may_restore;

    my %col_labels = (
        id    => 'ID',
        type  => 'Type',
        title => 'Title',
        url   => 'URL',
        date  => 'Date',
    );

    # setup paging list of objects
    my $pager = pkg('HTMLPager')->new(
        cgi_query        => $query,
        use_module       => pkg('Trash'),
        columns          => ['id', 'type', 'title', 'url', 'date', 'thumbnail', 'checkbox_column'],
        column_labels    => \%col_labels,
        columns_sortable => [qw(id type title url date)],
        id_handler  => sub { $self->_id_handler(@_) },
        row_handler => sub { $self->_row_handler(@_, \%asset_permissions, \%admin_permissions) },
    );

    # Run the pager
    $pager->fill_template($template);
    return $template->output;
}

sub _id_handler { return $_[1]->{type} . '_' . $_[1]->{id} }

sub _row_handler {
    my ($self, $row, $obj, $asset_permission_for, $admin_permission) = @_;

    # do the clone
    $row->{$_} = $obj->{$_} for keys %$obj;

    # show the item's checkbox (determined by user's category permissions)
    $row->{show_checkbox} = $obj->{may_edit};

    # mix in user asset permission
    $row->{show_checkbox} = 0
      unless $asset_permission_for->{$obj->{type}} eq 'edit';

    # anyway, show the checkbox if we have admin_delete permission
    $row->{show_checkbox} = 1
      if $admin_permission->{admin_delete};

    # format date
    my $date = $obj->{date};
    if ($date and $date ne '0000-00-00 00:00:00') {
        $date = Time::Piece->from_mysql_datetime($date);
        $row->{date} = $date->strftime('%m/%d/%Y %I:%M %p');
    } else {
        $row->{date} = '[n/a]';
    }

    # format URL
    if ($obj->{linkto}) {
        $row->{url} = format_url(
            url    => $obj->{url},
            linkto => "javascript:Krang.preview('story'," . $obj->{id} . ")",
            length => 50
        );
    } else {
        $row->{url} = format_url(
            url    => $obj->{url},
            length => 50
        );
    }

    # finally the asset type
    $row->{asset_type} = ucfirst($obj->{type});
}

=item goto_view

Redirects to the view detail screen for this object.

=cut

sub goto_view {
    my $self  = shift;
    my $query = $self->query;

    my $id      = $query->param('id');
    my $type    = $query->param('type');
    my $script  = $type . '.pl';
    my $type_id = $type . '_id';

    my $uri = "$script?rm=view&$type_id=$id&return_script=trash.pl";

    # mix in pager params for return
    foreach my $name (grep { /^krang_pager/ } $query->param) {
        $uri .= "&return_params=${name}&return_params=" . $query->param($name);
    }

    $self->header_props(-uri => $uri);
    $self->header_type('redirect');
    return "";
}

=item delete_checked

Deletes a list of checked objects.  Requires the param
krang_pager_rows_checked to be set to a list of values of the form
'type_id'.

=cut

sub delete_checked {
    my $self  = shift;
    my $query = $self->query;

    my @alerts = ();

    # try to delete
    foreach my $object (map { $self->_id2obj($_) } $query->param('krang_pager_rows_checked')) {

        eval { pkg('Trash')->delete(object => $object) };

        if ($@ and ref($@) and $@->moniker eq 'nodeleteaccess')
        {
            my $id_meth = $object->id_meth;
            push @alerts, ucfirst($object->moniker) . ' ' . $object->$id_meth . ': ' . $object->url;
        }
    }

    # inform user of what happened
    if (@alerts) {
        add_alert(
            'no_delete_permission',
            s => (scalar(@alerts) > 1 ? 's' : ''),
            item_list => join '<br/>',
            @alerts
        );
    } else {
        add_message('deleted_checked');
    }

    return $self->find;
}

=item restore_checked

Restore a list of checked ojects, bringing them back to live.
Requires an 'id' parameter of the form 'type_id'.

=cut

sub restore_checked {
    my $self  = shift;
    my $query = $self->query;

    my @restored = ();
    my @failed   = ();

    # try to restore
    foreach my $object (map { $self->_id2obj($_) } $query->param('krang_pager_rows_checked')) {

        eval { pkg('Trash')->restore(object => $object) };

        if ($@ and ref($@)) {
            my $exception = $@;    # save it away
            push @failed, $self->_format_msg(object => $object, exception => $exception);
        } else {
            push @restored, $self->_format_msg(object => $object);
        }
    }

    # inform user of what happened
    $self->_register_msg(\@restored, \@failed);

    return $self->find;
}

#
# Utility functions
#

# pass the messages to add_message() or add_alert()
sub _register_msg {
    my ($self, $restored, $failed) = @_;

    my @restored = @$restored;
    my @failed   = @$failed;

    if (@failed) {
        if (@restored) {
            add_alert(
                'restored_with_some_exceptions',
                restored_phrase => (scalar(@restored) > 1 ? 'These items were' : 'This item was'),
                restored_list => join('<br/>', @restored),
                failed_phrase => (scalar(@failed) > 1 ? 'These items were' : 'This item was'),
                failed_list => join('<br/>', @failed),
            );
        } else {
            add_alert(
                'restored_with_exceptions_only',
                failed_phrase => (scalar(@failed) > 1 ? 'These items were' : 'This item was'),
                failed_list => join '<br/>',
                @failed,
            );
        }
    } else {
        add_message(
            'restored_without_exceptions',
            restored_phrase => (scalar(@restored) > 1 ? 'These items were' : 'This item was'),
            restored_list => join '<br/>',
            @restored,
        );
    }
}

# format a message/alert
sub _format_msg {
    my ($self, %args) = @_;

    my $ex      = $args{exception};    # in case of conflict
    my $object  = $args{object};
    my $type    = $object->moniker;
    my $id_meth = $object->id_meth;
    my $id      = $object->$id_meth;

    my $msg =
        ucfirst($type) . ' ' 
      . $id . ' '
      . $object->url
      . '(restored to '
      . ($object->archived ? 'Archive' : 'Live') . ')';

    # sucess
    return $msg unless $ex;

    my $ex_type = $ex->moniker;

    # missing restore permission
    return $msg . " (no restore permission)"
      if $ex_type eq 'norestoreaccess';

    # URL conflict
    if ($ex_type eq 'duplicateurl') {
        if ($ex->categories) {
            my @cats = @{$ex->categories};
            my $reason =
              scalar(@cats) > 1
              ? ' URL conflict with <br/>'
              : ' URL conflict with <br/>';
            return $msg 
              . '<br/>(' 
              . $reason
              . join('<br/>', map { "Category $_->{id} &ndash; $_->{url}" } @cats) . ' )';
        } elsif ($ex->stories) {
            my @stories = @{$ex->stories};
            my $reason =
              scalar(@stories) > 1
              ? ' URL conflict with <br/>'
              : ' URL conflict with <br/>';
            return $msg 
              . '<br/>(' 
              . $reason
              . join('<br/>', map { "Story $_->{id} &ndash; $_->{url}" } @stories) . ' )';
        } elsif (my $id = $ex->id_meth) {
            return $msg . ' (URL conflict with ' . ucfirst($type) . ' ' . $id;
        } else {
            return $msg . '(URL conflict - no further information)';
        }
    }

    return $msg . '(unknown reason)';
}

# transform type_id into an object
sub _id2obj {
    my $self = shift;

    my ($type, $id) = $_[0] =~ /^([^_]+)_(.*)$/;
    croak("Unable to find type and id in '$_[0]'")
      unless $type and $id;

    # get package to handle type
    my $pkg = pkg(ucfirst($type));

    croak("No Krang package for type '$type' found")
      unless $pkg;

    # get object with this id
    my ($obj) = $pkg->find($pkg->id_meth => $id);

    croak("Unable to load $type $id")
      unless $obj;

    return $obj;
}

1;

=back

=cut
