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
# {{{1 Status
#
# {{{2 Data Issues
#
# - some teachers on webuntis missing from mssql (thus missing gender non-critical)
# - *mapning mellem de enkelte kurser og hold mangler, har kun information på årgangsniveau, og hvilke årgange der følger hvert kursus*
# - *Info følgende grupper mangler via mssql: fss12b, fss11A, fss11B, fsf10a, fss10, fss10b, fss12a, norF14.1, norF14.2, norF14.3, nore12.1, samt "SPL M5 - F13A og F13B"*
# - activity is not necessarily unique for group/location at a particular time, this slightly messes up current/next activity api, which just returns a singlura next/previous
#
# {{{2 Back Log - January-April 2015
#
#
# - (marcin? mapping between ucc-organism room id's and schedule room name)
# - update rest-test
# - location->agents at current time api
# - update location and agent state on events
# - use new events
#
# - √new data for testing (but disabled rest-test)
# - √agent+event uniform static data
# - √temporary proxy for frontend development
#
# {{{3 misc todo
#
# - location -> agents at current time
#   - events using new event api
#   - current state object, traverse new events live, and update state
# - integration/test with frontend
# - uniform agent scheduling / representation of agent-events
# - repeat with recent non-empty data, if empty data
# - delivered data: document expectations, check if workarounds are still needed, and more verbose reporting + erroring when not ok
# - ambient data
#   - `/timeofday` day cycle
#   - grants, su, etc.
# - structured/random events for agents: 
#   - agent types: researchers, kitchen staff, administrators, janitors, ..
#   - lunch, toilet-breaks, illness-leave, ..
#
# {{{3 uniform agent scheduling notes
# 
# New data schema:
# - agents: (teachers, or students member of groups)
#   - id
#   - kind: teacher | student | researcher | janitor | bus | train | ...
#   - ?gender: 0/1 (for teacher/student)
#   - ?groups (for students)
#     - id
#     - group (groupname/id)
#     - programme
#     - department
#     - name (groupname/id)
#   - ?programme:
#   - ?programmeDesc:
#   - ?age (for student)
#   - ?end (for student)
#   - ?name (for train/bus)
#   - ?origin (for train/bus)
# - now/agent: current, prev, next events for agent
# - events - from activities, train arrivals, etc.
#   - time
#   - kind: activity-start, activity-end, bus-arrival, train-arrival, 
#   - desc: activity-subject, etc.
#   - agents
#   - locations
#
# {{{2 Release Log
#
# {{{3 In between development 2014
#
# - dummy-hold when missing data
# - workaround for data where several groups has the same untis_did
# - create dummy data with "error:missing" when missing teacher, location or subject
# - student age
# - ignore bad ssl-certificates for webuntis - as they were/(are?) buggy
#
#
# {{{3 Milestone 3 - running until Jan 20. 2014
#
# - configure mac-mini autostart api-server
# - dashboard
# - get data from remote-calendar (train schedule, etc.)
# - fix timezone bug (test daylight saving handling)
# - do not tunnel data anymore, but send it directly to the macmini via port 8080 now that the firewall is opened.
# - update config on windows server, to send current days, and not one month in the future for test.
# - preparation-server: support dump to file for development purposes
# - dashboard: show events live as they happen
# - dashboard skeleton
# - added api for getting ids of all teachers/groups/locations/activities
#
# {{{3 Milestone 2 - running until Dec. 29 2013
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
# {{{3 Milestone 1 - running until Dec. 22 2013
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
# {{{1 Common stuff
# {{{2 About

exports.about =
  title: "UCC Organism Backend"
  author: "Rasmus Erik Voel Jensen"
  description: "Backend for the UCC-organism"
  owner: "UCC-Organism"
  name: "uccorg-backend"
  dependencies:
    solapp: "*"
  package:
    scripts:
      test: "rm -f test.out ; ./node_modules/coffee-script/bin/coffee uccorg-backend.coffee test ; diff test.out test.expected"
    dependencies:
      async: "0.2.9"
      "coffee-script": "1.6.3"
      express: "3.4.6"
      faye: "1.0.1"
      mssql: "0.4.1"
      request: "2.30.0"
      rrule: "2.0.0"

# {{{2 Dependencies

assert = require "assert"
fs = require "fs"
express = require "express"
http = require "http"
faye = require "faye"
async = require "async"
mssql = require "mssql"
request = require "request"

# {{{2 Utility functions
#
# Unique ID
uniqueId = do ->
  prevId = 0
  return -> prevId += 1
