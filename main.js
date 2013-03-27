var Earp = require('./lib/earp'), wyatt;

module.exports = function() {
	if (arguments.length) {
		wyatt = Object.create( Earp.prototype );
		wyatt = (Earp.apply( wyatt, arguments ) || wyatt);
		return wyatt;
	} else return wyatt;
}