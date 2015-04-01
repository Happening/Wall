Db = require 'db'
Dom = require 'dom'
Event = require 'event'
Form = require 'form'
Icon = require 'icon'
Modal = require 'modal'
Obs = require 'obs'
Page = require 'page'
Plugin = require 'plugin'
Server = require 'server'
Social = require 'social'
Time = require 'time'
Ui = require 'ui'
{tr} = require 'i18n'

exports.render = !->
	topicId = Page.state.get(0)
	if topicId
		renderTopic(topicId)
	else
		renderForum()


renderTopic = (topicId) !->
	Page.setTitle tr("Topic")
	topic = Db.shared.ref(topicId)
	Event.showStar topic.get('title')
	if Plugin.userId() is topic.get('by') or Plugin.userIsAdmin()
		Page.setActions
			icon: 'trash'
			action: !->
				Modal.confirm null, tr("Remove topic?"), !->
					Server.sync 'remove', topicId, !->
						Db.shared.remove(topicId)
					Page.back()
	Dom.div !->
		Dom.style margin: '-8px -8px 0', backgroundColor: '#f8f8f8', borderBottom: '2px solid #ccc'

		Dom.div !->
			Dom.style Box: 'top', Flex: 1, padding: '8px'

			if image = topic.get('image')
				Dom.img !->
					Dom.style
						maxWidth: '120px'
						maxHeight: '200px'
						margin: '2px 8px 4px 2px'
					Dom.prop 'src', topic.get('image')

			Dom.div !->
				Dom.style Flex: 1, fontSize: '90%'
				Dom.h3 !->
					Dom.style marginTop: 0
					Dom.text topic.get('title')
				Dom.text topic.get('description')

				if url = topic.get('url')
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

			if url = topic.get('url')
				Dom.onTap !->
					Plugin.openUrl url

		Dom.div !->
			Dom.style
				margin: '4px 8px'
				fontSize: '70%'
				color: '#aaa'
			Dom.text tr("Added by %1", Plugin.userName(topic.get('by')))
			Dom.text " • "
			Time.deltaText topic.get('time')

	Dom.div !->
		Dom.style margin: '0 -8px'
		Social.renderComments(topicId)

renderForum = !->
	Ui.list !->
		searchResult = Obs.create false
		searching = Obs.create false
		Server.send "searchSub", (result) !->
			searching.set false
			searchResult.set result

		# Top entry: adding an topic
		addE = null
		editingInput = Obs.create(false)
		Ui.item !->
			Dom.style padding: '8px 0 8px 6px'

			search = !->
				return if !addE.value().trim()
				searching.set true
				searchResult.set false
				Server.send 'search', addE.value().trim()

			save = !->
				return if !addE.value().trim()
				Server.sync 'add', addE.value().trim(), !->
					#id = Db.shared.incr 'maxId'
					#Db.shared.set(id, {time:0, by:Plugin.userId(), text: addE.value().trim()})
				addE.value ""
				editingInput.set(false)
				Form.blur()

			addE = Form.text
				simple: true
				name: 'topic'
				text: tr("+ Enter topic, search terms or url")
				onChange: (v) !->
					empty = !v?.trim()
					editingInput.set(!empty)
					if empty
						searchResult.set false
				onReturn: save
				inScope: !->
					Dom.style
						Flex: 1
						display: 'block'
						fontSize: '100%'
						border: 'none'
					Dom.prop 'rows', 1

			Obs.observe !->
				if editingInput.get()
					Ui.button !->
						Dom.style display: 'block', margin: '0 4px'
						Icon.render
							data: 'world'
							size: 16
							color: '#fff'
					, search
					if !searchResult.get() and !searching.get()
						Ui.button !->
							Dom.style margin: '0 4px'
							Dom.text tr("Add")
						, save
					else
						Ui.button !->
							Dom.style margin: '0 4px', paddingLeft: '1.2em', paddingRight: '1.2em'
							Dom.text tr("X")
						, !->
							searching.set false
							searchResult.set false
							addE.value ""
							editingInput.set(false)
							Form.blur()

		Obs.observe !->
			results = searchResult.get()
			log 'got some results', results
			if results
				for result in results then do (result) !->
					topic = Obs.create result
					Ui.item !->
						Dom.style padding: '8px 0 8px 8px'
						renderListTopic topic, true, !->
							Dom.div !->
								Dom.style color: '#aaa', fontSize: '75%', marginTop: '6px'
								desc = result.description || ''
								Dom.text desc.slice(0, 120) + (if desc.length>120 then '...' else '')
						#Ui.button tr("Add"), !->
						Dom.onTap !->
							Server.sync 'add', result
							searching.set false
							searchResult.set false
							addE.value ""
							editingInput.set(false)
							Form.blur()
			else if searching.get()
				Dom.div !->
					Dom.style
						Box: 'center'
						margin: '40px'
					Ui.spinner 24


	Ui.list !->
		count = 0
		empty = Obs.create(true)

		# List of all topics
		Db.shared.iterate (topic) !->
			empty.set(!++count)
			Obs.onClean !->
				empty.set(!--count)

			Ui.item !->
				Dom.style
					Box: 'middle'

				renderListTopic topic, false, !->
					Dom.div !->
						Dom.style
							Box: true
							margin: '4px 0'
							fontSize: '70%'
							color: '#aaa'
						Dom.div !->
							Dom.text tr("Added by %1", Plugin.userName(topic.get('by')))
							Dom.text " • "
							Time.deltaText topic.get('time'), 'short'
						if commentCnt = Db.shared.get('comments', topic.key(), 'max')
							Dom.div !->
								Dom.style Flex: 1, textAlign: 'right'
								Dom.b tr("%1 COMMENT|S", commentCnt)


				Dom.onTap !->
					Page.nav topic.key()


		, (topic) ->
			if +topic.key()
				newTime = if Event.isNew(topic.get('time')) then -topic.get('time') else 0
				unreadCount = -Event.getUnread([topic.key()])
				[newTime, unreadCount, -topic.key()]

		Obs.observe !->
			log 'empty now', empty.get()
			if empty.get()
				Ui.item !->
					Dom.style
						padding: '12px 6px'
						textAlign: 'center'
						color: '#bbb'
					Dom.text tr("No topics")


renderListTopic = (topic, searchResult, bottomContent) !->
	Dom.div !->
		Dom.style
			margin: '0 10px 0 0'
			width: '50px'
			height: '50px'
		if image = topic.get('image')
			Dom.style
				backgroundImage: "url(#{image})"
				backgroundSize: 'cover'
				backgroundPosition: '50% 50%'
		else
			Dom.style
				backgroundColor: '#eee'

	Dom.div !->
		Dom.style Flex: 1, color: (if Event.isNew(topic.get('time')) then '#5b0' else 'inherit')
		Dom.div !->
			Dom.style Box: true
			if !searchResult
				Dom.style minHeight: '30px'

			Dom.div !->
				Dom.style Flex: 1
				Dom.span !->
					Dom.style paddingRight: '6px'
					Dom.userText topic.get('title')
				if (url = topic.get('url')) and searchResult
					domain = url.match(/(^https?:\/\/)?([^\/]+)/)[2].split('.').slice(-2).join('.')
					Dom.span !->
						Dom.style
							color: '#aaa'
							textTransform: 'uppercase'
							fontSize: '70%'
							fontWeight: 'normal'
						Dom.text ' '+domain

			Dom.div !->
				Dom.style Box: 'middle'
				Event.renderBubble [topic.key()]


		bottomContent() if bottomContent
