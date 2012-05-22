public with sharing abstract class GeocodingService {
/*-----------------------------------------------------------------------------------------------
* abstract interface to geodata services
* each implementation implements methods to get geodata from an address or lat/long pair
* credentials for services, and priority, are stored in custom setting 
*
* @author Evan Callahan, Todd Reasinger
-----------------------------------------------------------------------------------------------*/

    public enum PROVIDER_DATA_TYPES {GEOCODING, REVERSE_GEOCODING, NATIONAL_LEGISLATIVE, STATE_LEGISLATIVE, 
    								 COUNTY_NAME, NEIGHBORHOOD, WATERSHED, SCHOOL_DISTRICT, CENSUS_DISTRICT}

    protected geoDataCredentials__c credentials;
	protected PROVIDER_DATA_TYPES[] requestedDatatypes;
    								         	
    public class GeocodingException extends Exception {}
    
    public static GeocodingService getProvider(PROVIDER_DATA_TYPES[] dataTypes) {

        GeocodingService service = null;
        geoDataCredentials__c[] providers = 
        	[SELECT API_Key__c, Name, Password__c, Request_Timeout__c, User_Id__c, endpoint__c 
                    FROM geoDataCredentials__c
                    WHERE IsActive__c = true
                    ORDER BY priority__c];
System.debug(LoggingLevel.ERROR, providers);        		
	                                            
        for (geoDataCredentials__c c : providers) {
System.debug(LoggingLevel.WARN, 'Getting service for ' + c.name);
        	Type t = Type.forName(c.name);
        	if (t != null) service = (GeocodingService) t.newInstance();

        	if (t == null || service == null) {
				System.debug(LoggingLevel.ERROR, 'Error trying to create geocoding service for  ' + c.name);        		
        	}

			if (service != null && dataTypes != null) {
				// use this service ONLY if it provides ALL requested data types
				for (PROVIDER_DATA_TYPES pdt : dataTypes) {
System.debug(LoggingLevel.WARN, 'does it provide ' + pdt);
					if (!service.providesDatatype(pdt)) {
System.debug(LoggingLevel.WARN, 'no');
						service = null;
						continue;
					}
				}
			}
			if (service != null) {
	            service.credentials = c;
	            service.requestedDatatypes = dataTypes;
	            break;
			}
        }
        return service;    
    }
    
    protected GeocodingService() {}

	/* 
	 * Methods that must be implemented by any provider.
	 */
    public abstract Boolean providesDatatype(PROVIDER_DATA_TYPES datatype);
	public abstract PROVIDER_DATA_TYPES[] getAvailableDatatypes();
    public abstract Geo_Data__c[] getGeodata(String addr);
    public abstract Geo_Data__c getGeodata(Decimal lat, Decimal lng);
	public abstract integer getMaxCallsForBatch();		// this tells us whether we can do 1 per apex transaction or up to 10
	public abstract integer getMinDelay();				// this tells us the number of seconds we need to wait before making more calls
	public abstract integer getAvailableCallouts();		// returns the total number of callout "credits," or null if unlimited

	/* 
	 * Utility method that combines data into a single geodata.
	 */
	public void mergeData(Geo_data__c masterData, Geo_data__c mergeData) {
		if (masterData.geoDataTopCandidate__c == null) masterData.geoDataTopCandidate__c = mergeData.geoDataTopCandidate__c;
		if (masterData.Contact__c == null) masterData.Contact__c = mergeData.Contact__c;
		if (masterData.geoAddressComplete__c == null) masterData.geoAddressComplete__c = mergeData.geoAddressComplete__c;
		if (masterData.geoAddressScorePercent__c == null) masterData.geoAddressScorePercent__c = mergeData.geoAddressScorePercent__c;
		if (masterData.geoLat__c == null) masterData.geoLat__c = mergeData.geoLat__c;
		if (masterData.geoLong__c == null) masterData.geoLong__c = mergeData.geoLong__c;
		if (masterData.Street__c == null) masterData.Street__c = mergeData.Street__c;
		if (masterData.City__c == null) masterData.City__c = mergeData.City__c;
		if (masterData.State__c == null) masterData.State__c = mergeData.State__c;
		if (masterData.County__c == null) masterData.County__c = mergeData.County__c;
		if (masterData.Country_Short_Code__c == null) masterData.Country_Short_Code__c = mergeData.Country_Short_Code__c;
		if (masterData.Country_Long_Name__c == null) masterData.Country_Long_Name__c = mergeData.Country_Long_Name__c;
		if (masterData.Zip_Postal_Code__c == null) masterData.Zip_Postal_Code__c = mergeData.Zip_Postal_Code__c;
		if (masterData.Neighborhood__c == null) masterData.Neighborhood__c = mergeData.Neighborhood__c;
		if (masterData.Federal_District__c == null) masterData.Federal_District__c = mergeData.Federal_District__c;
		if (masterData.Federal_Display_Name__c == null) masterData.Federal_Display_Name__c = mergeData.Federal_Display_Name__c;
		if (masterData.Upper_District__c == null) masterData.Upper_District__c = mergeData.Upper_District__c;
		if (masterData.Lower_District__c == null) masterData.Lower_District__c = mergeData.Lower_District__c;
		if (masterData.Upper_Display_Name__c == null) masterData.Upper_Display_Name__c = mergeData.Upper_Display_Name__c;
		if (masterData.Lower_Display_Name__c == null) masterData.Lower_Display_Name__c = mergeData.Lower_Display_Name__c;
	} 

	public static String packAddress(String street, String city, String state, String postalCode) {
		String addr = isNotEmpty(street) ? street : '';
		addr += isNotEmpty(city) ? (isNotEmpty(addr) ? (', ' + city) : city) : '';
		addr += isNotEmpty(state) ? (isNotEmpty(addr) ? (', ' + state) : state) : '';
		//addr += isNotEmpty(postalCode) ? (isNotEmpty(addr) ? (', ' + postalCode) : postalCode) : '';
		addr += isNotEmpty(postalCode) ? (isNotEmpty(addr) ? (' ' + postalCode) : postalCode) : '';
		return addr;
	}
	
	private static Boolean isNotEmpty(String s) {
		return (s != null && s != '');
	}	
	
	/*
	 * Implementation used for testing.
	 */
    private class TestGeocodingService extends GeocodingService {
    	private PROVIDER_DATA_TYPES[] requestedDatatypes;
    	
        public override Boolean providesDatatype(PROVIDER_DATA_TYPES datatype) {
            return datatype == PROVIDER_DATA_TYPES.GEOCODING;           
        }
    
	    public override PROVIDER_DATA_TYPES[] getAvailableDatatypes() {
        	return new PROVIDER_DATA_TYPES[]{ PROVIDER_DATA_TYPES.GEOCODING };
	    }
	     
        public override Geo_Data__c[] getGeodata(String addr) {
            Geo_Data__c gd = new Geo_data__c();
            gd.geoAddressComplete__c = addr;
            return new Geo_Data__c[]{gd};
        }
        
        public override Geo_Data__c getGeodata(Decimal lat, Decimal lng) {
            Geo_Data__c gd = new Geo_data__c();
            gd.geoLat__c = lat;
            gd.geoLong__c = lng;
            return gd;
        }
        
        public override integer getMaxCallsForBatch() { return 9; }
		public override integer getMinDelay() { return null; }
	    public override integer getAvailableCallouts() { return null; }    	
    }

    private static final String TEST_ADDRESS = '123 Main Street, Pittsburgh, PA';
    public testMethod static void testGeocodingService() {
        
        geoDataCredentials__c invalidCreds = new geoDataCredentials__c();
        invalidCreds.Name = 'noClass';
        invalidCreds.IsActive__c = true;
        invalidCreds.Priority__c = 1;
        insert invalidCreds;

        geoDataCredentials__c creds = new geoDataCredentials__c();
        creds.Name = TestGeocodingService.class.getName();
        creds.IsActive__c = true;
        creds.Priority__c = 2;
		insert creds;
        
        GeocodingService s = getProvider( new PROVIDER_DATA_TYPES[]{ PROVIDER_DATA_TYPES.NATIONAL_LEGISLATIVE });
        System.assertEquals(null, s);
        s = getProvider(new PROVIDER_DATA_TYPES[]{ PROVIDER_DATA_TYPES.GEOCODING });
        System.assertNotEquals(null, s);
        Geo_data__c[] data = s.getGeodata(TEST_ADDRESS);
        System.assert(data != null && data.size() == 1);
        System.assertEquals(TEST_ADDRESS, data[0].geoAddressComplete__c);
        Geo_data__c oneData = s.getGeodata(1.01, -3.45);
        System.assert(oneData != null);
    }
    
    static testMethod void testPackAddress() {
		System.assertEquals('123 Main, San Francisco, CA', packAddress('123 Main', 'San Francisco', 'CA', null));
		System.assertEquals('San Francisco, CA', packAddress(null, 'San Francisco', 'CA', ''));
		System.assertEquals('94105', packAddress(null, '', null, '94105'));
	}
	
}