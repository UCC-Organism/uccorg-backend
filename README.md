# UCC Organism Backend
[![ci](https://secure.travis-ci.org/UCC-Organism/uccorg-backend.png)](http://travis-ci.org/UCC-Organism/uccorg-backend)

Backend for the UCC-organism

# Tasks

## Status

- deprecated webservice + extracted data from webuntis
- dummy data-set for automatic test
- implemented push to client via faye
- configuration/setup of server for dmz

## Next to do

## Backlog

- server actually on UCC DMZ, getting nightly data dumps
- ucc-data processing
- other data sources
  - train schedule/data
  - remote calendar
- administrative interface

# Configuration

    
    testing = process.argv[2] == "test"
    

Filename of data dump

    filename = "data.json"
    filename = "sample-data.json" if testing
    

Ical url 

    icalUrl = "http://www.google.com/calendar/ical/solsort.dk_74uhjebvm79isucb9j9n4eba6o%40group.calendar.google.com/public/basic.ics"
    

Port to listen to

    port = 8080
    

# Dependencies

    
    fs = require "fs"
    express = require "express"
    http = require "http"
    faye = require "faye"
    async = require "async"
    

# General Utility

    getISODate = -> (new Date).toISOString()
    sleep = (t, fn) -> setTimeout fn, t
    

# Data model
## Getting/creating `data`
### Get data from calendar
### Pushed to the server from UCC daily. TODO

    handleUCCData = (data, done) ->
      console.log "handle data update from ucc-server", data

... update data-object based on UCC-data, include prune old data

      cacheData done
    

### Getting data from webuntis-api

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
    
      fs.readFile "apikey.webuntis", "utf8", (err, apikey) ->
        return webUntisDataDone(err, undefined) if err
        apikey = apikey.trim()
        untisCall = 0

#### webuntis - function for calling the webuntis api

        webuntis = (name, cb) ->
          console.log "webuntis", name, ++untisCall
          url = "https://api.webuntis.dk/api/" + name + "?api_key=" + apikey
          (require 'request') url, (err, result, content) ->
            return cb err if err
            console.log url, content
            cb null, JSON.parse content

#### extract data, download data needed from webuntis

        extractData = (dataDone) ->
          startTime = getISODate()
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
    
    if !testing
      getWebUntisData (data)->
        console.log Object.keys data
    
    

### Core data

Cached data loaded at startup time. 

The file in the repository contains sample data for test.

For each kind of data there is a mapping from id to individual object

- activities
  - id
  - start/end
  - teachers - list
  - locations - list
  - subject
  - groups
- groups
  - id
  - group-name
  - programme
  - TODO: students
- teachers
  - id
  - gender
  - programme
- students TODO
  - groups
  - gender



    data = JSON.parse fs.readFileSync filename
    cacheData = (done) ->
      fs.writeFile "#{__dirname}/data.json", JSON.stringify(data), done
    
    

## Data structures

### Table with `events` (activity start/end)

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
    
    
    

# Server

    app = express()
    server = app.listen port
    console.log "starting server on port: #{port}"

## REST server

    app.use express.bodyParser()
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
    

## When getting a request to /update, write it to data.json
For example upload with: curl -X POST -H "Content-Type: application/json" -d @datafile.json http://localhost:7890/update

    app.all "/update", (req, res) ->
      handleUCCData req.body, -> res.end()
    

## Push server
### Setup

    bayeux = new faye.NodeAdapter
      mount: '/faye'
      timeout: 45
    
    bayeux.on "subscribe", (clientId, channel) ->
      console.log channel, typeof channel
    
    bayeux.attach server
    

### Events and event emitter

    eventEmitter = ->
      now = getISODate()
      while eventPos < events.length and events[eventPos] <= now
        event = events[eventPos].split(" ").slice -2
        event[1] = data.activities[event[1]] || event[1]
        bayeux.getClient().publish "/events", event
        ++eventPos
    setInterval eventEmitter, 100
    
    

# Test


    if process.argv[2] == "test"
    
      app.use express.static "#{__dirname}/public"
    
      testOk = true
    
      testStart = "2013-09-20T06:20:00"
      testEnd = "2013-09-20T18:20:00"

testEnd = "2013-09-21T06:20:00"
Factor by which the time will run by during the test

      testSpeed = 300
    

## Mock getISODate,

Date corresponds to the test data set, and a clock that runs very fast

      startTime = Date.now()
      testTime = + (new Date testStart)
      getISODate = -> (new Date(testTime + (Date.now() - startTime) * testSpeed)).toISOString()
    

## start phantomjs

      require("child_process").exec "./node_modules/.bin/phantomjs test-phantom.coffee"
    

## run the test - current test client just emits "/events" back as "/test"

      bayeux.getClient().subscribe "/test", (message) ->
        if message[0] == "end" and message[1].id == 10587
          process.exit (if testOk then 0 else 1)
      setInterval (->
        process.exit 1 if getISODate() >= testEnd
      ), 100000 / testSpeed
    


----

Autogenerated README.md, edit uccorg-backend.coffee or package.json to update ![solsort](https://ssl.solsort.com/_solapp_UCC-Organism_uccorg-backend.png)
