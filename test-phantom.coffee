#{{{1 Code for running test in client
page = require('webpage').create()
url = "http://localhost:7890"

page.open url, (status)->
  page.evaluate ->
    client = new Faye.Client("/faye")
    subscription = client.subscribe "/events", (message) ->
      client.publish "/test", message
