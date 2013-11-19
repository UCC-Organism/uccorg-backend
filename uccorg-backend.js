/*jshint sub:true*/
//{{{1 server
express = require("express");
server = express();
server.use(function(req, res, next) {
    res.header("Cache-Control", "public, max-age=0");
    res.headers("Access-Control-Allow-Origin", "*");
    res.removeHeader("X-Powered-By");
    next();
});
//{{{1 uccorg
//{{{3 notes
//
// TODO:
// - rework daily activities:
//   - group by location, group and teacher
//   - add "free" activities
//   - getActivities for group+timestamp, returning prev, current, next
// - get departments
// - general state info
// - socket.io-app + implement
// - automatic regular update of webuntis-data
// - dashboard
//
// ----
//
// - webuntis
//   - locations (36): rum/lokale
//   - subject (700+)s: fag/emne (både fag og eksamener etd.)
//   - groups (150+): hold+årgang
//   - evt. teachers (160+) - underviser-individ
//   - lessons (28000+): timetable-entry
//     - assumptions: at most one subject per lesson, at most one location per lesson, starts/ends same date
//   - departments...
//
// - api
//   - /activities/next
//   - /location
//   - /state
//     
// - data
//   - time-sorted list of activities for today
//     - time
//     - subject(key)
//     - individuals(key)
//     - location(key)
//   - subject-info
//   - teacher-info
//   - group-info
//   - location-info
//   - student-info
//
// - api
//   - activities
//     - previous activities
//     - all current activities
//     - next activities
//   - activity/$entityId
//     - prevActivity
//     - currentActivity
//     - nextActivity
//   - subject
//   - teacher : entity
//   - group : entity
//   - location : entity
//   - student
//     - groups
//
//{{{3 getWebuntisData
getWebuntisData = memoiseAsync(function(processData) {
    var createData;
    var webuntis;
    var untisCall;
    //{{{4 `webuntis` api call
    untisCall = 0;
    webuntis = function(name, cb) {
        loadCacheFile("/../apikey.webuntis", function(err, apikey) {
            var url;
            apikey = apikey.trim();
            if (err) {
                return cb(err);
            }
            console.log("webuntis", name, untisCall = untisCall + 1);
            url = "https://api.webuntis.dk/api/" + name + "?api_key=" + apikey;
            urlGet(url, function(err, result, content) {
                if (err) {
                    return cb(err);
                }
                cb(null, JSON.parse(content));
            });
        });
    };
    //{{{4 `createData` - extract full dataset from webuntis api
    createData = function(dataDone) {
        var result;
        var startTime;
        startTime = (new Date()).toISOString();
        result = {
            locations: {},
            subjects: {},
            lessons: {},
            groups: {},
            teachers: {},
            departments: {}
        };
        asyncSeqMap(Object.keys(result), function(datatype, cb) {
            webuntis(datatype, function(err, data) {
                if (err) {
                    cb(err);
                }
                console.log(err, data[0]["untis_id"]);
                asyncSeqMap(data, function(obj, cb) {
                    id = obj["untis_id"];
                    webuntis(datatype + "/" + id, function(err, data) {
                        result[datatype][id] = data;
                        cb(err);
                    });
                }, function(err) {
                    cb(err);
                });
            });
        }, function(err) {
            var lessons;
            var untisCmp;
            untisCmp = function(a, b) {
                return Number(a.untisId) - Number(b.untisId);
            };
            lessons = {};
            foreach(result["lessons"], function(_, lesson) {
                var date;
                date = lesson.start.slice(0, 10);
                lessons[date] = lessons[date] || [];
                lessons[date].push(lesson);
            });
            result["lessons"] = lessons;
            result["sync"] = {
                start: startTime,
                done: (new Date()).toISOString()
            };
            dataDone(err, result);
        });
    };
    //{{{4 try load cached data from file, or otherwise call createData, and cache it
    loadCacheFile("/../webuntisdata", function(err, data) {
        if (err) {
            createData(function(err, data) {
                if (err) {
                    return processData(err, data);
                }
                savefile("/../webuntisdata", JSON.stringify(data, null, 4), function() {
                    processData(err, data);
                });
            });
        } else if (true) {
            processData(false, JSON.parse(data));
        }
    });
});
//{{{3 Dashboard
uccorgDashboard = function(app) {
    var html;
    html = new HTML();
    html.content(["h1", "...dashboard..."]);
    app.done(html);
};
//{{{3 route uccorg
route("uccorg", function(app) {
    var path;
    path = app.args[1];
    if (isBrowser) {
        if (path === "dashboard") {
            return uccorgDashboard(app);
        } else if (true) {
            return app.done();
        }
    }
    getWebuntisData(function(err, webuntis) {
        var html;
        var act;
        var dayActivities;
        var teacher;
        var group;
        var activities;
        var day;
        var when;
        var lessonToActivity;
        var prevNextCurrentAll;
        var currentActivities;
        var dayData;
        //{{{4 dayData
        dayData = function(date) {
            var activityList;
            activities = webuntis["lessons"][date].map(lessonToActivity);
            activityList = {
                teacher: {},
                group: {},
                location: {},
                activities: {}
            };
            activities.forEach(function(activity) {
                activity["locations"].forEach(function(loc) {
                    activityList["location"][loc] = activityList["location"][loc] || [];
                    activityList["location"][loc].push(activity["id"]);
                    activityList.activities[activity["id"]] = activity;
                });
                activity["teachers"].forEach(function(loc) {
                    console.log("LOC", loc);
                    activityList["teacher"][loc] = activityList["teacher"][loc] || [];
                    activityList["teacher"][loc].push(activity["id"]);
                    activityList.activities[activity["id"]] = activity;
                });
                activity["groups"].forEach(function(loc) {
                    activityList["group"][loc] = activityList["group"][loc] || [];
                    activityList["group"][loc].push(activity["id"]);
                    activityList.activities[activity["id"]] = activity;
                });
            });
            return activityList;
        };
        //{{{4 currentActivities
        currentActivities = function(aList, aMap, date) {
            var result;
            var pos;
            var datetime;
            datetime = Number(new Date(date));
            pos = binarySearchFn(aList, function(a) {
                return Number(new Date(aMap[a]["end"])) - datetime;
            });
            result = {};
            if (pos - 1 >= 0) {
                result["prev"] = aList[pos - 1];
            }
            if (pos < aList.length) {
                if (aMap[aList[pos]]["start"] > date) {
                    result["next"] = aList[pos];
                } else if (true) {
                    result["current"] = aList[pos];
                    if (pos + 1 < aList.length) {
                        result["next"] = aList[pos + 1];
                    }
                }
            }
            return result;
        };
        //{{{4 prevNextCurrentAll
        prevNextCurrentAll = function(when) {
            var prevNextCurrentEntities;
            var result;
            day = when.slice(0, 10);
            dayActivities = dayData(day);
            result = {
                teacher: {},
                group: {},
                location: {},
                activities: {}
            };
            prevNextCurrentEntities = function(entity) {
                foreach(dayActivities[entity], function(id, aList) {
                    var prevNextCurrentEntry;
                    prevNextCurrentEntry = currentActivities(aList, dayActivities["activities"], when);
                    foreach(prevNextCurrentEntry, function(_, activity) {
                        result["activities"][activity] = dayActivities["activities"][activity];
                    });
                    result[entity][id] = prevNextCurrentEntry;
                });
            };
            prevNextCurrentEntities("teacher");
            prevNextCurrentEntities("group");
            prevNextCurrentEntities("location");
            return result;
        };
        //{{{4 convert webuntis data to api-data
        lessonToActivity = function(lesson) {
            var i;
            var d;
            var result;
            result = {};
            d = new Date(lesson["start"]);
            // TODO: handle time zone
            result["id"] = lesson["untis_id"];
            result["start"] = lesson["start"];
            result["end"] = lesson["end"];
            result["teachers"] = lesson["teachers"].map(function(teacher) {
                teacher = webuntis["teachers"][teacher];
                console.log(teacher);
                return teacher["untis_id"];
            });
            result["locations"] = lesson["locations"].map(function(location) {
                return webuntis["locations"][location]["name"];
            });
            if (lesson["subjects"].length) {
                result["subject"] = webuntis["subjects"][lesson["subjects"][0]]["name"];
            } else if (true) {
                result["subject"] = "undefined";
            }
            result["groups"] = lesson["groups"];
            result["students"] = [];
            i = 0;
            while (i < 25) {
                result["students"].push(String.fromCharCode(65 + i) + webuntis["groups"][pickRandom(lesson.groups)]["untis_id"]);
                i = i + 1;
            }
            return result;
        };
        //{{{4 activities
        if (app.args[1] === "activities") {
            when = (app.args[2] ? (new Date(app.args[2])) : new Date()).toJSON();
            day = when.slice(0, 10);
            console.log(day, Object.keys(webuntis["lessons"]), webuntis["lessons"][day]);
            activities = (webuntis["lessons"][day] || []).map(lessonToActivity).filter(function(activity) {
                return activity.start < when && when < activity.end;
            });
            /*
      html = new HTML();
      html.content(["pre", JSON.stringify(activities, null, 4)]);
      app.done(html);
      */
            console.log(activities);
            app.done({
                activities: activities
            });
            //{{{4 /student
        } else if (app.args[1] === "student") {
            id = app.args[2];
            group = webuntis["groups"][id.slice(1)];
            app.done({
                id: id,
                group: group.name,
                gender: "TBD",
                longevity: "???",
                programme: webuntis["departments"][group["department"]]["name"],
                activity: "not here, - will be implemented (not yet) in /uccorg/teacher/" + id + "/activity, to decouple dynamic data from static data"
            });
            //{{{4 /teacher
        } else if (app.args[1] === "teacher") {
            id = app.args[2];
            teacher = webuntis["teachers"][id];
            app.done({
                id: id,
                gender: "TODO derrive from name: " + teacher["forename"],
                longevity: "???",
                programme: teacher["departments"].map(function(id) {
                    return webuntis["departments"][id]["name"];
                }),
                activity: "not here, - will be implemented (not yet) in /uccorg/teacher/" + id + "/activity, to decouple dynamic data from static data"
            });
            //{{{4 /test
        } else if (app.args[1] === "current") {
            when = (app.args[2] ? (new Date(app.args[2])) : new Date()).toJSON();
            app.done(prevNextCurrentAll(when));
            //{{{4 /test
        } else if (app.args[1] === "test") {
            when = (app.args[2] ? (new Date(app.args[2])) : new Date()).toJSON();
            day = when.slice(0, 10);
            dayActivities = dayData(day);
            act = currentActivities(dayActivities["teacher"][6], dayActivities["activities"], when);
            app.done({
                act: act,
                dayData: dayActivities
            });
            //{{{4 /
        } else if (true) {
            html = new HTML();
            html.content(["h1", "API for UCC organism"]);
            app.done(html);
        }
    });
});
