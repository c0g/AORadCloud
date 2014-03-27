var http = require('http');
var querystring = require('querystring');

var type = Function.prototype.call.bind( Object.prototype.toString );

http.createServer(function (req, res) {
	if (req.method == "POST") {
    console.log('POST');
		var queryData = "";
		req.on('data', function(data) {
            queryData += data;
        });

    req.on('end', function() {
      var obj = JSON.parse(queryData);
      console.log(obj.id);
      // console.log(JSON.parse(queryData).payload);
      if (obj.payload === "ok" || obj.payload === "fail") {
        console.log(obj.payload)
      } else {
        console.log("Received data JSON");
      }
      res.writeHead(200, "OK", {'Content-Type': 'text/plain'});
      res.end();
    });
	}
  	
}).listen(3001);