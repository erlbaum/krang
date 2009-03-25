if (Prototype == undefined) {
    throw new Error("The library xorigin.js is based on prototype.js, but Prototype is not defined");
}

Prototype.XOrigin = {};

Prototype.XOrigin._send = function(type, xwindow, xurl, xpath, options, xtarget) {
    var callback = {};
    ['onSuccess', 'onComplete', 'onException', 'onFailure'].each(function(cb) {
            callback[cb] = options[cb] || Prototype.emptyFunction;
            delete options[cb];
    });

    // add our type
    options['__type__'] = type;

    // our defaults
    options.method = options.method ? options.method : 'get';
    if (type == 'xupdater') {
        options.evalScripts = options.evalScripts ? options.evalScripts : true;
    }

    // pack message for cross document messaging
    var msg = xurl + xpath + "\uE000" + Object.toJSON(options);
    if (type == 'xupdater' && xtarget) { msg += "\uE000" + Object.toJSON(xtarget); }

    // show load indicator
    var loadIndicator = $('krang_preview_editor_load_indicator');
    loadIndicator.show();

    // install 'message' event listener to receive the response
    var responseHandler = function(e) {
            if (e.origin == xurl.replace(/^(https?:\/\/[^/]+).*$/, "$1")) {
                // message coming from xwindow

                // TODO hide indicator
                loadIndicator.hide();

                // call callbacks
                var data;
                if (data = e.data && e.data.split(/\uE000/)) {

                    console.debug("5. Response data from xurl: " + data);

                    var cb   = data[0];
                    var json = data[1].evalJSON() || {};
                    var pref = data[2].evalJSON() || {};
                    var conf = data[3].evalJSON() || {};

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
    xwindow.postMessage(msg, xurl);
};

Prototype.XOrigin.Request  = Prototype.XOrigin._send.curry('request');
Prototype.XOrigin.XUpdater = Prototype.XOrigin._send.curry('xupdater');
