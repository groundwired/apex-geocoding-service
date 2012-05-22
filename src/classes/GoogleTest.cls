/**
 * This class contains unit tests for validating the behavior of Apex classes
 * and triggers.
 *
 * Unit tests are class methods that verify whether a particular piece
 * of code is working properly. Unit test methods take no arguments,
 * commit no data to the database, and are flagged with the testMethod
 * keyword in the method definition.
 *
 * All test methods in an organization are executed whenever Apex code is deployed
 * to a production organization to confirm correctness, ensure code
 * coverage, and prevent regressions. All Apex classes are
 * required to have at least 75% code coverage in order to be deployed
 * to a production organization. In addition, all triggers must have some code coverage.
 * 
 * The @isTest class annotation indicates this class only contains test
 * methods. Classes defined with the @isTest annotation do not count against
 * the organization size limit for all Apex scripts.
 *
 * See the Apex Language Reference for more information about Testing and Code Coverage.
 */
@isTest
public class GoogleTest extends GoogleGeoCode{

	public GoogleTest(String testName)
	{
		this.testName = testName;
	}
	public string testName;
	
	public virtual override HttpResponse execute(Http h, HttpRequest request) {
        system.debug(logginglevel.WARN, request); 
        if (testName == 'httpError') {
            throw(new GeocodingException('Problem contacting Google.'));
        }
        return new HttpResponse();
    } 
    
    public virtual override string getResponseBody(HttpResponse response) { 
        system.debug('testName is: ' + testName);
        return 
            (testName == 'address') ? '{"results" : [{"address_components" : [{"long_name" : "1600","short_name" : "1600","types" : [ "street_number" ]},{"long_name" : "Amphitheatre Pkwy","short_name" : "Amphitheatre Pkwy","types" : [ "route" ]},{"long_name" : "Mountain View","short_name" : "Mountain View","types" : [ "locality", "political" ]},{"long_name" : "Santa Clara","short_name" : "Santa Clara","types" : [ "administrative_area_level_2", "political" ]},{"long_name" : "California","short_name" : "CA","types" : [ "administrative_area_level_1", "political" ]},{"long_name" : "United States","short_name" : "US","types" : [ "country", "political" ]},{"long_name" : "94043","short_name" : "94043","types" : [ "postal_code" ]}],"formatted_address" : "1600 Amphitheatre Pkwy, Mountain View, CA 94043, USA","geometry" : {"location" : {"lat" : 37.42291810,"lng" : -122.08542120},"location_type" : "ROOFTOP","viewport" : {"northeast" : {"lat" : 37.42426708029149,"lng" : -122.0840722197085},"southwest" : {"lat" : 37.42156911970850,"lng" : -122.0867701802915}}},"types" : [ "street_address" ]}],"status" : "OK"}' :
            (testName == 'nodata') ? '{"status" : "ZERO_RESULTS"}' :             
            (testName == 'error') ? '{"status" : "OVER_QUERY_LIMIT"}' :             
            'bogusResponse';
    }
    
    static testMethod void testCallProviderError() 
    {
    	insert new geoDataCredentials__c(name = 'GoogleTest', priority__c = 1, IsActive__c = true);

    	GoogleTest googleTest = new GoogleTest('error');
    	string errMsg = null;    	
        try
        {
			List<Geo_Data__c> gdList = googleTest.getGeoData('123 4th');
        }
        catch(exception ex)
        {
        	errMsg = ex.getMessage();
        }
        System.assertEquals(errMsg, 'Google API Error: OVER_QUERY_LIMIT');
    }
    
    static testMethod void testCallProviderValidAddress() 
    {
    	insert new geoDataCredentials__c(name = 'GoogTest', priority__c = 1, IsActive__c = true);
    	GoogleTest googleTest = new GoogleTest('address');
    	
		List<Geo_Data__c> gdList = GoogleTest.getGeoData('1600 Amphitheatre Pkwy, Mountain View, CA');
		        
        system.assert(gdList[0].geoJson__c != null);
    	system.assertEquals(gdList[0].geoLat__c , Decimal.valueOf('37.4229181'));
    	system.assertEquals(gdList[0].City__c , 'Mountain View');
    	system.assertEquals(gdList[0].State__c , 'CA');
    	system.assertEquals(gdList[0].County__c , 'Santa Clara');
    	system.assertEquals(gdList[0].Zip_postal_code__c , '94043');
    	system.assertEquals(gdList[0].Country_long_name__c , 'United States');
    	system.assertEquals(gdList[0].Country_short_code__c , 'US');
    	system.assertEquals(gdList[0].Street__c , '1600 Amphitheatre Pkwy');
    	
    	system.debug(logginglevel.warn, gdlist);

		Geo_Data__c gd = GoogleTest.getGeoData(48, -122);
    	system.debug(logginglevel.warn, gd);
    	system.assertEquals('1600 Amphitheatre Pkwy, Mountain View, CA 94043, USA', gd.geoAddressComplete__c);    	
    }

}