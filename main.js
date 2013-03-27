var Earp = require('./lib/earp'), main;

module.exports = function() {
	if (arguments.length) {
		var wyatt = Object.create( Earp.prototype );
		wyatt = (Earp.apply( wyatt, arguments ) || wyatt);
		if (!main) main = wyatt;
		return wyatt;
	} else return wyatt;
}