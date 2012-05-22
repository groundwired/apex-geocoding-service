@isTest
private class TaskQueueSchedulableTest {

	static testMethod void testProcessGeocodingTasks() {
		CiceroTest c = new CiceroTest();
		
		List<Contact> conts = new List<Contact> {
			new Contact(FirstName = 'Unit', LastName = 'Test123', MailingCity = 'San Francisco', MailingState = 'CA'),
			new Contact(FirstName = 'Unit', LastName = 'Test234', MailingCity = 'New York', MailingState = 'NY')
		};
		insert conts;
		
		List<Task_Queue__c> taskQueues = new List<Task_Queue__c> {
			new Task_Queue__c(Execution_Attempts__c = 0, ObjecId__c = conts[0].Id, Task_Type__c = 'Geocode'),
			new Task_Queue__c(ObjecId__c = conts[1].Id, Task_Type__c =  'Geocode')
		};
		insert taskQueues;
		
		TaskQueueSchedulable.processGeocodingTasks('legislative_district');
		
		List<Task_Queue__c> updatedTaskQueues = [select Execution_Attempts__c from Task_Queue__c where Id in :taskQueues];
		
		System.assertEquals(2, updatedTaskQueues.size());
		for (Task_Queue__c tq : updatedTaskQueues) {
			System.assertEquals(1.0, tq.Execution_Attempts__c);
		}
		System.assertEquals(0, [select count() from Geo_Data__c where Contact__c in :conts]);
	}
}