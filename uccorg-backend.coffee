# {{{1 Tasks
#
# {{{2 Status
#
# - deprecated webservice + extracted data from webuntis
# - dummy data-set for automatic test
# - implemented push to client via faye
# - configuration/setup of server for dmz
#
# {{{2 Next to do
#
# {{{2 Backlog
#
# - server actually on UCC DMZ, getting nightly data dumps
# - ucc-data processing
# - other data sources
#   - train schedule/data
#   - remote calendar
# - administrative interface
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

#{{{1 Data model
#{{{2 Getting data
#
# Pushed to the server from UCC daily.
# 
#{{{3 Getting data from webuntis-api 
#
# We do not yet know if we should use the webuntis api, or get a single data dump from ucc
# If needed extract code from old-backend-code.js

#{{{3 Core data 
#
# Cached data loaded at startup time. 
#
# The file in the repository contains sample data for test.
#
# For each kind of data there is a mapping from id to individual object
#
# - activities
#   - id
#   - start/end
#   - teachers - list
#   - locations - list
#   - subject
#   - groups
# - groups
#   - id
#   - group-name
#   - programme
#   - TODO: students
# - teachers
#   - id
#   - gender
#   - programme
# - students - not there yet
# 
#
data = JSON.parse fs.readFileSync filename

#{{{2 Data structures
#
#{{{3 Table with events (activity start/end)
# 
# This is a list of event start/stop, - ordered by time, - used for emitting 
events = []
for _,activity of data.activities
  events.push "#{activity.start} start #{activity.id}"
  events.push "#{activity.end} end #{activity.id}"
events.sort()
eventPos = 0

# {{{1 Server
app = express()
server = app.listen port
console.log "starting server on port: #{port}"
#{{{2 REST server
app.use express.bodyParser()
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

#{{{2 When getting a request to /update, write it to data.json
# For example upload with: curl -X POST -H "Content-Type: application/json" -d @datafile.json http://serverurl
app.all "/update", (req, res) ->
  console.log req.body
  fs.writeFile "#{__dirname}/data.json", JSON.stringify(req.body), ->
    res.end()

#{{{2 Push server
#{{{3 Setup
bayeux = new faye.NodeAdapter
  mount: '/faye'
  timeout: 45

bayeux.on "subscribe", (clientId, channel) ->
  console.log channel, typeof channel

bayeux.attach server

#{{{3 Events and event emitter
eventEmitter = ->
  while eventPos < events.length and events[eventPos] <= getISODate()
    event = events[eventPos].split(" ").slice -2
    event[1] = data.activities[event[1]] || event[1]
    bayeux.getClient().publish "/events", event
    ++eventPos
setInterval eventEmitter, 100


#{{{1 Test
#
if process.argv[2] == "test"

  app.use express.static "#{__dirname}/public"

  testOk = true

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

  #{{{2 start phantomjs
  require("child_process").exec "./node_modules/.bin/phantomjs test-phantom.coffee"

  #{{{2 run the test - current test client just emits "/events" back as "/test"
  bayeux.getClient().subscribe "/test", (message) ->
    if message[0] == "end" and message[1].id == 10587
      process.exit (if testOk then 0 else 1)
  setInterval (->
    process.exit 1 if getISODate() >= testEnd
  ), 100000 / testSpeed
