const {
	parse,
	stringify,
	assign
} = require('comment-json')
const fs = require('fs')

var file = process.env.path_to_appsettings;
var slackToken = process.env.slack_token;

fs.readFile(file, function (err, obj) {

	const config = parse(obj.toString())

	config.Umbraco.CMS.HealthChecks.Notification.Enabled = true;

	config.Umbraco.CMS.HealthChecks.Notification.NotificationMethods.slack.Settings.botUserOAuthToken = slackToken;

	if (err) console.error(err);

	fs.writeFile(file, stringify(config, null, 2), function (err) {
		if (err) console.error(err);
		console.log("appsettings.json updated with build info")
	});
})