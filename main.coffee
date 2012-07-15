queryURL = (url, callback, selectors...) ->
	chrome.tabs.create { active: false }, (tab) ->
		chrome.tabs.executeScript tab.id, { file: "injector.js" }, ->
			port = chrome.tabs.connect tab.id
			port.postMessage selectors
			port.onMessage.addListener (msg) ->
				callback(msg)

