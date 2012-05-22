global class TaskQueueSchedulable implements Schedulable {
/*
Class to perform background updates using data from API callouts
*/
	// UNDONE: lots of work to do here
	
	private static final Double MaxAttempts = 3.0;
	
	global void execute(SchedulableContext sc) {
		processGeocodingTasks(null);
	}
	
	public static void processGeocodingTasks(String testName) {
		Cicero c;
		if (Test.isRunningTest())
			c = new CiceroTest(testName);
		else
			c = new Cicero();
		
		Integer maxNumCalls = c.getMaxCallsForBatch();
		
		try {
			// UNDONE: Not sure what we want to do with task_type__c
			List<Task_Queue__c> taskQueues = [select Execution_Attempts__c, ObjecId__c
												from Task_Queue__c 
												where 
												//Task_Type__c = 'Geocode' and
											    Execution_Attempts__c < :MaxAttempts 
												limit :maxNumCalls];
			if (taskQueues.isEmpty())
				return;
			
			Map<Id, Task_Queue__c> contactTaskQueueMap = new Map<Id, Task_Queue__c>();
			for (Task_Queue__c tq : taskQueues) {
				contactTaskQueueMap.put(tq.ObjecId__c, tq);
			}
			List<Contact> contacts = [select MailingStreet, MailingCity, MailingState, MailingPostalCode from Contact where Id in :contactTaskQueueMap.keySet()];
			if (contacts.isEmpty())
				return;
			
			List<Geo_Data__c> geoDataToInsert = new List<Geo_Data__c>();
			List<Task_Queue__c> taskQueuesToDelete = new List<Task_Queue__c>();
			List<Task_Queue__c> taskQueuesToUpdate = new List<Task_Queue__c>();
			
			for (Contact cont : contacts) {
				Task_Queue__c tq = contactTaskQueueMap.get(cont.Id);
				String addr = GeocodingService.packAddress(cont.MailingStreet, cont.MailingCity, cont.MailingState, cont.MailingPostalCode);
				List<Geo_Data__c> gds;
				if (Test.isRunningTest()) {
					gds = new List<Geo_Data__c>();
				} else {
					gds = c.getGeoData(addr);
				}
				if (gds != null && gds.size() > 0) {
					// pick the first one
					gds[0].Contact__c = cont.Id;
					geoDataToInsert.add(gds[0]);
					taskQueuesToDelete.add(tq);
				} else {
					// nothing returned in failed attempt
					if (tq.Execution_Attempts__c == null)
						tq.Execution_Attempts__c = 1.0;
					else
						tq.Execution_Attempts__c += 1.0;
					taskQueuesToUpdate.add(tq);
				}
			}
			
			if (!geoDataToInsert.isEmpty())
				insert geoDataToInsert;
			if (!taskQueuesToDelete.isEmpty())
				delete taskQueuesToDelete;
			if (!taskQueuesToUpdate.isEmpty())
				update taskQueuesToUpdate;
			
		} catch (Exception e) {
			System.debug('Failed to find tasks in queue: ' + e.getMessage());
		}
	}
	
}