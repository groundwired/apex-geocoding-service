public virtual with sharing class GoogleGeoCode extends GeocodingService {
/*-----------------------------------------------------------------------------------------------
* Apex class that integrates with the Google REST API and interprets the JSON it returns
* Written by Sara Chieco and Evan Callahan
*
* For info see:
* https://developers.google.com/maps/documentation/geocoding/
*-----------------------------------------------------------------------------------------------*/

	// UNDONE: we should look at trying to move google geocoding to the client - on the Salesforce server
	// will quickly run out of API calls.  Would require some kind of component that sends the data via
	// javascript remoting. May not be possible in this service implementation - certainly could not happen
	// on a schedule in the background.

    final string endpoint = 'https://maps.googleapis.com/maps/api/geocode/json';
    final integer timeout = 5000;       // in milliseconds - 5 second default

	/* GOOGLE Status Codes:
	    "OK" indicates that no errors occurred; the address was successfully parsed and at least one geocode was returned.
	    "ZERO_RESULTS" indicates that the geocode was successful but returned no results. This may occur if the geocode was passed a non-existent address or a latlng in a remote location.
	    "OVER_QUERY_LIMIT" indicates that you are over your quota.
	    "REQUEST_DENIED" indicates that your request was denied, generally because of lack of a sensor parameter.
	    "INVALID_REQUEST" generally indicates that the query (address or latlng) is missing.
	*/	
	public class GoogleJson {
		public List<GoogleResult> results;
		public String status;
	}

	public class AddressComponent {
		public String long_name;
		public String short_name;
		public List<String> types;
	}

	public class Location {
		public Double lat;
		public Double lng;
	}

	public class Geometry {
		public Location location;
		public String location_type;
		public Viewport viewport;
	}

	public class GoogleResult {
		public List<AddressComponent> address_components;
		public String formatted_address;
		public Geometry geometry;
		public List<String> types;
	}

	public class Viewport {
		public Location northeast;
		public Location southwest;
	}

    public override Boolean providesDatatype(PROVIDER_DATA_TYPES datatype) {
        return ( 
        	datatype == PROVIDER_DATA_TYPES.GEOCODING ||
        	datatype == PROVIDER_DATA_TYPES.COUNTY_NAME
			);
    }

    public override PROVIDER_DATA_TYPES[] getAvailableDatatypes() {
        return new PROVIDER_DATA_TYPES[] { 
        	PROVIDER_DATA_TYPES.GEOCODING, 
        	PROVIDER_DATA_TYPES.COUNTY_NAME 
        };           
    }

	// UNDONE: not sure how to express the google limitations - truth is, they are out of our control
    public override integer getMaxCallsForBatch() { return null; }
	public override integer getMinDelay() { return null; }
    public override integer getAvailableCallouts() { return null; }    	

    public override Geo_Data__c[] getGeodata(string address) {
    	string js = callGoogleGeo(address, null);
    	return interpretGoogleGeoCodeJson( js );
    }

    public override Geo_Data__c getGeodata(Decimal latitude, Decimal longitude) {
    	string js = callGoogleGeo(null, string.valueOf(latitude) + ', ' + string.valueOf(longitude));
    	Geo_Data__c[] gd = interpretGoogleGeoCodeJson( js ); 
		return (gd == null || gd.isEmpty()) ? null : gd[0];
    }

    public String callGoogleGeo(String address, String latlng) {

		if ((address == null || address.equals('')) && (latlng == null || latlng.equals('')))
		{
			throw new GeocodingException('Error when trying to access Google API.\n');
		}
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
				postbody += '?address=' + EncodingUtil.urlEncode(address, 'UTF-8');
			}
			postbody += '&sensor=false';
			
			req.setEndpoint(postbody);
	        req.setTimeout(timeout);
	system.debug( LOGGINGLEVEL.warn, postBody );
	
	        // execute the request
	        resp = execute( h, req );
	
	        // interpret the response
	        js = getResponseBody( resp );
	system.debug( LOGGINGLEVEL.warn, js );

        } catch (System.CalloutException ex) {
            throw new GeocodingException('Callout error when trying to communicating with Google API.\n' + ex.getMessage(), ex);
        } catch (exception ex) {
            throw new GeocodingException('Error when trying to access Google API.\n' + ex.getMessage(), ex);
        }
        return js;        
    }

	public virtual Geo_Data__c[] interpretGoogleGeoCodeJson( string js ) {
       	geo_data__c[] gd = new geo_data__c[0];

		GoogleJson gj;
        try {
            gj = (GoogleJson)(JSON.deserialize(js, GoogleJson.class));
        } catch (exception ex) {
            throw new GeocodingException('Error when trying to deserialize JSON data from Google API.\n' + ex.getMessage(), ex);
        }

		if (gj.status != 'OK' && gj.status != 'ZERO_RESULTS')
			throw new GeocodingException('Google API Error: ' + gj.status);

		if (gj.results != null) { 
	        for (GoogleResult gr : gj.results) {
		    	Geo_Data__c d = new Geo_Data__c(
		        	geoJson__c = js,
		        	geoAddressComplete__c = gr.formatted_address,
		        	geoLat__c = Decimal.valueOf(gr.geometry.location.lat),
		        	geoLong__c = Decimal.valueOf(gr.geometry.location.lng)
		        );
		        string street;
		        string route;
		        for (AddressComponent ac : gr.address_components) {
		        	if (ac.types != null && !ac.types.isEmpty()) {
			        	if (ac.types[0] == 'street_number') 
			        		street = ac.long_name;
			        	if (ac.types[0] == 'route') 
			        		route = ac.long_name;
			        	if (ac.types[0] == 'locality')
			        		d.City__c = ac.long_name;
			        	if (ac.types[0] == 'administrative_area_level_1') 
			        		d.State__c = ac.short_name;
			        	if (ac.types[0] == 'postal_code')
			        		d.Zip_postal_code__c = ac.long_name;
			        	if (ac.types[0] == 'country') 
			        		d.Country_long_name__c = ac.long_name;
			        	if (ac.types[0] == 'country') 
			        		d.Country_short_code__c = ac.short_name;
			        	if (ac.types[0] == 'administrative_area_level_2') 
			        		d.County__c = ac.long_name;
		        	}
		        	d.Street__c = (((street != null) ? street : '') + ' ' + ((route != null) ? route : '')).trim();
		        }
		        gd.add(d);
	        }
		}
		system.debug(logginglevel.WARN, gd);        
        return gd;
    }

    public virtual HttpResponse execute(Http h, HttpRequest request) {
        return h.send(request);
    }

    public virtual string getResponseBody(HttpResponse response) {
        return response.getBody();
    }

}