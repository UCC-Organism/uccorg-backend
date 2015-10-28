# 2015 uccorg

- mismatch mellem skærme der ikke sker noget på
  - deploy
- researches etc.
- odroids views locally

Observations:

- Inconsistent view in frontend, (same frontend running parallel, - one has the agents from the backend, and the other doesn't)
- Researchers consistently missing in frontend
- Apparently misscoped variables in frontend: `attribAlias`, `targetNode`, `anotherAgent`, and possibly `P`, `lines`, `k`, `v`, and `e`. Might lead to bug/instability
- Repeatable missing agents, after switching view back and forth 

Results:

- Debug networking / find bug with odroids having same ip address
- Make frontend work/build on case-sensitive file systems
- Example screens are the same as the odroids
- Bugfix: researchers
- see git log
- set up api-proxy for testing
- build+hosted version of frontend with fixes for testing


- Status
- årsagen til at forskerne manglede da jeg skulle demo'e det, var at vi 


The 

- New agents might arrive, during the day. 


Have been looking missing agents in the frontend and it turns out:

- Agents without a study programme does not spawn, (and not every agent has a study programme): https://github.com/UCC-Organism/ucc-organism/blob/097936e8bda78b876cdb37cfae6922e652492135/src/ucc/sys/agentSpawnSys.js#L88 (probably fixed)
- Agents that are not part of the initial state, but arrives with events later, are silently ignored, instead of added: https://github.com/UCC-Organism/ucc-organism/blob/097936e8bda78b876cdb37cfae6922e652492135/src/ucc/data/Client.js#L107 (fixed)
- Something is odd about the data model, ie. the type/kind of agent seems to be expected to be stored in `programme`, which in the data represent the study program. https://github.com/UCC-Organism/ucc-organism/097936e8bda78b876cdb37cfae6922e652492135/master/src/ucc/sys/agentSpawnSys.js#L25
- Programme does not get assigned. https://github.com/UCC-Organism/ucc-organism/blob/097936e8bda78b876cdb37cfae6922e652492135/src/ucc/data/Client.js#L78 (fixed)

I did some quick hacks/workarounds which make the researcher agents etc. appear in frontend, but it does not process the type of agent etc., so needs to be worked through, and it would probably be good to take a general look at the data model.


Also spotted:

- Agents disappear when switching example screens, - indicates some instability in the data model, that could lead to other errors on the actual clients
- robustness for lost connectivity? Ie. if faye disconnects and reconnects, events during the disconnect is lost, should probably re-initialise agents based on current-state
- Many leaks to global scope (missing `var`), which may lead to unexpected bugs, - I'd recommend running some tools to identify scope leaks, and fixing those. ie. https://github.com/UCC-Organism/ucc-organism/blob/097936e8bda78b876cdb37cfae6922e652492135/src/ucc/sys/agentFlockingSys.js#L69 https://github.com/UCC-Organism/ucc-organism/blob/097936e8bda78b876cdb37cfae6922e652492135/src/ucc/stores/MapStore.js#L142 ...  (partly fixed)
- Toilets: "random toilet" "random closet" for janitor, vs "toilet" for going to toilet, - probably some issues.
- Issues running frontend: it only build/bundled on case-insensitive file systems (fixed, so that works now), and `npm run watch` fails.


----

Sporadic connectivity to odroids. Both the faye-connection, and the requests for `client-config` (which should happen every 30s) happens rarely and at random, except from 10.251.25.32 and 10.251.25.46. To see if it was a network issue, I ping'ed 10.251.25.32-10.251.25.64 every minute for ten minutes, with the following result:

- `10.251.25.32`(=localhost) and `10.251.25.46`(the other mac mini) replied to all 10 pings
- `10.251.25.34` replied to three of the pings, `10.251.25.50` replied to two of the pings, and `10.251.25.52`, `10.251.25.53`, `10.251.25.58`, and `10.251.25.60` replied to one ping each.
- none of the others replied

So apparently something is failing with the network connectivity of the odroids.

    /data/misc/smsc95xx_mac_addr


