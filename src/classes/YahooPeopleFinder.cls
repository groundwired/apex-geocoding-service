public virtual class YahooPeopleFinder extends GeocodingService {
/*-----------------------------------------------------------------------------------------------
* Apex class that integrates with the Yahoo People Finder REST API and interprets the JSON it returns
* Written by Sara Chieco
*
* For info see:
* http://developer.yahoo.com/geo/placefinder/
*-----------------------------------------------------------------------------------------------*/

    final string endpoint = 'http://where.yahooapis.com/geocode';
    public integer timeout = 60000;       // in milliseconds - the full minute, baby
    protected string appId; 

    public class YahooJson {
        public YahooResponse resultset;
    }
    
    public class YahooResponse {
        public String version;
        public Integer error;
        public String errorMessage;
        public String locale;
        public Integer quality;
        public Integer found;
        Public List<Result> results;
    }

	public class Result {
		public Integer quality;
		public String latitude;
		public String longitude;
		public String offsetlat;
		public String offsetlon;
		public Integer radius;
		public String name;
		public String line1;
		public String line2;
		public String line3;
		public String line4;
		public String house;
		public String street;
		public String xstreet;
		public String unittype;
		public String unit;
		public String postal;
		public String neighborhood;
		public String city;
		public String county;
		public String state;
		public String country;
		public String countrycode;
		public String statecode;
		public String countycode;
		public String uzip;
		public String hash;
		public Integer woeid;
		public integer woetype;
	}
	
	// default constructor
	public YahooPeopleFinder() { }
	
    // constructor where you specify the credentials
    public YahooPeopleFinder(string yahooAppId, integer tm) {
        appId = yahooAppId;
        timeout = tm;
    }

    public override Boolean providesDatatype(PROVIDER_DATA_TYPES datatype) {
        return ( 
        	datatype == PROVIDER_DATA_TYPES.GEOCODING ||
        	datatype == PROVIDER_DATA_TYPES.REVERSE_GEOCODING ||
        	datatype == PROVIDER_DATA_TYPES.COUNTY_NAME ||
			datatype == PROVIDER_DATA_TYPES.NEIGHBORHOOD
			);
    }

    public override PROVIDER_DATA_TYPES[] getAvailableDatatypes() {
        return new PROVIDER_DATA_TYPES[] { 
        	PROVIDER_DATA_TYPES.GEOCODING, 
        	PROVIDER_DATA_TYPES.REVERSE_GEOCODING, 
        	PROVIDER_DATA_TYPES.COUNTY_NAME, 
        	PROVIDER_DATA_TYPES.NEIGHBORHOOD 
        };           
    }
	
	// UNDONE: does yahoo have any specific limits?
    public override integer getMaxCallsForBatch() { return null; }
	public override integer getMinDelay() { return null; }
    public override integer getAvailableCallouts() { return null; }    	

	/**
	* this method parses out the JSON String returned from the GET and populates the YahooResult objects
	* It returns a list of GeoData objects for all results returned, it will be an empty list if there 
	* are no results returned
	* if there is an error, an exception will be thrown
	*/
	geo_data__c[] callYahoo(string address, string latlng) {
		
		if ((address == null || address.equals('')) && latlng == null)
			throw new GeocodingException('Error when trying to access Yahoo API; no address or location provided.');

		// if we do not already have credentials, query for them
	    if (appId == null) {					
	        if (credentials == null) {    	
	        	geoDataCredentials__c[] providers = 
	        		[SELECT API_Key__c, Name, Password__c, Request_Timeout__c, User_Id__c, endpoint__c 
	                        FROM geoDataCredentials__c
	                        WHERE name like 'Yahoo%' and IsActive__c = true
	                        ORDER BY priority__c LIMIT 1];
		        if (!providers.isEmpty())
		        	credentials = providers[0];
	        }
	        
	        if (credentials != null) {    	
		    	appId = credentials.api_key__c;
		    	if (credentials.request_timeout__c != null) 
		    		timeout = (Integer)credentials.Request_Timeout__c;
	        }
        }
	    	
	    if (appId == null)		
			throw new GeocodingException('You do not have a Yahoo API key configured. Ask your system administrator to create a GeoDataCredential setting named Yahoo and provide the key there.');

	    HttpResponse resp;
	    string js;
	    try {
	        // prepare the request
	        Http h = new Http();
	        HttpRequest req = new HttpRequest();
	        req.setMethod('GET');
	        req.setHeader('Content-Type','application/x-www-form-urlencoded');
	       
	        String postbody = endpoint;
			// set up params
			if (latlng != null && !latlng.equals(''))
			{
				postbody += '?latlng=' + EncodingUtil.urlEncode(latlng, 'UTF-8');
			}
			if (address != null && !address.equals(''))
			{
				postbody += '?q=' + EncodingUtil.urlEncode(address, 'UTF-8');
			}
			postbody += '&appid=' + appId; 			
			req.setEndpoint(postbody+ '&flags=J');
	        req.setTimeout(timeout);
			//system.debug( LOGGINGLEVEL.warn, postBody );
	
	        // execute the request
	        resp = execute( h, req );
	
	        // interpret the response
	        js = getResponseBody( resp );
			//system.debug( LOGGINGLEVEL.warn, js );

        } catch (System.CalloutException ex) {
            throw new GeocodingException('Callout error when trying to communicating with Yahoo API.\n' + ex.getMessage(), ex);
        } catch (exception ex) {
            throw new GeocodingException('Error when trying to access Yahoo API.\n' + ex.getMessage(), ex);
        }
        
		YahooJson yj;
		List<Geo_Data__c> gdList = new List<Geo_Data__c>();
		
        try {
            yj = (YahooJson)(JSON.deserialize(js, YahooJson.class));
        } catch (exception ex) {
            throw new GeocodingException('Error when trying to deserialize JSON data from Yahoo API.\n' + ex.getMessage(), ex);
        }

		if (yj.resultset.error != 0)
		{
			throw new GeocodingException('Error: ' + yj.resultset.error + ': ' + yj.resultset.errorMessage);
		}
		
        YahooResponse yr = yj.resultset;

        Geo_Data__c gd;
        if (!yr.results.isEmpty()) 
        {
        	for (Result result : yr.results)
        	{
		        gd = new Geo_Data__c(
		        	geoJson__c = js,
		        	geoAddressScorePercent__c = result.quality,
		        	geoLat__c = Decimal.valueOf(result.latitude),
		        	geoLong__c = Decimal.valueOf(result.longitude),
		        	City__c = result.city,
		        	State__c = result.statecode,
		        	County__c = result.county,
		        	Zip_postal_code__c = result.postal,
		        	Country_long_name__c = result.country,
		        	Country_short_code__c = result.countrycode,
		        	Neighborhood__c = result.neighborhood,
		        	Street__c = result.house + ' ' + result.street,
		        	geoAddressComplete__c = packAddress(result.house + ' ' + result.street, result.city, result.statecode, result.postal)
		        );
		        gdList.add(gd);
				//system.debug(logginglevel.WARN, gd);        
        	}	
        }
        return gdList;
    }

    public override Geo_Data__c[] getGeodata(string address) {
    	return callYahoo(address, null);
    }

    public override Geo_Data__c getGeodata(Decimal latitude, Decimal longitude) {
    	Geo_Data__c[] gd = callYahoo(null, string.valueOf(latitude) + ', ' + string.valueOf(longitude));
    	return (gd == null || gd.isEmpty()) ? null : gd[0];
    }

    public virtual HttpResponse execute(Http h, HttpRequest request) {
        return h.send(request);
    }

    public virtual string getResponseBody(HttpResponse response) {
        return response.getBody();
    }

    public class GeocodingException extends Exception {

    }
}