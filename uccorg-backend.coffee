#!/usr/bin/env coffee
# {{{1 Info
#
# The server is run with `coffee uccorg-backend.coffee configfile.json`, where `configfile.json` contains the actual configuration of the server. 
# Depending on the configuration, this runs as:
# 
# - production data preparation server(windows), which is responsible for getting the data from ucc/webuntis/calendar/..., anonymising them, and sending them onwards to the api server
# - production api server(debian on macmini), which gets the anonymised data from the data preparation server, makes them available via an api, and emits events using the Bayeux protocol
# - development server for backend, which uses real data dumps instead of talking with external services
# - automated test, which runs automatically using travis, uses sample data dumps, and mocks the time to run very fast.
# - development server for frontend, - which runs of sample data dump and mocks the time, - to be able to get events without having to wait for real-world activities 
#
#{{{2 Configuration
#
# All configuration options are listed in `config.json.sample`. Also see `test.json` for an actual configuration, the content of this configuration wille also be a good choice for a frontend development server, - just remove `"outfile"`, and reduce the time speed factor `"xTime"` - which tells how much faster the mocked clock should run.
#
#{{{2 API
#
# The api delivers JSON objects, and is available through http, with JSONP and CORS enabled. The endpoints are:
#
# - `/(teacher|group|location|activity)/$ID` returns info about the particular entity
# - `/now/(teacher|group|location)/$ID` returns an object with the next, current, and previous activity for the given entity
# - `/(teachers|groups|locations|activities)` returns list of ids
#
# Events are pushed on `/events` as they happens through faye (http://faye.jcoglan.com/), ie. `(new Faye.Client('http://localhost:8080/')).subscribe('/events', function(msg) { ... })`
#
#{{{2 Status/issues
#
# - cannot access macmini through port 8080, - temporary workaround through ssl.solsort.com, but needs to be fixed.
# - some teachers on webuntis missing from mssql (thus missing gender non-critical)
# - *mapning mellem de enkelte kurser og hold mangler, har kun information på årgangsniveau, og hvilke årgange der følger hvert kursus*
# - *Info følgende grupper mangler via mssql: fss12b, fss11A, fss11B, fsf10a, fss10, fss10b, fss12a, norF14.1, norF14.2, norF14.3, nore12.1, samt "SPL M5 - F13A og F13B"*
# - activity is not necessarily unique for group/location at a particular time, this slightly messes up current/next activity api, which just returns a singlura next/previous
#
# {{{2 Done
#
# {{{3 Milestone 3 - running until ..
#
# - preparation-server: support dump to file for development purposes
# - dashboard: show events live as they happen
# - dashboard skeleton
# - added api for getting ids of all teachers/groups/locations/activities
#
# {{{3 Milestone 2 - running until Dec. 29
#
# - the windows server configured to extract the data each night at 1'o'clock, and send them to the mac mini.
# - added api for getting current/next/prev activity given a location, teacher or group
# - update REST-api
# - moving configuration into config-file
# - generate datafile for apiserver from ucc/webuntis-data
# - anonymising students
# - temporarily forwarding data through ssl.solsort.com, as port 8080 from ssmldata to macmini doesn't seem to be open.
# - send data from ssmldata-server to macmini
#
# {{{3 Milestone 1 - running until Dec. 22
#
# - get data from sqlserver
# - getting data from webuntis
# - got macmini onto UCCs serverpark
# - live events via faye
# - get data via api
# - got access to provisioned ssmldata-server
# - dummy data-set for automatic test
# - automatic test on macmini with fast time for development
# - deprecated solsort.com running webuntis-based webservice for development
#
#
# {{{2 To Do
#
# - update config on windows server, to send current days, and not one month in the future for test.
# - dashboard / administrative interface
# - get data from remote-calendar
# - make macmini production-ready
# - test daylight saving handling
# - train schedule
#
# {{{1 Common stuff
# {{{2 Dependencies

assert = require "assert"
fs = require "fs"
express = require "express"
http = require "http"
faye = require "faye"
async = require "async"
mssql = require "mssql"
request = require "request"

# {{{2 Load config file
#
# See sample file in `config.json-sample`, and `test.json`.
#

try
  configfile = process.argv[2]
  configfile = "config" if !configfile
  configfile += ".json" if configfile.slice(-5) != ".json"
  config = JSON.parse fs.readFileSync configfile, "utf8"
catch e
  console.log "reading config #{configfile}:", e
  process.exit 1

