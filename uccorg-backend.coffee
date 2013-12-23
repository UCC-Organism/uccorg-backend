# {{{1 Info
#
# This is actually code for two different servers:
#
# 1. ssmldata-server, which is responsible for getting the data from ucc/webuntis/calendar/..., anonymising them, and sending them onwards
# 2. macmini-server, which gets the anonymised data from the ssmldata-server, makes them available via an api, and emits events
#
# In addition to this, there is some shared code, and testing.
#
# {{{2 Done
#
# - getting data from webuntis
# - got macmini onto UCCs serverpark
# - live events via faye
# - get data via api
# - got access to provisioned ssmldata-server
# - dummy data-set for automatic test
# - automatic test on macmini with fast time for development
# - deprecated webuntis-based webservice for development
#
# {{{2 In progress
#
# - send data from ssmldata-server to macmini
# - anonymise/cleanup data from ucc/webuntis
# - get data from sqlserver
# - get data from remote-calendar
#
# {{{2 To do
#
# - make servers production-ready
# - test daylight saving handling
# - dashboard / administrative interface
# - train schedule
#
# {{{1 Common stuff
# {{{2 Dependencies

fs = require "fs"
express = require "express"
http = require "http"
faye = require "faye"
async = require "async"
mssql = require "mssql"

# {{{2 Configuration
#

testing = process.argv[2] == "test"
ssmldata = process.argv[2] == "ssmldata"
#apihost = "uccorg.solsort.com"
apihost = "10.251.26.11"

# Filename of data dump
filename = "data.json"
filename = "sample-data.json" if testing

# Ical url 
icalUrl = "http://www.google.com/calendar/ical/solsort.dk_74uhjebvm79isucb9j9n4eba6o%40group.calendar.google.com/public/basic.ics"

# Port to listen to
port = 8080

# configuration for access to webuntis/sql, must be a jsonfile with content a la:
#
#     {
#       "webuntis": "...apikey...",
#       "mssql": {
#         "server": "...",
#         "database": "...",
#         "user": "...",
#         "password": "..."
#       }
#     }
try
  config = JSON.parse fs.readFileSync "config.json", "utf8"
catch e
  config = {}
  console.log e

console.log config

# {{{2 Utility functions
getISODate = -> (new Date).toISOString()
sleep = (t, fn) -> setTimeout fn, t
sendUpdate = (host, data, callback) ->
  opts =
    hostname: host
    port: port
    path: "/update"
    method: "post"
    headers:
      "Content-Type": "application/json"


  req = http.request opts, callback
  req.end JSON.stringify data

#{{{1 data processing/extract running on the SSMLDATA-server
if ssmldata
  #{{{2 Calendar data
  #{{{2 SQL Server data source
  getSqlServerData = (done) ->
    entries = ["Hold", "Studerende", "Ansatte", "AnsatteHold", "StuderendeHold"]
    result = {}
    return done(result) if not config.mssql

    handleNext = ->
      return done(result) if entries.length == 0
      current = entries.pop()
      req = con.request()
      req.execute "Get#{current}CampusNord", (err, reqset) ->
        throw err if err
        result[current] = reqset
        handleNext()

    con = new mssql.Connection config.mssql, (err) ->
      throw err if err
      handleNext()
  
  #{{{2 Webuntis data source
  #
  # We do not yet know if we should use the webuntis api, or get a single data dump from ucc
  # If needed extract code from old-backend-code.js
  
  getWebUntisData = (callback) ->
    # DEBUG code, run it on cached data instead of loading all of the webuntis data
    try
      result = JSON.parse fs.readFileSync "#{__dirname}/webuntis.json"
      return callback?(result)
    catch e
      console.log e
      undefined
  
    do ->
      apikey = config.webuntis
      untisCall = 0
      #webuntis - function for calling the webuntis api
      webuntis = (name, cb) ->
        console.log "webuntis", name, ++untisCall
        url = "https://api.webuntis.dk/api/" + name + "?api_key=" + apikey
        (require 'request') url, (err, result, content) ->
          return cb err if err
          console.log url, content
          cb null, JSON.parse content
      #extract data, download data needed from webuntis
      extractData = (dataDone) ->
        result =
          locations: {}
          subjects: {}
          lessons: {}
          groups: {}
          teachers: {}
          departments: {}
        
        async.eachSeries (Object.keys result), ((datatype, cb) ->
          webuntis datatype, (err, data) ->
            cb err if err
            console.log err, data[0]["untis_id"]
            async.eachSeries data, ((obj, cb) ->
              id = obj.untis_id
              webuntis "#{datatype}/#{id}", (err, data) ->
                result[datatype][id] = data
                cb err
            ), (err) -> cb err
        ), (err) ->
          console.log result
          dataDone err, result
  
      extractData (err, data) ->
        throw err if err
        callback?(data)
        # DEBUG code, run it on cached data instead of loading all of the webuntis data
        fs.writeFile "webuntis.json", (JSON.stringify data, null, 4), -> undefined
  
  
  #{{{2 Transform data for the event/api-server
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
  #   - students
  # - teachers
  #   - id
  #   - gender
  #   - programme
  # - students
  #   - id
  #   - groups
  #   - gender
  # 
  processData = (data1, data2, callback) ->
    callback
      webuntis: data1
      sqlserver: data2
  
  #{{{2 execute
  getWebUntisData (data1) ->
    getSqlServerData (data2) ->
      processData data1, data2, (result) ->
        sendUpdate apihost, result, () ->
          console.log "submitted to api-server"

