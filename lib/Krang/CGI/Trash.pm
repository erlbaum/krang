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

use Krang::ClassLoader Session => qw(%session);
use Krang::ClassLoader Log     => qw(debug assert affirm ASSERT);
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
          ['id', 'type', 'title', 'url', 'date', 'thumbnail', 'command_column', 'checkbox_column'],
        column_labels           => \%col_labels,
        columns_sortable        => [qw(id type title url date)],
        command_column_commands => ['view'],
        command_column_labels   => {view => 'View Detail'},
        id_handler              => sub { $self->_obj2id(@_) },
        row_handler             => sub { $self->_row_handler(@_) },
    );

    # Run the pager
    $pager->fill_template($template);
    return $template->output;
}

sub _row_handler {
    my ($self, $row, $obj) = @_;

    my $date;
    if ($obj->isa('Krang::Story')) {
        $row->{story_id}   = $obj->story_id;
        $row->{id}         = $self->_obj2id($obj);
        $row->{title}      = $obj->title;
        $row->{story_type} = $obj->class->display_name;
        $row->{is_story}   = 1;
        $row->{url}        = format_url(
            url    => $obj->url,
            linkto => "javascript:Krang.preview('story'," . $obj->story_id . ")",
            length => 50
        );

        $date = $obj->cover_date();
    } elsif ($obj->isa('Krang::Media')) {
        $row->{media_id}  = $obj->media_id;
        $row->{id}        = $self->_obj2id($obj);
        $row->{title}     = $obj->title;
        $row->{thumbnail} = $obj->thumbnail_path(relative => 1);
        $row->{is_media}  = 1;
        $row->{url}       = format_url(
            url    => $obj->url,
            linkto => "javascript:Krang.preview('media', " . $obj->media_id . ")",
            length => 50
        );
        $date = $obj->creation_date();
    } else {
        $row->{template_id} = $obj->template_id;
        $row->{id}          = $self->_obj2id($obj);
        $row->{title}       = $obj->filename;
        $row->{is_template} = 1;
        $row->{url}         = format_url(
            url    => $obj->url,
            length => 50
        );
        $date = $obj->creation_date();
    }

    # format the date
    $row->{date} = ref $date ? $date->strftime('%m/%d/%Y %I:%M %p') : '[n/a]';

    # setup version, used by all type
    $row->{version} = $obj->version;

    # permissions, used by everyone
    $row->{may_edit} = $obj->may_edit;
}

=item goto_view

Redirects to the view detail screen for this object.

=cut

sub goto_view {

    return "TODO (see Workspace's implementation of goto_log()"

}

=item delete_checked

Deletes a list of checked objects.  Requires an 'id' parameter of the form
'type_id'.

=cut

sub delete_checked {
    my $self  = shift;
    my $query = $self->query;
    add_message('deleted_checked');
    foreach my $obj (map { $self->_id2obj($_) } $query->param('krang_pager_rows_checked')) {
        $obj->delete;
    }
    return $self->show;
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

# transform object into a type_id pair
sub _obj2id {
    my $self = shift;

    my $obj = shift;
    return "story_" . $obj->story_id if $obj->isa('Krang::Story');
    return "media_" . $obj->media_id if $obj->isa('Krang::Media');
    return "template_" . $obj->template_id;
}

# transform type_id into an object
sub _id2obj {
    my $self = shift;

    my ($type, $id) = $_[0] =~ /^([^_]+)_(.*)$/;
    croak("Unable to find type and id in '$_[0]'")
      unless $type and $id;

    my $obj;
    if ($type eq 'story') {
        ($obj) = pkg('Story')->find(story_id => $id);
    } elsif ($type eq 'media') {
        ($obj) = pkg('Media')->find(media_id => $id);
    } else {
        ($obj) = pkg('Template')->find(template_id => $id);
    }
    croak("Unable to load $type $id")
      unless $obj;
    return $obj;
}

1;

=back

=cut
