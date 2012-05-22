public virtual with sharing class Cicero extends GeocodingService {
/*-----------------------------------------------------------------------------------------------
* Apex class that integrates with the Cicero REST API and interprets the JSON it returns
* Written by Evan Callahan
*
* For info see:
*   http://www.azavea.com/products/cicero/
*   http://www.azavea.com/products/cicero/features/api/rest-api/
*   http://cicero.azavea.com/docs/getting_started.html
*   http://cicero.azavea.com/docs/
*-----------------------------------------------------------------------------------------------*/

    public static string currentToken;
    public static integer userId;	
	final integer maxCallsForBatch = 9;
	final string taskQueueType = 'Cicero';

	// endpoints
	private static final String publicEndpoint = 'rpc.geocoder.us/service/csv';
	private static final String authEndpoint = 'geocoder.us/member/service/csv/geocode';

	protected string username;
	protected string password;
	public Integer timeout = 60000;		// the full minute - cicero can be slowish
	
	/*
	*  Data structures to match the JSON response expected from Cicero
	*/
	public class CiceroJson {
		CiceroResponse response;
	}

	public class CiceroResponse {
	    public list<string> errors;
	    public list<string> messages;
		CiceroResult results;
	}
	
    public class CiceroResult {
    	public ResultCount count;
        public list<Candidate> candidates;
        public list<District> districts;
        public list<Official> officials;
    }

	public class Addresses {
		public String county;
		public String postal_code;
		public String phone_2;
		public String phone_1;
		public String fax_1;
		public String city;
		public String fax_2;
		public String state;
		public String address_1;
		public String address_2;
		public String address_3;
	}

	public class Representing_country {
		public String status;
		public String name_short;
		public String gmi_3;
		public String valid_from;
		public String name_short_iso;
		public String name_short_local;
		public Boolean is_staging;
		public Object valid_to;
		public Integer id;
		public Integer sk;
		public String name_short_un;
		public String fips;
		public String last_update_date;
		public String iso_3;
		public String iso_2;
		public Integer iso_3_numeric;
		public String name_long_local;
		public String name_long;
	}

	public class Government {
		public String city;
		public String state;
		public String name;
		public Representing_country country;
		public String notes;
		public String type;
	}

	public class Committees {
		public String valid_from;
		public String description;
		public Boolean is_staging;
		public Object valid_to;
		public Integer sk;
		public String last_update_date;
		public Integer id;
	}

	public class Official {
		public String last_name;
		public List<Addresses> addresses;
		public Office office;
		public String initial_term_start_date;
		public String current_term_start_date;
		public String last_update_date;
		public String salutation;
		public Integer id;
		public String photo_origin_url;
		public String middle_initial;
		public String first_name;
		public String valid_from;
		public List<Committees> committees;
		public List<String> notes;
		public List<String> identifiers;
		public String name_suffix;
		public String valid_to;
		public Integer sk;
		public String term_end_date;
		public List<String> urls;
		public String party;
		public List<String> email_addresses;
	}

	public class Chamber {
		public String election_frequency;
		public String name;
		public String term_length;
		public Government government;
		public String url;
		public String type;
		public String notes;
		public String last_update_date;
		public Integer official_count;
		public Boolean has_geographic_representation;
		public String redistricting_rules;
		public Boolean is_chamber_complete;
		public String remarks;
		public String contact_email;
		public String legislature_update_date;
		public String inauguration_rules;
		public String name_native_language;
		public String election_rules;
		public String contact_phone;
		public Integer id;
		public String name_formal;
	}

	public class Office {
		public String valid_from;
		public District district;
		public Representing_country representing_country;
		public String representing_state;
		public String notes;
		public String title;
		public Object valid_to;
		public Integer sk;
		public Chamber chamber;
		public String last_update_date;
		public String election_rules;
		public Integer id;
		public String representing_city;
	}

	public class TokenResponse {
	    public string token;
	    public integer user;
	    public boolean success;
	}

    public class ResultCount {
        public integer total;
    }
    
    public class Candidate {
        public ResultCount count;
        public string confidence;
        public integer wkid;
        public string entity;
        public string locator;      // e.g. "interpolation"
        public decimal score; 
        public string match_addr;
        public decimal y;
        public decimal x;
        public string geoservice;   // e.g. "Bing"
        public list<District> districts;
        public list<Official> officials;
    }

    public virtual class District {
        public string district_type;  // e.g. "NATIONAL_LOWER"
        public string city;
        public string valid_from;
        public string country;        // 2-letter country code
        public string district_id;
        public string valid_to;
        public string label;
        public integer sk;
        public string subtype;        // e.g. "LOWER"
        public string state;
        public string last_update_date;
        public DistrictData data;
        public integer id;
    }

	public class DistrictData {
		public String FUNCSTAT;
		public String METDIVFP;
		public Double AWATER;
		public String COUNTYFP;
		public String MTFCC;
		public String CLASSFP;
		public String STATEFP;
		public String CBSAFP;
		public String INTPTLAT;
		public String NAME;
		public String INTPTLON;
		public String LSAD;
		public String GEOID;
		public String NAMELSAD;
		public String CSAFP;
		public Double ALAND;
		public String COUNTYNS;
	}

    public override Boolean providesDatatype(PROVIDER_DATA_TYPES datatype) {
        return ( 
        	datatype == PROVIDER_DATA_TYPES.GEOCODING ||
        	datatype == PROVIDER_DATA_TYPES.NATIONAL_LEGISLATIVE || 
        	datatype == PROVIDER_DATA_TYPES.STATE_LEGISLATIVE || 
        	datatype == PROVIDER_DATA_TYPES.COUNTY_NAME ||
        	datatype == PROVIDER_DATA_TYPES.WATERSHED ||
        	datatype == PROVIDER_DATA_TYPES.SCHOOL_DISTRICT ||
        	datatype == PROVIDER_DATA_TYPES.CENSUS_DISTRICT 
			);
    }

    public override PROVIDER_DATA_TYPES[] getAvailableDatatypes() {
        return new PROVIDER_DATA_TYPES[] { 
        	PROVIDER_DATA_TYPES.GEOCODING, 
        	PROVIDER_DATA_TYPES.NATIONAL_LEGISLATIVE, 
        	PROVIDER_DATA_TYPES.STATE_LEGISLATIVE, 
        	PROVIDER_DATA_TYPES.COUNTY_NAME, 
        	PROVIDER_DATA_TYPES.WATERSHED, 
        	PROVIDER_DATA_TYPES.SCHOOL_DISTRICT,
        	PROVIDER_DATA_TYPES.CENSUS_DISTRICT 
        };           
    }
    
	// default constructor
	public Cicero() { }
	
    // constructor where you specify the credentials
    public Cicero(string un, string pw, integer tm) {
        username = un;
        password = pw;
        timeout = tm;
    }

	public override Geo_Data__c[] getGeodata(String addr) {

		List<Geo_Data__c> locations = new List<Geo_Data__c>();

		// call to geocode the address
		string js = callCicero( 'legislative_district', new map<string, string>{ 'search_loc' => addr } );
		
		CiceroResult cr = interpretJson( js );
		
		// create a geodata for each address "candidate" returned by cicero        	        
        for (Candidate cc : cr.candidates) {
	        Geo_Data__c d = createGeoData( js, cc.match_addr, cc.score, cc.y, cc.x, cc.districts );
			locations.add( d );
        }

		// for each extra data type requested, make another call to get additional data for the top candidate
		if (!locations.isEmpty() && requestedDatatypes != null) {
			for (PROVIDER_DATA_TYPES dt : requestedDatatypes) {
				geo_data__c gd;
				if (dt == PROVIDER_DATA_TYPES.COUNTY_NAME)
					gd = getGeodata(locations[0].geoLat__c, locations[0].geoLong__c, 'COUNTY');
				if (dt == PROVIDER_DATA_TYPES.WATERSHED)
					gd = getGeodata(locations[0].geoLat__c, locations[0].geoLong__c, 'WATERSHED');
				if (dt == PROVIDER_DATA_TYPES.SCHOOL_DISTRICT)
					gd = getGeodata(locations[0].geoLat__c, locations[0].geoLong__c, 'SCHOOL');
				if (dt == PROVIDER_DATA_TYPES.CENSUS_DISTRICT)
					gd = getGeodata(locations[0].geoLat__c, locations[0].geoLong__c, 'CENSUS');

				// merge new data into the first candidate
				if (gd != null) {
					//system.debug(logginglevel.warn, gd);					
					mergeData(locations[0], gd);
				}
			}
		}
		return locations;
	}

	public override Geo_Data__c getGeodata(Decimal lat, Decimal lng) {
		
		// call for legislative district data
		string js = callCicero( 'legislative_district', 
			new map<string, string>{ 'lat' => string.valueOf(lat), 'lon' => string.valueOf(lng) } );

		CiceroResult cr = interpretJson( js );        	        
	    Geo_Data__c d = createGeoData( js, null, null, lat, lng, cr.districts );
	    return d;
	}
		
	public Geo_Data__c getGeodata(Decimal lat, Decimal lng, string districtType) {
    	string js = callCicero( 'nonlegislative_district', 
    		new map<string, string>{ 'lat' => string.valueOf(lat), 'lon' => string.valueOf(lng), 'type' => districtType } );

		CiceroResult cr = interpretJson( js );        	        
	    Geo_Data__c d = createGeoData( js, null, null, lat, lng, cr.districts );
	    return d;
	}

	private CiceroResult interpretJson( string js ) {
		// interpret the json response
		CiceroJson cj;
        try {
            cj = (CiceroJson)(JSON.deserialize(js, CiceroJson.class));
        } catch (exception ex) {
            throw new GeocodingException('Error when trying to deserialize JSON data from Cicero API.\n' + ex.getMessage(), ex);
        }
        return cj.response.results;		
	}

	public Geo_Data__c createGeoData(string js, string match_addr, decimal score, decimal lat, decimal lng, list<District> districts) {
		Geo_Data__c d = new Geo_Data__c(
        	geoJson__c = js,
        	geoAddressComplete__c = match_addr,
        	geoAddressScorePercent__c = score,
        	geoLat__c = lat,
        	geoLong__c = lng
        );
        for (District cd : districts) {
        	if (cd.city != null) d.city__c = cd.city;
        	if (cd.state != null) d.state__c = cd.state;
        	if (cd.country != null) d.country_short_code__c = cd.country;
        	if (cd.district_type.startsWith('NATIONAL_EXEC') && cd.label != null)
        		d.country_long_name__c = cd.label; 
	        	
        	if (cd.district_type.startsWith('NATIONAL_LOWER') && cd.district_id != null)
        		d.federal_district__c = integer.valueOf(cd.district_id); 
			
        	if (cd.district_type.startsWith('STATE_UPPER') && cd.district_id != null)
        		d.upper_district__c = integer.valueOf(cd.district_id); 

        	if (cd.district_type.startsWith('STATE_LOWER') && cd.district_id != null)
        		d.lower_district__c = integer.valueOf(cd.district_id); 

        	if (cd.district_type == 'COUNTY')
		        d.county__c = (cd.data.name != null) ? cd.data.name : cd.label;
		        
        	if (cd.district_type == 'WATERSHED')
		        d.watershed__c = cd.label;

        	if (cd.district_type == 'SCHOOL')
		        d.school_district__c = cd.label;

        	if (cd.district_type == 'CENSUS' && d.census_district__c != null)
		        d.census_district__c = cd.label;
        }
        return d;
	}	

    public boolean getToken() {
	
		// if we do not already have credentials, query for them
	    if (username == null || password == null) {					
	        if (credentials == null) {    	
	        	geoDataCredentials__c[] providers = 
	        		[SELECT API_Key__c, Name, Password__c, Request_Timeout__c, User_Id__c, endpoint__c 
	                        FROM geoDataCredentials__c
	                        WHERE name like 'Cicero%' and IsActive__c = true
	                        ORDER BY priority__c LIMIT 1];
		        if (!providers.isEmpty())
		        	credentials = providers[0];
	        }
	        
	        if (credentials != null) {    	
		    	username = credentials.user_id__c;
		    	password = credentials.password__c;
		    	if (credentials.request_timeout__c != null) 
		    		timeout = (Integer)credentials.Request_Timeout__c;
	        }
        }
	    	
	    if (username == null || password == null)		
			throw new GeocodingException('You do not have credentials configured for Cicero. Ask your system administrator to create a GeoDataCredential setting named Cicero.');

        HttpResponse resp;
        TokenResponse tr; 
        string js;
        try {
            // prepare the request
            Http h = new Http();
            HttpRequest req = new HttpRequest();
            req.setMethod('POST');
            req.setHeader('Content-Type','application/x-www-form-urlencoded');
            req.setEndpoint('https://cicero.azavea.com/v3.1/token/new.json');
            req.setTimeout(timeout);
            req.setBody('username=' + username + '&password=' + password);

            // execute the request
            resp = execute( h, req );

            // interpret the response
            js = getResponseBody( resp, 'token' );
			// system.debug( LOGGINGLEVEL.warn, js );
			// SAMPLE: {"token": "21q-df53da3e9fcd1ce221f1", "user": 99, "success": true}
	
        } catch (System.CalloutException ex) {
            throw new GeocodingException('Callout error when trying to communicating with Cicero API.\n' + ex.getMessage(), ex);
        } catch (exception ex) {
            throw new GeocodingException('Error when trying to log in to Cicero API.\n' + ex.getMessage(), ex);
        }
	
        try {
            tr = (TokenResponse)(JSON.deserialize(js, TokenResponse.class));
        } catch (exception ex) {
            throw new GeocodingException('Error when trying to deserialize JSON data from Cicero API.\n' + ex.getMessage(), ex);
        }
	        
        if (tr != null && tr.success) {
            currentToken = tr.token;
            userid = tr.user;
            return true;
        } else {
        	return false;
	    }
    }

    public virtual string callCicero( string requestType, map<string, string> params ) {

        if (requestType == null)
            throw new GeocodingException('Error communicating with Cicero: Request type was not provided.');

        if (currentToken == null || userid == null)
            getToken();

        if (currentToken == null || userid == null)
            throw new GeocodingException('Cicero login credentials, token, or user code were not provided and could not be found.');

        // set up params
        string postBody = 'user=' + userid + '&token=' + currentToken + '&f=json';
        if (params != null) {
            for ( string paramName : params.keySet() ) {
                postBody += '&' + paramName + '=' + EncodingUtil.urlEncode(params.get(paramName), 'UTF-8');
            }
        }

        string js;
        HttpResponse resp;
        try {
            // prepare the request
            // SAMPLE: http://cicero.azavea.com/v3.1/legislative_district?search_loc=32+Molesworth+St,+Wellington&user=99&token=21q-df53da3e9fcd1ce221f1&f=json
            Http h = new Http();
            HttpRequest req = new HttpRequest();
            req.setMethod('POST');
            req.setHeader('Content-Type','application/x-www-form-urlencoded');
            req.setEndpoint('https://cicero.azavea.com/v3.1/' + requestType + '?' + postBody);
            req.setTimeout(timeout);
            req.setBody(postBody);

            // execute the request
            resp = execute( h, req );

            // interpret the response
            js = getResponseBody( resp, requestType );
			//system.debug( LOGGINGLEVEL.warn, js );
			
        } catch (System.CalloutException ex) {
            throw new GeocodingException('Callout error when trying to communicate with Cicero API.\n' + ex.getMessage(), ex);
        } catch (exception ex) {
            throw new GeocodingException('Error when trying to communicate with Cicero API.\n' + ex.getMessage(), ex);
        }

		// check for a bad response
		if (resp.getStatusCode() != 200) {
			throw new GeocodingException('Callout error when trying to communicate with Cicero API.\n' + resp.getStatus());
		}
        
		// check for an error
		map<string, object> r1 = (map<string, object>)(JSON.deserializeUntyped(js));
		map<string, object> res = (map<string, object>)(r1.get('response'));
		list<object> errors = (list<object>)(res.get('errors'));
		if (!errors.isEmpty())
			throw new GeocodingException( 'Cicero API Error.\n' + (string)(errors[0]) );
        
        return js; 
    }

	public override integer getMaxCallsForBatch() { return maxCallsForBatch; }

	public override integer getMinDelay() { return null; }

    public override integer getAvailableCallouts() {    	
    	integer bal;
		Pattern balancePattern = Pattern.compile('.*?"credit_balance":\\W*?(\\d+).*?');
    	string js = callCicero( 'account/credits_remaining', new map<string, string>() );
		//system.debug(logginglevel.warn, js);
    	
		Matcher balanceMatcher = balancePattern.matcher(js);
		
		if (balanceMatcher.matches()) {
			string bs = balanceMatcher.group(1);
			bal = integer.valueOf(bs);
		}	
		
		return bal;
    }

    public list<Official> getDataForOfficials( string address ) {
    	string js = callCicero( 'official', new map<string, string>{ 'search_loc' => address } );
		CiceroResult cr = interpretJson( js );
		return 
			(cr != null && cr.candidates != null && !cr.candidates.isEmpty() && cr.candidates[0].officials != null) ?
				cr.candidates[0].officials : 
			(cr != null && cr.officials != null) ? 
				cr.officials : 
			null;
    }

    public list<Official> getDataForOfficials( decimal lat, decimal lng ) {
    	string js = callCicero( 'official', new map<string, string>{ 'lat' => string.valueOf(lat), 'lon' => string.valueOf(lng) } );
		CiceroResult cr = interpretJson( js );        	        
        return cr.officials;
    }

    public virtual HttpResponse execute(Http h, HttpRequest request) {
        return h.send(request);
    }

    public virtual string getResponseBody(HttpResponse response, string requestType) {
        return response.getBody();
    }

}