Db = require 'db'
Http = require 'http'
Plugin = require 'plugin'
Subscription = require 'subscription'
Event = require 'event'

exports.client_searchSub = (cb) !->
	cb.subscribe 'search:'+Plugin.userId()

exports.client_search = (text) !->
	Http.get
		query: text
		searchYahoo: true
		name: 'httpSearch'
		args: [Plugin.userId()]

exports.client_add = (text) !->
	if typeof text is 'object'
		addTopic Plugin.userId(), text
	else if (text.indexOf('http:') is 0 or text.indexOf('www.') is 0) and text.split(' ').length is 1
		Http.get
			url: text
			getMetaTags: true
			name: 'httpTags'
			args: [Plugin.userId()]
	else
		addTopic Plugin.userId(), title: text

exports.httpSearch = (userId, data) !->
	log 'pushing data', JSON.stringify(data)
	Subscription.push 'search:'+userId, data

exports.httpTags = (userId, data) !->
	log 'got tags data', data.title, data.description, data.image, data.url
	addTopic userId, data

addTopic = (userId, data) !->
	topic =
		title: data.title
		image: data.image
		description: data.description||''
		url: data.url
		time: 0|(new Date()/1000)
		by: userId

	maxId = Db.shared.incr('maxId')
	Db.shared.set(maxId, topic)

	name = Plugin.userName(userId)
	Event.create
		text: "#{name} added topic: #{topic.title}"
		sender: Plugin.userId()

exports.client_remove = (id) !->
	return if Plugin.userId() isnt Db.shared.get(id, 'by') and !Plugin.userIsAdmin()
	Db.shared.remove(id)
