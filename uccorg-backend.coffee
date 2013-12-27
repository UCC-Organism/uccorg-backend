# {{{1 Info
#
# This is actually code for two different servers:
#
# 1. ssmldata-server, which is responsible for getting the data from ucc/webuntis/calendar/..., anonymising them, and sending them onwards
# 2. macmini-server, which gets the anonymised data from the ssmldata-server, makes them available via an api, and emits events
#
# In addition to this, there is some shared code, and testing.
#
# {{{2 Status/issues
#
# - cannot access macmini through port 8080, - temporary workaround through ssl.solsort.com, but needs to be fixed.
# - some teachers on webuntis missing from mssql (thus missing gender non-critical)
# - *mapning mellem de enkelte kurser og hold mangler, har kun information på årgangsniveau, og hvilke årgange der følger hvert kursus*
# - *Info følgende grupper mangler via mssql: fss12b, fss11A, fss11B, fsf10a, fss10, fss10b, fss12a, norF14.1, norF14.2, norF14.3, nore12.1, samt "SPL M5 - F13A og F13B"*
#
# {{{2 Done
# {{{3 Milestone 2 - running until Dec. 29
#
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
# - get data from remote-calendar
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

# {{{2 Load config file
#
# See sample file in `config.json-sample`, and `test.json`.
#

try
  configfile = process.argv[2]
  configfile = "config" if !configfile
  configfile += ".json" if configfile.slice(-5, 0) != ".json"
  config = JSON.parse fs.readFileSync configfile, "utf8"
catch e
  console.log e
  console.log "could not read configfile #{configfile}"
  process.exit 1

# {{{2 Utility functions
getISODate = -> (new Date).toISOString()
sleep = (t, fn) -> setTimeout fn, t
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

#{{{1 data processing/extract running on the SSMLDATA-server
if config.prepare
  #{{{2 Calendar data
  #{{{2 SQL Server data source
  getSqlServerData = (done) ->
    if config.prepare.mssqlDump
      try
        result = JSON.parse fs.readFileSync config.prepare.mssqlDump
        return done? result
      catch e
        console.log e

    entries = ["Hold", "Studerende", "Ansatte", "AnsatteHold", "StuderendeHold"]
    result = {}
    return done?(result) if not config.prepare.mssql

    handleNext = ->
      if entries.length == 0
        if config.prepare.mssqlDump
          fs.writeFileSync config.prepare.mssqlDump, (JSON.stringify data, null, 2)
        return done?(result)
      current = entries.pop()
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
        console.log e
  
    do ->
      apikey = config.prepare.webuntis
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
        if config.prepare.webuntisDump
          fs.writeFileSync config.prepare.webuntisDump, (JSON.stringify data, null, 2)
        callback?(data)
  
  
  #{{{2 Transform data for the event/api-server

  processData = (webuntis, sqlserver, callback) ->

    startTime = "2013-09-20"
    endTime = "2013-09-21"
  
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
  
  #{{{2 execute
  getWebUntisData (data1) ->
    getSqlServerData (data2) ->
      processData data1, data2, (result) ->
        sendUpdate result, () ->
          console.log "submitted to api-server"
          process.exit 0

#{{{1 event/api-server
else
  #{{{2 Pushed to the server from UCC daily. 
  handleUCCData = (data, done) ->
    console.log "handle data update from ucc-server", data
    #... update data-object based on UCC-data, include prune old data
    cacheData done
  
  data = JSON.parse fs.readFileSync config.apiserver.cachefile
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
  
    app.use express.static "#{__dirname}/public"
  
  
    testStart = config.test.startDate
    testEnd = config.test.endDate
    #testEnd = "2013-09-21T06:20:00"
    # Factor by which the time will run by during the test
    testSpeed = config.test.xTime

  
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
      if getISODate() >= testEnd
        testLog "testDone"
        testDone()
    ), 100000 / testSpeed
    #sendUpdate data, -> undefined
