
queryURL = (url, callback, selectors...) ->
	chrome.tabs.create { active: false, url }, (tab) ->
		chrome.tabs.executeScript tab.id, { file: "injector.js" }, ->
			port = chrome.tabs.connect tab.id
			port.postMessage selectors
			port.onMessage.addListener (msg) ->
				callback msg...
				chrome.tabs.remove tab.id


loadJSON = (url, callback) ->
	getAccessToken (token) ->
		xhr = new XMLHttpRequest
		xhr.open 'get', url.replace('@token', token), true
		xhr.onload = ->
			callback JSON.parse xhr.responseText
		xhr.send null

Array::remove = (e) -> @[t..t] = [] if (t = @indexOf(e)) > -1

shuffle = (list) ->
    i = list.length
    while --i
        j = Math.floor(Math.random() * (i+1))
        [list[i], list[j]] = [list[j], list[i]]
    list

accessToken = ''
getAccessToken = (callback) ->
	return callback(accessToken) if accessToken != ''
	queryURL 'https://developers.facebook.com/docs/reference/api/', ({href}) -> 
		accessToken = href.split('?')[1]
		callback accessToken
	, 'a[href*=friends]'


getFriends = (callback) ->
	loadJSON 'https://graph.facebook.com/me/friends?@token', ({data}) ->
		callback data

retrieveInfo = (uid, callback) ->
	return callback(JSON.parse(localStorage[uid]), true) if uid of localStorage and localStorage[uid].length > 100
	loadJSON "https://graph.facebook.com/#{uid}?@token", (table) ->
		console.log table.username, table
		queryURL "https://www.facebook.com/#{table.username}/info", (info) ->
			for [name, value] in info when name isnt ''
				table[name] = value
			localStorage[uid] = JSON.stringify(table)
			callback table
		, '@info'


queue = []
processing = []
finished = []

beginProcess = ->
	getFriends (friends) ->
		queue = shuffle friends
		loadNext = ->
			return if queue.length is 0
			friend = queue.shift()
			processing.push friend.id
			retrieveInfo friend.id, (table, cached) ->
				friend.info = table
				finished.push friend
				processing.remove friend.id
				console.log processing.length, finished.length, queue.length
				if cached
					loadNext()
				else
					setTimeout(loadNext, Math.random() * 5000)
		for i in [0..5]
			setTimeout(loadNext, Math.random() * 5000)


displayOutput = ->
	document.body.innerHTML = ''
	text = document.createElement 'textarea'
	text.value = JSON.stringify(finished, null, '\t')
	text.style.width = '100%'
	text.style.height = '100%'
	text.style.top = '0'
	text.style.left = '0'
	text.style.position = 'absolute'
	document.body.appendChild text

saveOutput = ->
	saveFile 'facebook.json', JSON.stringify(finished, null, '\t')

toBlob = (str) ->
	try
		return new Blob([str])  
	catch error
		bb = new WebKitBlobBuilder()
		bb.append(str)
		return bb.getBlob()
	

saveFile = (name, str) ->
	url = webkitURL.createObjectURL(toBlob(str))
	click = (node) ->
		event = document.createEvent("MouseEvents")
		event.initMouseEvent(
			"click", true, false, window, 0, 0, 0, 0, 0
			, false, false, false, false, 0, null
		)
		return node.dispatchEvent(event)

	link = document.createElement('a');
	link.download = name;
	link.href = url;
	link.target = "_blank";
	click(link);

__load = ->
	xhr = new XMLHttpRequest
	xhr.open 'get', '../sensitive.json', true
	xhr.onload = ->
		finished = JSON.parse xhr.responseText
		console.log "loaded #{finished.length} friends"
	xhr.send null

saveCSV = ->
	saveFile 'facebook.csv', toCSV()

toCSV = ->
	# ['Name', 'E-mail Address 1', 'E-mail Address 2', 'E-mail Address 3',
	# 'Phone 1', 'Phone 2',
	# 'Google Talk', 'MSN', 'Skype', 'Yahoo',
	# 'Website 1', 'Website 2', 'Website 3',
	# 'Website Facebook', 'Home Address', 'Birthday'
	# ];
	obj = {}
	set = (name, value) ->
		value = '"' + (value || '') + '"'
		if name of obj
			obj[name].push(value || '')
		else
			obj[name] = [value]

	setx = (name, type, value) ->
		set "#{name} - Type", type
		set "#{name} - Value", value

	setm = (name, service, value) ->
		set "#{name} - Type", "New"
		set "#{name} - Service", service
		set "#{name} - Value", value

	parsePhones = (str) ->
		number.split('\t')[0] for number in (str || '').split('\n')

	screenName = (str) ->
		services = {}
		for account in (str || '').split('\n')
			[all, id, type] = account.match(/(.*)\((.*)\)/) || []
			services[type] = id
		services
	for {info} in finished
		set "Name", info.name
		set "Given Name", info.first_name
		set "Family Name", info.last_name
		set "Gender", info.gender
		# set "Occupation", info.
		setx "E-mail 1", "Facebook", info.Email || "#{info.username}@facebook.com"
		phones = parsePhones(info['Mobile Phones']).concat(parsePhones(info['Other Phones']))
		setx 'Phone 1', "Mobile", phones[0]
		setx 'Phone 2', 'Home', phones[1]
		setx 'Phone 3', 'Other', phones[2]
		services = screenName info['Screen Names']
		setm 'IM 1', 'Google Talk', services['Google Talk']
		setm 'IM 2', 'MSN', services['Windows Live Messenger']
		setm 'IM 3', 'Skype', services['Skype']
		setm 'IM 4', 'AIM', services['AIM']
		setm 'IM 5', 'Yahoo', services['Yahoo! Messenger']
		sites = (info['Website'] || '').split('\n')
		setx 'Website 1', 'Facebook', info.link
		setx 'Website 2', '', sites[0]
		setx 'Website 3', '', sites[1]
		setx 'Website 4', '', sites[2]
		set 'Birthday', info.birthday
		set 'Home Address', info['Address']
		set "Notes", (info.bio || '').replace(/"/g, '')
	keys = Object.keys(obj)
	csv = [keys.join(',')]
	for i in [0...finished.length]
		csv.push (obj[key][i] for key in keys).join(',')
	csv.join('\n')
