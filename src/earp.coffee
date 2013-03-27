EventEmitter = require('events').EventEmitter
_ = require 'underscore'
Handlebars = require 'handlebars'
async = require 'async'
fs = require 'fs'
path = require 'path'

cleanExt = (ext) ->
	unless _.isString(ext) and ext then return ""
	if ext.substr(0, 1) is "." then ext = ext.substr(1)
	return ".#{ext}"

cbWrap = (callback) ->
	return (err) =>
		if _.isFunction(callback) then callback.apply(@, arguments)
		else if err then @emit("error", err)

class Earp extends EventEmitter
	constructor: (folder, options) ->
		@options = _.defaults options || {},
			layout: null,
			extensions: [ 'hbs', 'hbr', 'handlebars' ],
			partials: [],
			cache: true

		# Base vars
		@cache = []
		@locals = {}
		@helpers = {}
		@partials = {}

		# Deal with partials
		_.each @options.partials, (name) => @registerPartial name
		
		# Deal with folder
		@location = path.resolve(process.cwd(), folder);
		unless fs.existsSync(@location) then throw new Error("#{@location} couldn\'t be found.")

	set: (key, val) ->
		if _.isObject(key) then _.extend @locals, key
		else @locals[key] = val

	registerHelper: (name, fnc) ->
		@helpers[name] = fnc

	registerPartial: (template, data) ->
		unless _.isObject(data) then data = {}
		@partials[template] = data

	middleware: () ->
		return (req, res, next) =>
			res.render = (name, data, options) =>
				unless _.isObject(data) then data = {};
				_.extend data, { $req: req }

				@template name, options, (err, template) ->
					if err then next(err)
					else
						try html = template.compile data
						catch e then return next(e)

						res.send(html)

			next();

	find: (template, cb) ->
		file = path.resolve @location, template
		cb = cbWrap.call @, cb

		async.detectSeries(@options.extensions, (ext, callback) ->
			fs.exists file + cleanExt(ext), callback
		, (ext) ->
			if ext is undefined then return cb(null, null)
			file = file + cleanExt(ext)

			fs.stat file, (err, stat) ->
				if err then cb(err)
				else unless stat.isFile() then cb(new Error("\"#{template}\" is not a file."))
				else cb(null, {
					stat: stat,
					file: file
				})
		)

	retrieve: (file, cb) ->
		file = path.resolve @location, file
		cb = cbWrap.call @, cb

		fs.readFile file, 'utf8', (err, content) ->
			if err then return cb(err)
			
			unless content then ctx = () -> return ""
			else
				try ctx = Handlebars.compile(content)
				catch e then return cb(e)

			cb(null, {
				compile: ctx,
				content: content
			});

	template: (name, options, cb) ->
		if _.isFunction(options) and !cb then [cb, options] = [options, {}]
		options = _.extend {}, @options, options or {}
		cb = cbWrap.call @, cb

		@find name, (err, template) =>
			if err then return cb err
			else unless template then return cb new Error("Couldn't find template \"#{name}\".")
			
			if options.cache
				cached = _.findWhere @cache, { file: template.file }
				if cached and template.stat.atime <= cached.stat.atime then return cb null, cached

			@retrieve template.file, (err, extras) =>
				if err then return cb err
				_.extend template, extras

				final = (template) =>
					if options.cache then @cache.push template
					cb null, template

				done = (template) =>
					template.compile = @giveContext template.compile, options.data

					if options.partials then @retrievePartials options.partials, (err, partials) =>
						if err then cb(err)
						else
							compile = template.compile
							template.compile = (data, options) =>
								unless _.isObject(options) then options = {}
								options.partials = _.extend {}, partials, options.partials
								return compile data, options

							final(template)
					else final(template)		

				if options.layout
					lopts = _.extend {}, options, { layout: null }
					
					@template options.layout, lopts, (err, layout) =>
						if err then return cb err

						compile = template.compile
						template.compile = (data, options) =>
							unless data then data = {}
							data.body = new Handlebars.SafeString compile data, options
							return layout.compile data, options

						done(template)
				else done(template)

	retrievePartials: (partials, cb) ->
		if _.isFunction(options) and !cb then [cb, options] = [options, {}]
		if _.isArray(partials) then partials = _.object(partials, [])
		partials = _.pairs _.extend {}, @partials, partials
		cb = cbWrap.call @, cb

		async.map(partials, (p, callback) =>
			@template p[0], { layout: null, data: p[1], partials: false }, (err, template) ->
				if err then callback(err)
				else callback null, [ p[0], template.compile ]
		, (err, ps) ->
			if err then cb(err)
			else cb null, _.object(ps)
		)

	giveContext: (compile, custom) ->
		return (data, options) =>
			data = _.extend {}, @locals, custom, data
			
			unless _.isObject(options) then options = {}
			options.helpers = _.extend {}, Handlebars.helpers, @helpers, options.helpers
			options.partials = _.extend {}, Handlebars.partials, options.partials

			return compile data, options

module.exports = Earp