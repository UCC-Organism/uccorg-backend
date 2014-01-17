# UCC Organism Backend
[![ci](https://secure.travis-ci.org/UCC-Organism/uccorg-backend.png)](http://travis-ci.org/UCC-Organism/uccorg-backend)

Backend for the UCC-organism

# Info

The server is run with `coffee uccorg-backend.coffee configfile.json`, where `configfile.json` contains the actual configuration of the server. 
Depending on the configuration, this runs as:

- production data preparation server(windows), which is responsible for getting the data from ucc/webuntis/calendar/..., anonymising them, and sending them onwards to the api server
- production api server(debian on macmini), which gets the anonymised data from the data preparation server, makes them available via an api, and emits events using the Bayeux protocol
- development server for backend, which uses real data dumps instead of talking with external services
- automated test, which runs automatically using travis, uses sample data dumps, and mocks the time to run very fast.
- development server for frontend, - which runs of sample data dump and mocks the time, - to be able to get events without having to wait for real-world activities 

## Configuration

All configuration options are listed in `config.json.sample`. Also see `test.json` for an actual configuration, the content of this configuration wille also be a good choice for a frontend development server, - just remove `"outfile"`, and reduce the time speed factor `"xTime"` - which tells how much faster the mocked clock should run.

## API

The api delivers JSON objects, and is available through http, with JSONP and CORS enabled. The endpoints are:

- `/(teacher|group|location|activity)/$ID` returns info about the particular entity
- `/now/(teacher|group|location)/$ID` returns an object with the next, current, and previous activity for the given entity
- `/(teachers|groups|locations|activities)` returns list of ids

Events are pushed on `/events` as they happens through faye (http://faye.jcoglan.com/), ie. `(new Faye.Client('http://localhost:8080/')).subscribe('/events', function(msg) { ... })`

## Status/issues

- cannot access macmini through port 8080, - temporary workaround through ssl.solsort.com, but needs to be fixed.
- some teachers on webuntis missing from mssql (thus missing gender non-critical)
- *mapning mellem de enkelte kurser og hold mangler, har kun information på årgangsniveau, og hvilke årgange der følger hvert kursus*
- *Info følgende grupper mangler via mssql: fss12b, fss11A, fss11B, fsf10a, fss10, fss10b, fss12a, norF14.1, norF14.2, norF14.3, nore12.1, samt "SPL M5 - F13A og F13B"*
- activity is not necessarily unique for group/location at a particular time, this slightly messes up current/next activity api, which just returns a singlura next/previous

## Done

### Milestone 3 - running until Jan 17

- dashboard
- get data from remote-calendar (train schedule, etc.)
- fix timezone bug (test daylight saving handling)
- do not tunnel data anymore, but send it directly to the macmini via port 8080 now that the firewall is opened.
- update config on windows server, to send current days, and not one month in the future for test.
- preparation-server: support dump to file for development purposes
- dashboard: show events live as they happen
- dashboard skeleton
- added api for getting ids of all teachers/groups/locations/activities

### Milestone 2 - running until Dec. 29

- the windows server configured to extract the data each night at 1'o'clock, and send them to the mac mini.
- added api for getting current/next/prev activity given a location, teacher or group
- update REST-api
- moving configuration into config-file
- generate datafile for apiserver from ucc/webuntis-data
- anonymising students
- temporarily forwarding data through ssl.solsort.com, as port 8080 from ssmldata to macmini doesn't seem to be open.
- send data from ssmldata-server to macmini

### Milestone 1 - running until Dec. 22

- get data from sqlserver
- getting data from webuntis
- got macmini onto UCCs serverpark
- live events via faye
- get data via api
- got access to provisioned ssmldata-server
- dummy data-set for automatic test
- automatic test on macmini with fast time for development
- deprecated solsort.com running webuntis-based webservice for development


## To Do

- make macmini production-ready
- setup calender for anders

# Common stuff
## About

    
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
    

## Dependencies

    
    assert = require "assert"
    fs = require "fs"
    express = require "express"
    http = require "http"
    faye = require "faye"
    async = require "async"
    mssql = require "mssql"
    request = require "request"
    

## Utility functions

Get the current time as yyyy-mm-ddThh:mm:ss (local timezone, - or mocked value if running test/dev)


    getDateTime = -> (new Date(Date.now() - (new Date).getTimezoneOffset() * 60 * 1000)).toISOString().slice(0,-1)


more comfortable syntax for set timeout: `sleep #seconds, -> ...`

    sleep = (t, fn) -> setTimeout fn, t*1000

### binarySearchFn

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
    
    

### sendUpdate

    sendUpdate = (data, callback) ->
      datastr = JSON.stringify data

escape unicode as ascii

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
    

# data preparation - processing/extract running on the SSMLDATA-server

    dataPreparationServer = ->

## getCalendarData

      getCalendarData = (done) ->
        return done() if ! config?.prepare?.icalUrl
        
        if config.prepare.icalDump && fs.existsSync config.prepare.icalDump
          fs.readFile config.prepare.icalDump, "utf8", (err, content) ->
            throw err if err
            handleIcal content
        else
          request config.prepare.icalUrl, (err, result, content) ->
            fs.writeFile config.prepare.icalDump, content if config.prepare.icalDump
            throw err if err
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

## SQL Server data source

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
      

## Webuntis data source

We do not yet know if we should use the webuntis api, or get a single data dump from ucc
If needed extract code from old-backend-code.js

      
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

webuntis - function for calling the webuntis api

          webuntis = (name, cb) ->
            if ((++untisCall) % 100) == 0
              console.log "webuntis api call ##{untisCall}: #{name}"
            url = "https://api.webuntis.dk/api/" + name + "?api_key=" + apikey
            request url, (err, result, content) ->
              return cb err if err
              cb null, JSON.parse content

extract data, download data needed from webuntis

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
      
      

## Transform data for the event/api-server

    
      processData = (webuntis, sqlserver, icaldata, callback) ->
        startTime = config.prepare.startDate || 0
        if typeof startTime == "number"
          startTime = (new Date(+(new Date()) + startTime * 24*60*60*1000)).toISOString()
        else
          startTime = (new Date(startTime)).toISOString()
        endTime = (new Date(+(new Date(startTime)) + (config.prepare.timespan || 1) * 24*60*60*1000)).toISOString()
        console.log "Extracting data from #{startTime} to #{endTime}"
      

The file in the repository contains sample data for test.

For each kind of data there is a mapping from id to individual object

        

### Output description

- activities: id, start/end, teachers, locations, subject, groups
- groups: id, group-name, programme, students(id,gender)
- teachers: id, gender, programme
- locations: id, name, longname, capacity
- calendarEvents: start, end, title, description

       

### input description

- webuntis
  - locations: untis_id, capacity, longname
  - subjects: untis_id, name, longname, alias
  - lessons: untis_id, start, end, subjects, teachers, groups, locations, course
  - groups: untis_id, name, alias, schoolyear, longname, department
  - teachers: untis_id, name, forename, longname, departments
  - departments: untis_id, name, longname
- sqlserver
  - StuderendeHold: Holdnavn (lessons.alias), Studienummer
  - AnsatteHold: Holdnavn (lessons.alias), Initialer (teacher.name)
  - Ansatte: Initialer, Afdeling, Køn
  - Studerende: Studienummer, Afdeling, Køn
  - Hold: Afdeling, Holdnavn, Beskrivelse, StartDato, SlutDato

      

### Initialisation

        result =
          locations: {}
          activities: {}
          groups: {}
          teachers: {}
    

### Locations

        for _, location of webuntis.locations
          result.locations[location.name] =
            id: location.name
            name: location.longname
            capacity: location.capacity
    

### addTeacher

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
    

### addGroup (and students)

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
    

### Handle Activities

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
    

### Handle input from iCal

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
          try
            for key, val of JSON.parse activity.description
              activity[key] = val
          catch e
            undefined
          result.activities[activity.id] = activity
    
        iCalDate = (t) ->
          d = t.replace /.*:/, ""

WARNING: here we assume that we are in Europe/Copenhagen-timezone

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
    

### done

        callback result
      

## execute

      getWebUntisData (data1) ->
        getSqlServerData (data2) ->
          getCalendarData (data3) ->
            processData data1, data2, data3, (result) ->
              if config.prepare.dest.dump
                fs.writeFile config.prepare.dest.dump, JSON.stringify(result, null, 2)
              sendUpdate result, (err, data) ->
                console.log "submitted to api-server"
                process.exit 0
    

# event/api-server

    apiServer = ->

## Handle data
### Pushed to the server from UCC daily.

      handleUCCData = (input, done) ->
        console.log "handling data update from ucc-server"
        fs.writeFile config.apiserver.cachefile, JSON.stringify(input), ->
          data = input
          enrichData()
          console.log "data replaced with new data from ucc-server"
          done()
      

### Data structures


      activitiesBy =
        group: {}
        location: {}
        teacher: {}
      events = []
      eventPos = 0
      enrichData = ->
    
        activitiesBy =
          group: {}
          location: {}
          teacher: {}
    

#### Tables with activities ordered by group/location/teacher

        for _, activity of data.activities
          for kind, collection of activitiesBy
            for elem in activity["#{kind}s"]
              collection[elem] ?= []
              collection[elem].push activity
        for _, collection of activitiesBy
          for _, arr of collection
            arr.sort (a, b) -> a.end.localeCompare b.end
    

#### Table with `events` (activity start/end)

activity start/stop - ordered by time, - used for emitting events

        now = getDateTime()
        eventEmitter()
        events = []
        eventPos = 0
        for _,activity of data.activities
          events.push "#{activity.start} start #{activity.id}" if activity.start > now
          events.push "#{activity.end} end #{activity.id}" if activity.end > now
        events.sort()
      

### read cached data

      try
        data = JSON.parse fs.readFileSync config.apiserver.cachefile
        process.nextTick enrichData
      catch e
        console.log "reading cached data:", e
        data = {}
      
      

## Server

      app = express()
      app.use express.static "#{__dirname}/public"
      server = app.listen config.apiserver.port
      console.log "starting server on port: #{config.apiserver.port}"

### REST server

      app.use (req, res, next) ->

no caching, if server through cdn

        res.header "Cache-Control", "public, max-age=0"

CORS

        res.header "Access-Control-Allow-Origin", "*"

no need to tell the world what server software we are running, - security best practise

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
        arr = activitiesBy[req.params.kind][req.params.id]
        return res.end if ! arr
        now = getDateTime()
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
      

### When getting a request to /update, write it to data.json
For example upload with: curl -X POST -H "Content-Type: application/json" -d @datafile.json http://localhost:7890/update

      app.all "/update", (req, res) ->
        handleUCCData req.body, -> res.end()

TODO temporary url while rerouting through ssl.solsort.com

      app.use "/uccorg-update", (req, res, next) ->
        result = ""
        req.on "data", (data) ->
          result += data
        req.on "end", ->
          console.log "getting #{result.length} bytes"
          handleUCCData (JSON.parse result), -> res.end()
      

### Push server
#### Setup

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
      

#### Events and event emitter

      eventEmitter = ->
        now = getDateTime()
        while eventPos < events.length and events[eventPos] <= now
          event = events[eventPos].split(" ").slice -2
          console.log Date(), events[eventPos]
          event[1] = data.activities[event[1]] || event[1]
          bayeux.getClient().publish "/events", event
          ++eventPos
      setInterval eventEmitter, 100
      
      

## Test


      if config.test
        testResult = ""
        testLog = (args...)->
          testResult += JSON.stringify([args...]) + "\n"
        testDone = ->
          fs.writeFileSync config.test.outfile, testResult if config.test.outfile
          process.exit()
      
      
      
        testStart = config.test.startDate
        testEnd = config.test.endDate

Factor by which the time will run by during the test

        testSpeed = config.test.xTime
    

### Rest test

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
            restTestRequest "now/group/39"
            restTestRequest "now/teacher/23"
            restTestRequest "now/location/C.224"
            restTestRequest "group/39"
            restTestRequest "teacher/23"
            restTestRequest "location/C.206"
            restTestRequest "activity/23730"
          ]
          undefined
      

### Mock getDateTime,

Date corresponds to the test data set, and a clock that runs very fast

        startTime = Date.now()
        testTime = + (new Date testStart)
        getDateTime = -> (new Date(testTime + (Date.now() - startTime) * testSpeed)).toISOString()
      
      

### run the test - current test client just emits "/events" back as "/test"

        bayeux.getClient().subscribe "/events", (message) ->
          testLog "event", message
        setInterval (->
          if config.test.restTestTime && getDateTime() >= config.test.restTestTime
            restTest()
          if getDateTime() >= testEnd
            testLog "testDone"
            testDone()
        ), 100000 / testSpeed

sendUpdate data, -> undefined
# Main

See sample file in `config.json-sample`, and `test.json`.


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
    
    


----

Autogenerated README.md, edit uccorg-backend.coffee to update [![repos](https://ssl.solsort.com/_solapp_UCC-Organism_uccorg-backend.png)](https://github.com/UCC-Organism/uccorg-backend)
