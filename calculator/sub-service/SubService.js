var http = require('http');

const PORT = process.env.PORT || 50002;

console.log("Listening on port : " + PORT);
http.createServer (function(req, resp) {
	let body = [];
	req.on('data', (chunk) => { 
			body.push(chunk);
		})
	   .on('end', () => { 
			body = Buffer.concat(body).toString(); 
			
			resp.writeHead(200, {'Content-Type': 'text/plain'});
			if (body.length != 0) {
				var values = body.split(' ');
				console.log("New request : ");
				console.log("A = " + values[0]);
				console.log("B = " + values[1]);
				var res = parseFloat(values[0]) - parseFloat(values[1]);
				console.log("A - B = " + res);
				console.log("\r\n");
				resp.write(res +"\r\n");
			}
			resp.end();
	   });

}).listen(PORT);
