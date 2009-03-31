var Krang;
if (Object.isUndefined(Krang)) { Krang = {} }
/**
   Krang exec function when condition is true
**/
Krang.execWhenTrue = function(cond, func, delay) {

    // default delay
    if (Object.isUndefined(delay)) {
        delay = 50;
    }

    // exec func when cond is true
    (function() {
        if (cond()) {
            func();
        } else {
            setTimeout(arguments.callee, 50);
        }
    })();

};
