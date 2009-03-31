var Krang;
if (Object.isUndefined(Krang)) { Krang = {} }
/**
   File loader
**/
Krang.loadFile = function(href) {
    if (Object.isUndefined(href)) { return }
        
    if (href.endsWith('js')) {
        document.body.appendChild(new Element('script', {
            language: 'JavaScript',
            type:     'text/javascript',
            src:      href
        }));
    } else if (href.endsWith('css')) {
        document.getElementsByTagName('head')[0].appendChild(new Element('link', {
            type: 'text/css',
            rel:  'stylesheet',
            href: href
        }));
    } else {
        alert("Unsupported file type in Krang.loadFile(): "+href);
    }
} 