#{{{1 event/api-server
else
  #{{{2 Pushed to the server from UCC daily. 
  handleUCCData = (data, done) ->
    fs.writeFile "#{__dirname}/dump.json", JSON.stringify data
    console.log "handle data update from ucc-server", data
    #... update data-object based on UCC-data, include prune old data
    cacheData done
  
  data = JSON.parse fs.readFileSync filename
  cacheData = (done) ->
    fs.writeFile "#{__dirname}/data.json", JSON.stringify(data), done
  
  
  #{{{3 Data structures
  #
  #{{{4 Table with `events` (activity start/end)
  # 
  # activity start/stop - ordered by time, - used for emitting events
  events = []
  eventPos = 0
  updateEvents = ->
    now = getISODate()
    eventEmitter()
    events = []
    for _,activity of data.activities
      events.push "#{activity.start} start #{activity.id}" if activity.start > now
      events.push "#{activity.end} end #{activity.id}" if activity.end > now
    events.sort()
    eventPos = 0
  process.nextTick updateEvents
  
  
  
  # {{{2 Server
  app = express()
  server = app.listen port
  console.log "starting server on port: #{port}"
  #{{{3 REST server
  app.use express.bodyParser()
  app.use (req, res, next) ->
    # no caching, if server through cdn
    res.header "Cache-Control", "public, max-age=0"
    # CORS
    res.header "Access-Control-Allow-Origin", "*"
    # no need to tell the world what server software we are running, - security best practise
    res.removeHeader "X-Powered-By"
    next()
  
  defRest = (name, member) ->
    app.all "/#{name}/:id", (req, res) ->
      res.json data[member][req.params.id]
      res.end()
  
  endpoints =
    teacher: "teachers"
    activity: "activities"
    group: "groups"
    student: "students"
  
  defRest name, member for name, member of endpoints
  
  #{{{3 When getting a request to /update, write it to data.json
  # For example upload with: curl -X POST -H "Content-Type: application/json" -d @datafile.json http://localhost:7890/update
  app.all "/update", (req, res) ->
    handleUCCData req.body, -> res.end()
  
  #{{{3 Push server
  #{{{4 Setup
  bayeux = new faye.NodeAdapter
    mount: '/faye'
    timeout: 45
  
  bayeux.on "subscribe", (clientId, channel) ->
    console.log channel, typeof channel
  
  bayeux.attach server
  
  #{{{4 Events and event emitter
  eventEmitter = ->
    now = getISODate()
    while eventPos < events.length and events[eventPos] <= now
      event = events[eventPos].split(" ").slice -2
      event[1] = data.activities[event[1]] || event[1]
      bayeux.getClient().publish "/events", event
      ++eventPos
  setInterval eventEmitter, 100
  
  
  #{{{2 Test
  #
  if process.argv[2] == "test"
  
    testResult = ""
    testLog = (args...)->
      testResult += JSON.stringify([args...]) + "\n"
    testDone = ->
      fs.writeFileSync "test.out", testResult
      process.exit()
  
    app.use express.static "#{__dirname}/public"
  
  
    testStart = "2013-09-20T06:20:00"
    testEnd = "2013-09-20T18:20:00"
    #testEnd = "2013-09-21T06:20:00"
    # Factor by which the time will run by during the test
    testSpeed = 3000

  
    #{{{3 Mock getISODate, 
    #
    # Date corresponds to the test data set, and a clock that runs very fast
    startTime = Date.now()
    testTime = + (new Date testStart)
    getISODate = -> (new Date(testTime + (Date.now() - startTime) * testSpeed)).toISOString()
  
  
    #{{{3 run the test - current test client just emits "/events" back as "/test"
    bayeux.getClient().subscribe "/events", (message) ->
      testLog "event", message
      if message[0] == "end" and message[1].id == 10587
        testDone()
    setInterval (->
      if getISODate() >= testEnd
        testLog "date > testend"
        testDone()
    ), 100000 / testSpeed
    sendUpdate "localhost", data, -> undefined
