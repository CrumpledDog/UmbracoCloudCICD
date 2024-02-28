var file = process.env.path_to_nuget_config + '/NuGet.config';

var read = require('read-file');
var buffer = read.sync(file, { encoding: 'utf8' });

var DomParser = require('@xmldom/xmldom').DOMParser;
var XmlSerializer = require('@xmldom/xmldom').XMLSerializer;
var vkbeautify = require("vkbeautify");

var doc = new DomParser().parseFromString(
	buffer
	, 'text/xml');

var token = process.env.package_view_token;
var nugetFeedUrl = process.env.package_feed_url;

var packageSources = doc.getElementsByTagName("packageSources")[0];

var adds = packageSources.getElementsByTagName("add");
var addNode = doc.createElement("add");
for (let i = 0; i < adds.length; i++) {
	if (adds[i].getAttribute("key") === "github"){
		addNode = adds[i];
	}
}

addNode.setAttribute("key", "github")
addNode.setAttribute("value", nugetFeedUrl)
packageSources.appendChild(addNode);


var packageSourceCredentials = doc.getElementsByTagName("packageSourceCredentials")[0];
if (packageSourceCredentials === undefined) {
	packageSourceCredentials = doc.createElement("packageSourceCredentials");
}

var newElement = packageSourceCredentials.getElementsByTagName("github")[0]
if (newElement != undefined) {
	packageSourceCredentials.removeChild(newElement);
}

const github = doc.createElement("github");
const username = doc.createElement("add");
username.setAttribute("key", "Username");
username.setAttribute("value", "Crumpled-Dog-IT");
const password = doc.createElement("add");
password.setAttribute("key", "ClearTextPassword")
password.setAttribute("value", token)
github.appendChild(username);
github.appendChild(password);
packageSourceCredentials.appendChild(github);
doc.getElementsByTagName("configuration")[0].appendChild(packageSourceCredentials);

var sXML = new XmlSerializer().serializeToString(doc);
sXML = vkbeautify.xml(sXML);

var writeFile = require('write');
writeFile.sync(file, sXML);