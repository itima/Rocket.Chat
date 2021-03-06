Meteor.startup ->
	UserPresence.awayTime = 300000
	UserPresence.start()

	window.lastMessageWindow = {}

	@defaultUserLanguage = -> 
		lng = window.navigator.userLanguage || window.navigator.language || 'en'

		# Fix browsers having all-lowercase language settings eg. pt-br, en-us
		re = /([a-z]{2}-)([a-z]{2})/
		if re.test lng
			lng = lng.replace re, (match, parts...) -> return parts[0] + parts[1].toUpperCase()
		return lng

	if localStorage.getItem("userLanguage")
		userLanguage = localStorage.getItem("userLanguage")
	else
		userLanguage = defaultUserLanguage()
	
	localStorage.setItem("userLanguage", userLanguage)
	userLanguage = userLanguage.split('-').shift()
	TAPi18n.setLanguage(userLanguage)
	moment.locale(userLanguage)

	Meteor.users.find({}, { fields: { name: 1, pictures: 1, status: 1, emails: 1, phone: 1, services: 1 } }).observe
		added: (user) ->
			Session.set('user_' + user._id + '_name', user.name)
			Session.set('user_' + user._id + '_status', user.status)
			Session.set('user_' + user._id + '_emails', user.emails)
			Session.set('user_' + user._id + '_phone', user.phone)

			UserAndRoom.insert({ type: 'u', uid: user._id, name: user.name})
		changed: (user) ->
			Session.set('user_' + user._id + '_name', user.name)
			Session.set('user_' + user._id + '_status', user.status)
			Session.set('user_' + user._id + '_emails', user.emails)
			Session.set('user_' + user._id + '_phone', user.phone)

			UserAndRoom.update({ uid: user._id }, { $set: { name: user.name } })
		removed: (user) ->
			Session.set('user_' + user._id + '_name', null)
			Session.set('user_' + user._id + '_status', null)
			Session.set('user_' + user._id + '_emails', null)
			Session.set('user_' + user._id + '_phone', null)

			UserAndRoom.remove({ uid: user._id })

	ChatRoom.find({ t: { $ne: 'd' } }, { fields: { t: 1, name: 1 } }).observe
		added: (room) ->
			roomData = { type: 'r', t: room.t, rid: room._id, name: room.name }

			UserAndRoom.insert(roomData)
		changed: (room) ->
			UserAndRoom.update({ rid: room._id }, { $set: { t: room.t, name: room.name } })
		removed: (room) ->
			UserAndRoom.remove({ rid: room._id })

	Tracker.autorun ->
		rooms = []
		ChatSubscription.find({ uid: Meteor.userId() }, { fields: { rid: 1 } }).forEach (sub) ->
			rooms.push sub.rid

		ChatRoom.find({ _id: $in: rooms }).observe
			added: (data) ->
				Session.set('roomData' + data._id, data)
			changed: (data) ->
				# @TODO alterar a sessão adiciona uma reatividade talvez desnecessária, avaliar melhor
				Session.set('roomData' + data._id, data)
			removed: (data) ->
				Session.set('roomData' + data._id, undefined)

	ChatSubscription.find({}, { fields: { ls: 1, ts: 1, rid: 1 } }).observe
		changed: (data) ->
			if (data.ls? and moment(data.ls).add(1, 'days').startOf('day') >= moment(data.ts).startOf('day'))
				KonchatNotification.removeRoomNotification(data.rid)
		removed: (data) ->
			KonchatNotification.removeRoomNotification(data.rid)

	ChatSubscription.find({}, { fields: { unread: 1 } }).observeChanges
		changed: (id, fields) ->
			if fields.unread and fields.unread > 0

				# @TODO testar se não é a sala aberta atual e fazer funcionar (não tenho mais os dados da msg)
				# KonchatNotification.showDesktop(roomData, self.data.uid + ': ' + self.data.msg)

				KonchatNotification.newMessage()
