Comments = require 'comments'
Db = require 'db'
Dom = require 'dom'
Event = require 'event'
Form = require 'form'
Icon = require 'icon'
Loglist = require 'loglist'
Modal = require 'modal'
Obs = require 'obs'
Page = require 'page'
Photo = require 'photo'
App = require 'app'
Server = require 'server'
Time = require 'time'
Ui = require 'ui'
Util = require 'util'
{tr} = require 'i18n'


exports.render = !->
	if postId = Page.state.get(0)
		renderSinglePost postId
	else
		renderWall()


renderSinglePost = (postId) !->
	Page.setTitle tr("Post")

	Comments.enable legacyStore: postId

	post = Db.shared.ref(postId)
	Event.showStar post.get('title')
	if App.userId() is post.get('memberId') or App.userIsAdmin()
		Page.setActions
			icon: 'delete'
			action: !->
				Modal.confirm null, tr("Remove post?"), !->
					Server.sync 'remove', postId, !->
						Db.shared.remove(postId)
					Page.back()

	url = post.get('url')
	image = post.get('image')

	if !url and image
		require('photoview').render key:image
	else if url
		Dom.div !->
			Dom.style
				Box: 'top'
				Flex: 1
				padding: '8px'
				marginBottom: '8px'
				backgroundColor: '#eee'
				border: '1px solid #ddd'
				borderBottom: '2px solid #ddd'
				borderRadius: '2px'
			Dom.cls 'link-box'

			if image
				Dom.img !->
					Dom.style
						maxWidth: '120px'
						maxHeight: '200px'
						marginRight: '8px'
					Dom.prop 'src', if image.indexOf('/') < 0 then Photo.url(image, 400) else image

			Dom.div !->
				Dom.style Flex: 1, fontSize: '90%'
				Dom.h3 !->
					Dom.style marginTop: 0
					Dom.text post.get('title')

				Dom.text post.get('description')

				Dom.div !->
					Dom.style
						marginTop: '6px'
						color: '#aaa'
						fontSize: '90%'
						whiteSpace: 'nowrap'
						textTransform: 'uppercase'
						fontWeight: 'normal'
					Dom.text Util.getDomainFromUrl(url)

			Dom.onTap !->
				App.openUrl url

	if text = post.get('text')
		Dom.div !->
			if image
				Dom.style marginTop: '12px'
			Dom.userText text


	expanded = Obs.create false
	byUserId = post.get('memberId')
	Dom.div !->
		Dom.style
			paddingTop: '8px'
			fontSize: '70%'
			color: '#aaa'
		Dom.text tr("Posted by %1", App.userName(byUserId))
		Dom.text " • "
		Time.deltaText post.get('time')

		Dom.text " • "
		expanded = Comments.renderLike
			store: ["likes", postId+"-post"]
			userId: byUserId
			aboutWhat: tr("post")

	Obs.observe !->
		if expanded.get()
			Dom.div !->
				Dom.style marginTop: 0
				Comments.renderLikeNames
					store: ["likes", postId+"-post"]
					userId: byUserId

renderWall = !->
	addingPost = Obs.create false
	Comments.disable()

	Ui.top !->
		Dom.style Box: 'middle', marginBottom: 0

		Ui.avatar App.userAvatar(),
			style: marginRight: '12px'
			onTap: !-> App.showMemberInfo(App.userId())

		Comments.renderInput
			text: tr("New post...")
			photo: true
			flex: true
			name: "commentText"
			snipName: "commentSnip"
			onSend: (msg, snip) !->
				addingPost.set true
				Server.sync 'add', {text: msg, snip: snip, onReady: !-> addingPost.set(false)}

	# Dom.div !->
	# spinner when a new post is added
	Obs.observe !->
		maxId = 0|Db.shared.get 'maxId'
		if addingPost.get()
			Dom.div !->
				Dom.style Box: 'middle', padding: '8px 0', borderBottom: '1px solid #ebebeb'
				Ui.spinner 38
				Dom.div !->
					Dom.style paddingLeft: '16px', color: '#aaa', Flex: 1
					Dom.text tr("Adding...")

	postCnt = 0
	empty = Obs.create(true)

	if fv = Page.state.get('firstV')
		firstV = Obs.create(fv)
	else
		firstV = Obs.create(-Math.max(1, (Db.shared.peek('maxId')||0)-20))
	lastV = Obs.create()
		# firstV and lastV are inversed when they go into Loglist
	Obs.observe !->
		lastV.set -(Db.shared.get('maxId')||0)

	# list of all posts
	Loglist.render lastV, firstV, (num) !->
		num = -num
		post = Db.shared.ref(num)
		return if !post.get('time')
		empty.set(!++postCnt)

		if post.get('s')
			c = post.get()
			c.id = post.key()
			renderNotice c
		else
			renderPost post

		Obs.onClean !->
			empty.set(!--postCnt)

	Dom.div !->
		if firstV.get()==-1
			Dom.style display: 'none'
			return
		Dom.style padding: '4px', textAlign: 'center'

		Ui.button tr("Earlier posts"), !->
			fv = Math.min(-1, firstV.peek()+20)
			firstV.set fv
			Page.state.set('firstV', fv)

	Obs.observe !->
		if empty.get()
			Ui.item !->
				Dom.style
					Box: 'middle center'
					color: '#bbb'
				Dom.text tr("Nothing has been posted yet")

renderNotice = (c) !->
	Ui.item !->
		Dom.style paddingTop: '2px', paddingBottom: '2px', minHeight: 0
		Dom.div !->
			Dom.style margin: '6px 0 6px 52px', fontSize: '70%'
			Dom.span !->
				Dom.style color: '#999'
				Time.deltaText c.time
				Dom.text " • "
			Dom.text Comments.getUserEventText c
		if aboutId = c.a
			Dom.onTap !-> App.showMemberInfo aboutId


