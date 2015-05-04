module.exports = {
  "cooking": [
    {
      "agents": agentNames("kitchen staff", 10),
      "locations": ["cafe", "canteen", "kitchen", "kitchen", "kitchen", "canteen"]
    }
  ],
  "workers": [
    {
      "agents": agentNames("researcher", 10),
      "activity": "researchers",
      "locations": ["B.103", "B.105", "B.104", "B.109", "A.104", "A.106"]
    },
    {
      "agents": agentNames("administrator", 10),
      "activity": "administrators",
      "locations": ["C.103", "C.105", "C.104", "C.109", "B.104", "B.106"]
    }
  ],
  "janitors": [
    {
      "agents": agentNames("janitor", 2),
      "activity": "roaming"
    },
    {
      "agentTypes": ["janitor"],
      "minDuration": 1,
      "maxDuration": 3,
      "description": "toilet",
      "locations": ["random toilet"],
      "during": ["scheduled", "roaming"],
      "frequencyPerHour": 0.1
    },
    {
      "agentTypes": ["janitor"],
      "minDuration": 1,
      "maxDuration": 10,
      "description": "closet",
      "locations": ["random closet"],
      "during": ["scheduled", "roaming"],
      "frequencyPerHour": 0.5
    }
  ],
  "formiddag": [
    {
      "agents": ["time-of-day"],
      "locations": ["global-state"],
      "minIntensity": 0.3,
      "maxIntensity": 0.5
    },
    {
      "agentTypes": ["student", "teacher", "researcher"],
      "minDuration": 1,
      "maxDuration": 10,
      "description": "toilet",
      "locations": ["toilet"],
      "during": ["scheduled", "roaming"],
      "frequencyPerHour": 0.01
    }
  ],
  "frokost": [
    {
      "agentTypes": ["student", "teacher", "researcher"],
      "minDuration": 10,
      "maxDuration": 30,
      "description": "lunch",
      "locations": ["canteen", "canteen", "canteen", "cafe"],
      "during": ["roaming"],
      "frequencyPerHour": 4
    }
  ],
  "aften": [
    {
      "agents": ["time-of-day"],
      "locations": ["global-state"],
      "minIntensity": 0.0,
      "maxIntensity": 0.1
    }
  ],
  "eftermiddag": [
    {
      "agents": ["time-of-day"],
      "locations": ["global-state"],
      "minIntensity": 0.6,
      "maxIntensity": 0.9
    }
  ],
  "morgen": [
    {
      "agents": ["time-of-day"],
      "locations": ["global-state"],
      "minIntensity": 0.0,
      "maxIntensity": 1
    }
  ],
  "nat": [
    {
      "agents": ["time-of-day"],
      "locations": ["global-state"]
    }
  ]
};

function agentNames(name, count) {
  var result = [];
  for (var i = 1; i <= count; ++i) {
    result.push(name + i);
  }
  return result;
}
