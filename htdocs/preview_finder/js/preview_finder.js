/**
   Krang Preview Finder Module
 */
(function() {
/*
                   --- CMS access data ---
*/
    var cmsWin   = top.opener;
    try {
        var cmsData = window.name ? window.name.evalJSON() : {}
    }
    catch(er) {
        alert(er.name + ": Critical error in preview_finder.js. Please inform the Krang developer team.\n");
    }
    var cmsURL     = cmsData.cmsURL;
    var cmsWinID   = cmsData.winID;

    // get story ID
    var fLabel  = $$('.krang_preview_editor_element_label').first();
    var flName  = fLabel ? fLabel.readAttribute('name') : '';
    try {
        var flObj   = flName ? flName.evalJSON() : '';
    }
    catch (er) {
        alert(er.name + ": Critical error in preview_finder.js. Please inform the Krang developer team.");
    }
    var storyID = flObj.storyID;

    console.debug("CMS URL: "+cmsURL);
    console.debug("Window ID: "+cmsWinID);
    console.debug("Story ID: "+storyID);

/*
                    --- Template Finder ---
*/

    // helper function to format infos extracted from our comment
    var formatInfo = function(info, separator) {
        var html   = '';

        var script = info.type == 'template'
        ? cmsURL + "/template.pl?rm=search&do_advanced_search=1&search_template_id=" + info.id
        : cmsURL + "/media.pl?rm=find&do_advanced_search=1&search_media_id=" + info.id;

        if (separator) {html += '<hr style="margin:3px 0px" class="__skip_pinfo"/>';}

        html += info.type == 'template'
        ? '<div class="__skip_pinfo"><strong class="__skip__pinfo">Template</strong> ' + info.id
         +'<br /><strong class="__skip_pinfo">File:</strong> ' + info.filename
        : '<div class="__skip_pinfo"><strong class="__skip__pinfo">Media</strong> ' + info.id
         +'<br /><strong class="__skip_pinfo">Title:</strong> ' + info.title

        html += '<br /><strong class="__skip_pinfo">URL:</strong> <a target="_blank" href="'
               +script+'" class="krang-find-template-link __skip_pinfo">'+info.url+'</a></div>';

        return html;
    };

    // find comments up from the element the user clicked on
    // checking previous siblings and then the parent, the tree upwards
    var findCommentsUp = function(element, callback) {
        element = $(element);
        var node = element;
        var acc  = [];
        while (node !== null) {
            while (node !== null) {
                if (node.nodeType == 8) { // comment node
                    if (Object.isFunction(callback)) {
                        // found a comment: extract the info
                        var info = (callback(node));
                        if (info !== null) {
                            acc.push(info);
                        }
                    } else {
                        acc.push(node);
                    }
                }
                last = node;
                node = node.previousSibling;
            }        
            node = last.parentNode;
        }
        return acc;
    }

    var startRE = /KrangPreviewFinder Start/;
    var endRE   = /KrangPreviewFinder End/;
    var pinfo   = null;

    // template finder click handler, looks up the info in the special
    // comments, formats them and display them in a popup
    var templateFinderClickHandler = function(e) {

        var element = e.element();
        var html    = '';
        var skip    = false;
        var info    = '';

        // skip our info DIV
        if (/__pinfo/.test(element.id) || element.hasClassName('__skip_pinfo')
            || element.hasClassName('krang_preview_editor_element_label')) {
            return;
        }

        // find the info comments we put in in Krang::ElementClass::find_template()
        var infos = findCommentsUp(element, function(element) {
                var comment = element.nodeValue;
                if (skip) {
                    // the previous one was an End tag: skip the corresponding start tag
                    if (startRE.test(comment)) {
                        // it's a start tag: reset skip
                        skip = false;
                    }
                    return null;
                }

                if (startRE.test(comment)) {
                    // a start tag: extract info
                    comment = comment.replace(/KrangPreviewFinder Start/, '').strip();
                    try {
                        info = comment.evalJSON();
                    }
                    catch (er) {
                        alert(er.name + ": Critical error in preview_finder.js. Please inform the Krang developer team.");
                    }
                    return info;
                } else if (endRE.test(comment)) {
                    // an end tag: we are not interested in the corresponding start tag
                    skip = true;
                    return null;
                } else {
                    // another comment
                    return null;
                }
        });

        // format the info
        var html = '';
        infos.each(function(info, index) {
            var separator = index === 0 ? false : true;
            html += formatInfo(info, separator);
        });
        
        // finally print it to the popup
        if (pinfo === null) {
            pinfo = ProtoPopup.makeFunction('__pinfo', {
                header:         '<strong>Template / Media Info</strong>',
                width:          '400px',
                cancelIconSrc : cmsURL + '/proto_popup/images/cancel.png'
            });
        }

//        if (info.cmsRoot) {
            pinfo(html);
//        }

        // and prevent the default behavior for links, unless it's our own link
        if (!element.hasClassName("krang-find-template-link")) {
            Event.stop(e);
        }
        return false;
    };

/*
                         --- Preview Editor ---

*/

    var runMode = '';

    // click handler for container element labels, posts back to the
    // CMS to open the corresponding container element in the "Edit Story" UI
    var labelClickHandler = function(e) {
        var label   = e.element();
        var info    = label.readAttribute('name');
        var cms     = info.evalJSON();
        var url     = cmsURL + '/story.pl';
        var params  = {
            window_id: cmsWinID,
            rm:        runMode,
            story_id:  cms.storyID,
            path:      cms.elementXPath
        };

        if (Object.isFunction(window.postMessage)) {
            // HTML5 feature implemented by Firefox 3+, IE8+ and Safari 4+
            params['ajax'] = 1;
            Prototype.XOrigin.XUpdater(cmsWin, cmsURL, '/story.pl', {parameters:params}, {success: 'C'});
        }
    };

    // position the labels
    var positionLabels = function() {
        $$('.krang_preview_editor_element_label').reverse().each(function(contElm) {
                var offset = contElm.next().cumulativeOffset();
                contElm.show().setStyle({left: offset.left - 7 + 'px', top: offset.top - 23 + 'px'})
    })};
    positionLabels();

    // reposition them when resizing the window
    Event.observe(window, 'resize', positionLabels);

/*
    
                  --- Overlay UI ---
    
*/
    // Stop click events from bubbling up above the UI container
    $('krang_preview_editor_top_overlay').observe('click', function(e) { Event.stop(e) });

    // Update overlay buttons callback
    var initOverlay = function(status) { // status provided by Krang::CGI::Story::get_status()

        console.debug("Story status on next line: ");
        console.debug(status);

        var uiReset = function() {
            try { $('__pinfo').hide() } catch(er) {}
            $$('.krang_preview_editor_btn').invoke('removeClassName', 'krang_preview_editor_btn_pressed');            
            $$('.krang_preview_editor_element_label').invoke('hide');
            document.stopObserving('click', templateFinderClickHandler);
            document.stopObserving('click', labelClickHandler);
        };

        var doActivateEdit = function() {
            $('krang_preview_editor_btn_edit').addClassName('krang_preview_editor_btn_pressed').show();
            $$('.krang_preview_editor_element_label').invoke('show');
            document.observe('click', labelClickHandler);
        };

        var activateEdit = function() {
            $('krang_preview_editor_btn_edit').show().observe('click', function(e) {
                uiReset();
                doActivateEdit();
            });
        }

        // reset UI
        uiReset();

        // Browse button
        $('krang_preview_editor_btn_browse').addClassName('krang_preview_editor_btn_pressed')
        .show().observe('click', function(e) {
            uiReset();
            $('krang_preview_editor_btn_browse').addClassName('krang_preview_editor_btn_pressed');
        });

        // Find template button
        $('krang_preview_editor_btn_find').show().observe('click', function(e) {
            uiReset();
            $('krang_preview_editor_btn_find').addClassName('krang_preview_editor_btn_pressed');
            document.observe('click', templateFinderClickHandler);
        });

        // Edit/Steal buttons and checked out msg
        if (status.checkedOutBy == 'me') {
            runMode = 'edit';
            activateEdit();
        } else if (status.checkedOut == '0') {
            runMode = 'checkout_and_edit';
            activateEdit();
        } else if (status.checkedOut == '1' && status.maySteal == '0') {
            var co = $('krang_preview_editor_checked_out');
            co.update(co.innerHTML + ' ' + status.checkedOutBy).show();
        } else if (status.maySteal == '1') {
            var ms = $('krang_preview_editor_btn_steal');
            ms.update(ms.innerHTML +  ' ' + status.checkedOutBy).show().observe('click', function(e) {
                    uiReset();
                    Prototype.XOrigin.XUpdater(cmsWin, cmsURL, '/story.pl', {
                            parameters: {
                                rm:        'pe_steal_story',
                                ajax:      1,
                                window_id: cmsWinID,
                                story_id:  storyID
                            },
                            onComplete: function(json, pref, conf) {
                                if (json.status == 'ok') {
                                    ms.hide();
                                    runMode = 'edit';
                                    doActivateEdit();
                                    activateEdit();
                                    Krang.Messages.add(json.msg).show(pref.message_timeout);
                                } else {
                                    console.error("Steal Story "+storyID+" failed (preview_finder.js)");
                                }
                            }
                        },
                        {success: 'C'}
                    );
            });
        } else {
            throw(new Error("Unknown story status in initOverlay() - preview_finder.js"));
        }

        // Close button
        $('krang_preview_editor_close').observe('click', function(e) {
            top.location.href = window.location.href;
        });

        // Help button
        var helpBtn = $('krang_preview_editor_help');
        var helpURL  = helpBtn.readAttribute('name');
        var showHelp = function() {
            window.open(helpURL, "kranghelp", "width=400,height=500");
        }
        helpBtn.observe('click', showHelp);
    }

    // initialize overlay
    Prototype.XOrigin.Request(cmsWin, cmsURL, '/story.pl', {
        parameters: {
            window_id: cmsWinID,
            rm:        'pe_get_status',
            story_id:  storyID
        },
        onComplete: initOverlay
    });


/*

            --- Other buttons

*/


})();
