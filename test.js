var Earp = require('./main');

var theme = new Earp("/Users/Tyler/Dropbox/Clients/Pixels\ and\ Press/smart-form/views", { layout: 'layout' });

theme.set("title", "Hello!");

theme.registerHelper("titleText", function(str) {
	if (str) return " ~ " + str;
});

theme.registerPartial("nav", { test: "nav page" });

theme.template("signin", function(err, template) {
	if (err) console.error(err);
	else console.log(template.compile({ test: "signin page" }));
});