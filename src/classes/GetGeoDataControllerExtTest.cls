@isTest
private class GetGeoDataControllerExtTest {
	
	static testMethod void testOneContact() {
		Contact c = new Contact(FirstName = 'Unit', LastName = 'Test123', MailingCity = 'San Francisco', MailingState = 'CA');
		insert c;
		
		ApexPages.Standardcontroller controller = new ApexPages.Standardcontroller(c);
		GetGeoDataControllerExt ext = new GetGeoDataControllerExt(controller);
		
		System.assertEquals(1, ext.numContacts);
		System.assertEquals('Unit Test123', ext.contName);
		System.assertEquals(null, ext.street);
		System.assertEquals('San Francisco', ext.city);
		System.assertEquals('CA', ext.state);
		System.assertEquals(null, ext.postalCode);
		
		ext.submitOne();
		System.assertEquals(true, ApexPages.getMessages()[0].getSummary().contains('Get Legislator Info'));
	}
	
	static testMethod void testMultipleContacts() {
		List<Contact> contacts = new List<Contact> {
			new Contact(FirstName = 'Unit', LastName = 'Test234', MailingCity = 'New York', MailingState = 'NY'),
			new Contact(FirstName = 'Unit', LastName = 'Test456', MailingCity = 'Seattle', MailingState = 'WA'),
			new Contact(FirstName = 'Unit', LastName = 'Test567', MailingCity = 'Chicago', MailingState = 'IL')
		};
		insert contacts;
		
		ApexPages.Standardsetcontroller controller = new ApexPages.Standardsetcontroller(contacts);
		GetGeoDataControllerExt ext = new GetGeoDataControllerExt(controller);
		
		// no contacts selected
		System.assertEquals(0, ext.numContacts);
		System.assertEquals(true, ApexPages.getMessages()[0].getSummary().contains('No contacts selected.'));
		
		// 2 out of 3 selected
		controller.setSelected(new List<Contact> {contacts[1], contacts[2]});
		ext = new GetGeoDataControllerExt(controller);
		
		System.assertEquals(2, ext.numContacts);
		
		ext.submitMany();
		System.assertEquals(2, [select count() from Task_Queue__c where ObjecId__c = :contacts[1].Id or ObjecId__c = :contacts[2].Id]);
		System.assertEquals(true, ApexPages.getMessages()[1].getSummary().contains('2 tasks inserted in queue'));
	}
	
}