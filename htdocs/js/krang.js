/*
Create the Krang namespace and put some helper methods
in it
*/

var Krang = {};

/*
    Krang.load()
    Applies all the loaded behaviours to the current document.
    Called at the end of each page. We avoid putting this into
    document.onload since that means it waits on pulling in
    all images, etc.
*/
Krang.load = function() {
    Behaviour.apply();
}

/*
    Krang.popup(url)
    Open the url into a new popup window consistently
*/
Krang.popup = function(url) {
    var win =window.open(url,"thewindow","width=500,height=500,left=200,top=0,status=no,toolbar=no,menubar=no,scrollbars=yes,location=no,directories=no,resizable=no");
    win.focus();
}

/*
    Krang.get_cookie(name)
    Returns the value of a specific cookie.
*/
Krang.get_cookie = function(name) {
    var value  = null;
    var cookie = document.cookie;
    var start, end;

    if ( cookie.length > 0 ) {
        start = cookie.indexOf( name + '=' );

        // if the cookie exists
        if ( start != -1 )  {
          start += name.length + 1; // need to account for the '='

          // set index of beginning of value
          end = cookie.indexOf( ';', start );

          if ( end == -1 ) end = cookie.length;

          value = unescape( cookie.substring( start, end ) );
        }
    }
    return value;
}

/*
    Krang.set_cookie(name, value)
    Sets a cookie to a particular value.
*/
Krang.set_cookie = function(name, value) {
    document.cookie = name + '=' + value;
}

/*
    Krang.my_prefs()
    Returns a hash of preferences values from the server
    (passed to use via a JSON cookie)
*/
Krang.my_prefs = function() {
    var json = Krang.get_cookie('KRANG_PREFS');
    return eval('(' + json + ')');
}

/*
    Krang.ajax_update({ url: 'story.pl' })
    Creates an Ajax.Updater object with Krang's specific needs
    in mind.
    Takes the following args in it's hash:

    url       : the full url of the request (required)
    target    : the id of the target element receiving the contents (optional defaults to 'content')
    indicator : the id of the image to use as an indicator (optional defaults to 'indicator')
    onComplete: a call back function to be executed after the normal processing (optional)
                Receives as arguments, the same args passed into ajax_submit

    Krang.ajax_update({
        url        : '/app/some_mod/something',
        target     : 'target_name',
        indicator  : 'add_indicator',
        onComplete : function(args) {
          // do something
        }
    });
*/
Krang.ajax_update = function(args) {
    var url       = args['url'];
    var target    = args['target'];
    var indicator = args['indicator'];
    var complete  = args['onComplete'] || Prototype.emptyFunction;

    // tell the user that we're doing something
    Krang.show_indicator(indicator);

    // add the ajax=1 flag to the existing query params
    var url_parts = url.split("?");
    var query_params;
    if( url_parts[1] == null || url_parts == '' ) {
        query_params = 'ajax=1'
    } else {
        query_params = url_parts[1] + '&ajax=1'
    }

    // the default target
    if( target == null || target == '' )
        target = 'content';

    // krang prompts when leaving an edit screen without saving
    // so we need to set/unset this depending on the success of
    // our actions
    orig_nav_emode = nav_emode;
    nav_emode = 0;

    new Ajax.Updater(
        { success : target },
        url_parts[0],
        {
            parameters  : query_params,
            evalScripts : true,
            asynchronous: true,
            onComplete : function(request) {
                // reapply any dynamic bits to the target that was updated
                Behaviour.apply(target);
                // hide the indicator
                Krang.hide_indicator(indicator);
                // do whatever else the user wants
                complete(args);
            },
            onFailure: function(req, e)   { Krang.show_error(e) },
            onException: function(req, e) { Krang.show_error(e) }
        }
    );
}

/*
    Krang.ajax_form_submit(form)
    Submit a form using AJAX.
*/
Krang.ajax_form_submit = function(form) {
    var url;
    if( form.action ) {
        url = form.action;
    } else {
        url = document.URL;
        // remove any possible query bits
        url = url.replace(/\?.*/, '');
    }
    url = url + "?" + Form.serialize(form);

    Krang.ajax_update({
        url       : url,
        target    : Krang.class_suffix(form, 'for_'),
        indicator : Krang.class_suffix(form, 'show_')
    });
};

/*
    Krang.show_indicator(id)
    Give the id of an element, show it. If no
    id is given, it will default to 'indicator';
*/
Krang.show_indicator = function(indicator) {
    // set the default
    if( indicator == null || indicator == '' )
        indicator = 'indicator';

    indicator = $(indicator);
    if( indicator != null )
        Element.show(indicator);
}

/*
    Krang.hide_indicator(id)
    Give the id of an element, hide it. If no
    id is given, it will default to 'indicator';
*/
Krang.hide_indicator = function(indicator) {
    // set the default
    if( indicator == null || indicator == '' )
        indicator = 'indicator';

    indicator = $(indicator);
    if( indicator != null )
        Element.hide(indicator);
}

/*
    Krang.show_error
    Shows an error to the user in the UI
*/
Krang.show_error = function(msg) {
    msg = 'An error occurred! ' + msg;
    // reset the nav_emode if we failed
    nav_emode = orig_nav_emode;
    // XXX - just show an alert for right now
    // We'll replace this with something better later
    alert(msg);
}

/*
    Krang.class_suffix(element, prefix)
    Returns the portion of the class name that follows the give
    prefix and correctly handles multiple class names.

    // el is <a class="foo for_bar">
    Krang.classNameSuffix(el, 'for_'); // returns 'bar'
*/
Krang.class_suffix = function(el, prefix) {
    var suffix = '';
    var regex = new RegExp("(^|\\s)" + prefix + "([^\\s]+)($|\\s)");
    var matches = el.className.match(regex);
    if( matches != null ) suffix = matches[2];

    return suffix;
}