renderPost = (post) !->
	Ui.item !->
		Dom.style Box: 'top'

		url = post.get('url')
		userId = post.get 'memberId'

		# avatar of the user who posted this
		Ui.avatar App.userAvatar(userId),
			style: margin: '8px 12px 0 0'
			onTap: !-> App.showMemberInfo(userId)

		# main box showing content of the post
		Dom.div !->
			Dom.style Flex: 1

			# header with name, time, likes, comments and unreadbubble
			Dom.div !->
				Dom.style Box: 'bottom', Flex: 1, margin: '4px 0'

				Dom.div !->
					Dom.style whiteSpace: 'nowrap'
					Dom.span !->
						Dom.style color: (if Event.isNew(post.get('time')) then '#5b0' else 'inherit'), fontWeight: 'bold'
						Dom.text App.userName(post.get('memberId'))
					Dom.span !->
						Dom.style color: '#aaa', fontSize: '85%'
						Dom.text " • "
						Time.deltaText post.get('time'), 'short'
						Dom.text " • "
						Comments.renderLike
							store: ['likes', post.key()+'-post']
							userId: post.get('by')
							aboutWhat: tr("post")
							minimal: true

				Dom.div !->
					Dom.style Flex: 1, textAlign: 'right', paddingRight: '2px'

					likeCnt = 0
					likeCnt++ for k,v of Db.shared.get('likes', post.key()+'-post') when +k and v>0
					if likeCnt
						Dom.span !->
							Dom.style display: 'inline-block', fontSize: '85%', color: '#aaa'
							Icon.render
								data: 'thumbup'
								size: 16
								color: '#aaa'
								style: {verticalAlign: 'bottom', margin: '0 2px 1px 8px'}
							Dom.span likeCnt

					commentCnt = Db.shared.get('comments', post.key(), 'max')
					if commentCnt
						Dom.span !->
							Dom.style display: 'inline-block', fontSize: '85%', color: '#aaa'
							Icon.render
								data: 'comments'
								size: 16
								color: '#aaa'
								style: {verticalAlign: 'bottom', margin: '1px 2px 0 8px'}
							Dom.span commentCnt
					else
						Dom.span !->
							Dom.style fontSize: '85%', padding: '5px 6px', margin: '-3px', borderRadius: '2px', color: App.colors().highlight
							Dom.text tr("Reply")
							Dom.onTap !-> Page.nav [post.key()]

					# unread bubble
					Event.renderBubble [post.key()], style: margin: '-3px -6px -3px 8px'

			# post user text
			Dom.div !->
				Dom.cls 'user-text'
				Dom.userText post.get('text')||''

			# url or image attachment
			if url
				renderAttachedUrl post
			else if post.get 'image'
				key = post.get 'image'
				bgUrl = Photo.url key, 800
				renderAttachedPhoto bgUrl

		Dom.onTap !->
			Page.nav post.key()



renderAttachedPhoto = (bgUrl, onTap) !->
	vpWidth = Page.width()
	vpHeight = Page.height()
	width = vpWidth
	if width * (1/2) > vpHeight * (1/2.5)
		height = 1/3 * vpHeight
		width = (2/1) * height

	Dom.div !->
		Dom.style maxWidth: width+'px'
		Dom.div !->
			Dom.style
				borderRadius: '2px'
				margin: if onTap then '0 0 8px 0' else '12px 0 8px 0'
				width: '100%'
				paddingBottom: '50%'
				backgroundImage: "url(#{bgUrl})"
				backgroundSize: 'cover'
				backgroundPosition: '50% 50%'
			if onTap
				Dom.onTap onTap



renderAttachedUrl = (post, isDraft) !->
	Dom.div !->
		url = post.get 'url'
		Dom.cls 'link-box'
		Dom.style
			Box: true
			backgroundColor: '#eee'
			border: '1px solid #ddd'
			borderBottom: '2px solid #ddd'
			padding: '6px'
			borderRadius: '2px'
			margin: if isDraft then '0 8px 8px 8px' else '12px 0 8px 0'
		if imgUrl = post.get('image')
			if imgUrl.indexOf('/') < 0
				imgUrl = Photo.url imgUrl, 200
			Dom.div !->
				Dom.style
					borderRadius: '2px 0 0 2px'
					width: '50px'
					height: '50px'
					margin: '2px 7px 0 2px'
					backgroundImage: "url(#{imgUrl})"
					backgroundSize: 'cover'
					backgroundPosition: '50% 50%'

		Dom.div !->
			Dom.style Flex: 1, fontSize: '80%'
			if isDraft
				Icon.render
					style:
						padding: '8px'
						margin: '-6px -6px 6px 6px'
						float: 'right'
					data: 'cancel'
					color: '#aaa'
					onTap: !->
						Server.sync 'draft', false

			Dom.div !->
				Dom.style textTransform: 'uppercase', color: '#888', fontWeight: 'bold'
				Dom.text post.get('title')
			Dom.div !->
				if descr = post.get('description')
					Dom.span !->
						Dom.text descr + ' '
				Dom.span !->
					Dom.style
						color: '#aaa'
						fontSize: '90%'
						whiteSpace: 'nowrap'
						textTransform: 'uppercase'
					Dom.text Util.getDomainFromUrl(url)

		Dom.onTap !->
			App.openUrl url

Dom.css
	'.link-box.tap':
		background: 'rgba(0, 0, 0, 0.1) !important'
	'.user-text A':
		color: '#aaa'
