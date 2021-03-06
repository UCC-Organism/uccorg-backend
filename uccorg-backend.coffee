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
# Client config pushed on deman to the Odroids / Screens is in client-config/default.js
#
#{{{2 API
#
# The api delivers JSON objects, and is available through http, with JSONP and CORS enabled. The endpoints are:
#
# - `/(agent|location|event)/$ID` returns info about the particular entity
# - `/now/(agent|location)/$ID` returns an object with status for the moment, NOTICE: this varies over time
# - `/current-state` returns active agents+activities
# - `/client-config` returns client config
#
# Old api:
# - `/(agents|locations|events)` returns list of ids. NOTICE: This is meant for development/exploration, and not expected to be used in production, as some events/agents will be created on the fly and may not be in the list yet
# - `/(teacher|group|activity)/$ID` returns info about the particular entity
# - `/(teachers|groups|activities)` returns list of ids
#
# Events are pushed on `/events` as they happens through faye (http://faye.jcoglan.com/), ie. `(new Faye.Client('http://localhost:8080/')).subscribe('/events', function(msg) { ... })`
#
# {{{3 uniform agent scheduling notes
# 
# Data schema:
# - agents: (teachers, or students member of groups)
#   - id
#   - kind: teacher | student | researcher | janitor | bus | train | ...
#   - ?gender: 0/1 (for teacher/student)
#   - ?groups of ids (for students)
#   - ?programme:
#   - ?age (for student)
#   - ?end (for student)
#   - ?name (for train/bus)
#   - ?origin (for train/bus)
# - events - from activities, train arrivals, etc.
#   - time
#   - TODO kind: activity-start, activity-end, bus-arrival, train-arrival, 
#   - agents
#   - ?description: activity-subject, etc.
#   - ?location
#   - TODO ?activity - link to ucc-activity for debugging
# - locations
#   - id
#   - name
#   - ?capacity
#   
# {{{2 Production server setup
#
# For the production system we choose to use a virtual linux server on the existing mac.
#
# Requirements for the server for the api-server:
#
# - boots automatically on power failure etc.
# - runs linux (other operating systems should also work, but I will not give any support on it)
# - when running a http service on port `8080`, it will be available as `http://10.251.26.11:8080` on the internal network
# - some way of rebooting it, and accessing it, remotely 
#
#
# The immediate options are either 
#
# - to set up a dedicated server on the UCC network
# - run a virtual server on the mac that will drive one of displays
#
# As there already is a virtual server configured on the mac, and under assumption that it is being kept running in production, we choose the latter.
#
# Server setup on linux, as user `uccorganism` with home `/home/uccorganism`. Assumes `git`/`nc` is installed via package manager, and  `node`/`npm`/`coffee` is installed in `/usr/local/bin`. Installation of the server is done with:
#
#     cd
#     git clone https://github.com/UCC-Organism/uccorg-backend.git
#     cd uccorg-backend
#     npm install
#     (crontab -l; echo @reboot /home/uccorganism/uccorg-backend/apiserver-start.sh) | sort | uniq | crontab -
#
# Then the api-server should then run after a reboot
#
#
# {{{1 Assumptions about external data sources
# 
# Data sources
# 
# - webuntis access via an API-key
#   - `/api/[locations|subjects|lessons|groups|teachers|departments]` returns json array of ids
#   - `/api/locations/$ID` returns json object with: untis_id, capacity, longname
#   - `/api/subjects/$ID` returns json object with: untis_id, name, longname, alias
#   - `/api/lessons/$ID` returns json object with: untis_id, start, end, subjects, teachers, groups, locations, course
#   - `/api/groups/$ID` returns json object with: untis_id, name, alias, schoolyear, longname, department
#     - The alias must match the "Holdnavn" in  the mssql database
#   - `/api/teachers/$ID` returns json object with: untis_id, name, forename, longname, departments
#     - The name must match "Initialer" in the mssql-database
#   - `/api/departments/$ID` returns json object with: untis_id, name, longname
# - ucc mssql database - accessible via stored procedures on the server: 
#   - GetStuderendeHoldCampusNord: Holdnavn (=groups.alias), Studienummer
#   - GetAnsatteHoldCampusNord: Holdnavn, Initialer
#   - GetAnsatteCampusNord: Initialer, Afdeling, Køn
#     - There must be an entry for each teacher from webuntis, with Initialer the same as teacher.name
#   - GetStuderendeCampusNord: Studienummer, Afdeling, Køn(0/1 -> agent.gender), Fødselsdag(DDMMYY -> agent.gender)
#   - GetHoldCampusNord: Afdeling, Holdnavn, Beskrivelse, StartDato, SlutDato
#     - There should be a hold for each Holdnavn for ansatte/studerende, and also one matching the every `groups.alias` from webuntis
# - google-calendar returns ical data parseable by rrule, with `SUMMARY` as the title of the event
# - rejseplanen-api `http://xmlopen.rejseplanen.dk/bin/rest.exe/arrivalBoard?id=8600683&date=...` returns schedule with arrivals in the form `<Arrival name="..." type="..." date="..." origin="...">`.
# {{{1 Status
# {{{2 Release Log
# {{{3 January-April 2015
#
# - Overordnet
#   - √homogen repræsentation af alle agent-typer, så eksempelvis forskere, undervisere, pedeller, køkkenersonale etc. repæsenteres på samme måde som studerende: tilknyttes grupper, bevæger sig mellem lokaler etc.
#   - √tilfældig opførsel af agenter, såsom pauser mellem undervisning, toiletbesøg, frokost etc.
#   - √globale tilstande såsom: dagscyklus, udbetaling af su og lignende
#   - √mulighed for at konfigurere tilfældig opførsel og events
#   - √løbende tilpasninger af backend efter ønsker fra A&K og frontendudviklingen frem til idiftsættelsen
#   - √håndtering af at systemet kører videre, selv hvis de eksterne datakilder fejler
#   - √afklaring af driftskonfiguration, - skal vi sætte en separat linux-server op, eller køre det parallelt på mac'en der også driver skærmen
#   - √not-needed (eventult konfiguration og opsætning af linux-server)
#   - √proaktiv løbende kommunikation med frontendudviklingen, for at sikre at backend matcher ønsker og forventninger i forhold til frontend
#   - √dokumentation af forventninger og krav til de eksterne datakilder
#
# - week 16
#   - intensity level 0-1+random for globale events
#   - forskudt tid (håndterer skævt ur på mac)
# - week 15
#   - case insensitive+trim calendar events
#   - documentation of used data sources in README
#   - to tilfældige farver fra colorrange+fagretning per agent.
# - week 14
#   - bugfix: neverending roaming
#   - decide-on/document production setup
#   - configurable shortening of classes to create breaks
#   - configurable configuration+calendar + static data for repeatable unit test, when system configuration changes
#   - configure events for administrators, janitors, kitchenstaff, and cafe/canteen
#   - fix pseudorandom - bug due to imul
#   - (frontend running on linux)
# - week 13
#   - random behaviour
#     - only random events on agents present
#     - random event emission - background and restore other events
#     - generate random events
#     - configurable random behaviour - lunch, toilet-break, illness-leave, pauser mellem undervisning etc.
#     - random-hash-evenly-distributed
#     - sample random configuration passed into the system
#     - prefix for events from schedule + isScheduled
#     - refactor next to be a function
#   - more url-friendly event-ids (with "_" instead of " ")
#   - event-id in /now
#   - have events also bring along a likely end time
#   - implement `/next` api endpoint
# - week 12
#   - add random roaming/away state for agents - needed for random events for agents at campus not doing anything in particular
#     - configurable in data/general-settings.json
#   - server fejlbesked hvis fejl i json
# - week 10
#   - global state - day cycle etc. via agent -  ie. `/agent/time-of-day` day cycle - grants, su, etc. configurable
#   - apiserver-script in version control
#   - support for stopping/rebooting the API-server remotely
#   - calendar data retrieval in API-server
#   - internal: preserve order of event-ids using hash function, to avoid test error due to changing order of events at same time.
# - week 9
#   - change structure of configuration files in data/ to make them easier to edit: data/behavior.js split up into locations.json, agents.json, calendar.js, og behaviour.js
#   - begun moving calendar-retrieval from data-processing to API-server
# - week 8
#   - repeat with old data, if we haven't gotten any updates from the data server recently
# - week 7
#   - handle several locations, by distributing agents into locations
#   - creation of events and agents from calendar
#   - configuration of calendar behaviour in data/behaviour.js
# - week 6
#   - include warnings in status, and propagate warnings from windows server to api-server
#   - bus/train events as uniform events instead of separate arrivals
#   - contact UCC about SSMLDATA-server is down
#   - some refactoring / dead code elimination
# - week 5
#   - webservice to get current state of agents and locations, replaces old `/now/`
#   - events emitted are from the new uniform api
#   - new test data (but rest-test disabled)
# - week 4
#   - draft new api: `/events`, `/agents`, `/locations`
#   - agent+event uniform static data
#   - temporary proxy for frontend development
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
# {{{2 Data Issues
#
# - some teachers on webuntis missing from mssql (thus missing gender non-critical)
# - *mapning mellem de enkelte kurser og hold mangler, har kun information på årgangsniveau, og hvilke årgange der følger hvert kursus*
# - *Info følgende grupper mangler via mssql: fss12b, fss11A, fss11B, fsf10a, fss10, fss10b, fss12a, norF14.1, norF14.2, norF14.3, nore12.1, samt "SPL M5 - F13A og F13B"*
# - activity is not necessarily unique for group/location at a particular time, this slightly messes up current/next activity api, which just returns a singlura next/previous
# - navngivning af lokaler er måske ikke konsistent
#
# {{{1 Main
#
# See sample file in `config.json-sample`, and `test.json`.
#
config = {}
if require.main == module then do ->
  try
    configfile = process.argv[2]
    configfile = "config" if !configfile
    configfile += ".json" if configfile.slice(-5) != ".json"
    config = JSON.parse (require "fs").readFileSync configfile, "utf8"
  catch e
    console.log "reading config #{configfile}:", e
    process.exit 1

  config.icalCacheFile ?= "cached-calendar.ical"
  config.configData ?= "data"

  process.nextTick ->
    if config.prepare then dataPreparationServer() else apiServer()

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
      test: "solapp build; rm -f test.out ; ./node_modules/coffee-script/bin/coffee uccorg-backend.coffee test ; diff test.out test.expected"
    dependencies:
      async: "0.2.9"
      "coffee-script": "1.6.3"
      express: "3.4.6"
      faye: "1.0.1"
      mssql: "0.4.1"
      request: "2.30.0"
      rrule: "2.0.0"
      "js-beautify": "1.5.4"
      "jshint": "2.6.0"

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
# {{{3 Math.imul
Math.imul ?= (a,b)->
  _ah = (a >>> 16) & 0xffff
  _al = a & 0xffff
  _bh = (b >>> 16) & 0xffff
  _bl = b & 0xffff
  (_al * _bl) + (((_ah * _bl + _al * _bh) << 16) >>> 0)|0