# {{{2 Utility functions
getISODate = -> (new Date).toISOString()
sleep = (t, fn) -> setTimeout fn, t*1000
#{{{3 binarySearchFn
binSearchFn = (arr, fn) ->
  start = 0
  end = arr.length
  while start < end
    mid = start + end >> 1
    if fn(arr[mid]) < 0
      start = mid + 1
    else
      end = mid
  return start

if config.test then do ->
  arr = [0,1,2,3,4,5]
  assert.equal 2, binSearchFn arr, (a) -> a - 2
  assert.equal 3, binSearchFn arr, (a) -> a - 2.1


#{{{3 sendUpdate
sendUpdate = (data, callback) ->
  datastr = JSON.stringify data
  # escape unicode as ascii
  datastr = datastr.replace /[^\x00-\x7f]/g, (c) ->
    "\\u" + (0x10000 + c.charCodeAt(0)).toString(16).slice(1)
  opts =
    hostname: config.prepare.dest.host
    path: config.prepare.dest.path || "/uccorg-update"
    port: config.prepare.dest.port || undefined
    method: "post"
    headers:
      "Content-Type": "application/json"
      "Content-Length": datastr.length
  if !(config.prepare.dest.protocol in ["http", "https"])
    throw "config error: prepare.dest.protocol neither 'http' nor 'https'" 
  req = (require config.prepare.dest.protocol).request opts, callback
  console.log "sending data: #{datastr.length} bytes"
  req.write datastr
  req.end()

