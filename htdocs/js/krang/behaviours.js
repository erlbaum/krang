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
        
        // turn off browser's auto-complete
        el.autocomplete = "off";

        new Ajax.Autocompleter(
            el,
            div,
            el.form.readAttribute('action'),
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
