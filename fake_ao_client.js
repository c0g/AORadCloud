var http = require('http');
var querystring = require('querystring');

var options_send = {
 host: "localhost",
 port: "3000",
 path: "/",
 method: "post"
}

send_message = function(id, payload) {
  var post_req = http.request(options_send, function(res) {
      res.setEncoding('utf8');
      res.on('data', function (chunk) {
          console.log('Response: ' + chunk);
      });
  }).on('error',function(){});
  post_req.write(
    JSON.stringify( {"id": id, "payload": payload })
    );
  post_req.end();
}