
url = "http://traindata.dsb.dk/stationdeparture/Service.asmx?op=GetStations"
SOAPAction = "http://schemas.dsb.dk/StationDeparture/2010/01/GetStations"
soapreq = """
  <?xml version="1.0" encoding="utf-8"?>
  <soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
    <soap:Body>
      <GetStations xmlns="http://schemas.dsb.dk/StationDeparture/2010/01" />
    </soap:Body>
  </soap:Envelope>
"""

###
###
uic = "8600683"
url = "http://traindata.dsb.dk/stationdeparture/Service.asmx?op=GetStationQueue"
SOAPAction = "http://schemas.dsb.dk/StationDeparture/2010/01/GetStationQueue"
soapreq = """
  <?xml version="1.0" encoding="utf-8"?>
  <soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
    <soap:Body>
       <GetStationQueue xmlns="http://schemas.dsb.dk/StationDeparture/2010/01">
         <request>
           <UICNumber>#{uic}</UICNumber>
         </request>
       </GetStationQueue>
    </soap:Body>
  </soap:Envelope>
"""
  
uic = "8600683"
url = "http://xmlopen.rejseplanen.dk/bin/rest.exe/arrivalBoard?id=8600683&date=19.02.14&time=15:30"
(require "request") {
    url: url
    method: "POST"
    headers:
      "Content-Type": "text/xml; charset=utf-8"
      "Content-Length": soapreq.length
      SOAPAction: SOAPAction
    body: soapreq
  }, (err, result, body) ->
    console.log body

