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
# {{{1 Create dummy data set for automatic test

if process.argv[2] == "test"
  datadump = readFileSync
