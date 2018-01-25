var express = require("express");
var app = express();
var bodyParser = require('body-parser');

var server = app.listen(3000, function(){
    console.log("listen:" + server.address().port);
});

app.use(express.static('public'));

app.use(bodyParser.urlencoded({
    extended: true
}));

app.use(bodyParser.json());

app.get('/', function (req, res) {
  res.send('public');
});