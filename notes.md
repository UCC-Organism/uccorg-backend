# Status from sprint 2015-10-28

I looked into the following:

- Missing agents in frontend
- Network issue
- Misc changes

Changes: https://github.com/UCC-Organism/ucc-organism/compare/53fb1c50210fe0bccbff2dbd5477ffbd623276da...b48d16b6a15f03609d7036b9e41872ddd87c105e

## Missing agents in frontend

Researchers etc. was missing in the visualisation. There turned out to be several reasons for this:

- Seemed like the intention was to assign a hardcoded `programme` to certain kinds of agents, but this never happened due to bug
- If events had agents which was not in initial state, the agents was not created, but silently ignored instead.
- Agents without `programme` was never spawned.

*Conclusion:* workaround implemented so agents are now created. 

## Network issue

This one was difficult to debug.

Initial indications of something very wrong was that `faye` did not stay connected, and the client http-requests was sporadic from semi-random clients. Looking into the frontend code, it was clear that it should request a `client-config` every 30s. After adding extra logging code to the backend, it was clear that two clients requested the `client-config` consistently, and then there were a couple of requests in between. Futher exploration was to send a ping to all the clients simultanous, in which case there were typically 2-4 replies, two of them consistently the same, and the rest varying with different probability. The two working clients turned out to be the Mac Minis, and the rest was the odroids. Pinging the odroid that seemed most common every 10ms indicated that there were time windows when it worked, and many where it didn't work. A reason for this could be that the routing tables was changing/ messed up, for example if they all had the same MAC-address. This turned out to be the case.

Next: how to change the mac address, when the network is bad. Turns out that the MAC-address on the odroid is initialised at first boot, and is stored in `/data/misc/smsc95xx_mac_addr`. A solution would be to ssh in to the odroid, remove the mac-address, and reboot the device, - but the network is too unstable to be able to ssh due to the duplicate MAC-addresses. Solution: first identify which odroid is most likely possible to reach, by pinging all odroids with wrong mac address, and see where an answer actually comes through. Then rapidly ping that odroid, such that the network packages that flow through the network makes the route to this odroid more likely to be the current one in the routing table. After this: some attempts to ssh to that odroid and execute `rm /data/misc/smsc95xx_mac_addr; toolbox restart` was sometimes successful within the retry/timeout of the TCP-connection, and the MAC-addresses got slowly reset.

*Conclusion:* Problem was due to duplicate MAC-address on odroids. This is fixed for most odroids now (there were a couple that I couldn't connect to, which still have the old(same) MAC-address). When new images are copied on the odroid it should _not_ contain `/data/misc/smsc95xx_mac_addr`, as this needs to be unique on each odroid, and is randomly generated on boot if it is not there. 

## Misc changes

- The example screens is now the same as the actual odroid screens, so it is possible to compare the visualisation
- Less pollution of global scope
- Build now working on case-sensitive file systems

Temporary changes during for debugging:

- api-server/dashboard and frontend-build temporarily available on http://ssl.solsort.com:8080/ and http://ssl.solsort.com/uccorg/
- extra more logging in backend(not committed) + script for ping/arp clients

## Observations/tasks/issues/thoughts

- The errors with the missing agents was all around the `programme` property of the agent. The `programme` in the frontend seems not only to be the study programme, but also mixing the type/kind of the agent etc. - might be good to look into this aspect of the data model, as it is probably intended as the kind of agent and not just study programme. The current fixes just preserve existing behaviour.
- Agents disappear after changing forth and back between example screens in user interface (on top of live data).
- It looks as if it does not handle lost connectivity, ie. when faye reconnects it might make sense to reload current-state, as events might be lost during disconnect. (Was critical before network issue was debugged, - not that critical anymore).
- Variables leaks to global scope, etc. - linting with jshint or similar might improve code, and possibly find errors
- `npm run watch` fails on non-mac
- Not sure if "random toilet" and "random closet" location for janitor works in the frontend.