# {{{3 evenType
eventType = (eventObject) -> (eventObject.description || "undefined").split(" ")[0]
# {{{3 djb2-hash
hash = (str) ->
  result = 5381
  for i in [1..str.length-1]
    result = 33 * result + str.charCodeAt(i) &0x7fffffff
  result

# {{{3 uniqueHash
uniqueHashes = {}
uniqueHash = (s) ->
  h = hash(s)
  s2 = uniqueHashes[h]
  while s2 && s2 != s
    h += 1
    s2 = uniqueHashes[h]
  uniqueHashes[h] = s
  h

# {{{3 pseudoRandom utility functions
prand = (i) ->
  i ?= 0
  next = -> 
    i = Math.imul(1103515245, i) + 12345 & 0x7fffffff
  return {
    next: -> next(); (i & 0x3fffffff) / 0x40000000
    nextN: (n) -> next(); n * (i & 0x3fffffff) / 0x40000000 | 0
  }

# {{{3 pseudorandom
#
seed = prand(0)
pseudoRandom = -> seed.next()

# {{{3 uniqueId
uniqueId = do ->
  prevId = 0
  return -> prevId += 1

# {{{3 getDateTime
# Get the current time as yyyy-mm-ddThh:mm:ss (local timezone, - or mocked value if running test/dev)
#
timeoffset = 0
timecorrection = 0
getDateTime = -> (new Date(Date.now() + timecorrection - (new Date).getTimezoneOffset() * 60 * 1000 + timeoffset)).toISOString().slice(0,-1)

