Db = require 'db'
Event = require 'event'
Http = require 'http'
Photo = require 'photo'
Plugin = require 'plugin'
Subscription = require 'subscription'
Util = require 'util'

exports.getTitle = -> # we implemented our own title input

exports.client_add = (data) !->
	#log '_add', JSON.stringify(data)
	if typeof data is 'string'
		text = data.trim()

		# see if there are any urls
		urls = Util.getUrlsFromText text
		url = null
		if urls.length is 1
			if text.split(' ').length is 1
				# share only the url, no text
				url = text
				text = null
			else
				# share the first url, but also the original text
				url = urls[0]

		if url
			Http.get
				url: url
				getMetaTags: true
				name: 'httpTags'
				memberId: Plugin.userId()
				args: [Plugin.userId(), text]
		else
			addPost Plugin.userId(), text: text
	else if data.photoguid
		# there's a photo, don't interpret any urls
		data.by = Plugin.userId()
		Photo.claim data.photoguid, data

exports.onPhoto = (info, data) !->
	if info.key and data.by
		data.photo = info.key
		addPost data.by, data

exports.httpTags = (userId, text, data) !->
	#log 'httpTags received: '+JSON.stringify(data)
	if !data.url
		# url was probably malformed, just add the (url-based) title as text (unless we also have text)
		addPost userId, text: text ? data.title
	else
		if text
			data.text = text
		addPost userId, data

addPost = (userId, data) !->
	post =
		time: 0|(new Date()/1000)
		by: userId
	
	notiText = '' # becomes text, otherwise title, otherwise (photo)
	if data.image
		post.image = data.image
	if data.imageThumb
		post.imageThumb = data.imageThumb
	if data.photo
		post.photo = data.photo
		notiText = '(photo)'
	if data.url
		post.title = data.title
		post.description = data.description||''
		post.url = data.url
		notiText = post.title
	if data.text
		post.text = data.text
		notiText = post.text


	maxId = Db.shared.incr('maxId')
	Db.shared.set(maxId, post)

	name = Plugin.userName(userId)
	Event.create
		text: "#{name} posted: #{notiText}"
		sender: userId

exports.client_remove = (id) !->
	return if Plugin.userId() isnt Db.shared.get(id, 'by') and !Plugin.userIsAdmin()

	# remove any associated photos
	Photo.remove imageThumb if imageThumb = Db.shared.get(id, 'imageThumb')
	Photo.remove photo if photo = Db.shared.get(id, 'photo')

	Db.shared.remove(id)
