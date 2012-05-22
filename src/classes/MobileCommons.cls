public virtual with sharing class MobileCommons extends GeocodingService {
/*-----------------------------------------------------------------------------------------------
* Apex class that integrates with the Moile Commons REST API and interprets the JSON it returns
* Written by Sara Chieco & Evan Callahan
*
* For info see:
* http://congress.mcommons.com
* http://congress.mcommons.com/districts/lookup.xml
*-----------------------------------------------------------------------------------------------*/

    final string endpoint = 'http://congress.mcommons.com/districts/lookup.xml';
    final integer timeout = 5000;       // in milliseconds - 5 second default

    public override Boolean providesDatatype(PROVIDER_DATA_TYPES datatype) {
        return ( 
        	datatype == PROVIDER_DATA_TYPES.NATIONAL_LEGISLATIVE || 
        	datatype == PROVIDER_DATA_TYPES.STATE_LEGISLATIVE 
			);
    }

    public override PROVIDER_DATA_TYPES[] getAvailableDatatypes() {
        return new PROVIDER_DATA_TYPES[] { 
        	PROVIDER_DATA_TYPES.NATIONAL_LEGISLATIVE, 
        	PROVIDER_DATA_TYPES.STATE_LEGISLATIVE 
        };           
    }

	// mobile commons does not publish any specific limits
    public override integer getMaxCallsForBatch() { return null; }
	public override integer getMinDelay() { return null; }
    public override integer getAvailableCallouts() { return null; }    	

	// mobile commons does not geocode
    public override Geo_Data__c[] getGeodata(String addr) {
        return null;
    }
    
    public override Geo_Data__c getGeodata(Decimal latitude, Decimal longitude) {
        Geo_Data__c gd = new Geo_data__c();

		if (latitude == null || longitude == null)
		{
			throw new GeocodingException('Error no latitude or longitude specified.');
		}
	    HttpResponse resp;
	    string js; 
	    Dom.Document doc;
		
		try
		{	
	        // prepare the request
	        Http h = new Http();
	        HttpRequest req = new HttpRequest();
	        req.setMethod('GET');
	        req.setTimeout(timeout);	    
	        req.setEndpoint(endpoint + 
	            	'?lat=' + string.valueOf(latitude) +
	            	'&lng=' + string.valueOf(longitude));    
			//system.debug(LOGGINGLEVEL.warn, 'http://' + endpoint + '?lat=' + string.valueOf(latitude) + '&lng=' + string.valueOf(longitude));
	            	
	        // execute the request
	        resp = execute( h, req );
	        
	        // interpret the response
        	doc = getResponseBody( resp );
			//system.debug( LOGGINGLEVEL.warn, js );			
        }
        catch( System.Exception e ) {
        	if (e.getMessage().startsWith('Unauthorized endpoint')) {
				throw new GeocodingException('Before using the Mobile Commons service, an administrator must go to Setup => Security => Remote Site Settings ' +
					'and add the following endpoint:  http://' + endpoint);
        	} 
        	else {
				throw new GeocodingException('Error communicating with Mobile Commons service: \n' + e.getMessage());
        	}
        }        

		if (doc != null) {
			// Parse the xml and retrieve the root element
			Dom.XMLNode root = doc.getRootElement();
				
			// check for error
			Dom.XMLNode errNode = root.getChildElement('error', null);
			if (errNode != null) {
				throw new GeocodingException(errNode.getText());
			} 
			else {
				//system.debug(logginglevel.warn, root.getchildelements());
				// get the details
				gd.State__c = root.getChildElement('federal', null).getChildElement('state', null).getText(); 
				gd.Federal_District__c = integer.valueOf(
					root.getChildElement('federal', null).getChildElement('district', null).getText()
				);
				gd.Federal_Display_Name__c = root.getChildElement('federal', null).getChildElement('display_name', null).getText();
				gd.Upper_District__c = integer.valueOf(
					root.getChildElement('state_upper', null).getChildElement('district', null).getText()
				);
				gd.Upper_Display_Name__c = root.getChildElement('state_upper', null).getChildElement('display_name', null).getText();
				gd.Lower_District__c = integer.valueOf(
					root.getChildElement('state_lower', null).getChildElement('district', null).getText()
				);
				gd.Lower_Display_Name__c = root.getChildElement('state_lower', null).getChildElement('display_name', null).getText();
			} 
		}
		else {
			throw new GeocodingException('No response from Mobile Commons service.');					
        } 
        
		//system.debug(logginglevel.WARN, gd);        
        return gd;
    }
	
    public virtual HttpResponse execute(Http h, HttpRequest request) {
		return h.send(request);
    }

    public virtual DOM.Document getResponseBody(HttpResponse response) {
    	Integer status = response.getStatusCode();
    	
		if (status == 200) {
			if (response != null) {
        		return response.getBodyDocument();
			}
		}		
		return null;
    }  
}