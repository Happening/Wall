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
Plugin = require 'plugin'
Server = require 'server'
Social = require 'social'
Time = require 'time'
Ui = require 'ui'
Util = require 'util'
{tr} = require 'i18n'


exports.render = !->
	if postId = Page.state.get(0)
		renderSinglePost postId, !!Page.state.get('focus')
	else
		renderWall()


renderSinglePost = (postId, startFocused = false) !->
	Page.setTitle tr("Post")
	post = Db.shared.ref(postId)
	Event.showStar post.get('title')
	if Plugin.userId() is post.get('memberId') or Plugin.userIsAdmin()
		Page.setActions
			icon: 'trash'
			action: !->
				Modal.confirm null, tr("Remove post?"), !->
					Server.sync 'remove', postId, !->
						Db.shared.remove(postId)
					Page.back()

	Dom.div !->
		Dom.style margin: '-16px -8px 0', padding: '8px 0', backgroundColor: '#f8f8f8', borderBottom: '2px solid #ccc'

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
					margin: '8px 8px 4px 8px'
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
							margin: '2px 8px 4px 2px'
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
					Plugin.openUrl url

		if text = post.get('text')
			Dom.div !->
				Dom.style padding: '8px 8px 0 8px'
				Dom.userText text


		expanded = Obs.create false
		byUserId = post.get('memberId')
		Dom.div !->
			Dom.style
				padding: '8px 8px 0 8px'
				fontSize: '70%'
				color: '#aaa'
			Dom.text tr("Posted by %1", Plugin.userName(byUserId))
			Dom.text " • "
			Time.deltaText post.get('time')

			Dom.text " • "
			expanded = Social.renderLike
				path: [postId]
				id: 'post'
				userId: byUserId
				aboutWhat: tr("post")

		Obs.observe !->
			if expanded.get()
				Dom.div !->
					Dom.style margin: '0 8px 0 8px'
					Social.renderLikeNames
						path: [postId]
						id: 'post'
						userId: byUserId

	Dom.div !->
		Dom.style margin: '0 -8px'
		Social.renderComments
			path: [postId]
			startFocused: startFocused

