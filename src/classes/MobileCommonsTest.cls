@istest
public with sharing class MobileCommonsTest extends MobileCommons {

	private static final string SAMPLE_RESPONSE = '<?xml version="1.0" encoding="UTF-8"?><response><lat>40.7145248</lat><lng>-74.007073</lng><federal><state>NY</state><district>8</district><display_name>NY 8th</display_name></federal><state_lower><state>NY</state><district>066</district><display_name>NY 66th</display_name></state_lower><state_upper><state>NY</state><district>025</district><display_name>NY 25th</display_name></state_upper></response>';

    // override methods for calling the API 
    public virtual override HttpResponse execute(Http h, HttpRequest request) {
        HttpResponse resp = new HttpResponse();
        resp.setStatusCode(200);
        return resp;
    }

	// override the method to return the http response
    public virtual override DOM.Document getResponseBody(HttpResponse response) { 
        DOM.Document d = new DOM.Document();
        d.load( SAMPLE_RESPONSE );
        return d;
    }   
    
    static testmethod void testGetDistricts() {
    	insert new geoDataCredentials__c(name = 'MobileCommons', priority__c = 1, IsActive__c = true);
    	        
        // get the token
        MobileCommonsTest c = new MobileCommonsTest();
		Geo_Data__c gd = c.getGeodata(48, 120);
		        
        system.assertEquals(8, gd.federal_district__c);
    }
}