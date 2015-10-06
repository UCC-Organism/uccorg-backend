module.exports = {
  "cooking": [
    {
      "agents": agentNames("kitchen staff", 10),
      "locations": ["cafe", "canteen", "kitchen", "kitchen", "kitchen", "canteen"]
    }
  ],
  "workers": [
    {
      "agents": agentNames("researcher", 100),
      "activity": "researchers",
      "locations": ["B.103", "B.105", "B.104", "B.109", "A.104", "A.106", "A.004", "A.101", "A.103", "A.124", "B.101", "C.101", "C.106", "C.107", "C.108", "C.116", "C.117", "C.201", "C.208", "C.226", "C.230", "C.216", "C.220", "A.16A", "A.18A", "A.110A", "A.111A", "A.17D" ]
    },
    {
      "agents": agentNames("administrator", 40),
      "activity": "administrators",
      "locations": ["C.103", "C.105", "C.104", "C.109", "B.104", "B.106", "A.018", "A.021", "A.023Q", "A.025Q", "A.014", "A.027", "A.029", "A.031", "A.019", "A.023U", "A.18H", "A.112H", "A.18J", "A.18L", "A.112J", "A.18N"]
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
      "maxDuration": 40,
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
