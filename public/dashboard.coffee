# TODO
#
# - list connected clients
# - when was last update
#
explore = (url, cb) ->
  $.get url,  (x) ->
    result = "<h3>#{url}</h3>"
    type = url.split("/")[1]
    if type in ["teachers", "groups", "activities", "locations"]
      result += "<ul>#{
        (for elem in x
          "<li><a href=\"##{if type == "activities" then "activity" else type.slice(0, -1)}/#{elem}\">#{elem}</a></li>"
        ).join("")
      }</ul>"
    else
      result += "<pre>#{JSON.stringify x, null, 2}</pre>"
    ($ "#apiResult").html result


client = new Faye.Client "/faye"

subscription = client.subscribe "/events", (msg) ->
  ($ "#events").prepend "<div><strong>#{Date()}:</strong><br/><small>#{JSON.stringify msg}</small></div>"
console.log subscription

($ window).on "hashchange", ->
  explore location.hash.replace "#", "/"
  console.log "hashchange", location.hash
