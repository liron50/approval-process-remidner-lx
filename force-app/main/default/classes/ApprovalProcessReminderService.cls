public with sharing class ApprovalProcessReminderService {

    public static Map<String, object> sendApprovalProcessReminder(Approval_Process_Reminder__c reminderSetup){
        Map<String, object> result = new Map<String, object>{'returnCode'=>0};

        try{

            //Retrieve the relevant approval process reminder setup
            List<Approval_Process_Record__c> approvalProcessRecords = [ SELECT Id,Record_Id__c,ProcessInstance_Id__c,Alerts_Sent__c,Approver__c 
                                                                        FROM Approval_Process_Record__c
                                                                        WHERE Approval_Process_Reminder__c = :reminderSetup.Id AND status__c = 'Pending'];

            //per each key (record Id from approval + processInstanceId + approverId) its Approval Process Record (if exists)
            Map<String, Approval_Process_Record__c> keyAPRMap = new Map<String, Approval_Process_Record__c>();
            
            for(Approval_Process_Record__c apr : approvalProcessRecords){
                keyAPRMap.put(apr.Record_ID__c + '_' + apr.ProcessInstance_Id__c + '_' + apr.Approver__c, apr);
            }
                
            //list of APR recors for insert
            List<Approval_Process_Record__c> newAPRList = new List<Approval_Process_Record__c>();
            
            //Log message to insert, this will send alert
            List<mba_services__Log_Message__c> newLogList = new List<mba_services__Log_Message__c>();

            //Set of APR records that was increased by 1
            Set<Id> increasedAPRIdSet = new Set<Id>();
            
            //list of ProcessInstance
            List<ProcessInstanceWrp> processInstanceList = getProcessInstance(reminderSetup.Related_Approval_Process__c);
            
            //list of records Id in approval process
            List<Id> targetRecordIds = new List<Id>();

            //Map of approver to get their related managers
            Map<Id, User> approversMap = new Map<Id, User>();
            
            for ( ProcessInstanceWrp piw:   processInstanceList) {
                targetRecordIds.add(piw.targetObjectId);
                for (ProcessItemWrp pihw : piw.workItems) {
                    approversMap.put(pihw.ActorId, null);
                }
            }
            
            if(! targetRecordIds.isEmpty()){
                for(User userRec : [    SELECT Id,ManagerId FROM User WHERE Id IN :approversMap.keySet()]){
                    approversMap.put(userRec.Id, userRec);
                }

                List<Recipiant> recipiantList = (List<Recipiant>) JSON.deserialize(reminderSetup.Recipient_List__c, List<Recipiant>.class);

                //Should collect all relevant records Ids which currently in approval process, and query their related users (According to the setup in approval reminder)
                Schema.SObjectType objSchema = Schema.getGlobalDescribe().get(reminderSetup.Related_Object__c);
                Map<String, Schema.SObjectField> fieldMap = objSchema.getDescribe().fields.getMap();//This has the list of all field names.
        
                String soqlQuery = 'SELECT ';
                for(Schema.SObjectField s : fieldMap.values()){
                    soqlQuery += s.getDescribe().getName() + ',';
                }
                soqlQuery = soqlQuery.subString(0, soqlQuery.length() - 1);
               
                //Query data from the object in the approval process
                Map<Id, sObject> relatedRecordMap = new Map<Id, sObject>();
                for(sObject rec : Database.query(soqlQuery + ' FROM ' + reminderSetup.Related_Object__c + ' WHERE Id in :targetRecordIds')){
                    relatedRecordMap.put(rec.id, rec);
                }
                
                //Loop over all approval process records that were retrieved
                for ( ProcessInstanceWrp piw:   processInstanceList) {
                            
                    //Per each pending approver
                    for (ProcessItemWrp pihw : piw.workItems) {
                        
                        //Only users supported for reminders
                        if(pihw.actorId.getSobjectType().getDescribe().getName() == 'User'){

                            //Calculate the hours difference from time processinstance was created until now
                            Decimal pendingHours = reminderSetup.Business_Hours__c == null ? 
                                            (Double) ((system.now().getTime() - pihw.createdDate.getTime()))/1000/60/60 :
                                            (Double) BusinessHours.diff(reminderSetup.Business_Hours__c, pihw.createdDate, system.now())/1000/60/60;

                            mba_services__Log_Message__c newLog = new mba_services__Log_Message__c(
                                mba_services__Log_Level__c = 'Info', 
                                mba_services__Log_Type__c = 'Process', 
                                mba_services__Subject__c = 'Approval Process Reminder', 
                                mba_services__Message_Email__c = 'Note that the following ' + reminderSetup.Related_Object_Label__c + ' is pending approval for more than: ' + pendingHours.setScale(2) + ' hours. <br/>' + System.URL.getSalesforceBaseUrl().toExternalForm() + '/' + piw.targetObjectId);
                                
                            system.debug('###pendingHours:' + pendingHours);
                            
                            //If target object id inside the map, means alert was already sent for this record before
                            if(keyAPRMap.containsKey(piw.targetObjectId + '_' + piw.processId + '_' + pihw.actorId)){
                                
                                if(reminderSetup.Stop_Recurrence_After__c == 0 ||
                                    keyAPRMap.get(piw.targetObjectId + '_' + piw.processId + '_' + pihw.actorId).Alerts_Sent__c < reminderSetup.Stop_Recurrence_After__c){
                                    //calculate if hours that approval is pending divded by the alerts that were sent is greater than current number of alerts
                                    //If criteria aply - means it time to send another reminder
                                    if(math.Floor(pendingHours/reminderSetup.Recurring_Every_H__c) > keyAPRMap.get(piw.targetObjectId + '_' + piw.processId + '_' + pihw.actorId).Alerts_Sent__c){
                                        
                                        //Increase the Alert Send by 1
                                        keyAPRMap.get(piw.targetObjectId + '_' + piw.processId + '_' + pihw.actorId).Alerts_Sent__c ++;
                                        
                                        keyAPRMap.get(piw.targetObjectId + '_' + piw.processId + '_' + pihw.actorId).Pending_Hours__c = pendingHours;

                                        newLogList.addAll(getAlerts(newLog, recipiantList, approversMap.get(pihw.actorId), relatedRecordMap.get(piw.targetObjectId), Integer.valueOf(keyAPRMap.get(piw.targetObjectId + '_' + piw.processId + '_' + pihw.ActorId).Alerts_Sent__c)));
                                    }    
                                }

                                //This will be used later. Need to know which Approval Process Records was increased. Other
                                //records will be updated with Status = 'Approved'
                                increasedAPRIdSet.add(keyAPRMap.get(piw.targetObjectId + '_' + piw.processId + '_' + pihw.actorId).id);
                            }
                            else{   //No previous alert was sent for this record
                                
                                //Pending hour is more than the setup, should send first alert
                                if(pendingHours > reminderSetup.Start_Reminder_After_H__c){ 
                                    newLogList.addAll(getAlerts(newLog, recipiantList, approversMap.get(pihw.actorId), relatedRecordMap.get(piw.targetObjectId), 1));
                                    
                                    //Add new Approval Process Record        
                                    newAPRList.add(new Approval_Process_Record__c(  Approval_Process_Reminder__c = reminderSetup.id,
                                                                                    Status__c = 'Pending', 
                                                                                    Record_Id__c = piw.targetObjectId, 
                                                                                    ProcessInstance_Id__c = piw.processId, 
                                                                                    Alerts_Sent__c = 1,
                                                                                    Pending_Hours__c = pendingHours,
                                                                                    Approver__c = pihw.actorId));
                                }
                            }
                        }
                    }
                }
                
                //Evaluate old APR records that are no longer in the approval process. Should update their status to 'Approved'
                for(Approval_Process_Record__c apr : approvalProcessRecords){
                    //if not update earlier
                    if(!increasedAPRIdSet.contains(apr.id)){
                        apr.Status__c = 'Approved';
                    }
                }
                    
                //New Approval Process Records for insert
                if(! newAPRList.isEmpty()){
                    insert newAPRList;
                }
                
                //Update all existing Approval Process Records. This list contain 3 type of records:
                //1.Records that Alert_Sent was increased, and now another reminder will be send for them
                //2.Records that are no longer found in the pending ProcessInstances, therefore will be upadated to status 'Approved'
                //3.Records without any change in this run
                if(!approvalProcessRecords.isEmpty()){
                    update approvalProcessRecords;
                }

                //Send alerts
                if(! newLogList.isEmpty()){
                    insert newLogList;
                }
            }
            result.put('alertSent', newLogList.size());
        }
        catch(Exception ex){
            result = new Map<String, object>{'returnCode'=>1,'returnMessage'=>ex.getMessage()};
        }

        return result;
    }


    private static List<mba_services__Log_Message__c> getAlerts(mba_services__Log_Message__c newLog, List<Recipiant> recipiantList, User approver, sObject relatedRecord, Integer currentLevel){

        List<mba_services__Log_Message__c> newAlerts = new List<mba_services__Log_Message__c>();

        //Avoid duplicate - sending the same message to user twice
        Set<Id> addedUsers = new Set<Id>();

        for(Recipiant recItem : recipiantList){

            Integer fromLevel = recItem.fromLevel;
            
            if(fromLevel <= currentLevel){
                mba_services__Log_Message__c clonedMsg = newLog.clone();
                
                if(recItem.recipiantType == 'User'){
                    clonedMsg.mba_services__Notify_User_1__c = recItem.recipiant;
                }
                else if(recItem.recipiantType == 'User Field'){
                    String userValue = String.valueOf(relatedRecord.get(recItem.recipiant));
                            
                    if(! String.isBlank(userValue) && userValue.startsWith('005')){    //Only if the field reference to user record use it. Some field in SF can reference User/Queue
                        clonedMsg.mba_services__Notify_User_1__c = userValue;
                    }
                }
                else if(recItem.recipiantType == 'Approver'){
                    clonedMsg.mba_services__Notify_User_1__c = approver.Id;
                }
                else if(recItem.recipiantType == 'Approver Manager'){
                    if(approver.ManagerId != null){
                        clonedMsg.mba_services__Notify_User_1__c = approver.ManagerId;
                    }
                }

                if(! addedUsers.contains(clonedMsg.mba_services__Notify_User_1__c)){
                    addedUsers.add(clonedMsg.mba_services__Notify_User_1__c);
                    newAlerts.add(clonedMsg);
                }
            }
        }

        return newAlerts;
    }

    private static List<ProcessInstanceWrp> getProcessInstance(String approvalProcessId){
        List<ProcessInstanceWrp> processList = new List<ProcessInstanceWrp>();

        if(Test.isRunningTest()){
            ProcessInstanceWrp processWrp = new ProcessInstanceWrp('xxxid', UserInfo.getUserId());

            processWrp.addItem(UserInfo.getUserId(), System.now() - 10);
            processList.add(processWrp);
        }
        else{
            for(ProcessInstance pi :    [   SELECT Id,TargetObjectId, (SELECT Id,ActorId,CreatedDate FROM StepsAndWorkitems where StepStatus='Pending')
                                            FROM ProcessInstance 
                                            WHERE Status IN ('Pending','Hold','Reassigned','NoResponse')
                                            AND ProcessDefinition.Id = :approvalProcessId]){
                
                ProcessInstanceWrp processWrp = new ProcessInstanceWrp(pi.Id, pi.TargetObjectId);

                for (ProcessInstanceHistory pih : pi.StepsAndWorkItems) {
                    processWrp.addItem(pih.ActorId, pih.CreatedDate);
                }

                processList.add(processWrp);
            }
        }

        return processList;
    }

    public class ProcessInstanceWrp{
        public String processId;
        public String targetObjectId;
        public List<ProcessItemWrp> workItems;

        public ProcessInstanceWrp(String pId, String targetId){
            processId = pId;
            targetObjectId = targetId;
            workItems = new List<ProcessItemWrp>();
        }

        public void addItem(Id approverId, Datetime createdDate){
            workItems.add(new ProcessItemWrp(approverId, createdDate));
        }
    }

    public class ProcessItemWrp{
        public Id actorId;
        public Datetime createdDate;

        public ProcessItemWrp(Id aId, Datetime cDate){
            actorId = aId;
            createdDate = cDate;
        }
    }

    public class Recipiant{
        public String recipiantType;
        public String recipiant;
        public Integer fromLevel;
    }
}
