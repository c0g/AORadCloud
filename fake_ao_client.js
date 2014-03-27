var http = require('http');
var querystring = require('querystring');

var options_send = {
 host: "osculate.it",
 port: "3000",
 path: "/",
 method: "post"
}

send_message = function(host, id, payload) {
  var options_send = {
 host: host,
 port: "3000",
 path: "/",
 method: "post"
}
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