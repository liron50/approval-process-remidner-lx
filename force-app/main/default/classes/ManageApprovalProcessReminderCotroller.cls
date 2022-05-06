public with sharing class ManageApprovalProcessReminderCotroller {
    @AuraEnabled
    public static Map<String, object> getInitData(){

        Map<String, object> mRetData = new Map<String, object>();

        mRetData.put('reminderList', getApprovalReminderList());

        ApexClass clsItem = [SELECT Id,NamespacePrefix FROM ApexClass WHERE Name ='ApprovalReminderBatch' LIMIT 1];
        String classRunner = String.isBlank(clsItem.NamespacePrefix) ? 'ApprovalReminderBatch' : (clsItem.NamespacePrefix + '.ApprovalReminderBatch');

        List<mba_services__Async_Job__c> runningJob = [ SELECT Id,mba_services__Time_to_Run__c
                                                        FROM mba_services__Async_Job__c
                                                        WHERE mba_services__Class_Runner__c = :classRunner
                                                        AND mba_services__Status__c IN ('Queued', 'Processing')
                                                        LIMIT 1];

        if(! runningJob.isEmpty()){
            mRetData.put('timeToRun', runningJob.get(0).mba_services__Time_to_Run__c);
        }
        mRetData.put('isProcessRunning', runningJob.isEmpty() == false);

        return mRetData;
    }
    
    private static List<ReminderProcess> getApprovalReminderList(){
        List<ReminderProcess> reminderList = new List<ReminderProcess>();

        for(Approval_Process_Reminder__c reminder :[    SELECT Id,Name,Active__c,Business_Hours__c,Recipient_List__c,Recurring_Every_H__c,
                                                            Related_Approval_Process__c,Related_Object__c,Related_Object_Label__c,Start_Reminder_After_H__c,Stop_Recurrence_After__c,Note__c
                                                        FROM Approval_Process_Reminder__c]){
            reminderList.add(new ReminderProcess(reminder));
        }

        return reminderList;
    }

    @AuraEnabled
    public static List<ReminderProcess> deleteApprovalReminder(Id recordId){
        Approval_Process_Reminder__c reminder = new Approval_Process_Reminder__c(Id = recordId);        
        delete reminder;

        return getApprovalReminderList();
    }

    @AuraEnabled
    public static List<ReminderProcess> saveApprovalReminder(Map<String, object> reminderItem){

        Approval_Process_Reminder__c reminder = new Approval_Process_Reminder__c(
            Id = reminderItem.containsKey('remId') ? String.valueOf(reminderItem.get('remId')) : null,
            Name = reminderItem.containsKey('remName') ? String.valueOf(reminderItem.get('remName')) : null,
            Active__c = reminderItem.containsKey('active') ? Boolean.valueOf(reminderItem.get('active')) : false,
            Business_Hours__c = reminderItem.containsKey('business_Hours') ? String.valueOf(reminderItem.get('business_Hours')) : null,
            Recipient_List__c = reminderItem.containsKey('recipient_List') ? String.valueOf(reminderItem.get('recipient_List')) : null,
            Recurring_Every_H__c = reminderItem.containsKey('recurring_Every_H') ? Integer.valueOf(reminderItem.get('recurring_Every_H')) : null,
            Related_Approval_Process__c = reminderItem.containsKey('related_Approval_Process') ? String.valueOf(reminderItem.get('related_Approval_Process')) : null,
            Related_Object__c = reminderItem.containsKey('related_Object') ? String.valueOf(reminderItem.get('related_Object')) : null,
            Related_Object_Label__c = reminderItem.containsKey('related_Object_Label') ? String.valueOf(reminderItem.get('related_Object_Label')) : null,
            Start_Reminder_After_H__c = reminderItem.containsKey('start_Reminder_After_H') ? Integer.valueOf(reminderItem.get('start_Reminder_After_H')) : null,
            Stop_Recurrence_After__c = reminderItem.containsKey('stop_Recurrence_After') ? Integer.valueOf(reminderItem.get('stop_Recurrence_After')) : null,
            Note__c = reminderItem.containsKey('note') ? String.valueOf(reminderItem.get('note')) : null
        );

        upsert reminder;
        
        return getApprovalReminderList();
    }

    //Load data for marker action
    @AuraEnabled
    public static Map<String, object> getApprovalProcessMeta(String processId){
        Map<String, object> mRetData = new Map<String, object>{'returnCode' => 0};

        try{
            ProcessDefinition approvalProcess = [   SELECT Id,DeveloperName,State,Name,TableEnumOrId
                                                    FROM ProcessDefinition 
                                                    WHERE Id = :processId];

            List<Map<String, String>> userFieldsOptions = new List<Map<String, String>>();
            
            //Get fields for the related object
            Schema.DescribeSObjectResult objectDesc = Schema.getGlobalDescribe().get(approvalProcess.TableEnumOrId).getDescribe();
        
            for(Schema.SObjectField field : objectDesc.fields.getMap().values()){
                            
                Schema.DescribeFieldResult dfr = field.getDescribe();

                if(dfr.getType() == Schema.DisplayType.REFERENCE) {
                    String referenceto;
                    for(Schema.sObjectType refTo : dfr.getReferenceTo()){
                        if(String.isBlank(referenceto) || refTo.getDescribe().getName() == 'User'){
                            referenceto = refTo.getDescribe().getName();
                        }
                    }
                    
                    if(referenceto == 'User'){
                        userFieldsOptions.add(new Map<String, String>{'label'=>dfr.getLabel(), 'value'=>dfr.getName()});
                    }
                }
            }

            mRetData.put('approvalName', approvalProcess.Name);
            mRetData.put('objectName', objectDesc.getName());
            mRetData.put('objectLabel', objectDesc.getLabel());
            mRetData.put('userFieldsOptions', userFieldsOptions);
        } 
        catch (Exception ex) {
            mRetData = new Map<String, object>{'returnCode' => 1, 'returnMessage' => ex.getMessage()};
        }
        
        return mRetData;
    }

    @AuraEnabled
    public static Map<String, object> scheduleProcess(Integer interval){
        Map<String, object> mRetData = new Map<String, object>{'returnCode' => 0};

        try {        
            ApexClass clsItem = [SELECT Id,NamespacePrefix FROM ApexClass WHERE Name ='ApprovalReminderBatch' LIMIT 1];
            String classRunner = String.isBlank(clsItem.NamespacePrefix) ? 'ApprovalReminderBatch' : (clsItem.NamespacePrefix + '.ApprovalReminderBatch');
            mba_services.AsyncJobServices.addAsyncJobRepeated (
                'Approval Process Reminders', 'Batch', classRunner, 'High', null, System.now(), 'Minutes', interval);
        } 
        catch (Exception ex) {
            mRetData = new Map<String, object>{'returnCode' => 1, 'returnMessage' => ex.getMessage()};
        }

        return mRetData;
    }

    @AuraEnabled
    public static Map<String, object> abortProcess(){
        Map<String, object> mRetData = new Map<String, object>{'returnCode' => 0};

        try {
            ApexClass clsItem = [SELECT Id,NamespacePrefix FROM ApexClass WHERE Name ='ApprovalReminderBatch' LIMIT 1];
            String classRunner = String.isBlank(clsItem.NamespacePrefix) ? 'ApprovalReminderBatch' : (clsItem.NamespacePrefix + '.ApprovalReminderBatch');

            List<mba_services__Async_Job__c> runningJob = [ SELECT Id
                                                            FROM mba_services__Async_Job__c
                                                            WHERE mba_services__Class_Runner__c = :classRunner
                                                            AND mba_services__Status__c = 'Queued'
                                                            LIMIT 1];

            String retMsg = mba_services.AsyncJobServices.abortScheduleJob(runningJob.get(0).Id);

            mRetData = (Map<String, object>) JSON.deserializeUntyped(retMsg);
        } 
        catch (Exception ex) {
            mRetData = new Map<String, object>{'returnCode' => 1, 'returnMessage' => ex.getMessage()};
        }

        return mRetData;
    }

    public class ReminderProcess{
        @AuraEnabled
        public String remId;
        @AuraEnabled
        public String remName;
        @AuraEnabled
        public Boolean active;
        @AuraEnabled
        public String business_Hours;
        @AuraEnabled
        public String recipient_List;
        @AuraEnabled
        public Integer recurring_Every_H;
        @AuraEnabled
        public String related_Approval_Process;
        @AuraEnabled
        public String related_Object;
        @AuraEnabled
        public String related_Object_Label;
        @AuraEnabled
        public Integer start_Reminder_After_H;
        @AuraEnabled
        public Integer stop_Recurrence_After;
        @AuraEnabled
        public String note;

        public ReminderProcess(Approval_Process_Reminder__c reminder){
            remId = reminder.Id;
            remName = reminder.Name;
            active = reminder.Active__c;
            business_Hours = reminder.Business_Hours__c;
            recipient_List = reminder.Recipient_List__c;
            recurring_Every_H = Integer.valueOf(reminder.Recurring_Every_H__c);
            related_Approval_Process = reminder.Related_Approval_Process__c;
            related_Object = reminder.Related_Object__c;
            related_Object_Label = reminder.Related_Object_Label__c;
            start_Reminder_After_H = Integer.valueOf(reminder.Start_Reminder_After_H__c);
            stop_Recurrence_After = Integer.valueOf(reminder.Stop_Recurrence_After__c);
            note = reminder.Note__c;
        }
    }
}
