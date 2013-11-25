# Code transfer in progress, and therefore currently defunct (code for development prototype is running in another environment and needs some refactoring before coming here).
#
# {{{1 Tasks
#
# {{{2 Status
#
# - deprecated webservice + extracted data from webuntis
# - dummy data-set for automatic test
#
# {{{2 Next to do
#
# - new server w/push functionality
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

#{{{2 start/bind server
server = app.listen port
bayeux.attach server




#{{{1 Test
#
if process.argv[2] == "test"

  testStart = "2013-09-20T06:20:00"
  testEnd = "2013-09-20T18:20:00"
  #testEnd = "2013-09-21T06:20:00"
  # Factor by which the time will run by during the test
  testSpeed = 10000

  #{{{2 Mock getISODate, 
  #
  # Date corresponds to the test data set, and a clock that runs very fast
  startTime = Date.now()
  testTime = + (new Date testStart)
  getISODate = -> (new Date(testTime + (Date.now() - startTime) * testSpeed)).toISOString()

  #{{{2 run the test
  setInterval (->
    #console.log getISODate()
    process.exit 0 if getISODate() >= testEnd
  ), 100000 / testSpeed
