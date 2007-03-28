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
    // apply our registered behaviours
    Behaviour.apply(target);

    // run any code from Krang.onload()
    for(var i=0; i< Krang.onload_code.length; i++) {
        var code = Krang.onload_code.pop();
        if( code ) code();
    }

    // show the messages and alerts if there are any
    Krang.Messages.show();
    Krang.Messages.show('alerts');
};

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
};

/*
    Krang.popup(url)
    Open the url into a new popup window consistently
*/
Krang.popup = function(url) {
    var win = window.open( url, 'thewindow', 'width=500,height=500,top=0,left=200,scrollbars' );
    win.focus();
};

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
};

/*
    Krang.set_cookie(name, value)
    Sets a cookie to a particular value.
*/
Krang.set_cookie = function(name, value) {
    document.cookie = name + '=' + value;
};

/*
    Krang.my_prefs()
    Returns a hash of preferences values from the server
    (passed to use via a JSON cookie)
*/
Krang.my_prefs = function() {
    var json = Krang.get_cookie('KRANG_PREFS');
    return eval('(' + json + ')');
};

/*
    Krang.ajax_request({ url: 'story.pl' })
    Creates an Ajax.Updater object with Krang's specific needs
    in mind.
    Takes the following args in it's hash:

    url       : the full url of the request (required)
    indicator : the id of the image to use as an indicator (optional defaults to 'indicator')
    onComplete: a callback function to be executed after the normal processing (optional)
                Receives as arguments, the same args passed into ajax_update the AJAX transport
                object, and any JSON object returned in the X-JSON HTTP header.
    onFailure : a callback function to be executed in case of an error. Receives as arguments
                the AJAX transport object and the exception thrown. This is in addition to the
                normal error message the Krang will show to in the UI.

    Krang.ajax_request({
        url        : '/app/some_mod/something',
        indicator  : 'add_indicator',
        onComplete : function(args, transport, json) {
            // do something
        },
        onFailure  : function(transport, exception) {
            // do something
        }
    });

    TODO: handle GET and POST differently
*/
Krang.ajax_request = function(args) {
    var url       = args['url'];
    var indicator = args['indicator'];
    var complete  = args['onComplete'] || Prototype.emptyFunction;
    var failure   = args['onFailure'] || Prototype.emptyFunction;

    // tell the user that we're doing something
    Krang.show_indicator(indicator);

    // add the ajax=1 flag to the existing query params
    var url_parts = url.split("?");
    var query_params;
    if( url_parts[1] == null || url_parts == '' ) {
        query_params = 'ajax=1';
    } else {
        query_params = url_parts[1] + '&ajax=1';
    }

    new Ajax.Request(
        url_parts[0],
        {
            parameters  : query_params,
            evalScripts : true,
            asynchronous: true,
            // if we're successful we're not in edit mode (can be reset by the request)
            onSuccess   : function() { Krang.Nav.edit_mode(false) },
            onComplete  : function(transport, json) {
                // wait 12 ms so we know that the JS in our request has been evaled
                // since Prototype will wait 10 gives for the Browser to update
                // it's DOM
                setTimeout(function() {
                    // hide the indicator
                    Krang.hide_indicator(indicator);
                    // do whatever else the user wants
                    complete(args, transport, json);
                }, 12);
            },
            onFailure   : function(transport, e) { 
                failure(transport, e);
                Krang.show_error(e);
            },
            onException : function(transport, e) { 
                failure(transport, e);
                Krang.show_error(e);
            }
        }
    );
};

/*
    Krang.ajax_update({ url: 'story.pl' })
    Creates an Ajax.Updater object with Krang's specific needs
    in mind.
    Takes the following args in it's hash:

    url       : the full url of the request (required)
    target    : the id of the target element receiving the contents (optional defaults to 'C')
    indicator : the id of the image to use as an indicator (optional defaults to 'indicator')
    onComplete: a callback function to be executed after the normal processing (optional)
                Receives as arguments, the same args passed into ajax_update the AJAX transport
                object, and any JSON object returned in the X-JSON HTTP header.
    onFailure : a callback function to be executed in case of an error. Receives as arguments
                the AJAX transport object and the exception thrown. This is in addition to the
                normal error message the Krang will show to in the UI.

    Krang.ajax_update({
        url        : '/app/some_mod/something',
        target     : 'target_name',
        indicator  : 'add_indicator',
        onComplete : function(args, transport, json) {
          // do something
        },
        onFailure  : function(transport, exception) {
          // do something
        }
    });

    TODO: handle GET and POST differently
*/
Krang.ajax_update = function(args) {
    var url       = args['url'];
    var target    = args['target'];
    var indicator = args['indicator'];
    var complete  = args['onComplete'] || Prototype.emptyFunction;
    var failure   = args['onFailure'] || Prototype.emptyFunction;

    // tell the user that we're doing something
    Krang.show_indicator(indicator);

    // add the ajax=1 flag to the existing query params
    var url_parts = url.split("?");
    var query_params;
    if( url_parts[1] == null || url_parts == '' ) {
        query_params = 'ajax=1';
    } else {
        query_params = url_parts[1] + '&ajax=1';
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
            onComplete  : function(transport, json) {
                // wait 12 ms so we know that the JS in our request has been evaled
                // since Prototype will wait 10 gives for the Browser to update
                // it's DOM
                setTimeout(function() {
                    // reapply any dynamic bits to the target that was updated
                    Krang.load(target);
                    // hide the indicator
                    Krang.hide_indicator(indicator);
                    // do whatever else the user wants
                    complete(args, transport, json);
                }, 12);
            },
            onFailure   : function(transport, e) { 
                failure(transport, e);
                Krang.show_error(e);
            },
            onException : function(transport, e) { 
                failure(transport, e);
                Krang.show_error(e);
            }
        }
    );
};

