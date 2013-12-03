# Code transfer in progress, and therefore currently defunct (code for development prototype is running in another environment and needs some refactoring before coming here).
#
# {{{1 Tasks
#
# {{{2 Status
#
# - deprecated webservice + extracted data from webuntis
# - dummy data-set for automatic test
# - implemented push to client via faye
#
# {{{2 Next to do
#
# - configuration of server for dmz
#
# {{{2 Backlog
#
# - ucc-data processing
# - other data sources
#   - train schedule/data
#   - remote calendar
# - administrative interface
# - server actually on UCC DMZ, getting nightly data dumps
#
# {{{1 Configuration
#
# Filename of data dump
filename = "/location/of/data/dump"
filename = "sample-data.json" if process.argv[2] == "test"

# Ical url 
icalUrl = "http://www.google.com/calendar/ical/solsort.dk_74uhjebvm79isucb9j9n4eba6o%40group.calendar.google.com/public/basic.ics"

# Port to listen to
port = 7890

# {{{1 Dependencies

fs = require "fs"
express = require "express"
http = require "http"
faye = require "faye"

# {{{1 General Utility
getISODate = -> (new Date).toISOString()
sleep = (t, fn) -> setTimeout fn, t


# {{{1 Load data

data = JSON.parse fs.readFileSync filename

for key, objs of data
  data[key] = {}
  for obj in objs
    data[key][obj.id] = obj

# {{{1 Actual server
#{{{2 REST server
app = express()
app.use (req, res, next) ->
  # no caching, if server through cdn
  res.header "Cache-Control", "public, max-age=0"
  # CORS
  res.header "Access-Control-Allow-Origin", "*"
  # no need to tell the world what server software we are running, - security best practise
  res.removeHeader "X-Powered-By"
  next()

#{{{3 /teacher route
app.all "/teacher/:id", (req, res) ->
  res.json data.teachers[req.params.id]
  res.end()

#{{{3 /activity route
app.all "/activity/:id", (req, res) ->
  res.json data.activities[req.params.id]
  res.end()

#{{{3 /group route
app.all "/group/:id", (req, res) ->
  res.json data.groups[req.params.id]
  res.end()

#{{{3 /route
app.all "/group/:id", (req, res) ->
  res.json data.groups[req.params.id]
  res.end()


#{{{2 Push server
bayeux = new faye.NodeAdapter
  mount: '/faye'
  timeout: 45

bayeux.on "subscribe", (clientId, channel) ->
  console.log channel, typeof channel

#{{{2 start/bind server
server = app.listen port
bayeux.attach server
console.log "starting server on port: #{port}"

#{{{1 Events and event emitter
events = []
for _,activity of data.activities
  events.push "#{activity.start} start #{activity.id}"
  events.push "#{activity.end} end #{activity.id}"
events.sort()
eventPos = 0

eventEmitter = ->
  while eventPos < events.length and events[eventPos] <= getISODate()
    bayeux.getClient().publish "/events", events[eventPos].split(" ").slice -2
    ++eventPos
setInterval eventEmitter, 100

#{{{1 Test
#
if process.argv[2] == "test"

  app.use express.static "#{__dirname}/public"

  testStart = "2013-09-20T06:20:00"
  testEnd = "2013-09-20T18:20:00"
  #testEnd = "2013-09-21T06:20:00"
  # Factor by which the time will run by during the test
  testSpeed = 300

  #{{{2 Mock getISODate, 
  #
  # Date corresponds to the test data set, and a clock that runs very fast
  startTime = Date.now()
  testTime = + (new Date testStart)
  getISODate = -> (new Date(testTime + (Date.now() - startTime) * testSpeed)).toISOString()

  #{{{2 run the test
  setInterval (->
    process.exit 0 if getISODate() >= testEnd
  ), 100000 / testSpeed