#{{{1 data preparation - processing/extract running on the SSMLDATA-server
if config.prepare
  #{{{2 Calendar data
  #{{{2 SQL Server data source
  getSqlServerData = (done) ->
    if config.prepare.mssqlDump
      try
        result = JSON.parse fs.readFileSync config.prepare.mssqlDump
        return done? result
      catch e
        console.log "Loading mssql dump:",  e

    entries = ["Hold", "Studerende", "Ansatte", "AnsatteHold", "StuderendeHold"]
    result = {}
    return done?(result) if not config.prepare.mssql

    handleNext = ->
      if entries.length == 0
        if config.prepare.mssqlDump
          fs.writeFileSync config.prepare.mssqlDump, (JSON.stringify result, null, 2)
        return done?(result)
      current = entries.pop()
      console.log "mssql", current
      req = con.request()
      req.execute "Get#{current}CampusNord", (err, reqset) ->
        throw err if err
        result[current] = reqset
        handleNext()

    con = new mssql.Connection config.prepare.mssql, (err) ->
      throw err if err
      handleNext()
  
  #{{{2 Webuntis data source
  #
  # We do not yet know if we should use the webuntis api, or get a single data dump from ucc
  # If needed extract code from old-backend-code.js
  
  getWebUntisData = (callback) ->
    if config.prepare.webuntisDump
      try
        result = JSON.parse fs.readFileSync config.prepare.webuntisDump
        return callback?(result)
      catch e
        console.log "Loading webuntis dump:", e
  
    do ->
      apikey = config.prepare.webuntis
      untisCall = 0
      #webuntis - function for calling the webuntis api
      webuntis = (name, cb) ->
        if ((++untisCall) % 100) == 0
          console.log "webuntis api call ##{untisCall}: #{name}"
        url = "https://api.webuntis.dk/api/" + name + "?api_key=" + apikey
        request url, (err, result, content) ->
          return cb err if err
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
          console.log "getting #{datatype} from webuntis"
          webuntis datatype, (err, data) ->
            cb err if err
            async.eachSeries data, ((obj, cb) ->
              id = obj.untis_id
              webuntis "#{datatype}/#{id}", (err, data) ->
                result[datatype][id] = data
                cb err
            ), (err) -> cb err
        ), (err) ->
          dataDone err, result
  
      extractData (err, data) ->
        throw err if err
        if config.prepare.webuntisDump
          fs.writeFileSync config.prepare.webuntisDump, (JSON.stringify data, null, 2)
        callback?(data)
  
  
  #{{{2 Transform data for the event/api-server

  processData = (webuntis, sqlserver, icaldata, callback) ->

    startTime = config.prepare.startDate || 0
    if typeof startTime == "number"
      startTime = (new Date(+(new Date()) + startTime * 24*60*60*1000)).toISOString()
    else
      startTime = (new Date(startTime)).toISOString()
    endTime = (new Date(+(new Date(startTime)) + (config.prepare.timespan || 1) * 24*60*60*1000)).toISOString()
    console.log "Extracting data from #{startTime} to #{endTime}"
  
    # The file in the repository contains sample data for test.
    #
    # For each kind of data there is a mapping from id to individual object
    
    #{{{3 Output description
    #
    # - activities: id, start/end, teachers, locations, subject, groups
    # - groups: id, group-name, programme, students(id,gender)
    # - teachers: id, gender, programme
    # - locations: id, name, longname, capacity
   
    #{{{3 input description
    #
    # - webuntis
    #   - locations: untis_id, capacity, longname
    #   - subjects: untis_id, name, longname, alias
    #   - lessons: untis_id, start, end, subjects, teachers, groups, locations, course
    #   - groups: untis_id, name, alias, schoolyear, longname, department
    #   - teachers: untis_id, name, forename, longname, departments
    #   - departments: untis_id, name, longname
    # - sqlserver
    #   - StuderendeHold: Holdnavn (lessons.alias), Studienummer
    #   - AnsatteHold: Holdnavn (lessons.alias), Initialer (teacher.name)
    #   - Ansatte: Initialer, Afdeling, Køn
    #   - Studerende: Studienummer, Afdeling, Køn
    #   - Hold: Afdeling, Holdnavn, Beskrivelse, StartDato, SlutDato
  
    #{{{3 Initialisation
    result =
      locations: {}
      activities: {}
      groups: {}
      teachers: {}

    #{{{3 Locations
    for _, location of webuntis.locations
      result.locations[location.name] =
        id: location.name
        name: location.longname
        capacity: location.capacity

    #{{{3 addTeacher
    teachers = {}
    for obj in sqlserver.Ansatte[0]
      teachers[obj.Initialer] = obj

    addTeacher = (obj) ->
      id = obj.untis_id
      name = obj.name
      result.teachers[id] =
        id: id
        gender: teachers[name]?["Køn"]
        programme: teachers[name]?["Afdeling"]
        programmeDesc: do ->
          id = obj.departments[0]
          dept = webuntis.departments[id]
          "#{dept?.name} - #{dept?.longname}"

    #{{{3 addGroup (and students)
    students = {}
    studentId = 0
    studentIds = {}
    getStudentId = (studienummer) -> studentIds[studienummer]

    for obj in sqlserver.Studerende[0]
      studentIds[obj.Studienummer] = ++studentId
      students[getStudentId obj.Studienummer] =
        id: getStudentId obj.Studienummer
        gender: obj["Køn"]

    groups = {}
    for obj in sqlserver.Hold[0]
      groups[obj.Holdnavn] =
        name: obj.Holdnavn
        department: obj.Afdeling
        start: obj.StartDato
        end: obj.SlutDato
        students: []
    for obj in sqlserver.StuderendeHold[0]
      groups[obj.Holdnavn].students.push students[getStudentId obj.Studienummer]

    addGroup = (obj) ->
      return obj.untis_id if result.groups[obj.untis_id]
      grp = result.groups[obj.untis_id] = groups[obj.alias] || {}
      grp.id = obj.untis_id
      grp.group = obj.name
      dept = webuntis.departments[obj.department]
      grp.programme = "#{dept?.name} - #{dept?.longname}"
      grp.id

    #{{{3 Handle Activities
    for _, activity of webuntis.lessons
      if startTime < activity.end && activity.start < endTime && activity.end
        result.activities[activity.untis_id] =
          id: activity.untis_id
          start: activity.start
          end: activity.end
          teachers: activity.teachers.map (untis_id) ->
            addTeacher(webuntis.teachers[untis_id])
            untis_id
          locations: activity.locations.map (loc) -> webuntis.locations[loc].name
          subject: activity.subjects.map((subj) -> webuntis.subjects[subj].longname).join(" ")
          groups: activity.groups.map (untis_id) ->
            addGroup webuntis.groups[untis_id]
    #{{{3 done
    callback result
  
  #{{{2 getCalendarData
  getCalendarData = (done) ->
    done()
  #{{{2 execute
  getWebUntisData (data1) ->
    getSqlServerData (data2) ->
      getCalendarData (data3) ->
        processData data1, data2, data3, (result) ->
          if config.prepare.dest.dump
            fs.writeFile config.prepare.dest.dump, JSON.stringify(result, null, 2)
          sendUpdate result, (err, data) ->
            console.log "submitted to api-server"
            process.exit 0

