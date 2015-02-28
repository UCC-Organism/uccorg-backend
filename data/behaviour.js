var config = {
    "calendar": require("./calendar.js"),
    "locations": require("./locations.json"),
    "agents": require("./agents.json"),
};

var randomSeed;

exports.calendarAgents = function(calendar, uccorg, data) {
    var id, i, o, researchers, activity;
    randomSeed = 0;

    for (var agentType in config.agents) {
        var agentInfo = config.agents[agentType];
        if (agentInfo.count) {
            var agentIds = agentNames(agentType, agentInfo.count);
            for (i = 0; i < agentIds.length; ++i) {
                uccorg.addAgent({
                    id: agentIds[i],
                    kind: agentType,
                    age: agentInfo.minAge + pseudoRandom() * (agentInfo.maxAge - agentInfo.minAge) | 0,
                    gender: (pseudoRandom() > agentInfo.genderBalance) ? 0 : 1
                });
            }
        }
    }

    for (i = 0; i < calendar.length; ++i) {
        o = calendar[i];
        activity = config.calendar[o.type];
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
};

function pseudoRandom() {
    randomSeed = 1103515245 * randomSeed + 12345 & 0x7fffffff;
    return (randomSeed & 0x3fffffff) / 0x40000000;
}

function agentNames(name, count) {
  var result = [];
  for (var i = 1; i <= count; ++i) {
    result.push(name + i);
  }
  return result;
}
