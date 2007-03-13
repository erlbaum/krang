var rules = {
    'a.new_window' : function(el) {
        el.observe('click', function(event) {
            Krang.new_window(this.readAttribute('href'));
            Event.stop(event);
        }.bindAsEventListener(el));
    },
    'input.autocomplete' : function(el) {
        // add a new div of class 'autocomplete' right below this input
        var div = Builder.node('div', { className: 'autocomplete', style : 'display:none' }); 
        el.parentNode.insertBefore(div, el.nextSibling);
        
        // turn off browser's auto-complete
        el.autocomplete = "off";

        // get the target class for the values
        var target_class = Krang.classNameSuffix(el, 'from_');

        new Ajax.Autocompleter(
            el,
            div,
            el.form.readAttribute('action'),
            { 
                paramName: 'phrase',
                tokens   : [' '],
                callback : function(el, url) {
                    url = url + '&rm=autocomplete&class=' + target_class;
                    return url;
                }
            }
        );
    }
};
Behaviour.register(rules);