/*
    Krang.ajax_form_submit(form)
    Submit a form using AJAX.

    TODO: set the method from the form
*/
Krang.ajax_form_submit = function(form) {
    Krang.ajax_update({
        url       : Krang.form_as_url(form),
        target    : Krang.class_suffix(form, 'for_'),
        indicator : Krang.class_suffix(form, 'show_')
    });
};

/*
    Krang.form_as_url(form)
    Create a URL representation of a current form state
*/
Krang.form_as_url = function(form) {
    var url;
    if( form.action ) {
        url = form.readAttribute('action');
    } else {
        url = document.URL;
        // remove any possible query bits
        url = url.replace(/\?.*/, '');
    }
    url = url + "?" + Form.serialize(form);
    return url;
};

/*
    Krang.form_set(formName, { input: 'value'})
    Select a form and set the values of it's inputs
*/
Krang.form_set = function(formName, inputs) {
    var form = document.forms[formName];
    var err = 'Krang.form_set(): ';

    if( !form ) alert(err + 'form "' + formName + '" does not exist!');

    if( inputs ) {
        $H(inputs).each( function(pair) {
            var el = form.elements[pair.key];
            if(! el ) alert(err + 'input "' + pair.key + '" does not exist in form "' + formName + '"!');
            el.value = pair.value;
        });
    }
}

/*
    Krang.form_submit(formName, { input: 'value' }, new_window)
    Select a form, optionally sets the values of those
    elements and then submits the form.

    You can also specify a third parameter which is a boolean
    indicating whether or not the results will open up in a new
    window.

    *NOTE* - This should not be used by the onclick handler of
    an input of type 'button' if the form is not of the 'non_ajax'
    class. This is because the browser won't stop the chain of events
    when we reach form.submit(), but will instead call the form's onsubmit()
    handler and then possibly submit the form again for the 2nd time.
    In the case of inputs of type 'submit', just use Krang.form_set()
    to set the values and let the form take care of the rest.
*/
Krang.form_submit = function(formName, inputs, new_window) {
    Krang.form_set(formName, inputs);
    var form = document.forms[formName];

    if( new_window ) {
        // save the old target of the form so we can restore it after
        // submission
        var old_target = form.target;
        form.target = '_blank';
        form.non_ajax_submit ? form.non_ajax_submit() : form.submit();
        form.target = old_target;
    } else {
        Krang.show_indicator();
        return form.submit();
    }
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
};

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
};

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
    if( prog > 1 ) prog = 1;

    var width = Math.floor( prog * 400 );

    bar.style.width = width + 'px';
    perc.innerHTML = Math.floor( prog * 100) + '%';
    if( label ) document.getElementById('progress_bar_label').innerHTML = string;
};

/*
    Krang.show_error
    Shows an error to the user in the UI
*/
Krang.show_error = function(msg) {
    var msg = "<h3>Whoops!</h3><strong>An error has occurred on the server.</strong><br>";
    msg += "Please notify the administrator of the time this occurred and what you were trying to do.<br>";
    msg += "<em>Thank you and sorry for the inconvenience.</em>";
    alert(msg);
};

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
};

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

/*
    Krang.Help
*/
Krang.Help = {
    current_topic    : '',
    current_subtopic : '',
    set              : function(topic, subtopic) {
        Krang.Help.current_topic    = topic;
        Krang.Help.current_subtopic = subtopic;
    },
    go               : function() {
        var url = 'help.pl';
        if( Krang.Help.current_topic )
            url = url + '?topic=' + Krang.Help.current_topic;
        if( Krang.Help.current_subtopic )
            url = url + '#' + Krang.Help.current_subtopic;
        Krang.popup(url);
    }
};

