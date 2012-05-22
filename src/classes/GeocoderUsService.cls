public with sharing class GeocoderUsService extends GeocodingService {
/*-----------------------------------------------------------------------------------------------
* interface to geocoder.us web service
* give it any address, get back latitude, longitude, and a parsed address
*
* if you do not provide a username and password for the geocoder service, the class uses the
* free version which is for non-commercial use only.  please note that you can only use the free
* version once every 15 seconds from a given IP address
*
* @author Evan Callahan, Todd Reasinger
-----------------------------------------------------------------------------------------------*/

	private static final Integer DEFAULT_TIMEOUT = 2000;

	// endpoints
	private static final String publicEndpoint = 'rpc.geocoder.us/service/csv';
	private static final String authEndpoint = 'geocoder.us/member/service/csv/geocode';
    
	protected String username;	
	protected String password;
	public Integer timeout = DEFAULT_TIMEOUT;

	// properties
	public string response { get; private set; }
	public string error { get; private set; }
	public List<Geo_Data__c> locations { get; private set; }
	
	// need to special case the test
	final string testResp = '47.618967,-122.348993,123 4th Ave N,Seattle,WA,98109'; 
	
	// track this so we don't call the services once we are shut out
	boolean outOfGeocoderRequests = false;

	// constructors
	public GeocoderUsService() {
	}

	public override Geo_Data__c[] getGeodata(String address) {
        	
		// if we do not already have credentials, query for them
        if (credentials == null) {
        	geoDataCredentials__c[] providers = 
        		[SELECT API_Key__c, Name, Password__c, Request_Timeout__c, User_Id__c, endpoint__c 
                        FROM geoDataCredentials__c
                        WHERE name like 'GeocoderUs%' and IsActive__c = true
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

		// initialize		
		locations = new List<Geo_Data__c>();
		response = error = null;

		if (address != null && address.trim() != '' && !outOfGeocoderRequests) {
			String configuredEndpoint = (credentials != null && credentials.endpoint__c != null) ? credentials.endpoint__c : (username == null ? authEndpoint : publicEndpoint);
            String endpoint = ((username != null && password != null) ? 
            				  (EncodingUtil.URLEncode(username, 'UTF-8') + ':' + 
            					EncodingUtil.URLEncode(password, 'UTF-8') + '@' ) : '') 
            					+ configuredEndpoint; 

			Http h = new Http();
            HttpRequest req = new HttpRequest();
            req.setEndpoint('http://' + endpoint + '?address=' + EncodingUtil.URLEncode(address, 'UTF-8'));
            req.setMethod('GET');            	
            req.setTimeout(timeout);    	            
            
            try {
	        	HttpResponse resp;
	            Integer status;
				if (Test.isRunningTest()) {
					response = testResp;
					status = 200;					
				} else {					
		            resp = h.send(req);
					response = resp.getBody();
					status = resp.getStatusCode();
				}								
				if (status == 200) {
					if (response != null) {
						for (string addr : response.split('\n')) {
							string[] parsed = addr.split(',');
							if (parsed.size() == 6) {
								
								Geo_Data__c gd = new Geo_Data__c();
								gd.geoLat__c = Decimal.valueOf(parsed[0]);
								gd.geoLong__c = Decimal.valueOf(parsed[1]);
								gd.Street__c = parsed[2];
								gd.City__c = parsed[3];
								gd.State__c = parsed[4];
								gd.Zip_Postal_Code__c = parsed[5];
								locations.add(gd);
								
							}
						}
						if (locations.isEmpty())
							error = 'Response from geocoding service: ' + response;						
					} else {
						error = 'No response from geocoding service.';
					}
				} else {
					error = 'Unexpected response from geocoding service (STATUS ' + string.valueOf(status) + '): \n' + response;
				}
				
            } catch( System.Exception e) {
            	if (e.getMessage().startsWith('Unauthorized endpoint')) {
					error = 'Before using the geocoder.us service, an administrator must go to Setup => Security => Remote Site Settings ' +
						'and add the following endpoint:  http://' + ((username != null) ? authEndpoint : publicEndpoint);
            	} else {
					error = 'Error communicating with geocoding service: ' + e.getMessage();
					outOfGeocoderRequests = (error.contains('Read timed out'));
            	}
			} finally {
				if (error != null)
					system.debug(loggingLevel.ERROR, error);
			}
		}
		
		return locations;		
	}

    public override Boolean providesDatatype(PROVIDER_DATA_TYPES datatype) {
        return (datatype == PROVIDER_DATA_TYPES.GEOCODING);           
    }
    
    public override PROVIDER_DATA_TYPES[] getAvailableDatatypes() {
        return new PROVIDER_DATA_TYPES[]{ PROVIDER_DATA_TYPES.GEOCODING }; 
    }
	
	public override Geo_Data__c getGeodata(Decimal lat, Decimal lng) {
		return null;
	}

	// for public version, you can make calls only once every 15 seconds
    public override integer getMaxCallsForBatch() { return (username != null && password != null) ? 9 : 1; }
	public override integer getMinDelay() { return (username != null && password != null) ? null : 15; }
	
    public override integer getAvailableCallouts() { return null; }  // no way to know the remaining credits  	
	
	public static testMethod void testGeocoder() {
    	insert new geoDataCredentials__c(name = 'GeocoderUsService', User_Id__c = 'test', priority__c = 1, IsActive__c = true);

		GeocoderUsService gc = new GeocoderUsService();
		gc.getGeodata('123 4th Ave, Seattle, WA');
		system.debug(loggingLevel.WARN, gc.locations);
		system.assertEquals(47.618967, gc.locations[0].geoLat__c);
	}

}