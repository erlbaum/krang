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
    'input.autocomplete' : function(el) {
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
};
Behaviour.register(rules);
