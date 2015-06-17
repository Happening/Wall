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
		renderPost postId, !!Page.state.get('focus')
	else
		renderWall()


renderPost = (postId, startFocused = false) !->
	Page.setTitle tr("Post")
	post = Db.shared.ref(postId)
	Event.showStar post.get('title')
	if Plugin.userId() is post.get('by') or Plugin.userIsAdmin()
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
		imgUrl = false
		if key = post.get('imageThumb')
			imgUrl = Photo.url key, 400
		else if image = post.get('image')
			imgUrl = image

		if !url and key = post.get('photo')
			require('photoview').render
				key: key
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

				if imgUrl
					Dom.img !->
						Dom.style
							maxWidth: '120px'
							maxHeight: '200px'
							margin: '2px 8px 4px 2px'
						Dom.prop 'src', imgUrl

				Dom.div !->
					Dom.style Flex: 1, fontSize: '90%'
					Dom.h3 !->
						Dom.style marginTop: 0
						Dom.text post.get('title')

					Dom.text post.get('description')

					domain = url.match(/(^https?:\/\/)?([^\/]+)/)[2].split('.').slice(-2).join('.')
					Dom.div !->
						Dom.style
							marginTop: '6px'
							color: '#aaa'
							fontSize: '90%'
							whiteSpace: 'nowrap'
							textTransform: 'uppercase'
							fontWeight: 'normal'
						Dom.text domain

				Dom.onTap !->
					Plugin.openUrl url

		if text = post.get('text')
			Dom.div !->
				Dom.style padding: '8px 8px 0 8px'
				Dom.userText text


		expanded = Obs.create false
		byUserId = post.get('by')
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
	addingPost = Obs.create 0
	Ui.list !->
		addE = null
		unclaimedPhoto = false
		photoThumb = Obs.create false

		addingUrl = Obs.create false
		editingInput = Obs.create false

		save = !->
			photoguid = if unclaimedPhoto then unclaimedPhoto.claim() else false
			return if !(val = addE.value().trim()) and !photoguid

			newId = (0|Db.shared.get('maxId'))+1
			Event.subscribe [newId] # TODO: subscribe serverside
			addingPost.set newId

			if photoguid
				text = Form.smileyToEmoji val
				Server.sync 'add',
					text: text
					photoguid: photoguid
			else
				if !addingUrl.get()
					val = Form.smileyToEmoji val
				Server.sync 'add', val # val is only the text

			photoThumb.set null
			addE.value ""
			editingInput.set false
			Form.blur()


		# Top entry: adding a post
		Ui.item !->
			Dom.style Box: false, padding: 0

			unclaimedPhoto = Photo.unclaimed 'postPhoto'
			if unclaimedPhoto
				photoThumb.set unclaimedPhoto.thumb

			Dom.div !->
				Dom.style Box: 'top'

				if pt = photoThumb.get()
					Dom.div !->
						Dom.style
							width: '80px'
							height: '80px'
							margin: '0 8px 8px 0'
							backgroundImage: "url(#{pt})"
							backgroundSize: 'cover'
							backgroundPosition: '50% 50%'
						Dom.onTap !->
							Modal.confirm tr("Remove photo?"), !->
								unclaimedPhoto.discard()
								photoThumb.set null

				addE = Form.text
					simple: true
					name: 'post'
					text: tr("What's happening?")
					rows: 3
					onChange: (v) !->
						v = v?.trim()||''
						if v
							editingInput.set v
							isUrl = v.split(' ').length is 1 and (v.toLowerCase().indexOf('http') is 0 or v.toLowerCase().indexOf('www.') is 0)
							addingUrl.set !!isUrl
						else
							editingInput.set false
							addingUrl.set false
					inScope: !->
						Dom.style
							Flex: 1
							display: 'block'
							fontSize: '100%'
							border: 'none'
							width: '100%'
					onContent: (content) !->
						urls = Util.getUrlsFromText content
						addE.value (if urls.length is 1 then urls[0] else content)
							# if it's one url in text, we'll only share the url

				Obs.onClean !->
					if unclaimedPhoto
						unclaimedPhoto.discard()

			Dom.div !->
				Dom.style
					Box: 'middle'
					backgroundColor: '#f8f8f8'
					borderTop: '1px solid #ddd'
					margin: '0 -8px -8px -8px'
					padding: '4px'

				Dom.div !->
					Dom.style Flex: 1
					if !photoThumb.get()
						Icon.render
							style:
								padding: '8px'
							data: 'camera'
							color: '#aaa'
							onTap: !->
								Photo.pick null, null, 'postPhoto'

				Ui.button !->
					Dom.text (if addingUrl.get() and !photoThumb.get() then tr("Post URL") else tr("Post"))
				, save


	Dom.div !->
		Obs.observe !->
			maxId = 0|Db.shared.get 'maxId'
			if addingPost.get()>maxId
				Ui.item !->
					Dom.style padding: '8px 4px', color: '#aaa'
					Dom.div !->
						Dom.style
							Box: 'center middle'
							width: '50px'
							height: '50px'
							marginRight: '10px'
						Ui.spinner 24
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

			renderListPost post

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


