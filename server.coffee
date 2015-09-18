Db = require 'db'
Event = require 'event'
Http = require 'http'
Metatags = require 'metatags'
Photo = require 'photo'
Plugin = require 'plugin'
Subscription = require 'subscription'
Util = require 'util'

exports.onUpgrade = !->
	all = Db.shared.get()
	for id,data of all when 0|id
		if newImage = data.imageThumb || data.photo
			delete data.imageThumb
			delete data.photo
			data.image = newImage
		if data.by
			data.memberId = data.by
			delete data.by
	Db.shared.set all

exports.getTitle = -> # we implemented our own title input


	
exports.client_draft = (url) !->
	personal = Db.personal()
	if url
		personal.set 'draft', 0
		Http.get
			url: url
			cb: ['handleDraftUrlPage', Plugin.memberId(), url]
	else
		personal.remove 'draft'

exports.handleDraftUrlPage = (memberId, url, resp) !->
	if meta = getMeta(resp)
		meta.url = url
		Db.personal(memberId).set 'draft', meta
	else
		Db.personal(memberId).remove 'draft'




exports.client_add = (post) !->
	log '_add', JSON.stringify(post)
	post.memberId = Plugin.memberId()
	text = post.text = post.text.trim() if post.text

	personal = Db.personal()
	if draft = personal.get('draft')
		personal.remove 'draft'

	if guid = post.photoguid
		# there's a photo, don't interpret any urls
		delete post.photoguid
		Photo.claim
			guid: guid
			cb: ['handlePhoto', post]
		return

	if draft
		post[k] = v for k,v of draft
		addPost post
		return

	if !text
		post.onReady?.reply()
		return

	# see if there are any urls
	if url = Util.getUrlsFromText(text)[0]
		if url==text # share only the url, no text
			post.text = null
		post.url = url
		Http.get
			url: url
			cb: ['handleUrlPage', post]
		return

	addPost post


exports.handlePhoto = (post, photoInfo) !->
	post.image = photoInfo?.key
	addPost post

getMeta = (resp) ->
	if resp.body and meta = Metatags.fromHtml(resp.body)
		title: meta.title
		image: meta.image
		description: meta.description

exports.handleUrlPage = (post, resp) !->
	if meta = getMeta(resp)
		for k,v of meta
			post[k] = v
	addPost post

exports.handleUrlPhoto = (post, photoInfo) !->
	post.image = photoInfo?.key
	addPost post

addPost = (post) !->
	if post.image and post.image.indexOf('/') > 0
		Photo.claim
			url: post.image
			cb: ['handleUrlPhoto',post]
			memberId: post.memberId
		return

	post.time = 0|(new Date()/1000)
	
	maxId = Db.shared.incr('maxId')
	Db.shared.set maxId, post
	post.onReady?.reply()

	name = Plugin.userName(post.memberId)
	notiText = post.text || post.title || post.url || '(photo)'
	Event.create
		text: "#{name} posted: #{notiText}"
		sender: post.memberId

exports.client_remove = (id) !->
	return if Plugin.memberId() isnt Db.shared.get(id, 'memberId') and !Plugin.userIsAdmin()

	Photo.remove image if (image = Db.shared.get(id, 'image')) and image.indexOf('/') < 0

	Db.shared.remove(id)