#{{{4 Correct time if very wrong
#
# Get time from http. Notice this is very imprecise, and the server setup should find the correct time via NTP. Unfortunately we seem to be behind a restrictive firewall, so if we can see that the local clock is drifting way wrong, we try to work around it.
#

if require.main == module then setImmediate ->
  (http.get "http://www.google.com", (o) ->
    requestTime = Date.now()
    remoteTime = new Date(o?.headers?.date)
    return warn "error getting date from www.google.com for clock sanity check" if String(remoteTime) == "Invalid Date"

    # This is very imprecise, requestTime occured at remoteTime + network latency
    # and we do not know the network latency (and http-request include handshake,
    # so it is also difficult to estimate).
    #
    # Anyhow remoteTime has precision in seconds, and network latency also
    # shouldn't be many seconds, so the offset should be precise within
    # a couple of seconds, - and we only apply it if we can observe a drift
    # of more than ½ minute :(
    timeOffset = (+remoteTime) - requestTime

    if Math.abs(timeOffset) > 30*1000
      warn "servertime is more the 30s off (#{timeOffset / 1000}), compared to google webservers + network latency, - local clock is probably very drifting, and thus we apply imprecise corrections"
      timecorrection = timeOffset
  ).on("error", (-> warn "error connecting to www.google.com for clock sanity check"))

