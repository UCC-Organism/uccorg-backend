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
filename = "/location/of/data/dump"
filename = "sample-data.json" if process.argv[2] == "test"

# {{{1 Dependencies

fs = require "fs"

# {{{1 Utility
getDate = -> (new Date).toISOString()
sleep = (t, fn) -> setTimeout fn, t

    

# {{{1 Create dummy data set for automatic test

datadump = JSON.parse fs.readFileSync filename
console.log datadump
console.log getDate()

#{{{1 Test
#
if process.argv[2] == "test"

  testStart = "2013-09-20T06:20:00"
  testEnd = "2013-09-21T06:20:00"
  testSpeed = 1000
  #{{{2 Mock getDate, 
  #
  # Date corresponds to the test data set, and a clock that runs very fast
  startTime = Date.now()
  testTime = + (new Date testStart)
  getDate = -> (new Date(testTime + (Date.now() - startTime) * testSpeed)).toISOString()

  #{{{2 run the test
  testSample = ->
    console.log getDate()
    if getDate() < testEnd
      sleep 100, testSample
  testSample()
