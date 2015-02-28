module.exports = {
  "researchers": {
    "agents": agentNames("researcher", 10),
    "location": ["B.103", "B.105", "B.104", "B.109", "A.104", "A.106"]
  },
};

function agentNames(name, count) {
  var result = [];
  for (var i = 1; i <= count; ++i) {
    result.push(name + i);
  }
  return result;
}
