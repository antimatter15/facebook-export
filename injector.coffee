chrome.extension.onConnect.addListener (port) ->
	port.onMessage.addListener (msg) ->
		response = for selector in msg
			document.querySelector(selector).innerText
		port.postMessage response