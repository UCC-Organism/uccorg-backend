module.exports = {
  "researchers": {
    "agents": agentNames("researcher", 10),
    "location": ["B.103", "B.105", "B.104", "B.109", "A.104", "A.106"]
  },
  "aften": { "agents": ["time-of-day"], "location": ["global-state"]},
  "formiddag": { "agents": ["time-of-day"], "location": ["global-state"]},
  "eftermiddag": { "agents": ["time-of-day"], "location": ["global-state"]},
  "morgen": { "agents": ["time-of-day"], "location": ["global-state"]},
  "nat": { "agents": ["time-of-day"], "location": ["global-state"]}
};

function agentNames(name, count) {
  var result = [];
  for (var i = 1; i <= count; ++i) {
    result.push(name + i);
  }
  return result;
}
