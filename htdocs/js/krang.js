/*
Create the Krang namespace and put some helper methods
in it
*/

var Krang = {};

/*
    Krang.load([target])
    Applies all the loaded behaviours to the current document.
    Called at the end of each page. We avoid putting this into
    document.onload since that means it waits on pulling in
    all images, etc.

    Optionally receives a target (either id, or element object)
    for which to apply the behaviors.
*/
Krang.load = function(target) {
    Behaviour.apply(target);
    for(var i=0; i< Krang.onload_code.length; i++) {
        var code = Krang.onload_code.pop();
        if( code ) code();
    }
}

/*
    Krang.onload()
    Add some code that will get executed after the DOM is loaded
    (but without having to wait on images, etc to load).
    Multiple calls will not overwrite previous calls and all code
    given will be executed in the order give.
*/
Krang.onload_code = [];
Krang.onload = function(code) {
    Krang.onload_code.push(code);
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
    target    : the id of the target element receiving the contents (optional defaults to 'C')
    indicator : the id of the image to use as an indicator (optional defaults to 'indicator')
    onComplete: a call back function to be executed after the normal processing (optional)
                Receives as arguments, the same args passed into ajax_update

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
        target = 'C';

    new Ajax.Updater(
        { success : target },
        url_parts[0],
        {
            parameters  : query_params,
            evalScripts : true,
            asynchronous: true,
            // if we're successful we're not in edit mode (can be reset by the request)
            onSuccess   : function() { Krang.Nav.edit_mode(false) },
            onComplete  : function(request) {
                // wait 10 ms so we know that the JS in our request has been evaled
                // since this is the time that Prototype gives for the Browser to update
                // it's DOM
                setTimeout(function() {
                    // reapply any dynamic bits to the target that was updated
                    Krang.load(target);
                    // hide the indicator
                    Krang.hide_indicator(indicator);
                    // do whatever else the user wants
                    complete(args);
                }, 10);
            },
            onFailure   : function(req, e) { Krang.show_error(e) },
            onException : function(req, e) { Krang.show_error(e) }
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
        url = form.readAttribute('action');
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
    Krang.form_submit(formName, { input: 'value' }, new_window)
    Select a form, optionally sets the values of those
    elements and then submits the form.

    You can also specify a third parameter which is a boolean
    indicating whether or not the results will open up in a new
    window.
*/
Krang.form_submit = function(formName, inputs, new_window) {
    var form = document.forms[formName];
    var err = 'Krang.form_submit(): ';

    if( !form ) alert(err + 'form "' + formName + '" does not exist!');

    if( inputs ) {
        $H(inputs).each( function(pair) {
            var el = form.elements[pair.key];
            if(! el ) alert(err + 'input "' + pair.key + '" does not exist in form "' + formName + '"!');
            el.value = pair.value;
        });
    }

    if( new_window ) {
        // save the old target of the form so we can restore it after
        // submission
        var old_target = form.target;
        form.target = '_blank';
        form.non_ajax_submit ? form.non_ajax_submit() : form.submit();
        form.target = old_target;
    } else {
        form.submit();
    }
}

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
    Krang.update_progress(count, total, label)

    Updates the progress bar (with id "progress_bar") to the correct
    width, sets the percentage counter (with id "progress_bar_percent")
    and the optionally updates a label (with id "progress_bar_label")
*/
Krang.update_progress = function(count, total, label) {
    var bar   = document.getElementById('progress_bar');
    var perc  = document.getElementById('progress_bar_percent');
    var prog  = ( count + 1 ) / total;

    // can't go over 100%
    if( prog > 1 ) prog = 1

    var width = Math.floor( prog * 400 );

    bar.style.width = width + 'px';
    perc.innerHTML = Math.floor( prog * 100) + '%';
    if( label ) document.getElementById('progress_bar_label').innerHTML = string;
}

/*
    Krang.show_error
    Shows an error to the user in the UI
*/
Krang.show_error = function(msg) {
    msg = 'An error occurred! ' + msg;
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

/* 
    Krang.Nav
*/
Krang.Nav = {
    edit_mode_flag : false,
    edit_message   : 'Are you sure you want to discard your unsaved changes?',
    edit_mode      : function(flag) {
        // by default it's true
        if( flag === undefined ) flag = true;
        Krang.Nav.edit_mode_flag = flag;
    },
    goto_url       : function(url) {
        if (!Krang.Nav.edit_mode_flag || confirm(Krang.Nav.edit_message)) {
            window.location = url;
            Krang.Nav.edit_mode_flag = false;
        }
    }
};
