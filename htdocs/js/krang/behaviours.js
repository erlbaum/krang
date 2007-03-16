var rules = {
    'a.popup' : function(el) {
        el.observe('click', function(event) {
            Krang.popup(this.readAttribute('href'));
            Event.stop(event);
        }.bindAsEventListener(el));
    },
    'a.help' : function(el) {
        // for now, just treat them like popup links
        // this may be expanded in the future
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
    'form.ajax' : function(el) {
        // only continue if we don't have any inputs of type 'file'
        // since you can't send those vi AJAX
        for(var i=0; i < el.elements.length; i++) {
            var field = el.elements[i];
            if( field.type == 'file' ) return;
        }

        // save the old on submit if there is one so that we can
        // call it later
        var oldOnSubmit = el.onsubmit;
        if( oldOnSubmit ) {
            oldOnSubmit = oldOnSubmit.bind(el);
        }

        // setup the onSubmit handler
        el.observe('submit', function(event) {
            // call our old onSubmit if there is one
            var good = true;
            if( oldOnSubmit ) good = oldOnSubmit();
            
            if( good ) Krang.ajax_form_submit(this);
            Event.stop(event);
        }.bindAsEventListener(el));

        // Krang likes to call submit() directly on forms
        // which unfortunately in JS does not call the onSubmit()
        // handler. So we need to handle that too
        el.submit = function() {
            Krang.ajax_form_submit(this);
        }.bindAsEventListener(el);
    },
    // create an autocomplete widget. This involves creating a div
    // in which to place the results and creating an Ajax.Autocompleter
    // object. We only do this if the use has the "use_autocomplete"
    // preference
    'input.autocomplete' : function(el) {
        var pref = Krang.my_prefs();
        if( pref.use_autocomplete ) {
            // add a new div of class 'autocomplete' right below this input
            var div = Builder.node('div', { className: 'autocomplete', style : 'display:none' }); 
            el.parentNode.insertBefore(div, el.nextSibling);
            
            // turn off browser's built-in auto-complete
            el.autocomplete = "off";

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
    }
};
Behaviour.register(rules);