/*
    Krang.Messages
*/
Krang.Messages = {
    stack : { messages: [], alerts: [] },
    add   : function(msg, level) {
        // default to 'messages'
        if( level === undefined ) level = 'messages';
        Krang.Messages.stack[level].push(msg);
    },
    show  : function(level) {
        // default to 'messages'
        if( level === undefined ) level = 'messages';

        var my_stack = Krang.Messages.stack[level];
        if( my_stack.length ) {
            var content = '';
            for(var i=0; i< my_stack.length; i++) {
                var msg = my_stack.pop();
                if( msg ) content = content + '<p>' + msg + '</p>';
            }
            var el = $(level);
            // set the content 
            el.down('div.content').update(content);

            // we need to reposition the messages div so it's
            // at the top of the viewport
            var pos = Position.page(el);
            var top = pos[1];
            if( top < 0 ) {
                top = Math.abs(top) + 'px';
                el.setStyle({ top: top });
            }
            new Effect.SlideDown(el, { duration: .5 });
        }
    },
    hide  : function(level) {
        // default to 'messages'
        if( level === undefined ) level = 'messages';
        new Effect.SlideUp(level, { duration: .5 });
    }
};

/* 
    Krang.row_checked(formName, inputName)
    Krang.pager_row_checked()
*/
Krang.row_checked = function( formName, inputName ) {
    var form = document.forms[ formName ];

    for ( var i = 0; i < form.elements.length; i++ ) {
        var el = form.elements[ i ];
        if ( el.type == 'checkbox' && el.checked && el.name == inputName ) 
            return true;  // db2: this should be a substring match, cf. ElementEditor/edit.tmpl
    }

    return false;
};

Krang.pager_row_checked = function() {
  return Krang.row_checked( 'krang_pager_form', 'krang_pager_rows_checked' );
};

/*
    Krang.check_all(checkbox, inputPrefix)
*/
Krang.check_all = function( checkbox, prefix ) {
    var form = checkbox.form;

    for ( var i = 0; i < form.elements.length; i++ ) {
        var el = form.elements[ i ];
        if ( el.type == 'checkbox' && el.name && el.name.indexOf( prefix ) == 0 ) 
            el.checked = checkbox.checked;
    }
};

/*
    Krang.update_order(select, prefix)

    Changes the values of a group of pull downs to reflect changes
    in their order. The given select box is the one which is assumed
    to have changed and all other inputs in the same form which have
    names that match the given prefix will also be updated.
*/
Krang.update_order = function( select, prefix ) {
    var position = select.value;
    var inputs   = [];
  
    // get the list of relevant elements
    for ( var i = 0; i < select.form.elements.length; i++ ) {
        var el = select.form.elements[i];
        if ( el.options && el.name && el.name.indexOf( prefix ) == 0 ) {
            inputs.push( el );
        }
    }

    // this sort function works for sorting with an upward or downward
    // bias if there is a tie
    var sort_function = function ( a, b, upward ) {
        var val = (a.value - b.value);
        if( val == 0 ) {
            if( a.name == select.name )      val = upward ? -1 :  1;
            else if( b.name == select.name ) val = upward ?  1 : -1;
        }
        return val;
    }

    inputs.sort(function(a, b) { return sort_function(a, b, false) });

    // that didn't do it? reverse bias!
    if ( inputs[ position -1 ] != select ) {
        inputs.sort(function(a, b) { return sort_function(a, b, true) });
    }

    // walk elements and assign indices
    for ( var i = 1; i <= inputs.length; i++ ) 
        inputs[i - 1].value = i;
}

/*
    Krang.preview(type, id)

    Opens up a new window to preview an element of a certain type
    (either 'story' or 'media') with a certain id (if not id is present
    the it will preview the one currently in the session)
*/
Krang.preview = function(type, id) {
    var url = 'publisher.pl?rm=preview_' + type + '&amp;'
            + ( ( id == null ) ? ( 'session=' + type ) : ( type + '_id=' + id ) );

    var instance = Krang.instance;
    // IE has problems with some characters that can appear in the instance name
    instance.toLowerCase().replace( new RegExp( '[^a-z]' , 'g' ), '' );

    var pop = window.open( url, ( instance + 'preview' ) );

    pop.focus();
}

/*
    new Krang.Navigation()

    Class for creating and controlling the expandable navigation menu.
*/
Krang.Navigation = Class.create();

