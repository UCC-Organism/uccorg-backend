console.log "here"
client = new Faye.Client "/faye"
subscription = client.subscribe "/events", (msg) ->
  ($ "#events").prepend "<div><strong>#{Date()}:</strong><br/><small>#{JSON.stringify msg}</small></div>"
console.log subscription

$ ->
