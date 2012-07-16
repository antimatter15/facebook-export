chrome.extension.onConnect.addListener (port) ->
	port.onMessage.addListener (msg) ->
		response = for selector in msg
			if selector is "@info"
				for e in document.querySelectorAll('tr') when e.children.length is 2 and e.firstChild.tagName == 'TH'
					[e.firstChild.innerText.trim(), e.lastChild.innerText.trim()] 
			else
				el = document.querySelector(selector)
				{
					text: el.innerText,
					href: el.href,
					html: el.innerHTML
				}
		port.postMessage response