#
# Get the current time as yyyy-mm-ddThh:mm:ss (local timezone, - or mocked value if running test/dev)
#
getDateTime = -> (new Date(Date.now() - (new Date).getTimezoneOffset() * 60 * 1000)).toISOString().slice(0,-1)
#
# more comfortable syntax for set timeout: `sleep #seconds, -> ...`
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

if typeof isTesting == "boolean" && isTesting then do ->
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
dataPreparationServer = ->
  #{{{2 getCalendarData
  getCalendarData = (done) ->
    return done() if ! config?.prepare?.icalUrl
    
    if config.prepare.icalDump && fs.existsSync config.prepare.icalDump
      fs.readFile config.prepare.icalDump, "utf8", (err, content) ->
        throw err if err
        handleIcal content
    else
      request config.prepare.icalUrl, (err, result, content) ->
        fs.writeFile config.prepare.icalDump, content if config.prepare.icalDump
        if err
          console.log 'Error getting calendar data', config.prepare.icalUrl
          console.log err
          throw err
        handleIcal content

    handleIcal = (ical)->
      events = []
      !ical.replace /BEGIN:VEVENT([\s\S]*?)END:VEVENT/g, (_,e) ->
        props = e.split(/\r\n/).filter((x) -> x != "")
        event = {}
        for prop in props
          pos = prop.indexOf ":"
          pos = Math.min(pos, prop.indexOf ";") if prop.indexOf(";") != -1
          event[prop.slice(0,pos)] = prop.slice(pos+1)
        events.push event
      done events
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
        request {
            url: url
            rejectUnauthorized: false
          }, (err, result, content) ->
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
    # - calendarEvents: start, end, title, description
   
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
      studentObject =
        id: getStudentId obj.Studienummer
        gender: obj["Køn"]

      # calculate age from birthday
      today = new Date()
      birthday = obj["Fødselsdag"]
      if birthday

        birthyear = parseInt(birthday.slice(4,6), 10)
        # fix two-digit year problem,
        # ie. "12" could be both 1912 and 2012
        # assume 21st century if it is before today.
        birthyear += 100 if birthyear < (today.getYear() - 100)

        birthmonth = parseInt(birthday.slice(2,4), 10)
        birthdate = parseInt(birthday.slice(0,2), 10)

        age = today.getYear() - birthyear
        age -= 1 if new Date(today.getYear(), birthmonth - 1, birthdate) > today

        studentObject.age = age

      studentObject.end = obj.Forventet_slutdato if obj.Forventet_slutdato

      students[getStudentId obj.Studienummer] = studentObject

    groups = {}
    for obj in sqlserver.Hold[0]
      groups[obj.Holdnavn] =
        name: obj.Holdnavn
        department: obj.Afdeling
        start: obj.StartDato
        end: obj.SlutDato
        students: []
    for obj in sqlserver.StuderendeHold[0]
      if !groups[obj.Holdnavn]
        console.log 'Data error: Hold missing for StuderendeHold', obj
        # Dummy hold
        groups[obj.Holdnavn] =
          name: obj.Holdnavn
          department: '219405'
          start: '01-01-2014'
          end: '01-01-2060'
          students: []
      groups[obj.Holdnavn].students.push students[getStudentId obj.Studienummer]

    addGroup = (obj) ->
      return obj.untis_id if result.groups[obj.untis_id]
      # Buggy data: sometimes the same group has several untis_id, which is why we make a deep copy with json.parse/stringify
      grp = result.groups[obj.untis_id] = JSON.parse JSON.stringify groups[obj.alias] || {}
      grp.id = obj.untis_id
      grp.group = obj.name
      dept = webuntis.departments[obj.department]
      grp.programme = "#{dept?.name} - #{dept?.longname}"
      grp.id

    #{{{3 Add all groups groups and teachers 
    #
    # to make sure they are available if needed needed by calendar events

    do ->
      for _, teacher of webuntis.teachers
        addTeacher teacher

      for _, group of webuntis.groups
        addGroup group

    #{{{3 Handle Activities
    for _, activity of webuntis.lessons
      if startTime < activity.end && activity.start < endTime && activity.end
        result.activities[activity.untis_id] =
          id: activity.untis_id
          start: activity.start
          end: activity.end
          teachers: activity.teachers.map (untis_id) ->
            addTeacher webuntis.teachers[untis_id] || {untis_id: untis_id, name: "error:missing", departments: ["error:missing"] }
            untis_id
          locations: activity.locations.map (loc) -> webuntis.locations[loc]?.name || "error:missing"
          subject: activity.subjects.map((subj) -> webuntis.subjects[subj]?.longname || "error:missing").join(" ")
          groups: activity.groups.map (untis_id) ->
            addGroup webuntis.groups[untis_id] || {untis_id: untis_id}

    #{{{3 Handle input from iCal
    calId = 0
    result.calendarEvents = []
    handleEvent = (dtstart, event) ->
      console.log dtstart.toISOString(), JSON.stringify event
      activity =
        id: "cal#{++calId}"
        start: dtstart.toISOString()
        end: new Date(+dtstart + (+iCalDate(event.DTEND) - +iCalDate(event.DTSTART))).toISOString()
        locations: event.LOCATION.split(",").map (s) -> s.trim()
        teachers: []
        groups: []
        subject: event.SUMMARY
        description: event.DESCRIPTION
      activity.description = "#{activity.description}".replace /\\(.)/g, (_, c) -> ({n:"\n",r:"\r",t:"\t"}[c] || c)
      try
        for key, val of JSON.parse activity.description
          activity[key] = val
      catch e
        undefined
      result.activities[activity.id] = activity

    iCalDate = (t) ->
      d = t.replace /.*:/, ""
      # WARNING: here we assume that we are in Europe/Copenhagen-timezone
      d = new Date(+d.slice(0,4), +d.slice(4,6) - 1, + d.slice(6,8), +d.slice(9,11), +d.slice(11,13), +d.slice(13,15), 0)
      d = new Date(+d - d.getTimezoneOffset() * 60 * 1000)
      if (t.slice(0, 23) == "TZID=Europe/Copenhagen:") || (t.slice(0,11) == "VALUE=DATE:")
        d
      else if t.slice(-1) == "Z"
        d = new Date(+d - d.getTimezoneOffset() * 60 * 1000)
      else
        console.log "timezone bug in calendar data", t, d
      d

    if icaldata then for event in icaldata
      if event.RRULE
        RRule = (require "rrule").RRule
        opts = RRule.parseString event.RRULE
        opts.dtstart = iCalDate event.DTSTART
        rule = new RRule(opts)
        occurences = rule.between(new Date(startTime), new Date(endTime), true)
        for occurence in occurences
          handleEvent occurence, event
      else if startTime <= iCalDate(event.DTSTART).toISOString() < endTime
        handleEvent iCalDate(event.DTSTART), event

    #{{{3 done
    callback result
  
  #{{{2 execute
  getWebUntisData (data1) ->
    getSqlServerData (data2) ->
      getCalendarData (data3) ->
        processData data1, data2, data3, (result) ->
          if config.prepare.dest.dump
            fs.writeFile config.prepare.dest.dump, JSON.stringify(result, null, 2)
          sendUpdate result, (err, data) ->
            if err
              console.log 'sendUpdate error:', err
            console.log "submitted to api-server"
            process.exit 0