Object.extend( Krang.Navigation.prototype, {
    cookie_name: 'KRANG_NAV_ACCORDION_OPEN_PANELS',
    initialize: function() {
        // all elements of '#S .nav_panel' are our panels
        this.panels = document.getElementsByClassName('nav_panel', $('S'));
        // get the opened panels from our cookie
        this.opened_panels = this.opened_panels_from_cookie();

        // this is to remember which panels are being acted upon
        this.action_panels = [];

        // now cycle through each panel, open it if appropriate, close
        // it other wise. Also add the onclick handlers
        var pos = 0;
        $A(this.panels).each(function(panel) {
            var label    = panel.childNodes[ 0 ];
            var contents = panel.childNodes[ 1 ];

            // is this panel opened?
            if ( this.opened_panels.indexOf( pos ) == -1 )
              Element.hide( contents );
            else
              Element.show( contents );

            // set the onclick handler to BlindDown if it's not visible
            // else BlindUp if it is
            label.observe(
                'click', 
                this._label_onclick(contents, pos).bind(this)
            );

            ++pos;
       }.bind(this));
    },
    _label_onclick: function(content, pos) {
        return function () {
            if( Element.visible(content) && !this.action_panels[pos]) {
                this.action_panels[pos] = true;
                new Effect.BlindUp(
                    content,
                    {
                        duration : .3,
                        afterFinish: function() { this.action_panels[pos] = false }.bind(this)
                    }
                );
                this.remove_opened_panel(pos);
            } else if( !this.action_panels[pos] ) {
                this.action_panels[pos] = true;
                new Effect.BlindDown(
                    content,
                    {
                        duration : .3,
                        afterFinish: function() { this.action_panels[pos] = false }.bind(this)
                    }
                );
                this.add_opened_panel(pos);
            }
        }.bind(this);
    },
    save_opened_panels: function(positions) {
        Krang.set_cookie(this.cookie_name, escape(positions.join(',')));
        this.opened_panels = positions;
    },
    remove_opened_panel: function(pos) {
        var panels = this.opened_panels;
        var index  = panels.indexOf( pos );

        // if we have it already
        if ( index != -1 ) panels.splice( index, 1 );

        this.save_opened_panels(panels);
    },
    add_opened_panel: function(pos) {
        var panels = this.opened_panels;

        // if we don't have it already
        if ( panels.indexOf(pos) == -1 ) panels.push(pos);

        this.save_opened_panels(panels);
    },
    opened_panels_from_cookie: function() {
        var value = Krang.get_cookie(this.cookie_name);
        var panels = [];

        // if we have nav cookie, then just use what it gives us
        if ( value && value != '' ) {
            panels = value.split(',');
        } else { // just show the first panel
            panels = [ 0 ];
        }
        return panels;
    }
} );

Krang.Widget = {};
/* 
    Krang.Widget.date_chooser(inputName)
    Primarily used by the HTML output by Krang::Widget::date_chooser()
*/
Krang.Widget.date_chooser = function(inputName) {
    // create a calendar object
    var cal = Calendar.setup({
        inputField  : inputName,
        ifFormat    : "%m/%d/%Y",
        button      : inputName + '_trigger',
        weekNumbers : false,
        showOthers  : true
    });
};

/*
    Krang.Widget.time_chooser(inputName)
    Primarily used by the HTML output by Krang::Widget::time_chooser()
*/
Krang.Widget.time_chooser = function(inputName) {
    // we need to find the associated clock and make the trigger display it
    var trigger = $(inputName + '_trigger');
    var clock   = $(inputName + '_clock');

    trigger.observe('click', function(event) {
        if( clock.visible() ) {
            clock.hide();
            // re-disable the inputs
            var hour = clock.down('select', 0);
            var minute = clock.down('select', 1);
            var ampm = clock.down('select', 2);

            hour.disabled   = true;
            minute.disabled = true;
            ampm.disabled   = true;

        } else {
            // position the clock to the right (30px) of the trigger
            var pos = Position.positionedOffset(trigger);
            clock.setStyle({ left: (pos[0] + 30) +'px', top: pos[1] +'px' });

            // un-disable the inputs
            var hour = clock.down('select', 0);
            var minute = clock.down('select', 1);
            var ampm = clock.down('select', 2);

            hour.disabled   = false;
            minute.disabled = false;
            ampm.disabled   = false;

            // parse the date in the input. If we get a valid time, then
            // set the selected values of the dropdowns
            var input = $(inputName);
            current = input.value;
            var regex = /^(\d+):(\d+)\s*(AM|PM)$/i;
            if( regex.exec(current) ) {
                hour.value   = RegExp.$1;
                minute.value = RegExp.$2;
                ampm.value   = RegExp.$3.toUpperCase();
            } else if(! current ) {
                // set the 1:00 AM since that's what the dropdown default to
                input.value = '1:00 AM';
            }
            
            clock.show();
        }
    });
};
Krang.Widget.update_time_chooser = function(inputName) {
    var clock = $(inputName + '_clock');
    var new_value = clock.down('select', 0).value + ':' + clock.down('select', 1).value + ' ' + clock.down('select', 2).value;

    $(inputName).value = new_value;
};
    

