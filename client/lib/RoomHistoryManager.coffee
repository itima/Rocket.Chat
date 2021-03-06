@RoomHistoryManager = new class
	defaultLimit = 30

	histories = {}

	getRoom = (roomId) ->
		if not histories[roomId]?
			histories[roomId] =
				hasMore: ReactiveVar true
				isLoading: ReactiveVar false
				loaded: 0

		return histories[roomId]

	initRoom = (roomId, from=new Date) ->
		room = getRoom roomId

		room.from = from

	getMore = (roomId, limit=defaultLimit) ->
		room = getRoom roomId

		if room.hasMore.curValue isnt true or not room.from?
			return

		room.isLoading.set true

		$('.messages-box .wrapper').data('previous-height', $('.messages-box .wrapper').get(0)?.scrollHeight - $('.messages-box .wrapper').get(0)?.scrollTop)

		Meteor.call 'loadHistory', roomId, room.from, limit, room.loaded, (err, result) ->
			ChatMessageHistory.insert item for item in result

			room.isLoading.set false

			room.loaded += result.length

			if result.length < limit
				room.hasMore.set false

	hasMore = (roomId) ->
		room = getRoom roomId

		return room.hasMore.get()

	isLoading = (roomId) ->
		room = getRoom roomId

		return room.isLoading.get()


	initRoom: initRoom
	getMore: getMore
	hasMore: hasMore
	isLoading: isLoading