#{{{1 event/api-server
else
  #{{{2
  #{{{3 Pushed to the server from UCC daily. 
  handleUCCData = (input, done) ->
    console.log "handling data update from ucc-server"
    fs.writeFile config.apiserver.cachefile, JSON.stringify(input), ->
      data = input
      enrichData()
      console.log "data replaced with new data from ucc-server"
      done()
  
  #{{{3 Data structures
  #
  activitiesBy =
    group: {}
    location: {}
    teacher: {}
  events = []
  eventPos = 0
  enrichData = ->

    #{{{4 Tables with activities ordered by group/location/teacher
    for _, activity of data.activities
      for kind, collection of activitiesBy
        for elem in activity["#{kind}s"]
          collection[elem] ?= []
          collection[elem].push activity
    for _, collection of activitiesBy
      for _, arr of collection
        arr.sort (a, b) -> a.end.localeCompare b.end

    #{{{4 Table with `events` (activity start/end)
    # 
    # activity start/stop - ordered by time, - used for emitting events
    now = getISODate()
    eventEmitter()
    events = []
    eventPos = 0
    for _,activity of data.activities
      events.push "#{activity.start} start #{activity.id}" if activity.start > now
      events.push "#{activity.end} end #{activity.id}" if activity.end > now
    events.sort()
  
  #{{{3 read cached data
  try
    data = JSON.parse fs.readFileSync config.apiserver.cachefile
    process.nextTick enrichData
  catch e
    console.log "reading cached data:", e
    data = {}
  
  
  # {{{2 Server
  app = express()
  app.use express.static "#{__dirname}/public"
  server = app.listen config.apiserver.port
  console.log "starting server on port: #{config.apiserver.port}"
  #{{{3 REST server
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
    app.all "/#{member}", (req, res) ->
      res.json Object.keys data[member]
      res.end()
  
  endpoints =
    teacher: "teachers"
    activity: "activities"
    group: "groups"
    location: "locations"

  app.all "/now/:kind/:id", (req, res) ->
    arr = activitiesBy[req.params.kind][req.params.id]
    return res.end if ! arr
    now = getISODate()
    idx = binSearchFn arr, (activity) -> activity.end.localeCompare now
    result = {
      current: []
    }
    result.prev = arr[idx-1]
    while arr[idx] && arr[idx].start < now
      result.current.push arr[idx]
      ++idx
    result.next = arr[idx]
    res.json result
    res.end()
  
  defRest name, member for name, member of endpoints
  
  #{{{3 When getting a request to /update, write it to data.json
  # For example upload with: curl -X POST -H "Content-Type: application/json" -d @datafile.json http://localhost:7890/update
  app.all "/update", (req, res) ->
    handleUCCData req.body, -> res.end()
  # TODO temporary url while rerouting through ssl.solsort.com
  app.use "/uccorg-update", (req, res, next) ->
    result = ""
    req.on "data", (data) ->
      result += data
    req.on "end", ->
      console.log "getting #{result.length} bytes"
      handleUCCData (JSON.parse result), -> res.end()
  
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
      console.log JSON.stringify event #DEBUG
      bayeux.getClient().publish "/events", event
      ++eventPos
  setInterval eventEmitter, 100
  
  
  #{{{2 Test
  #
  if config.test
    testResult = ""
    testLog = (args...)->
      testResult += JSON.stringify([args...]) + "\n"
    testDone = ->
      fs.writeFileSync config.test.outfile, testResult if config.test.outfile
      process.exit()
  
  
  
    testStart = config.test.startDate
    testEnd = config.test.endDate
    # Factor by which the time will run by during the test
    testSpeed = config.test.xTime

    #{{{3 Rest test
    restTest = ->
      restTest = -> undefined
      console.log "restTest", getISODate()

      url = "http://localhost:#{config.apiserver.port}/"
      restTestRequest = (id) -> (done) ->
        request url + id, (err, req, data) ->
          testLog id, JSON.parse data
          done()
      async.series [
        restTestRequest "now/location/Brikserum C.125"
        restTestRequest "now/group/39"
        restTestRequest "now/teacher/23"
        restTestRequest "now/location/C.224"
        restTestRequest "group/39"
        restTestRequest "teacher/23"
        restTestRequest "location/C.206"
        restTestRequest "activity/23730"
      ]
      undefined
  
    #{{{3 Mock getISODate, 
    #
    # Date corresponds to the test data set, and a clock that runs very fast
    startTime = Date.now()
    testTime = + (new Date testStart)
    getISODate = -> (new Date(testTime + (Date.now() - startTime) * testSpeed)).toISOString()
  
  
    #{{{3 run the test - current test client just emits "/events" back as "/test"
    bayeux.getClient().subscribe "/events", (message) ->
      testLog "event", message
    setInterval (->
      if config.test.restTestTime && getISODate() >= config.test.restTestTime
        restTest()
      if getISODate() >= testEnd
        testLog "testDone"
        testDone()
    ), 100000 / testSpeed
    #sendUpdate data, -> undefined
