global with sharing class ApprovalReminderBatch implements mba_services.IRunAsyncJobBatch, Database.Batchable<sObject>, Database.Stateful{
    private mba_services__Async_Job__c asyncJob;
    private List<String> errors = new List<String>();
    private Integer alertSent = 0;

    global ApprovalReminderBatch() {}

    public ApprovalReminderBatch (mba_services__Async_Job__c relatedJob){
        asyncJob = relatedJob;
    }

    global Id run(mba_services__Async_Job__c relatedJob){
        return Database.executeBatch(new ApprovalReminderBatch(relatedJob), 1);
    }
    
    global Database.QueryLocator start(Database.BatchableContext bc){
        String sqlQuery =   'SELECT Id,Name,Related_Object__c,Related_Approval_Process__c,Start_Reminder_After_H__c,Business_Hours__c,Recipient_List__c,'
                        +   'Stop_Recurrence_After__c,Recurring_Every_H__c FROM Approval_Process_Reminder__c WHERE Active__c = true';
        
        return Database.getQueryLocator(sqlQuery);
    }

    global void execute(Database.BatchableContext bc, list<Approval_Process_Reminder__c> scope){
    
        for(Approval_Process_Reminder__c proc : scope){    
            Map<String, object> result = ApprovalProcessReminderService.sendApprovalProcessReminder(proc);

            if(Integer.valueOf(result.get('returnCode')) != 0){
                proc.Note__c = 'Run competed with error: ' + String.valueOf(result.get('returnMessage'));
                errors.add(proc.Name + ' ' + proc.Note__c);
            }
            else{
                proc.Note__c = 'Process last run at ' + System.now().format() + '\n' + String.valueOf(result.get('alertSent')) + ' alerts were sent.';
                alertSent += Integer.valueOf(result.get('alertSent'));
            }
        }

        update scope;
    }
    
    global void finish(Database.BatchableContext bc){
    
        String summaryMessage = 'Completed at ' + System.now().format() + '<br/>';
        summaryMessage += alertSent + ' alerts were sent<br/>';
        
        if(errors.isEmpty() == false){
            summaryMessage +=' Following error was found:<br/>';
            
            for(String strError : errors){
                summaryMessage += strError + '<br/>';
            }
        }
        
        mba_services.AsyncJobServices.closeAsyncJob(
            asyncJob.Id, 
            errors.isEmpty(), 
            summaryMessage, 
            null,
            null,
            false);
    }
}
