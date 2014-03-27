var zmq = require('zmq');
var zsock = zmq.socket('pub')
var zsock_rec = zmq.socket('sub')

zsock.bind('tcp://*:5556')

zsock_rec.identity = 'node_agent';
zsock_rec.connect('tcp://localhost:5555');
zsock_rec.subscribe('');

var http = require('http');

var options_send = {
	host: "localhost",
	port: "3001",
	path: "/",
	method: "POST"
}


// When we receive a message from Matlab, POST it to the AO server.
// Manually remove null characters, which mess it all up!
zsock_rec.on('message', function(data) {
	var post_req = http.request(options_send, function(res) {
      res.setEncoding('utf8');
      res.on('data', function (chunk) {
          console.log('Response: ' + chunk);
      });
	}).on('error',function(){});
	post_req.write(data.toString().split("\0").join(""));
	post_req.end();
});


//We run a server to accept post requests
server = http.createServer( function(req, res) {

    // console.dir(req.param);

    if (req.method == 'POST') {
        console.log("POST");
        var body = '';
        req.on('data', function (data) {
            body += data;
            console.log("Partial body: " + body);
        });
        req.on('end', function () {
            console.log("Body: " + body);
            zsock.send(body);
        });
        
        res.writeHead(200, {'Content-Type': 'text/html'});
        res.end('post received');
    }

});

port = 3000;
server.listen(port, '0.0.0.0');