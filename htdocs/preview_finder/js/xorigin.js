// Krang.XOrigin namespace
if (Krang == undefined) { Krang = {} }
Krang.XOrigin = {};

// function factory
Krang.XOrigin.factory = (function() {

    // pseudo globals
    var loadIndicator = $('krang_preview_editor_load_indicator');
    var Options = {}, Handler = {};

    // complete handler: hook Krang.Messages
    var completeHandler = function(json, pref, conf) {
        var _onComplete = Options['onComplete'] || Prototype.emptyFunction;
        delete Options['onComplete'];

        // call custom handler
        _onComplete(json, pref, conf);

        // clear messages and alerts stack
        Krang.Messages.clear('messages');
        Krang.Messages.clear('alerts');

        if (!json) { return }

        // handle Krang.Messages 'alerts'
        if (json.alerts) {
            json.alerts.each(function(msg) { Krang.Messages.add(msg, 'alerts') });
        }
        Krang.Messages.show(pref.message_timeout, 'alerts');

        // handle Krang.Messages 'messages'
        if (json.messages) {
            // legacy Krang messages
            json.messages.each(function(msg) { Krang.Messages.add(msg, 'messages') });
        }
        if (json.status == 'ok') {
            // preview editor specific messages
            Krang.Messages.add(json.msg);
        }
        if (json.messages || json.status == 'ok') {
            Krang.Messages.show(pref.message_timeout, 'messages');
        }
    };

    // failure handler: hook modal failure popup
    var failureHandler = function() {
        var _cb = Options['onFailure'] || Prototype.emptyFunction;
        delete Options['onFailure'];

        // custom handler
        _cb();

        // default handler
        ProtoPopup.Alert.get('krang_preview_editor_failure', {
            modal:  true,
            width:  '500px',
            body:   'Looks like a little bug (probably an Internal Server Error)<br/>Contact your System Administrator if this problem continues.',
            cancelIconSrc:           false,
            bodyBackgroundImage:     'url("' + Options.cmsURL + '/images/bug.gif")',
            closeBtnBackgroundImage: 'url("' + Options.cmsURL + '/images/bkg-button-mini.gif")'
        }).show();
    };

    // exception handler: hook modal exception popup
    var exceptionHandler = function(error) {
        var _cb = Options['onException'] || Prototype.emptyFunction;
        delete Options['onException'];
        // custom handler
        _cb(error);

        // default handler
        ProtoPopup.Alert.get('krang_preview_editor_exception', {
            modal:  true,
            width:  '500px',
            body:   'Looks like a little bug (probably a JavaScript error)<br/>Contact your System Administrator if this problem continues.',
            cancelIconSrc:           false,
            bodyBackgroundImage:     'url("' + Options.cmsURL + '/images/bug.gif")',
            closeBtnBackgroundImage: 'url("' + Options.cmsURL + '/images/bkg-button-mini.gif")'
        }).show();
    };

    var addHandler = function () {
        Handler['onComplete']  = completeHandler;
        Handler['onFailure']   = failureHandler;
        Handler['onException'] = exceptionHandler;
        
        // The response and finish handlers for XOrigin.WinInfo
        ['response', 'finish'].each(function(cb) {
                Handler[cb] = Options[cb] || Prototype.emptyFunction;
                delete Options[cb];
        });
    };

    var responseHandler = function(e) {
        console.log(e.origin + ' ' + Options.cmsURL);
        if (e.origin == Options.cmsURL.replace(/^(https?:\/\/[^/]+).*$/, "$1")) {
            // message coming from xwindow

            // hide indicator
            loadIndicator.hide();

            // call handler
            var data;
            if (data = e.data && e.data.split(/\uE000/)) {

                console.debug("5. Response data from cmsURL: " + data);

                var cb   = data[0];
                var json = data[1] ? data[1].evalJSON() : {};
                var pref = data[2] ? data[2].evalJSON() : {};
                var conf = data[3] ? data[3].evalJSON() : {};

                Handler[cb](json, pref, conf);
            }

            // this is a one time event listener
//            var me = arguments.callee;
//            setTimeout(function() { Event.stopObserving(window, 'message', me) }, 10);


            console.log($H(Event.cache).inject(0,function(m,p){m+=$H(p.value).values().flatten().size();return m}))


        } else {
            throw new Error("Cross document message from unauthorized origin '" + e.origin +"'");
        }
    };

    return function(type, xwindow, options) {

        // set pseudo globals
        Options = options;
        addHandler(options);

        // add our type
        options.type = type;
        
        // pack message for cross document messaging
        var msg = Object.toJSON(options);
        
        // show load indicator
        loadIndicator.show();
        
        // install 'message' event listener to receive the response
        // listen for response
        Event.observe(window, 'message', responseHandler);
        
        // send message
        console.debug("1. Post message: "+msg);
        xwindow.postMessage(msg, options.cmsURL);
    };
})();

Krang.XOrigin.Request  = Krang.XOrigin.factory.curry('request');
Krang.XOrigin.XUpdater = Krang.XOrigin.factory.curry('xupdater');
Krang.XOrigin.WinInfo  = Krang.XOrigin.factory.curry('wininfo');
