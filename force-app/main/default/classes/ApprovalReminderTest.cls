@IsTest
private class ApprovalReminderTest {
    

    @IsTest
    static void testApprovalSetup(){
        List<ProcessDefinition> approvalProcess = [ SELECT Id,DeveloperName,State,Name,TableEnumOrId
                                                    FROM ProcessDefinition
                                                    LIMIT 1];
        String approvalProcessId = approvalProcess.isEmpty() ? null : approvalProcess.get(0).Id;

        Test.startTest();

        Map<String, object> res = ManageApprovalProcessReminderCotroller.getInitData();
        System.assertEquals(false, Boolean.valueOf(res.get('isProcessRunning')));
        
        Map<String, object> newRemider = new Map<String, object>{
            'name' => 'Test Reminder',
            'recipient_List' => '[{"recipiantIndex":1,"recipiantType":"User Field","fromLevel":1,"recipiant":"OwnerId","recipiantLabel":"Owner ID","isUser":false,"isUserField":true}]',
            'recurring_Every_H' => 1,
            'related_Object' => 'Account',
            'related_Approval_Process' => approvalProcessId,
            'related_Object_Label' => 'Acount',
            'start_Reminder_After_H' => 1,
            'stop_Recurrence_After' => 1,
            'active' => true
        };
        
        List<ManageApprovalProcessReminderCotroller.ReminderProcess> remindersist = ManageApprovalProcessReminderCotroller.saveApprovalReminder(newRemider);
        System.assertEquals(1, remindersist.size());

        res = ManageApprovalProcessReminderCotroller.scheduleProcess(10);
        System.assertEquals(0, Integer.valueOf(res.get('returnCode')));
            
        res = ManageApprovalProcessReminderCotroller.abortProcess();
        System.assertEquals(0, Integer.valueOf(res.get('returnCode')));
        
        remindersist = ManageApprovalProcessReminderCotroller.deleteApprovalReminder(remindersist.get(0).remId);
        System.assertEquals(0, remindersist.size());
    
        res = ManageApprovalProcessReminderCotroller.getApprovalProcessMeta(approvalProcessId);

        Test.stopTest();
    }

    @IsTest
    static void testRunApprovalReminder(){

        Account testAccount = new Account(Name = 'TestAccount1234');
        insert testAccount;
        
        ProcessDefinition approvalProcess;
        
        try{
             approvalProcess = [    SELECT id, DeveloperName,State,Type,TableEnumOrId 
                                    FROM ProcessDefinition 
                                    WHERE state = 'Active' AND type='Approval' limit 1];
        }
        catch(Exception ex){
            System.debug('No active approval process. Might have lower coverage');
        }
        
        //Get first Business Hours records
        BusinessHours bh = [select id from BusinessHours limit 1];
      
        //Create Approval Process Reminders.
        //Should contain value approval process and the correct Related object
        Approval_Process_Reminder__c newRemider = new Approval_Process_Reminder__c(
            Name = 'Test Reminder',
            Recipient_List__c = '[{"recipiantIndex":1,"recipiantType":"User","fromLevel":1,"recipiant":"' + UserInfo.getUserId() + '","recipiantLabel":"Owner ID","isUser":false,"isUserField":true}]',
            Recurring_Every_H__c = 1,
            Related_Object__c = approvalProcess != null ? approvalProcess.TableEnumOrId : 'Account',
            Related_Approval_Process__c = approvalProcess != null ? approvalProcess.DeveloperName : 'AccountAPR',
            Related_Object_Label__c = 'Acount',
            Start_Reminder_After_H__c = 1,
            Stop_Recurrence_After__c = 10,
            Active__c = true
        );
        insert newRemider;                                                
        
        Test.startTest();
        
        try{
            //Create record related to the approval process
            Schema.SObjectType targetType = Schema.getGlobalDescribe().get(approvalProcess != null ? approvalProcess.TableEnumOrId : 'Account');
            sObject obj = targetType.newSObject();
            insert obj;
            
            //Submit the approval request
            Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
            req.setNextApproverIds(new Id[] {UserInfo.getUserId()});
            req.setObjectId(obj.Id);
            Approval.ProcessResult result = Approval.process(req);
        }
        catch(Exception ex){
            system.debug('Failed to create/submit:' + ex.getMessage());
        }

        ManageApprovalProcessReminderCotroller.scheduleProcess(10);

        ApexClass clsItem = [SELECT Id,NamespacePrefix FROM ApexClass WHERE Name ='ApprovalReminderBatch' LIMIT 1];
        String classRunner = String.isBlank(clsItem.NamespacePrefix) ? 'ApprovalReminderBatch' : (clsItem.NamespacePrefix + '.ApprovalReminderBatch');

        //First run - create new APR records
        mba_services__Async_Job__c asyncJob1 = [SELECT Id,mba_services__Job_Params__c FROM mba_services__Async_Job__c WHERE mba_services__Class_Runner__c = :classRunner AND mba_services__Status__c = 'Queued'];
        ApprovalReminderBatch batchJob1 = new ApprovalReminderBatch();
        batchJob1.run(asyncJob1);

        //First run - create new APR records
        mba_services__Async_Job__c asyncJob2 = [SELECT Id,mba_services__Job_Params__c FROM mba_services__Async_Job__c WHERE mba_services__Class_Runner__c = :classRunner AND mba_services__Status__c = 'Queued'];
        ApprovalReminderBatch batchJob2 = new ApprovalReminderBatch();
        batchJob2.run(asyncJob2);
        
        Test.stopTest();
    }

    @Istest 
    static void testSearchRecords(){
        Approval_Process_Reminder__c newRemider = new Approval_Process_Reminder__c(
            Name = 'Test Reminder',
            Recurring_Every_H__c = 1,
            Related_Object_Label__c = 'Acount');
        insert newRemider;   

        Test.startTest();

        Approval_Process_Reminder__c mainRec = (Approval_Process_Reminder__c) SearchRecordsController.getRecordInit('Approval_Process_Reminder__c', new List<String>{'Name','Related_Object_Label__c'}, newRemider.Id);
        System.assert(mainRec.Id == newRemider.Id, 'Test failed, cannot find the correct job record.');

        SearchRecordsController.search('Approval_Process_Reminder__c', new List<String>{'Name','Related_Object_Label__c'}, 'Test');

        Test.stopTest();
    }
}