renderWall = !->
	Dom.style backgroundColor: '#f8f8f8'
	addingPost = Obs.create false

	Dom.div !->
		Dom.style Box: 'top', borderBottom: '1px solid #ebebeb', paddingBottom: '8px'

		Ui.avatar Plugin.userAvatar(),
			style: margin: '8px 0 0 0'
			onTap: !-> Plugin.userInfo()

		Dom.div !->
			Dom.style Flex: 1, border: '1px solid #e0e0e0', borderBottom: '2px solid #e0e0e0', borderRadius: '2px', margin: '4px 4px 8px 8px', backgroundColor: '#fff'
			addE = null
			unclaimedPhoto = false
			photoThumb = Obs.create false

			containsUrl = Obs.create false
			containsText = Obs.create false

			save = !->
				photoguid = false
				val = addE.value().trim()
				draft = Db.personal.get('draft')
				if draft and unclaimedPhoto
					unclaimedPhoto.discard() # draft takes precedence over photo
				else if unclaimedPhoto
					photoguid = unclaimedPhoto.claim()
				return if !val and !photoguid and !draft # we need something..

				newId = (0|Db.shared.get('maxId'))+1
				Event.subscribe [newId] # TODO: subscribe serverside
				addingPost.set true

				text = Form.smileyToEmoji val
				Server.sync 'add',
					text: text
					photoguid: photoguid
					onReady: -> addingPost.set false

				photoThumb.set null
				addE.value ''
				containsText.set false
				Form.blur()


			# post-something interface
			Dom.div !->
				unclaimedPhoto = Photo.unclaimed 'postPhoto'
				if unclaimedPhoto
					photoThumb.set unclaimedPhoto.thumb

				Dom.div !->
					Dom.style padding: '6px', Box: 'bottom', minHeight: '36px'

					addE = Form.text
						simple: true
						text: tr("What's happening?")
						onChange: (v) !->
							v = v?.trim()||''
							if v
								containsText.set v
								urls = Util.getUrlsFromText v
								containsUrl.set !!urls.length
							else
								containsText.set false
								containsUrl.set false
						inScope: !->
							Dom.style
								Flex: 1
								display: 'block'
								fontSize: '100%'
								paddingBottom: '2px'
								border: 'none'
								width: '100%'
						onContent: (content) !->
							content = content.trim()
							url = Util.getUrlsFromText(content)[0]

							# if it's one url in text, we'll only show an url preview
							if url==content
								Server.sync 'draft', url
							else
								addE.value content

					Obs.observe !->
						showPost = containsText.get() or photoThumb.get() or Db.personal.get('draft')
						# post button
						Ui.button !->
							Dom.style display: (if showPost then 'inline-block' else 'none'), margin: '3px 2px'
							Dom.text tr("Post")
						, save

						# camera icon
						Icon.render
							style:
								padding: '12px'
								margin: '-6px'
								display: (if showPost then 'none' else 'inline-block')
							data: 'camera'
							color: '#aaa'
							onTap: !->
								Photo.pick null, null, 'postPhoto'

					Obs.onClean !->
						if unclaimedPhoto
							unclaimedPhoto.discard()

				Obs.observe !->
					if pt = photoThumb.get()
						# show photo
						Dom.div !->
							Dom.style padding: '0 8px'
							renderAttachedPhoto pt, !->
								Modal.confirm tr("Remove photo?"), !->
									unclaimedPhoto.discard()
									photoThumb.set null
					else if Db.personal.get('draft')
						# show url snippet
						draft = Db.personal.ref('draft')
						renderAttachedUrl draft, true
					else
						# show snippet placeholder (tap to get preview)
						Dom.div !->
							Dom.cls 'link-box'
							draft = Db.personal.get('draft')
							Dom.style
								Box: 'middle center'
								display: if (draft is 0 or containsUrl.get()) and !photoThumb.get() then '' else 'none'
								height: '40px'
								fontSize: '80%'
								backgroundColor: '#eee'
								border: '1px solid #ddd'
								borderBottom: '2px solid #ddd'
								margin: '0 8px 8px 8px'
								borderRadius: '2px'
							if draft is 0
								Dom.style color: 'inherit', textTransform: 'none', fontWeight: 'normal'
								Ui.spinner 12, !-> Dom.style marginRight: '6px'
								Dom.text tr("Fetching..")
								Dom.onTap !->
									Modal.confirm null, tr("Stop fetching?"), !->
										Server.sync 'draft', false
							else
								Dom.style color: Plugin.colors().highlight, textTransform: 'uppercase', fontWeight: 'bold'
								Dom.text tr("Get link preview")
								Dom.onTap !->
									text = addE.value().trim()
									url = Util.getUrlsFromText(text)[0]
									Server.sync 'draft', url, !->
										Db.personal.set 'draft', 0 # in progress
									if url==text
										addE.value ''



	Dom.div !->
		# spinner when a new post is added
		Obs.observe !->
			maxId = 0|Db.shared.get 'maxId'
			if addingPost.get()
				Dom.div !->
					Dom.style Box: 'middle', padding: '8px 0', borderBottom: '1px solid #ebebeb'
					Ui.spinner 38
					Dom.div !->
						Dom.style paddingLeft: '8px', color: '#aaa', Flex: 1
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
						padding: '12px 0'
						Box: 'middle center'
						color: '#bbb'
					Dom.text tr("Nothing has been posted yet")


renderPost = (post) !->
	Dom.div !->
		Dom.style Box: 'top', padding: 0, borderBottom: '1px solid #ebebeb'

		url = post.get('url')
		userId = post.get 'memberId'

		# avatar of the user who posted this
		Ui.avatar Plugin.userAvatar(userId),
			style: margin: '8px 0 0 0'
			onTap: !-> Plugin.userInfo(userId)

		# main box showing content of the post
		Dom.div !->
			Dom.style padding: '4px 4px 8px 8px', Flex: 1

			# header with name, time, likes, comments and unreadbubble
			Dom.div !->
				Dom.style Box: 'bottom', Flex: 1 ,margin: '4px 0'

				Dom.div !->
					Dom.span !->
						Dom.style color: (if Event.isNew(post.get('time')) then '#5b0' else 'inherit'), fontWeight: 'bold'
						Dom.text Plugin.userName(post.get('memberId'))
					Dom.span !->
						Dom.style color: '#aaa', fontSize: '85%'
						Dom.text " • "
						Time.deltaText post.get('time'), 'short'
						Dom.text " • "
						Social.renderLike
							path: [post.key()]
							id: 'post'
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
							Dom.style fontSize: '85%', borderRadius: '2px', padding: '7px', margin: '-7px -4px -7px 3px', color: Plugin.colors().highlight
							Dom.text tr("Reply")
							Dom.onTap !-> Page.nav
								0: post.key()
								focus: true

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
	vpWidth = Dom.viewport.get 'width'
	vpHeight = Dom.viewport.get 'height'
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
			Plugin.openUrl url

Dom.css
	'.link-box.tap':
		background: 'rgba(0, 0, 0, 0.1) !important'
	'.user-text A':
		color: '#aaa'