#{{{1 event/api-server
apiServer = ->
  data = undefined
  activitiesBy =
    group: {}
    location: {}
    teacher: {}
  eventsByAgent = {}
  events = []
  eventPos = 0
  state = {}
  #{{{2 Handle data
  #{{{3 Pushed to the server from UCC daily. 
  handleUCCData = (input, done) ->
    console.log "handling data update from ucc-server"
    fs.writeFile config.apiserver.cachefile, JSON.stringify(input), ->
      data = input
      enrichData()
      console.log "data replaced with new data from ucc-server"
      done()
  
  enrichData = -> #{{{3 

    activitiesBy =
      group: {}
      location: {}
      teacher: {}

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
    now = getDateTime()
    #eventEmitter()
    events = []
    eventPos = 0
    for _,activity of data.activities
      events.push "#{activity.start} start #{activity.id}" if activity.start > now
      events.push "#{activity.end} end #{activity.id}" if activity.end > now
    events.sort()

    #{{{4 add agent+events
    addAgentEvents()
  
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
    event: "events"
    agent: "agents"

  app.all "/status", (req, res) ->
    fs.stat config.apiserver.cachefile, (err, stat) ->

      res.json
        organismTime: getDateTime()
        lastDataUpdate: stat.mtime
        eventDetails:
          count: events.length
          pos: eventPos
          first: events[0]
          next: events[eventPos + 1]
          last: events[events.length - 1]
        connections: clientCount
      res.end()

  app.all "/now/:kind/:id", (req, res) ->
    res.json (data[req.params.kind + "Now"] || {})[req.params.id] || {}
    res.end()
    ###
    arr = activitiesBy[req.params.kind][req.params.id]
    result = { current: [] }
    if arr
      now = getDateTime()
      idx = binSearchFn arr, (activity) -> activity.end.localeCompare now
      result.prev = arr[idx-1]
      while arr[idx] && arr[idx].start < now
        result.current.push arr[idx]
        ++idx
      result.next = arr[idx]
    res.json result
    res.end()
    ###

  app.all "/arrivals", (req, res) ->
    arrivals (result) ->
      res.json result
      res.end()
  
  defRest name, member for name, member of endpoints
  
  #{{{3 When getting a request to /update, write it to data.json
  # For example upload with: curl -X POST -H "Content-Type: application/json" -d @datafile.json http://localhost:7890/update
  app.all "/update", (req, res) ->
    handleUCCData req.body, -> res.end()
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

  clientCount = 0

  bayeux.on "handshake", (clientId, channel) ->
    ++clientCount

  bayeux.on "disconnect", (clientId, channel) ->
    --clientCount
  
  bayeux.attach server
  
  ### {{{4 Events and event emitter
  eventEmitter = ->
    now = getDateTime()
    while eventPos < events.length and events[eventPos] <= now
      event = events[eventPos].split(" ").slice -2
      console.log Date(), events[eventPos]
      event[1] = data.activities[event[1]] || event[1]
      bayeux.getClient().publish "/events", event
      ++eventPos
  setInterval eventEmitter, 100
  ###

  #{{{4 New events and event emitter
  eventEmitter2 = ->
    now = getDateTime()
    while data.eventPos < data.eventList.length and data.eventList[data.eventPos] <= now
      event = data.events[data.eventList[data.eventPos]]
      console.log now, event.id, event.description, event.location
      #event[1] = data.activities[event[1]] || event[1]
      updateState event.id
      bayeux.getClient().publish "/events", event
      ++data.eventPos
  setInterval eventEmitter2, 100
  
  
  #{{{2 Train arrival data from rejseplanen
  #{{{3 Get data
  arrivalCache = []
  getArrivals = (d, cb) ->

    url = "http://xmlopen.rejseplanen.dk/bin/rest.exe/arrivalBoard" +
      "?id=8600683&date=#{d.getUTCDate()}.#{d.getUTCMonth() + 1}.#{String(d.getUTCFullYear()).slice(2)}&time=#{d.getUTCHours()}:#{d.getUTCMinutes()}"
    (require "request") url, (err, _, data) ->
      return cb(err) if err
      arrivalCache = []
      !data.replace /<Arrival name="(.*?)"[^>]*?type="(.*?)"[^>]*?time="(.*?)" date="(.*?)" [^>]*? origin="(.*)">/g, (_, name, type, time, date, origin) ->
        arrivalCache.push
          name: name
          type: type
          date: "20#{date.slice(6,8)}-#{date.slice(3,5)}-#{date.slice(0,2)}T#{time}:00"
          origin: origin
      cb null, arrivalCache

  arrivals = (cb) ->
    now = getDateTime()
    getArrivals (new Date(now)), (err, result) ->
      if err
        cb []
      else
        cb result

  #{{{3 Emit events
  lastArrivalEmit = undefined
  arrivalEmitter = ->
    now = getDateTime().slice(0,-6) + "00"

    doEmit = (arrs) ->
      if now == lastArrivalEmit
        return setTimeout arrivalEmitter, 30000
      lastArrivalEmit = now
      if !arrs.length
        return setTimeout arrivalEmitter, 60*60*1000
      for arrival in arrs
        if arrival.date == now
          bayeux.getClient().publish "/arrival", arrival
      setTimeout arrivalEmitter, 30000

    if !arrivalCache.length || now >= arrivalCache[arrivalCache.length - 1].date
      arrivals doEmit
    else
      doEmit arrivalCache

  arrivalEmitter()

  #{{{2 update global state (agents/events)
  updateState = (eventId) ->
    event = data.events[eventId]
    for agent in event.agents
      prevLocation = (data.agentNow[agent] || {}).location
      data.locationNow[prevLocation].agents = data.locationNow[prevLocation].agents.filter ( (a) -> a != agent) if prevLocation
      location = event.location
      if location
        data.locationNow[location] = data.locationNow[location] || {}
        data.locationNow[location].agents = data.locationNow[location].agents || []
        data.locationNow[location].agents.push agent
      data.agentNow[agent] = {}
      data.agentNow[agent].location = location if location
      data.agentNow[agent].activity = event.description if event.description

  #{{{2 agent/event data structure
  addAgentEvents = ->
    data.agents = {} #{{{3
    for _, teacher of data.teachers
      id = "teacher" + teacher.id
      data.agents[id] = agent = {}
      agent.kind = "teacher"
      agent.gender = teacher.gender
      agent.programme = teacher.programmeDesc
      agent.id = id

    data.agents.JamesBond =
      kind: "yes"
      gender: 1
      license: "kill -9"
      id: "007"
      description: "undercover testagent"

    for groupId, group of data.groups
      continue if not group.students
      for student in group.students
        id = "student" + student.id
        data.agents[id] = agent = data.agents[id] || {}
        if agent.programme && group.programme != agent.programme
          console.log "warning: student in several programmes, ignoring", id, group.programme, agent.programme
        agent.kind = "student"
        agent.programme = group.programme
        agent.groups ?= []
        agent.groups.push groupId
        agent.age = student.age
        agent.gender = student.gender
        agent.end = student.end
        agent.id = id

    data.events = {} # {{{3
    addEvent = (agents, location, time, description) ->
      id = time + ' ' + uniqueId()
      data.events[id] =
        id: id
        location: location || undefined
        description: description
        time: time
        agents: agents

    for _, activity of data.activities
      agents = []
      for teacherId in activity.teachers
        agents.push "teacher" + teacherId
      for groupId in activity.groups
        for student in data.groups[groupId].students || []
          agents.push "student" + student.id
      # TODO handle several locations per event
      addEvent agents, activity.locations[0], activity.start, activity.subject
      addEvent agents, null,  (new Date(new Date(activity.end.slice(0,19)+'Z') - 1000)).toISOString().slice(0,19), undefined
    ###
    for id in events
      data.events[id] = event = {}
      [time, op, activityId] = id.split " "
      activity = data.activities[activityId]
      event.id = id

      if op == "start"
        event.locations = activity.locations
        event.description = activity.subject
        event.time = time
      else
        event.description = "end of activity"
        event.time = (new Date(new Date(time.slice(0,19)+'Z') - 1000)).toISOString().slice(0,19)
        event.locations = []

      event.agents = []
      for teacherId in activity.teachers
        event.agents.push "teacher" + teacherId
      for groupId in activity.groups
        for student in data.groups[groupId].students || []
          event.agents.push "student" + student.id
    ###

    data.eventPos = 0 #{{{3
    data.agentNow = {}
    data.locationNow = {}
    data.eventList = Object.keys data.events
    data.eventList.sort()

    while data.eventPos < data.eventList.length && data.eventList[data.eventPos] < getDateTime()
      updateState(data.eventList[data.eventPos])
      data.eventPos += 1

    ### eventsByAgent = {} #{{{3
    allEvents = (event for _, event of data.events)
    allEvents.sort((a,b) -> if a.time < b.time then -1 else 1)
    for event in allEvents
      for agent in event.agents
        eventsByAgent[agent] = [] if !eventsByAgent[agent]
        eventsByAgent[agent].push event
    ###

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
      console.log "restTest", getDateTime()

      url = "http://localhost:#{config.apiserver.port}/"
      restTestRequest = (id) -> (done) ->
        request url + id, (err, req, data) ->
          testLog id, JSON.parse data
          done()
      async.series [
        restTestRequest "now/location/Brikserum C.125"
        restTestRequest "now/group/49"
        restTestRequest "now/teacher/23"
        restTestRequest "now/location/C.284"
        restTestRequest "group/49"
        restTestRequest "teacher/23"
        restTestRequest "location/C.208"
        restTestRequest "activity/99009"
      ]
      undefined
  
    #{{{3 Mock getDateTime, 
    #
    # Date corresponds to the test data set, and a clock that runs very fast
    startTime = Date.now()
    testTime = + (new Date testStart)
    getDateTime = -> (new Date(testTime + (Date.now() - startTime) * testSpeed)).toISOString()
  
  
    #{{{3 run the test - current test client just emits "/events" back as "/test"
    bayeux.getClient().subscribe "/events", (message) ->
      testLog "event", message
    setInterval (->
      if config.test.restTestTime && getDateTime() >= config.test.restTestTime
        restTest()
      if getDateTime() >= testEnd
        testLog "testDone"
        testDone()
    ), 100000 / testSpeed
    #sendUpdate data, -> undefined
# {{{1 Main
#
# See sample file in `config.json-sample`, and `test.json`.
#
config = undefined
if require.main == module then do ->
  try
    configfile = process.argv[2]
    configfile = "config" if !configfile
    configfile += ".json" if configfile.slice(-5) != ".json"
    config = JSON.parse fs.readFileSync configfile, "utf8"
  catch e
    console.log "reading config #{configfile}:", e
    process.exit 1

  if config.prepare then dataPreparationServer() else apiServer()

