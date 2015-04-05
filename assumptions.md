# Assumptions about external data sources

Data sources

- webuntis access via an API-key
  - `/api/[locations|subjects|lessons|groups|teachers|departments]` returns json array of ids
  - `/api/locations/$ID` returns json object with: untis_id, capacity, longname
  - `/api/subjects/$ID` returns json object with: untis_id, name, longname, alias
  - `/api/lessons/$ID` returns json object with: untis_id, start, end, subjects, teachers, groups, locations, course
  - `/api/groups/$ID` returns json object with: untis_id, name, alias, schoolyear, longname, department
    - The alias must match the "Holdnavn" in  the mssql database
  - `/api/teachers/$ID` returns json object with: untis_id, name, forename, longname, departments
    - The name must match "Initialer" in the mssql-database
  - `/api/departments/$ID` returns json object with: untis_id, name, longname
- ucc mssql database - accessible via stored procedures on the server: 
  - GetStuderendeHoldCampusNord: Holdnavn (=groups.alias), Studienummer
  - GetAnsatteHoldCampusNord: Holdnavn, Initialer
  - GetAnsatteCampusNord: Initialer, Afdeling, Køn
    - There must be an entry for each teacher from webuntis, with Initialer the same as teacher.name
  - GetStuderendeCampusNord: Studienummer, Afdeling, Køn(0/1 -> agent.gender), Fødselsdag(DDMMYY -> agent.gender)
  - GetHoldCampusNord: Afdeling, Holdnavn, Beskrivelse, StartDato, SlutDato
    - There should be a hold for each Holdnavn for ansatte/studerende, and also one matching the every `groups.alias` from webuntis
- google-calendar returns ical data parseable by rrule, with `SUMMARY` as the title of the event
- rejseplanen-api `http://xmlopen.rejseplanen.dk/bin/rest.exe/arrivalBoard?id=8600683&date=...` returns schedule with arrivals in the form `<Arrival name="..." type="..." date="..." origin="...">`.
