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
public class YahooTest extends YahooPeopleFinder{

	public YahooTest(String testName)
	{
		this.testName = testName;
	}
	public string testName;
	
	public virtual override HttpResponse execute(Http h, HttpRequest request) {
        system.debug(logginglevel.WARN, request); 
        if (testName == 'httpError') {
            throw(new GeocodingException('Problem contacting Yahoo.'));
        }
        return new HttpResponse();
    } 
    
    public virtual override string getResponseBody(HttpResponse response) { 
        system.debug('testName is: ' + testName);
        return 
            (testName == 'address') ? '{"ResultSet":{"version":"1.0","Error":0,"ErrorMessage":"No error","Locale":"us_US","Quality":87,"Found":1,"Results":[{"quality":87,"latitude":"41.254715","longitude":"-73.524137","offsetlat":"41.254804","offsetlon":"-73.524158","radius":500,"name":"","line1":"25 West Ln","line2":"South Salem, NY  10590-1911","line3":"","line4":"United States","house":"25","street":"West Ln","xstreet":"","unittype":"","unit":"","postal":"10590-1911","neighborhood":"","city":"South Salem","county":"Westchester County","state":"New York","country":"United States","countrycode":"US","statecode":"NY","countycode":"","uzip":"10590","hash":"255B5785E2B6E50A","woeid":12761586,"woetype":11}]}}' :
            (testName == 'error') ? '{"ResultSet":{"version":"1.0","Error":100,"ErrorMessage":"No location parameters","Locale":"us_US","Quality":0,"Found":0}}' :             
            'bogusResponse';
    }

    static testMethod void testCallProviderError() 
    {
    	YahooTest yahooTest = new YahooTest('error');
    	string errMsg;    	
        try
        {
			List<Geo_Data__c> gdList = yahooTest.getGeoData('123 4th');
        }
        catch(exception ex)
        {
        	errMsg = ex.getMessage();
        }
        System.assertEquals('You do not have a Yahoo API key configured. Ask your system administrator to create a GeoDataCredential setting named Yahoo and provide the key there.', errMsg);

    	insert new geoDataCredentials__c(name = 'YahooTest', api_key__c = 'test', priority__c = 1, IsActive__c = true);

    	yahooTest = new YahooTest('error');
    	errMsg = null;    	
        try
        {
			List<Geo_Data__c> gdList = yahooTest.getGeoData('123 4th');
        }
        catch(exception ex)
        {
        	errMsg = ex.getMessage();
        }
        System.assertEquals('Error: 100: No location parameters', errMsg);
    }
    
    static testMethod void testCallProviderValidAddress() 
    {
    	insert new geoDataCredentials__c(name = 'YahooTest', api_key__c = 'test', priority__c = 1, IsActive__c = true);
    	YahooTest yahooTest = new YahooTest('address');
    	
		List<Geo_Data__c> gdList = yahooTest.getGeoData('25 West Lane, South Salem, NY 10590');
		        
        system.assert(gdList[0].geoJson__c != null);
    	system.assertEquals(gdList[0].geoAddressScorePercent__c, 87);
    	system.assertEquals(gdList[0].geoLat__c , Decimal.valueOf('41.254715'));
    	system.assertEquals(gdList[0].geoLong__c , Decimal.valueOf('-73.524137'));
    	system.assertEquals(gdList[0].City__c , 'South Salem');
    	system.assertEquals(gdList[0].State__c , 'NY');
    	system.assertEquals(gdList[0].County__c , 'Westchester County');
    	system.assertEquals(gdList[0].Zip_postal_code__c , '10590-1911');
    	system.assertEquals(gdList[0].Country_long_name__c , 'United States');
    	system.assertEquals(gdList[0].Country_short_code__c , 'US');
    	system.assertEquals(gdList[0].Neighborhood__c , '');
    	system.assertEquals(gdList[0].Street__c , '25 West Ln');
    	
    	system.debug(logginglevel.warn, gdlist);

		Geo_Data__c gd = yahooTest.getGeoData(48, -122);
    	system.debug(logginglevel.warn, gd);
    	system.assertEquals('25 West Ln, South Salem, NY 10590-1911', gd.geoAddressComplete__c);    	
    }

/* Sample response
{
    {"ResultSet":  
      {"version":"1.0",  
      "Error":0,  
      "ErrorMessage":"No error",  
      "Locale":"en_US",  
      "Quality":40,  
      "Found":1,  
      "Results":[  
      {"quality":40,  
        "latitude":"37.779160",  
        "longitude":"-122.420049",  
        "offsetlat":"37.779160",  
        "offsetlon":"-122.420049",  
        "radius":5000,  
        "name":"",  
        "line1":"",  
        "line2":"San Francisco,  
         CA",  
        "line3":"",  
        "line4":"United States",  
        "house":"",  
        "street":"",  
        "xstreet":"",  
        "unittype":"",  
        "unit":"",  
        "postal":"",  
        "neighborhood":"",  
        "city":"San Francisco",  
        "county":"San Francisco County",  
        "state":"California",  
        "country":"United States",  
        "countrycode":"US",  
        "statecode":"CA",  
        "countycode":"",  
        "uzip":"94102",  
        "hash":"C1D313AD706E3B3C",  
        "woeid":12587707,  
        "woetype":9}]  
         }  
        }  
*/
}