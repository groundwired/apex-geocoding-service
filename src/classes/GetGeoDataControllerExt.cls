public class GetGeoDataControllerExt {
	
	public String contName { get; private set; }
	public String street { get; set; }
	public String city { get; set; }
	public String state { get; set; }
	public String postalCode { get; set; }
	public String titleMessage { get; private set; }
	public Integer numContacts { get; private set; }
	public Boolean getLegislatorInfo { get; set; }
	public Boolean updateContactInfo { get; set; }
	
	private final List<Contact> conts;
	private final Contact cont;
	
	public GetGeoDataControllerExt(ApexPages.StandardController stdCon) {
		this.conts = [select Id, FirstName, LastName, MailingStreet, MailingCity, MailingState, MailingPostalCode from Contact where Id = :stdCon.getId()];
		numContacts = conts.size();
		cont = (numContacts > 0) ? conts[0] : null;
		if (cont != null) {
			contName = ((cont.FirstName != null) ? (cont.FirstName + ' ') : '') + cont.LastName;
			street = cont.MailingStreet;
			city = cont.MailingCity;
			state = cont.MailingState;
			postalCode = cont.MailingPostalCode;
			titleMessage = 'Get Geo Data for ' + contName;
		}
		getLegislatorInfo = false;
		updateContactInfo = false;
	}
	
	public GetGeoDataControllerExt(ApexPages.StandardSetController stdSetCon) {
		this.conts = [select Id/*, FirstName, LastName, MailingStreet, MailingCity, MailingState, MailingPostalCode*/ from Contact where Id in :stdSetCon.getSelected()];
		numContacts = conts.size();
		if (numContacts == 0) {
			ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.WARNING, 'No contacts selected.'));
		}
		titleMessage = 'Get Geo Data for ' + String.valueOf(numContacts) + ' contacts';
		getLegislatorInfo = false;
		updateContactInfo = false;
	}
	
	public PageReference submitOne() {
		if (inputsInvalid()) {
			ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.FATAL, 'No address specified.'));
		} else {
			String addr = GeocodingService.packAddress(street, city, state, postalCode);
			// call the API
			if (!Test.isRunningTest() && getLegislatorInfo) {
				Cicero c = new Cicero();
				List<Geo_Data__c> gdlist = c.getGeoData(addr);
				Geo_Data__c gd = ((gdlist.isempty()) ? null : gdlist[0]);
				
				if (gd != null) {
					System.debug('GeoData latitude: ' + gd.geoLat__c);
					ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.INFO, 'GeoData latitude: ' + gd.geoLat__c + '; longitude: ' + gd.geoLong__c));
				}
			}
			ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.INFO, 'Get Legislator Info: ' + getLegislatorInfo + '; Update Contact: ' + updateContactInfo));
		}
		return null;
	}
	
	public PageReference submitMany() {
		if (numContacts > 0) {
			List<Task_Queue__c> taskQueuesToInsert = new List<Task_Queue__c>();
			Cicero c = new Cicero();
			String taskType = 'Geocode';
			for (Contact ct : conts) {
				taskQueuesToInsert.add(new Task_Queue__c(ObjecId__c = ct.Id, Task_Type__c = taskType));
			}
			insert taskQueuesToInsert;
			ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.INFO, '' + taskQueuesToInsert.size() + ' tasks inserted in queue'));
		}
		return null;
	}
	
	private Boolean inputsInvalid() {
		return ((street == null || street == '') && (city == null || city == '') && (state == null || state == '') && (postalCode == null || postalCode == ''));
	}	
}