module.exports = {
  "researchers": [{
    "agents": agentNames("researcher", 10),
    "location": ["B.103", "B.105", "B.104", "B.109", "A.104", "A.106"]
  }],
  "janitors": [{
    "agents": agentNames("janitor", 2),
    "activity": "roaming"
  }, {
    "agentTypes": ["janitor"],
    "minDuration": 1,
    "maxDuration": 3,
    "description": "toilet",
    "locations": ["random toilet"],
    "during": ["scheduled", "roaming"],
    "frequencyPerHour": 0.1
  },{
    "agentTypes": ["janitor"],
    "minDuration": 1,
    "maxDuration": 10,
    "description": "closet",
    "locations": ["random closet"],
    "during": ["scheduled", "roaming"],
    "frequencyPerHour": 0.5 
  }],
  "aften": [{ "agents": ["time-of-day"], "location": ["global-state"]}],
  "formiddag": [{ 
    "agents": ["time-of-day"], 
    "location": ["global-state"]
  }, {
    "agentTypes": ["student", "teacher", "researcher"],
    "minDuration": 1,
    "maxDuration": 10,
    "description": "toilet",
    "locations": ["toilet"],
    "during": ["scheduled", "roaming"],
    "frequencyPerHour": 0.01
  }],
  "frokost": [
  {
    "agentTypes": ["student", "teacher", "researcher"],
    "minDuration": 10,
    "maxDuration": 30,
    "description": "lunch",
    "locations": ["canteen", "canteen", "canteen", "cafe"],
    "during": ["roaming"],
    "frequencyPerHour": 4
  }],
  "eftermiddag": [{ "agents": ["time-of-day"], "location": ["global-state"]}],
  "morgen": [{ "agents": ["time-of-day"], "location": ["global-state"]}],
  "nat": [{ "agents": ["time-of-day"], "location": ["global-state"]}]
};

function agentNames(name, count) {
  var result = [];
  for (var i = 1; i <= count; ++i) {
    result.push(name + i);
  }
  return result;
}
