var rules = {
    'a.popup' : function(el) {
        el.observe('click', function(event) {
            Krang.popup(this.readAttribute('href'));
            Event.stop(event);
        }.bindAsEventListener(el));
    },
    'a.ajax' : function(el) {
        el.observe('click', function(event) {
            Krang.ajax_update({
                url       : this.href,
                div       : Krang.class_suffix(el, 'for_'),
                indicator : Krang.class_suffix(el, 'show_')
            });
            Event.stop(event);
        }.bindAsEventListener(el));
    },
    'form' : function(el) {
        // skip it if it has a class of 'non_ajax'
        if( el.hasClassName('non_ajax') ) return;

        // only continue if we don't have any inputs of type 'file'
        // since you can't send those vi AJAX
        // We might fix this in the future if we get adventurous and decide
        // to use a hidden iframe to old-school async stuff.
        for(var i=0; i < el.elements.length; i++) {
            var field = el.elements[i];
            if( field.type == 'file' ) return;
        }

        // save the old on submit if there is one so that we can
        // call it later
        el.old_onsubmit = el.onsubmit;

        // save a non-ajax version of the submit in case we need it
        // (like sending the request to a new window via Krang.submit_form_new_window )
        el.old_submit = el.submit;
        el.non_ajax_submit = function() {
            if( !this.old_onsubmit || this.old_onsubmit() ) {
                this.old_submit();
            }
        }.bind(el);

        // Krang likes to call submit() directly on forms
        // which unfortunately in JS is handled differently 
        // than a user clicking on a 'submit' button. So we put the magic in 
        // onsubmit() and then have submit() call onsubmit().
        el.onsubmit = function(options) {
            if( !this.old_onsubmit || this.old_onsubmit() ) {
                Krang.ajax_form_submit(this, options);
            }
            return false;
        }.bind(el);
        el.submit = function(options) {
            this.onsubmit(options);
        }.bind(el);
    },
    // create an autocomplete widget. This involves creating a div
    // in which to place the results and creating an Ajax.Autocompleter
    // object. We only do this if the use has the "use_autocomplete"
    // preference.
    // Can specifically ignore inputs by giving them the 'non_auto' class
    'input.autocomplete' : function(el) {
        // ignore 'non_auto'
        if( el.hasClassName('non_auto') ) return;
        var pref = Krang.my_prefs();
        if( pref.use_autocomplete ) {
            // add a new div of class 'autocomplete' right below this input
            var div = Builder.node('div', { className: 'autocomplete', style : 'display:none' }); 
            el.parentNode.insertBefore(div, el.nextSibling);

            // the request_url is first retrieved from the action of the form
            // and second from the url of the current document.
            var request_url = el.form.readAttribute('action')
                || document.URL;

            new Ajax.Autocompleter(
                el,
                div,
                request_url,
                { 
                    paramName: 'phrase',
                    tokens   : [' '],
                    callback : function(el, url) {
                        url = url + '&rm=autocomplete';
                        return url;
                    }
                }
            );
        }
    },
    // if a checkbox is selected in this table, then highlight
    // the row that checkbox belongs to
    'table.select_row tbody input[type="checkbox"]' : function(el) {
        el.observe('change', function(event) {
            var clicked = Event.element(event);
            var row = clicked.up('tr');
            if( clicked.checked ) {
                row.addClassName('hilite');
            } else {
                row.removeClassName('hilite');
            }
        }.bindAsEventListener(el));
    },
    '#error_msg_trigger' : function(el) {
        Krang.Error.modal = new Control.Modal(el, {
            opacity  : .6,
            zindex   : 999,
            position : 'absolute',
            mode     : 'named'
        });
    }
};
Behaviour.register(rules);
