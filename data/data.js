var config = {
    "activities": {
        "researchers": {
            "agents": agentNames("researcher", 10),
            "location": ["B.103", "B.105", "B.104", "B.109", "A.104", "A.106"]
        },
    },
    "locations": [{
        "id": "Auditorium",
        "name": "Auditorium C.028",
        "capacity": 148
    }, {
        "id": "C.108",
        "name": "Teori",
        "capacity": 40,
        "kind": "study"
    }, {
        "id": "C.107",
        "name": "Teori",
        "capacity": 40
    }, {
        "id": "C.106",
        "name": "Teori",
        "capacity": 40
    }, {
        "id": "C.101",
        "name": "Teori",
        "capacity": 40
    }, {
        "id": "C.116",
        "name": "Teori",
        "capacity": 40
    }, {
        "id": "C.117",
        "name": "Teori",
        "capacity": 40
    }, {
        "id": "C.208",
        "name": "Teori",
        "capacity": 40
    }, {
        "id": "C.206",
        "name": "Teori",
        "capacity": 40
    }, {
        "id": "C.201",
        "name": "Teori",
        "capacity": 40
    }, {
        "id": "C.226",
        "name": "Teori",
        "capacity": 40
    }, {
        "id": "C.230",
        "name": "Teori",
        "capacity": 40
    }, {
        "id": "B.101",
        "name": "Teori",
        "capacity": 32
    }, {
        "id": "A.101",
        "name": "Teori",
        "capacity": 100
    }, {
        "id": "A.102",
        "name": "Teori",
        "capacity": 36
    }, {
        "id": "A.103",
        "name": "Teori",
        "capacity": 60
    }, {
        "id": "A.124",
        "name": "Teori",
        "capacity": 40
    }, {
        "id": "Bevægelse 1",
        "name": "Bevægelsessal 1 (L)",
        "capacity": 30
    }, {
        "id": "Bevægelse 2",
        "name": "Bevægelsessal 2 (S)",
        "capacity": 40
    }, {
        "id": "Brikserum C.125",
        "name": "Brikserum (L)",
        "capacity": 40
    }, {
        "id": "Brikserum C.129",
        "name": "Brikserum (S)",
        "capacity": 44
    }, {
        "id": "Behandlingsrum C.033",
        "name": "Behandlingsrum C.033",
        "capacity": 20
    }, {
        "id": "Bevægelse B001",
        "name": "Bevægelsessal B001",
        "capacity": 40
    }, {
        "id": "Teatersal",
        "name": "Teatersal",
        "capacity": 40
    }, {
        "id": "A.004",
        "name": "VNT - Teori",
        "capacity": 40
    }, {
        "id": "C.123",
        "name": "Naturvidensk. Café C.123",
        "capacity": 40
    }, {
        "id": "C.224",
        "name": "Mikrobiologi",
        "capacity": 40
    }, {
        "id": "SIM Lab C.220",
        "name": "SIM Lab (H-L-R)",
        "capacity": 6
    }, {
        "id": "Learning Lab C.216",
        "name": "Learning Lab",
        "capacity": 4
    }, {
        "id": "FrederiksborgCentret",
        "name": "Frederiksborg Centret",
        "capacity": 60
    }, {
        "id": "Ude af huset",
        "name": "Ude af huset"
    }, {
        "id": "Grupperum C113",
        "name": "Grupperum 1. sal",
        "capacity": 10
    }, {
        "id": "Grupperum C213",
        "name": "Grupperum 2. sal",
        "capacity": 10
    }, {
        "id": "Atrium",
        "name": "Atrium",
        "capacity": 300
    }, {
        "id": "Køkken",
        "name": "Køkken"
    }, {
        "id": "Kantine",
        "name": "Kantine",
        "capacity": 150
    }, {
        "id": "Bevægelse B.001",
        "name": "Bevægelsessal B.001",
        "capacity": 40
    }, {
        "id": "Grupperum C.113",
        "name": "Grupperum 1. sal",
        "capacity": 10
    }, {
        "id": "Grupperum C.213",
        "name": "Grupperum 2. sal",
        "capacity": 10
    }, {
        "id": "Konference B.105",
        "name": "Konference B.105",
        "capacity": 15
    }, {
        "id": "Reservér selv flexru",
        "name": "Flexrum"
    }, {
        "id": "Studieadministration",
        "name": "Studieadministrationen",
        "categories": ["adm"]
    }, {
        "id": "BUS"
    }, {
        "id": "EXB"
    }, {
        "id": "S"
    }, {
        "id": "TOG"
    }],
    "agents": {
        "researcher": {
            "count": 100,
            "minAge": 20,
            "maxAge": 60,
            "genderBalance": 0.5
        },
        "janitor": {},
        "kitchen staff": {},
        "teacher": {},
        "student": {},
        "transport": {}
    }
};

var randomSeed;
exports.calendarAgents = function(calendar, uccorg, data) {
    var id, i, o, researchers, activity;
    randomSeed = 0;

    for(var agentType in config.agents) {
      var agentInfo = config.agents[agentType];
      if(agentInfo.count) {
        var agentIds = agentNames(agentType, agentInfo.count);
        for(i=0;i<agentIds.length;++i) {
          uccorg.addAgent({
            id: agentIds[i],
            kind: agentType,
            age: agentInfo.minAge + pseudoRandom() * (agentInfo.maxAge-agentInfo.minAge) | 0,
            gender: (pseudoRandom() > agentInfo.genderBalance)?0:1
          });
        }
      }
    }

    for (i = 0; i < calendar.length; ++i) {
        o = calendar[i];
        activity = config.activities[o.type];
        if (activity) {
            uccorg.addEvent({
                time: o.start,
                agents: activity.agents,
                location: activity.location,
                description: o.type
            });
            uccorg.addEvent({
                time: o.end,
                agents: activity.agents
            });
        }
        console.log(o);
    }
    for(var i = 0; i < 1000; ++i) {
      console.log(pseudoRandom());
    }
};

function agentNames(name, count) {
  var result = [];
  for(var i = 1; i <= count; ++i) {
    result.push(name + i);
  }
  return result;
}

function pseudoRandom() {
  randomSeed = 1103515245 * randomSeed + 12345 & 0x7fffffff;
  return (randomSeed & 0x3fffffff) / 0x40000000;
}
