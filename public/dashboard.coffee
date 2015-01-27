# TODO
#
# - list connected clients
# - when was last update
#
explore = (url, cb) ->
  return if ! url
  $.get url,  (x) ->
    result = "<h3>#{url}</h3>"
    type = url.split("/")[1]
    if type in ["teachers", "groups", "activities", "locations", "agents", "events"]
      result += "<ul>#{
        (for elem in x
          "<li><a href=\"##{if type == "activities" then "activity" else type.slice(0, -1)}/#{elem}\">#{elem}</a></li>"
        ).join("")
      }</ul>"
    else
      result += "<pre>#{JSON.stringify x, null, 2}</pre>"
    ($ "#apiResult").html result
    if type in ["teacher", "group", "location", "agent"]
      $.get "/now" + url,  (x) ->
        result += "<h3>/now#{url}</h3>"
        result += "<pre>#{JSON.stringify x, null, 2}</pre>"
        ($ "#apiResult").html result


client = new Faye.Client "/faye"

subscription = client.subscribe "/events", (msg) ->
  ($ "#events").prepend "<div>#{(new Date).toLocaleString()} <strong>/events</strong>:<br/><small>#{JSON.stringify msg}</small></div>"
subscription = client.subscribe "/arrival", (msg) ->
  ($ "#events").prepend "<div>#{(new Date).toLocaleString()} <strong>/arrival</strong>:<br/><small>#{JSON.stringify msg}</small></div>"
console.log subscription

update = ->
  explore location.hash.replace "#", "/"
  console.log "hashchange", location.hash
  $.get "/status", (status) ->
    ($ "#status").html "
      Updated #{Date()}
      <pre>#{JSON.stringify status, null, 2}</pre>
      (connection count includes the api-server itself, and this dashboard)"

($ window).on "hashchange", update
($ "#updateButton").on "click", update
$ -> setTimeout update, 1000
