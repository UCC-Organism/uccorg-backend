var config = {
    "agents": [{
        "kind": "kitchen staff",
        "count": 5
    }, {
        "kind": "researchers",
        "count": 50
    }],
    "activities": [{
        "agents": [
            "kitchen staff"
        ],
        "calendar": "cooking",
        "id": "cooking",
        "locations": [
            "K\u00f8kken",
            "Kantine"
        ]
    }, {
        "agents": [
            "students",
            "teachers",
            "researchers",
            "kitchen staff",
            "janitors"
        ],
        "id": "toilet",
        "locations": [
            "TODO"
        ],
        "duration": 300,
        "probability": 0.001
    }]
};

exports.randomAgents = function(calendar, uccorg) {
    var id, i, o, researchers;

    researchers = [];
    for (i = 0; i < 100; ++i) {
        id = "researcher" + i;
        uccorg.addAgent({
            id: id,
            kind: "researcher"
        });
        researchers.push(id);
    }

    for (i = 0; i < calendar.length; ++i) {
        o = calendar[i];
        if (o.type === "researchers") {
            uccorg.addEvent({
                time: o.start,
                agents: researchers,
                location: "research facility",
                description: "research"
            });
            uccorg.addEvent({
                time: o.end,
                agents: researchers
            });
        }
        console.log(o);
    }
};