# {{{3 sleep
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

#{{{2 status
status =
  bootTime: getDateTime()
  warnings: {}
warn = (msg) ->
  status.warnings[msg] = getDateTime()

#{{{2
generalSettings =
  try (require "./#{config.configData}/general-settings.json")
  catch e
    warn "Error in configuration in #{config.configData}/ " + e
    {}

generalSettings.minRoam ?= 15
generalSettings.maxRoam ?= 30


#{{{1 calendar
#{{{1 data preparation - processing/extract running on the SSMLDATA-server
dataPreparationServer = ->
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
        warn "error loading webunits dump"
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
            warn "webuntis request error #{name}" if err
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
        warn "extractData error" if err
        throw err if err
        if config.prepare.webuntisDump
          fs.writeFileSync config.prepare.webuntisDump, (JSON.stringify data, null, 2)
        callback?(data)
  
  
  #{{{2 Transform data for the event/api-server

  processData = (webuntis, sqlserver, callback) ->
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
      warn "missing teacher in mssql" if !teachers[name]
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
        warn 'Data error: Hold missing for StuderendeHold ' + obj.Holdnavn
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
      warn "Department missing: #{obj.department}" if !dept and obj.department
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

    #{{{3 done
    callback result
  
  #{{{2 execute
  getWebUntisData (data1) ->
    getSqlServerData (data2) ->
      processData data1, data2, (result) ->
        result.status = status
        if config.prepare.dest.dump
          fs.writeFile config.prepare.dest.dump, JSON.stringify(result, null, 2)
        sendUpdate result, (err, data) ->
          if err
            console.log 'sendUpdate error:', err
            warn 'sendUpdate error'
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

  #{{{2 calendarData
  calendarData = (done) ->
    icaldata = []
    
    request config.icalUrl || "http://no-ical-url-in-config/", (err, result, ical) ->
      if err
        warn 'Error getting calendar data ' + config.icalUrl
        ical = fs.readFileSync config.icalCacheFile, "utf8"
      else
        fs.writeFile config.icalCacheFile, ical

      return done() if !ical
  
      icaldata = []
      !ical.replace /BEGIN:VEVENT([\s\S]*?)END:VEVENT/g, (_,e) ->
        props = e.split(/\r\n/).filter((x) -> x != "")
        event = {}
        for prop in props
          pos = prop.indexOf ":"
          pos = Math.min(pos, prop.indexOf ";") if prop.indexOf(";") != -1
          event[prop.slice(0,pos)] = prop.slice(pos+1)
        icaldata.push event
  
      calId = 0
      result = []
      startTime = getDateTime()
      endTime = +(new Date(getDateTime())) + 7 * 24 * 60 * 60 * 1000
      result.calendarEvents = []
  
      handleEvent = (dtstart, event) ->
        activity =
          id: "cal#{++calId}"
          start: dtstart.toISOString()
          end: new Date(+dtstart + (+iCalDate(event.DTEND) - +iCalDate(event.DTSTART))).toISOString()
          type: String(event.SUMMARY).trim().toLowerCase()
        result.push activity
    
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
          warn "timezone bug in calendar data " + t + " " + d
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
  
      data.calendar = result if data?
      done result
    
  #{{{2 calculate time offset once per hour, rewind clock a week, if more than eight days since last data update
  updateTimeOffset = ->
    lastUpdate = new Date(status.lastDataUpdate)
    if 8 < (new Date() - lastUpdate + timeoffset) / 1000 / 60 / 60 / 24
      timeoffset -= 7 * 24 * 60 * 60 * 1000
      enrichData()
  setInterval updateTimeOffset, 1000 * 60
  #{{{2 Handle data
  #{{{3 Pushed to the server from UCC daily. 
  handleUCCData = (input, done) ->
    console.log "handling data update from ucc-server"
    fs.writeFile config.apiserver.cachefile, JSON.stringify(input), ->
      data = input
      if input.status and input.status.warnings
        for key, val of input.status.warnings
          status.warnings[key] = "data " + val
      calendarData enrichData
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

    #{{{4 add agent+events

  #{{{2 agent/event data structure
    assignAgentColors = (agent) ->
      seed = prand(hash(agent.id))

      randomComponent = (a, b) ->
         a = parseInt a, 16
         b = parseInt b, 16
         n = 0x100 + a + seed.next() * (b - a) | 0
         n.toString(16).slice(1)

      randomColor = (c1, c2) ->
        r = randomComponent(c1.slice(1,3),c2.slice(1,3))
        g = randomComponent(c1.slice(3,5),c2.slice(3,5))
        b = randomComponent(c1.slice(5,7),c2.slice(5,7))
        "#" + r + g + b

      colors = generalSettings.agentColors?[agent.programme]
      colors = generalSettings.agentColors?.default if !colors
      return if !(colors?.color1min and colors.color2min and colors.color1max and colors.color2max)

      agent.color1 = randomColor(colors.color1min, colors.color1max)
      agent.color2 = randomColor(colors.color2min, colors.color2max)

    data.agents = {} #{{{3
    for _, teacher of data.teachers
      id = "teacher" + teacher.id
      data.agents[id] = agent = {}
      agent.kind = "teacher"
      agent.gender = teacher.gender
      agent.programme = teacher.programmeDesc
      agent.id = id
      assignAgentColors(agent)

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
          warn "warning: student in several programmes, ignoring " + id  + " " + group.programme + " " + agent.programme
        agent.kind = "student"
        agent.programme = group.programme
        agent.groups ?= []
        agent.groups.push groupId
        agent.age = student.age
        agent.gender = student.gender
        agent.end = student.end
        agent.id = id
        assignAgentColors(agent)

    data.events = {} # {{{3

    addEvent = (agents, location, time, description, misc) ->
      if !agents || !agents.length
        return
      #id = time + '_' + hash("" + agents + location + description) + '_'+ uniqueId()
      id = time + '_' + uniqueHash("" + agents + location + description) + '_'+ ((description || "").split " ")[0]
      data.events[id] =
        id: id
        location: location || undefined
        description: description
        time: time
        agents: agents
      if misc
        for key, val of misc
          data.events[id][key] ?= val
      id

    addEvents = (agents, locations, time, description, misc) ->
      len = locations.length
      if len > 1
        # distribute agents into locations for event
        for i in [0..len-1] by 1
          addEvent (agents[j] for j in [i..agents.length-1] by len),
            locations[i], time, description, misc
      else
        addEvent agents, locations[0], time, description, misc


    seed = prand(0)
    for _, activity of data.activities
      agents = []
      for teacherId in activity.teachers
        agents.push "teacher" + teacherId
      for groupId in activity.groups
        for student in data.groups[groupId].students || []
          agents.push "student" + student.id

      addEvents agents, activity.locations, activity.start, "scheduled " + activity.subject, { likelyEndTime: activity.end}
      minBreak = config.minBreak || 1 / 59
      maxBreak = config.maxBreak || 1 / 59
      breakRandom = prand(hash("" + activity.start + activity.locations + activity.agents))
      breakTime = 1000*60*(minBreak+breakRandom.next() * (maxBreak - minBreak))
      endTime = (new Date(new Date(activity.end.slice(0,19)+'Z') - breakTime)).toISOString().slice(0,19)
      addEvent agents, undefined, endTime, "roaming", {autoLeave: leaveTime(endTime + agents)}
      #for agent in agents
      #  addEvent [agent], undefined, (new Date(new Date(activity.end.slice(0,19)+'Z') - (- (generalSettings.minRoam + (generalSettings.maxRoam - generalSettings.minRoam) * pseudoRandom())|0) * 60 * 1000)).toISOString().slice(0,19), "away"

    randomEvents = (start, end, events) -> #{{{3
      for o in events
        o.minDuration ?= 0.1
        o.maxDuration ?= 10
        try
          for agentId, agent of data.agents
            if agent.kind in o.agentTypes
              time = +(new Date(start))
              end = +(new Date(end))
              random = prand(hash(agentId + start + o.description))
              time += 2 * random.next() * 60 * 60 * 1000 / o.frequencyPerHour
              while time < end
                location = o.locations[random.nextN o.locations.length]
                startEvent = addEvent [agentId], location, (new Date(time)).toISOString(), "random " + o.description, {during: o.during}
                endTime = time + 1000*60* (o.minDuration  + (o.maxDuration - o.minDuration) * random.next())
                addEvent [agentId], null, (new Date(endTime)).toISOString(), "random-end " + o.description, {ends: startEvent}
                time += 2 * random.next() * 60 * 60 * 1000 / o.frequencyPerHour
        catch e
          console.log e
          warn "error creating random events for #{JSON.stringify o}: #{String(e)}"
    data.beforeRandom = {}

    behaviourApi = #{{{3
      addEvent: (o) ->
        if Array.isArray o.location
          addEvents o.agents, o.location, o.time, o.description, o
        else
          addEvent o.agents, o.location, o.time, o.description, o
      addAgent: (agent) ->
        agent.id = agent.id || uniqueId()
        warn "missing agent kind #{agent.id}" if !agent.kind
        warn "duplicate agent #{agent.id}" if data.agents[agent.id]
        data.agents[agent.id] = agent
        assignAgentColors(agent)
      randomEvents: randomEvents

    try (require "./#{config.configData}/behaviour.js").calendarAgents (data.calendar || []), behaviourApi, data
    catch e
      warn "Error in configuration in data/ " + e

    data.eventPos = 0 #{{{3
    data.agentNow = {}
    data.locationNow = {}
    data.eventList = Object.keys data.events
    data.eventList.sort()

    while data.eventPos < data.eventList.length && data.eventList[data.eventPos] < getDateTime()
      updateState(filterEvent(data.events[data.eventList[data.eventPos]]))
      data.eventPos += 1

    data.next = {}
    for event in data.eventList
      e = data.events[event]
      if e.location
        data.next[e.location] ?= []
        data.next[e.location].push event
      for agent in (e.agents || [])
        data.next[agent] ?= []
        data.next[agent].push event
    for id, events of data.next
      data.next[id] = events.reverse()
  
  #{{{3 read cached data
  try
    data = JSON.parse fs.readFileSync config.apiserver.cachefile
    if data.status && data.status.warnings
      for key, val of data.status.warnings
        status.warnings[key] = "data " + val
  catch e
    console.log "reading cached data:", e
    data =
      activities: {}
      calendarEvents: []
      groups: {}
      locations: {}
      status: {}
      teachers: {}
    warn "couldn't read cached data"
  process.nextTick enrichData
  
  
  # {{{2 Server
  app = express()
  app.use express.static "#{__dirname}/public"
  server = app.listen config.apiserver.port
  console.log "starting server on port: #{config.apiserver.port}"
  #{{{3 REST server
  lastHTTPRequest = {}
  app.use (req, res, next) ->
    lastHTTPRequest[req.connection.remoteAddress] = new Date()
    # no caching, if server through cdn
    res.header "Cache-Control", "public, max-age=0"
    # CORS
    res.header "Access-Control-Allow-Origin", "*"
    # no need to tell the world what server software we are running, - security best practise
    res.removeHeader "X-Powered-By"
    next()

  app.all "/stop-server", (req,res)->
    res.end "ok, exiting"
    setImmediate -> process.exit 0
  
  nextEvent = (agentOrLocation) ->
    events = data.next[agentOrLocation]
    return null if !events
    events.pop() while events.length && (events[events.length - 1] < getDateTime())
    events[events.length - 1]

  defRest = (name, member) ->
    app.all "/next/:id", (req, res) ->
      event = nextEvent req.params.id
      res.json(if event then {event: event} else {})
      res.end()

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

  updateStatus = (cb) ->
    fs.stat config.apiserver.cachefile, (err, stat) ->
      status.organismTime = getDateTime()
      status.lastDataUpdate = stat?.mtime
      status.eventDetails =
          count: data.eventList.length
          pos: data.eventPos
          first: data.eventList[0]
          next: data.eventList[data.eventPos + 1]
          last: data.eventList[data.eventList.length - 1]
      status.connections = clientCount
      status.lastHTTPRequest = lastHTTPRequest
      status.lastHTTPRequestCount = Object.keys(lastHTTPRequest).length
      cb? status
  updateStatus()

  app.all "/status", (req, res) ->
    updateStatus (result) ->
      res.json result
      res.end()

  app.all "/now/:kind/:id", (req, res) ->
    res.json (data[req.params.kind + "Now"] || {})[req.params.id] || {}
    res.end()

  app.all "/current-state", (req, res) ->
    res.json data.agentNow
    res.end()

  app.all "/client-config", (req, res) ->
    try
      file = __dirname + "/client-config/default.json"
      file = __dirname + "/client-config/user.json" if fs.existsSync(__dirname + "/client-config/user.json")
      res.json JSON.parse(fs.readFileSync(file, "utf8"))
    catch e
      res.json {}
    res.end()

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
    timeout: 60*5
  
  bayeux.on "subscribe", (clientId, channel) ->
    console.log channel, typeof channel

  clientCount = 0

  bayeux.on "handshake", (clientId, channel) ->
    console.log new Date(), "handshake", clientId
    #setTimeout (-> console.log bayeux._server._engine._connections[clientId].socket._socket), 2000
    ++clientCount

  bayeux.on "disconnect", (clientId, channel) ->
    console.log new Date(), "disconnect", clientId, channel
    --clientCount
  
  bayeux.attach server
  
  #{{{4 Events and event emitter
  filterEvent = (event) ->
    currentEvent = data.events[data.agentNow[event.agents[0]]?.event] || {}
    if eventType(event) == "random"
      # only emit random events if they are happening during an activity where they can occur
      return if not (eventType(currentEvent) in event.during)
      # remember the previous event, to be able to restore it, - but only if it isn't a random event
      if eventType(currentEvent) != "random"
        data.beforeRandom[event.agents[0]] = currentEvent.id

    if eventType(event) == "random-end"
      if (data.agentNow[event.agents[0]]?.event) != event.ends
        data.beforeRandom[event.agents[0]] = undefined
        return
      prevEvent = data.events[data.beforeRandom[event.agents[0]] ]
      if prevEvent and !(prevEvent.description == "roaming" && prevEvent.autoLeave)
        event.description = prevEvent.description
        event.location = prevEvent.location
        event.clonedId = prevEvent.id
      else
        event.description = "roaming"
        event.autoLeave = leaveTime(event.id)

      data.beforeRandom[event.agents[0]] = undefined

    if event.description == "away" and data.agentNow[event.agents[0]].activity != "roaming"
      # TODO also go away if doing random stuff
      return
    return event

  autoLeave = []
  nextAutoLeave = "0"
  addAutoLeave = (event) ->
    autoLeave.push event
    nextAutoLeave = event.autoLeave if event.autoLeave < nextAutoLeave
  handleAutoLeave = (now) ->
    events = []
    if nextAutoLeave <= now
      list = autoLeave
      autoLeave = []
      nextAutoLeave = "9999"
      for event in list
        if event.autoLeave <= now
          for agent in event.agents
            if data.agentNow[agent].event == event.id
              id = event.autoLeave + '_' + uniqueHash(agent + event.id) + '_away'
              data.events[id] =
                id: id
                description: "away"
                time: event.autoLeave
                agents: [agent]
              events.push id
        else
          addAutoLeave event
    events

  leaveTime = (t) ->
    prng = prand(hash(t))
    (new Date(new Date(t.slice(0,19)+'Z') - (- (generalSettings.minRoam + (generalSettings.maxRoam - generalSettings.minRoam) * prng.next())|0) * 60 * 1000)).toISOString().slice(0,19)

  emitEvent = (event) ->
    event = filterEvent event
    return if not event
    addAutoLeave(event) if event.autoLeave
    data.events[event.id] = event if !data.events[event.id]
    console.log getDateTime(), event.id, event.description, event.location
    updateState event
    bayeux.getClient().publish "/events", event

  eventEmitter = ->
    now = getDateTime()
    events = handleAutoLeave now
    while data.eventPos < data.eventList.length and data.eventList[data.eventPos] <= now
      events.push data.eventList[data.eventPos]
      ++data.eventPos
    events.sort()
    for event in events
      emitEvent data.events[event]

  setInterval eventEmitter, 100
  
  
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

  doArrival = (arrival) ->
    agentId = arrival.name + " " + arrival.origin
    agent = data.agents[agentId]
    if !agent
      agent = data.agents[agentId] =
        id: agentId
        kind: "transport"
        name: arrival.name
        origin: arrival.origin
    location = data.locations[arrival.type]
    if !location
      location = data.locations[arrival.type] =
        id: arrival.type
        kind: "transport"
    emitEvent
      id: getDateTime() + agentId + " arrive"
      time: getDateTime()
      description: "transport arrival"
      agents: [agent.id]
      location: arrival.type
    sleep 2 + Math.random() * 60, ->
      emitEvent
        id: getDateTime() + agentId + " leave"
        time: getDateTime()
        description: "transport leaving"
        agents: [agent.id]

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
          doArrival arrival
      setTimeout arrivalEmitter, 30000

    if !arrivalCache.length || now >= arrivalCache[arrivalCache.length - 1].date
      arrivals doEmit
    else
      doEmit arrivalCache

  arrivalEmitter() if not config.test

  #{{{2 update global state (agents/events)
  updateState = (event) ->
    return if not event
    for agent in event.agents
      prevLocation = (data.agentNow[agent] || {}).location
      data.locationNow[prevLocation].agents = data.locationNow[prevLocation].agents.filter ( (a) -> a != agent) if prevLocation
      location = event.location
      if location
        data.locationNow[location] = data.locationNow[location] || {}
        data.locationNow[location].agents = data.locationNow[location].agents || []
        data.locationNow[location].agents.push agent
        data.locationNow[location].event = event.id
      data.agentNow[agent] = {}
      data.agentNow[agent].location = location if location
      data.agentNow[agent].activity = event.description if event.description
      data.agentNow[agent].event = event.id

  calendarData enrichData #{{{2

  #{{{2 Test
  #
  if config.test
    testResult = ""
    testLog = (args...)->
      testResult += (JSON.stringify([args...]) + "\n").replace(/("id":"2015[^_]*)[^"]*/, '"id":"some-id')
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
    testTime = + (new Date testStart)
    getDateTime = -> testTime
    setTimeout ( ->
      startTime = Date.now()
      getDateTime = -> (new Date(testTime + (Date.now() - startTime) * testSpeed)).toISOString() 
    ), 3000
  
  
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
