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

    # global delete permission
    my $admin_may_delete = pkg('Group')->user_admin_permissions('admin_delete');
    $template->param(admin_may_delete => $admin_may_delete);

    # global restore permission
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
        cgi_query  => $query,
        use_module => pkg('Trash'),
        columns =>
          ['id', 'type', 'title', 'url', 'date', 'thumbnail', 'checkbox_column'],
        column_labels           => \%col_labels,
        columns_sortable        => [qw(id type title url date)],
        id_handler              => sub { $self->_id_handler(@_)  },
        row_handler             => sub { $self->_row_handler(@_, \%asset_permissions) },
    );

    # Run the pager
    $pager->fill_template($template);
    return $template->output;
}

sub _id_handler { return $_[1]->{type} . '_' . $_[1]->{id} }

sub _row_handler {
    my ($self, $row, $obj, $asset_permissions_for) = @_;

    # do the clone
    $row->{$_} = $obj->{$_} for keys %$obj;

    # cumulate user category permission with user asset permission
    $row->{may_edit} = 0
      unless $asset_permissions_for->{$obj->{type}} eq 'edit';

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
    foreach my $the (map { $self->_id2the($_) } $query->param('krang_pager_rows_checked')) {

	# this should always succeed as long as delete permission is global
	# because the UI does not show the Delete button if user has no admin_delete perm
        eval { $the->{object}->delete };

	if ($@ and ref($@) and ref($@) =~ m[.+::NoDeleteAccess$]) { # cannot know the exact package, can we?
	    push @alerts,
	      ucfirst($the->{type}) . ' ' . $the->{id} . ': ' . $the->{object}->url;
	}
    }

    # inform user of what happened
    if (@alerts) {
	add_alert('no_delete_permission',
		  s => (scalar(@alerts) > 1 ? 's' : ''),
                  item_list => join '<br/>', @alerts);
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

    return "TODO"

}

#
# Utility functions
#

# transform type_id into an object
sub _id2the {
    my $self = shift;

    my ($type, $id) = $_[0] =~ /^([^_]+)_(.*)$/;
    croak("Unable to find type and id in '$_[0]'")
      unless $type and $id;

    # get package to handle type
    my $pkg = pkg(ucfirst($type));

    croak("No Krang package for type '$type' found")
      unless $pkg;

    # get object with this id
    my ($obj) = $pkg->find($type.'_id' => $id);

    croak("Unable to load $type $id")
      unless $obj;

    return {type => $type, id => $id, object => $obj};
}


1;

=back

=cut
