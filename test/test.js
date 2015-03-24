var page = require('webpage').create();
page.settings.localToRemoteUrlAccessEnabled = true;
page.settings.resourceTimeout = 1000;
// page.content = "<!doctype html>\n<html>\n<head>\new<script type=\"text/javascript\" src=\"https://code.jquery.com/jquery-1.11.2.min.js\"></script>\n</head>\n<body>\n<div id=\"foo\">bar<div>\n</body>\n</html>";
var content = '<!doctype html>';
content += '<html><head>';
content += '<script type="text/javascript" src="https://code.jquery.com/jquery-1.11.2.min.js"></script>';
content += '</head><body>';
content += '<h1 id="foo">bar</h1>';
content += '</body></html>';

// page.content = "<div id='foo'>bar</div>";

page.onConsoleMessage = function(msg) {
  console.log(msg);
};

page.onResourceTimeout = function(a) {
  phantom.exit(1);
};

page.onError = function(msg, trace) {

  var msgStack = ['ERROR: ' + msg];

  if (trace && trace.length) {
    msgStack.push('TRACE:');
    trace.forEach(function(t) {
      msgStack.push(' -> ' + t.file + ': ' + t.line + (t.function ? ' (in function "' + t.function +'")' : ''));
    });
  }

  console.log(msgStack.join('\n'));
  phantom.exit();
};

phantom.onError = function(msg, trace) {
  var msgStack = ['PHANTOM ERROR: ' + msg];
  if (trace && trace.length) {
    msgStack.push('TRACE:');
    trace.forEach(function(t) {
      msgStack.push(' -> ' + (t.file || t.sourceURL) + ': ' + t.line + (t.function ? ' (in function ' + t.function +')' : ''));
    });
  }
  console.log(msgStack.join('\n'));
  phantom.exit();
};

page.content = content

page.onLoadFinished = function() {
  page.evaluate(function() {
    console.log($('#foo').html());
  });
  phantom.exit();
};

// page.includeJs("http://code.jquery.com/jquery-1.11.2.min.js", function(){
// });
