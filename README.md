# UCC Organism Backend
[![ci](https://secure.travis-ci.org/UCC-Organism/uccorg-backend.png)](http://travis-ci.org/UCC-Organism/uccorg-backend)

Backend for the UCC-organism

# Info

This is actually code for two different servers:

1. ssmldata-server, which is responsible for getting the data from ucc/webuntis/calendar/..., anonymising them, and sending them onwards
2. macmini-server, which gets the anonymised data from the ssmldata-server, makes them available via an api, and emits events

In addition to this, there is some shared code, and testing.

## Status/issues

- cannot access macmini through port 8080, - temporary workaround through ssl.solsort.com, but needs to be fixed.
- some teachers on webuntis missing from mssql (thus missing gender)

## Done
### Milestone 2 - running until Dec. 29

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

- anonymise/cleanup data from ucc/webuntis
- get data from remote-calendar
- make servers production-ready
- test daylight saving handling
- dashboard / administrative interface
- train schedule

# Common stuff
## Dependencies

    
    fs = require "fs"
    express = require "express"
    http = require "http"
    faye = require "faye"
    async = require "async"
    mssql = require "mssql"
    

## Configuration


    
    testing = process.argv[2] == "test"
    ssmldata = process.argv[2] == "ssmldata"

apihost = "uccorg.solsort.com"

    apihost = "10.251.26.11"
    

Filename of data dump

    filename = "data.json"
    filename = "sample-data.json" if testing
    

Ical url 

    icalUrl = "http://www.google.com/calendar/ical/solsort.dk_74uhjebvm79isucb9j9n4eba6o%40group.calendar.google.com/public/basic.ics"
    

Port to listen to

    port = 8080
    

configuration for access to webuntis/sql, must be a jsonfile with content a la:

    {
      "webuntis": "...apikey...",
      "mssql": {
        "server": "...",
        "database": "...",
        "user": "...",
        "password": "..."
      }
    }

    try
      config = JSON.parse fs.readFileSync "config.json", "utf8"
    catch e
      config = {}
      console.log e
    

## Utility functions

    getISODate = -> (new Date).toISOString()
    sleep = (t, fn) -> setTimeout fn, t
    sendUpdate = (host, data, callback) ->
      datastr = JSON.stringify data

escape unicode as ascii

      datastr = datastr.replace /[^\x00-\x7f]/g, (c) ->
        "\\u" + (0x10000 + c.charCodeAt(0)).toString(16).slice(1)
    

Configuration - TODO: drop the solsort-part - currently routing through ssl.solsort.com, as connection to server doesn't seem to be open


      
      opts =
    

    hostname: host
    port: port

        hostname: "ssl.solsort.com"
        path: "/uccorg-update"
        method: "post"
        headers:
          "Content-Type": "application/json"
          "Content-Length": datastr.length
      req = (require "https").request opts, callback
      console.log "sending data: #{datastr.length} bytes"
      req.write datastr
      req.end()
    

# data processing/extract running on the SSMLDATA-server

    if ssmldata

## Calendar data
## SQL Server data source

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
      

## Webuntis data source

We do not yet know if we should use the webuntis api, or get a single data dump from ucc
If needed extract code from old-backend-code.js

      
      getWebUntisData = (callback) ->

DEBUG code, run it on cached data instead of loading all of the webuntis data

        try
          result = JSON.parse fs.readFileSync "#{__dirname}/webuntis.json"
          return callback?(result)
        catch e
          console.log e
          undefined
      
        do ->
          apikey = config.webuntis
          untisCall = 0

webuntis - function for calling the webuntis api

          webuntis = (name, cb) ->
            console.log "webuntis", name, ++untisCall
            url = "https://api.webuntis.dk/api/" + name + "?api_key=" + apikey
            (require 'request') url, (err, result, content) ->
              return cb err if err
              console.log url, content
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

DEBUG code, run it on cached data instead of loading all of the webuntis data

            fs.writeFile "webuntis.json", (JSON.stringify data, null, 4), -> undefined
      
      

## Transform data for the event/api-server

    
      processData = (webuntis, sqlserver, callback) ->
    


The file in the repository contains sample data for test.

For each kind of data there is a mapping from id to individual object

      processData = (webuntis, sqlserver, callback) ->
      

### Output description

- activities: id, start/end, teachers, locations, subject, groups
- groups: id, group-name, programme, students
- teachers: id, gender, programme
- locations: id, name, longname, capacity
- students, id, groups, programme/type, gender

       

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
          students: {}
        startTime = "2014-03-10"
        endTime = "2014-03-20"
    
    
    

### Locations

        for _, location of webuntis.locations
          result.locations[location.untis_id] =
            id: location.untis_id
            name: location.name
            longname: location.longname
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
            programmes2: obj.departments.map (id) ->
              dept = webuntis.departments[id]
              "#{dept.name} - #{dept.longname}"
    

### addGroup (and students) TODO

        addGroup = (obj) ->
          undefined
    

### Utility for anonymising ids

        idCounter = 0
        idAnonTable = {}
        anonIdTable = {}
        anonId = (id) -> idAnonTable[id] || (anonIdTable[++idCounter] = id) && (idAnonTable[id] = idCounter)
            

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
              locations: activity.locations
              subject: if activity.subjects.length == 1
                  webuntis.subjects[activity.subjects[0]].longname
                else
                  throw "error not single subject: #{JSON.stringify activity}" if activity.subjects.length
                  undefined
              groups: activity.groups.map (untis_id) ->
                addGroup(untis_id)
                untis_id

### done

        callback result
      

## execute

      if config.mssql
        getWebUntisData (data1) ->
          getSqlServerData (data2) ->
            processData data1, data2, (result) ->
              sendUpdate apihost, result, () ->
                console.log "submitted to api-server"
      else
        fs.readFile "dump.json", (err, data) ->
          throw err if err
          data = JSON.parse data
          processData data.webuntis, data.sqlserver, (result) ->

console.log result

            fs.writeFileSync "foo.json", JSON.stringify(result, null, 2)

sendUpdate apihost, result, () ->
console.log "submitted to api-server"

            undefined
    

# event/api-server

    else

## Pushed to the server from UCC daily.

      handleUCCData = (data, done) ->
        fs.writeFile "#{__dirname}/dump.json", JSON.stringify data
        console.log "handle data update from ucc-server", data

... update data-object based on UCC-data, include prune old data

        cacheData done
      
      data = JSON.parse fs.readFileSync filename
      cacheData = (done) ->
        fs.writeFile "#{__dirname}/data.json", JSON.stringify(data), done
      
      

### Data structures

#### Table with `events` (activity start/end)

activity start/stop - ordered by time, - used for emitting events

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
      
      
      

## Server

      app = express()
      server = app.listen port
      console.log "starting server on port: #{port}"

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
      
      endpoints =
        teacher: "teachers"
        activity: "activities"
        group: "groups"
        student: "students"
      
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
      
      bayeux.attach server
      

#### Events and event emitter

      eventEmitter = ->
        now = getISODate()
        while eventPos < events.length and events[eventPos] <= now
          event = events[eventPos].split(" ").slice -2
          event[1] = data.activities[event[1]] || event[1]
          bayeux.getClient().publish "/events", event
          ++eventPos
      setInterval eventEmitter, 100
      
      

## Test


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

testEnd = "2013-09-21T06:20:00"
Factor by which the time will run by during the test

        testSpeed = 3000
    
      

### Mock getISODate,

Date corresponds to the test data set, and a clock that runs very fast

        startTime = Date.now()
        testTime = + (new Date testStart)
        getISODate = -> (new Date(testTime + (Date.now() - startTime) * testSpeed)).toISOString()
      
      

### run the test - current test client just emits "/events" back as "/test"

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
    


----

Autogenerated README.md, edit uccorg-backend.coffee or package.json to update [![repos](https://ssl.solsort.com/_solapp_UCC-Organism_uccorg-backend.png)](https://github.com/UCC-Organism/uccorg-backend)
