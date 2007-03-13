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
    Krang.new_window(url)
    Open the url into a new window consistently
*/
Krang.new_window = function(url) {
    var win =window.open(url,"thewindow","width=500,height=500,left=200,top=0,status=no,toolbar=no,menubar=no,scrollbars=yes,location=no,directories=no,resizable=no");
    win.focus();
}

/*
    Krang.classNameSuffix(element, prefix)
    Returns the portion of the class name that follows the give
    prefix and correctly handles multiple class names.

    // el is <a class="foo for_bar">
    Krang.classNameSuffix(el, 'for_'); // returns 'bar'
*/
Krang.classNameSuffix = function(el, prefix) {
    var suffix = '';
    var regex = new RegExp("(^|\\s)" + prefix + "([^\\s]+)($|\\s)");
    var matches = el.className.match(regex);
    if( matches != null ) suffix = matches[2];

    return suffix;
}
