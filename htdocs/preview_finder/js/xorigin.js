if (Prototype == undefined) {
    throw new Error("The library xorigin.js is based on prototype.js, but Prototype is not defined");
}

Prototype.XOrigin = {};

//Prototype.XOrigin._send = function(type, xwindow, xurl, xpath, options, form, xtarget) {
Prototype.XOrigin._send = function(type, xwindow, options) {
    var callback = {};

    // Hook Krang.Messages into onComplete handler
    var _onComplete = options['onComplete'] || Prototype.emptyFunction;
    delete options['onComplete'];
    callback['onComplete'] = function(json, pref, conf) {
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

    // TODO: Hook modal error popup into onFailure and onException handler
    ['onException', 'onFailure'].each(function(cb) {
            callback[cb] = options[cb] || Prototype.emptyFunction;
            delete options[cb];
    });

    // The response and finish handlers for XOrigin.WinInfo
    ['response', 'finish'].each(function(cb) {
            callback[cb] = options[cb] || Prototype.emptyFunction;
            delete options[cb];
    });

    // add our type
    options.type = type;

    // pack message for cross document messaging
    var msg = Object.toJSON(options);

    // show load indicator
    var loadIndicator = $('krang_preview_editor_load_indicator');
    loadIndicator.show();

    // install 'message' event listener to receive the response
    var responseHandler = function(e) {
            if (e.origin == options.cmsURL.replace(/^(https?:\/\/[^/]+).*$/, "$1")) {
                // message coming from xwindow

                // TODO hide indicator
                loadIndicator.hide();

                // call callbacks
                var data;
                if (data = e.data && e.data.split(/\uE000/)) {

                    console.debug("5. Response data from cmsURL: " + data);

                    var cb   = data[0];
                    var json = data[1] ? data[1].evalJSON() : {};
                    var pref = data[2] ? data[2].evalJSON() : {};
                    var conf = data[3] ? data[3].evalJSON() : {};

                    callback[cb](json, pref, conf);
                }

                // this is a one time event listener
                var me = arguments.callee;
                setTimeout(function() { Event.stopObserving(window, 'message', me) }, 10);

            } else {
                throw new Error("Cross document message from unauthorized origin '" + e.origin +"'");
            }
    };

    // listen for response
    Event.observe(window, 'message', responseHandler);

    // send message
    console.debug("1. Post message: "+msg);
    xwindow.postMessage(msg, options.cmsURL);
};

Prototype.XOrigin.Request  = Prototype.XOrigin._send.curry('request');
Prototype.XOrigin.XUpdater = Prototype.XOrigin._send.curry('xupdater');
Prototype.XOrigin.WinInfo  = Prototype.XOrigin._send.curry('wininfo');
