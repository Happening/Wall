Db = require 'db'
Event = require 'event'
Http = require 'http'
Metatags = require 'metatags'
Photo = require 'photo'
App = require 'app'
Subscription = require 'subscription'
Util = require 'util'
{tr} = require 'i18n'

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

exports.client_draft = (url) !->
	personal = Db.personal()
	if url
		personal.set 'draft', 0
		Http.get
			url: url
			cb: ['handleDraftUrlPage', App.userId(), url]
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
	post.memberId = App.userId()
	snip = post.snip
	post.snip = null

	if snip.type is 'photo'
		Photo.claim
			guid: snip.upload
			cb: ['handlePhoto', post]
		return

	if snip.type is 'link'
		url = snip.url
		if url==post.text # share only the url, no text
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
	onReady = post.onReady
	delete post.onReady
	Db.shared.set maxId, post
	onReady.reply() if onReady

	name = App.userName(post.memberId)
	notiText = post.text || post.title || post.url || '(photo)'
	Event.create
		text: "#{name} posted: #{notiText}"
		sender: post.memberId

exports.client_remove = (id) !->
	return if App.userId() isnt Db.shared.get(id, 'memberId') and !App.userIsAdmin()

	Photo.remove image if (image = Db.shared.get(id, 'image')) and image.indexOf('/') < 0

	Db.shared.remove(id)


exports.onUserEvent = (c) ->
	maxId = Db.shared.incr('maxId')
	Db.shared.set maxId, {s:c.s, a:c.a, u:c.u, c:c.c, time:0|App.time()}
	c.path = '/' # /?cs doesn't make sense here
	c.store = false # we've done the writing ourselves
	c