renderListPost = (post) !->
	Dom.div !->
		Dom.style Box: 'top', borderBottom: '1px solid #e8e8e8'

		url = post.get('url')
		userId = post.get 'by'

		# posting user's avatar
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
						Dom.text Plugin.userName(post.get('by'))
					Dom.span !->
						Dom.style color: '#aaa', fontSize: '80%'
						Dom.text " • "
						Time.deltaText post.get('time'), 'short'

				Dom.div !->
					Dom.style Flex: 1, textAlign: 'right', paddingRight: '2px'

					if commentCnt = Db.shared.get('comments', post.key(), 'max')
						Dom.span !->
							Dom.style display: 'inline-block', fontSize: '85%', color: '#aaa'
							Icon.render
								data: 'comments'
								size: 16
								color: '#aaa'
								style: {verticalAlign: 'bottom', margin: '1px 2px 0 1px'}
							Dom.span commentCnt

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

					# unread bubble
					Event.renderBubble [post.key()], style: margin: '-3px -6px -3px 8px'

			# post user text
			Dom.div !->
				Dom.cls 'user-text'
				Dom.userText post.get('text')||''


			# url or image attachment
			if url
				Dom.div !->
					Dom.cls 'link-box'
					Dom.style
						Box: true
						backgroundColor: '#eee'
						border: '1px solid #ddd'
						borderBottom: '2px solid #ddd'
						padding: '6px'
						borderRadius: '2px'
						margin: '12px 0 8px 0'
					if key = post.get 'imageThumb'
						bgUrl = Photo.url key, 200
						Dom.div !->
							Dom.style
								borderRadius: '2px 0 0 2px'
								width: '50px'
								height: '50px'
								margin: '2px 7px 0 2px'
								backgroundImage: "url(#{bgUrl})"
								backgroundSize: 'cover'
								backgroundPosition: '50% 50%'

					Dom.div !->
						Dom.style Flex: 1, fontSize: '80%'
						Dom.div !->
							Dom.style textTransform: 'uppercase', color: '#888', fontWeight: 'bold'
							Dom.text post.get('title')
						Dom.div !->
							if descr = post.get('description')
								Dom.span !->
									Dom.text descr + ' '
							domain = url.match(/(^https?:\/\/)?([^\/]+)/)[2].split('.').slice(-2).join('.')
							Dom.span !->
								Dom.style
									color: '#aaa'
									fontSize: '90%'
									whiteSpace: 'nowrap'
									textTransform: 'uppercase'
								Dom.text domain
					Dom.onTap !->
						Plugin.openUrl url

			else if key = post.get 'photo'
				bgUrl = Photo.url key, 1000
				vpWidth = Dom.viewport.get 'width'
				vpHeight = Dom.viewport.get 'height'
				width = vpWidth-66
				if width * (1/2) > vpHeight * (1/2.5)
					height = 1/3 * vpHeight
					width = (2/1) * height
				else
					height = (1/2) * width

				Dom.div !->
					Dom.style
						borderRadius: '2px'
						margin: '12px 0 8px 0'
						width: Math.round(width)+'px'
						height: Math.round(height)+'px'
						backgroundImage: "url(#{bgUrl})"
						backgroundSize: 'cover'
						backgroundPosition: '50% 50%'

		Dom.onTap !->
			Page.nav post.key()

Dom.css
	'.link-box.tap':
		background: 'rgba(0, 0, 0, 0.1) !important'
	'.user-text A':
		color: '#aaa'
