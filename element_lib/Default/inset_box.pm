package Default::inset_box;
use strict;
use warnings;

=head1 NAME

Default::inset_box

=head1 DESCRIPTION

Default inset_box element class for Krang. 

=cut


use base 'Krang::ElementClass';

sub new {
   my $pkg = shift;
   my %args = ( name => 'inset_box',
                children => 
                [ 
                 Krang::ElementClass::Text->new(name         => "title",
                                                display_name => 'Title',
                                                allow_delete => '0',
                                                min => 1,
                                                max => 1,
                                                reorderable => 0
                                                ),
                 Krang::ElementClass::Textarea->new(name => "paragraph",
                                                    required => 1,
                                                    bulk_edit => 1,
                                                   ),
                 Default::image->new(),
                 Krang::ElementClass::PopupMenu->new(name => "alignment",
                                                     min => 1,
                                                     max => 1,
                                                     allow_delete => 0,
                                                     values => [ "Left",
                                                                 "Middle",
                                                                 "Right"],
                                                     default => "Left"),
                ],
                @_);
   return $pkg->SUPER::new(%args);
}

sub input_form {
    my ($self, %arg) = @_;
    my ($query, $element, $order) = @arg{qw(query element order)};
    return $element->child('title')->data;
}


1;
