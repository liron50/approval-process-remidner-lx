import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getInitData from '@salesforce/apex/ManageApprovalProcessReminderCotroller.getInitData';
import deleteApprovalReminder from '@salesforce/apex/ManageApprovalProcessReminderCotroller.deleteApprovalReminder';
import saveApprovalReminder from '@salesforce/apex/ManageApprovalProcessReminderCotroller.saveApprovalReminder';
import getApprovalProcessMeta from '@salesforce/apex/ManageApprovalProcessReminderCotroller.getApprovalProcessMeta';
import scheduleProcess from '@salesforce/apex/ManageApprovalProcessReminderCotroller.scheduleProcess';
import abortProcess from '@salesforce/apex/ManageApprovalProcessReminderCotroller.abortProcess';

export default class ManageApprovalProcessReminder extends LightningElement {

    @track reminderList = [];
    @track isLoading = true;
    initRun = false;

    @track showEditDialog = false;
    @track isProcessRunning = false;
    @track processInterval = 30;
    @track showRunDialog = false;
    @track reminderInDialog;
    @track recipiantsList;
    @track userFieldsOptions;

    get recipiantTypeOptions(){
        return [
            {label: 'Approver', value: 'Approver'},
            {label: 'Approver Manager', value: 'Approver Manager'},
            {label: 'User', value: 'User'},
            {label: 'User Field', value: 'User Field'}
        ];
    }


    connectedCallback(){
        if(this.initRun == false){
            this.initRun = true;
            getInitData().then(
                result =>{
                    this.reminderList = result.reminderList;
                    this.isProcessRunning = result.isProcessRunning;
                    this.isLoading = false;
                }
            );  
        }
    }

    getReminderList(res){
        this.reminderList = res;
        this.isLoading = false;
    }

    openEditDialog(event){
        this.reminderInDialog = {stop_Recurrence_After: 0};
        this.recipiantsList = [];
        let recId = event.currentTarget.dataset.recid;

        if(recId){
            for(let rItem in this.reminderList){
                if(this.reminderList[rItem].remId == recId){
                    this.reminderInDialog = this.reminderList[rItem];

                    if(this.reminderList[rItem].recipient_List){
                        this.recipiantsList = JSON.parse(this.reminderList[rItem].recipient_List);
                    }
                    break;
                }
            }
        }
        else{
            this.recipiantsList.push({
                recipiantIndex: this.recipiantsList.length + 1,
                recipiantType: 'Approver', 
                fromLevel: 1,
                recipiant: null,
                recipiantLabel: null,
                isUser: false,
                isUserField: false
            });
        }

        if(this.reminderInDialog.related_Approval_Process){
            getApprovalProcessMeta({processId: this.reminderInDialog.related_Approval_Process}).then(
                result =>{
                    this.userFieldsOptions = result.userFieldsOptions;
                    this.userFieldsOptions.sort(this.compareOption);
                }
            );
        }
        
        this.showEditDialog = true;
    }

    saveEditDialog(){
        this.isLoading = true;

        this.reminderInDialog.recipient_List = JSON.stringify(this.recipiantsList);
        saveApprovalReminder({reminderItem: this.reminderInDialog}).then(
            result =>{
                this.getReminderList(result);
                this.isLoading = false;
            }
        );

        this.showEditDialog = false;
    }

    setActivateProc(event){
        let recId = event.currentTarget.dataset.recid;
        let itemForUpd;
        for(let rItem in this.reminderList){
            if(this.reminderList[rItem].remId == recId){
                this.reminderList[rItem].active = event.currentTarget.dataset.act;
                itemForUpd = this.reminderList[rItem];
            }
        }

        this.isLoading = true;

        saveApprovalReminder({reminderItem: itemForUpd}).then(
            result =>{
                this.getReminderList(result);
                this.isLoading = false;
            }
        );
    }

    closeEditDialog(){
        this.showEditDialog = false;
    }

    reminderPropertyChange(event){
        this.reminderInDialog[event.detail.data.field] = event.detail.data.newValue;

        if(event.detail.data.field == 'related_Approval_Process'){
            if(event.detail.data.newValue){
                getApprovalProcessMeta({processId: event.detail.data.newValue}).then(
                    result =>{
                        this.userFieldsOptions = result.userFieldsOptions;
                        this.userFieldsOptions.sort(this.compareOption);

                        this.reminderInDialog.related_Object = result.objectName;
                        this.reminderInDialog.related_Object_Label = result.objectLabel;

                        if(! this.reminderInDialog.remName){
                            this.reminderInDialog.remName = result.approvalName;
                        }
                    }
                );
            }
        }
    }

    addRecipiant(){
        this.recipiantsList.push({
            recipiantIndex: this.recipiantsList.length + 1,
            recipiantType: 'User', 
            fromLevel: 1,
            recipiant: null,
            recipiantLabel: null,
            isUser: true,
            isUserField: false
        });
    }

    recipiantTypeAdded(event){
        for(let recItem in this.recipiantsList){
            if(this.recipiantsList[recItem].recipiantIndex == event.currentTarget.dataset.recipiantIndex){
                this.recipiantsList[recItem].recipiantType = event.detail.value;
                this.recipiantsList[recItem].recipiant = null;
                this.recipiantsList[recItem].recipiantLabel = null;
                this.recipiantsList[recItem].isUser = this.recipiantsList[recItem].recipiantType == 'User';
                this.recipiantsList[recItem].isUserField = this.recipiantsList[recItem].recipiantType == 'User Field';
            }
        }
    }

    userRecipiantSelected(event){
        for(let recItem in this.recipiantsList){
            if(this.recipiantsList[recItem].recipiantIndex == event.currentTarget.dataset.recipiantIndex){
                if(event.detail.data.record){
                    this.recipiantsList[recItem].recipiant = event.detail.data.record.Id;
                    this.recipiantsList[recItem].recipiantLabel = event.detail.data.record.Name;
                }
                else{
                    this.recipiantsList[recItem].recipiant = null;
                    this.recipiantsList[recItem].recipiantLabel = null;
                }
            }
        }
    }

    recipiantLevelAdded(event){
        for(let recItem in this.recipiantsList){
            if(this.recipiantsList[recItem].recipiantIndex == event.currentTarget.dataset.recipiantIndex){
                this.recipiantsList[recItem].fromLevel = event.detail.value;
            }
        }
    }

    fieldRecipiantSelected(event){
        for(let recItem in this.recipiantsList){
            if(this.recipiantsList[recItem].recipiantIndex == event.currentTarget.dataset.recipiantIndex){

                this.recipiantsList[recItem].recipiant = event.detail.value;
                this.recipiantsList[recItem].recipiantLabel = event.target.options.find(opt => opt.value === event.detail.value).label;
            }
        }
    }

    deleteRecipiant(event){
        for(let index = 0; index < this.recipiantsList.length; index++){
            if(this.recipiantsList[index].recipiantIndex == event.currentTarget.dataset.recipiantIndex){
                this.recipiantsList.splice(index, 1);
                break;
            }
        }

        //re-index recipiant items
        for(let index = 0; index < this.recipiantsList.length; index++){
            this.recipiantsList[index].recipiantIndex = index + 1;
        }
    }

    deleteReminder(event){
        if(confirm('Are you sure?')){

            this.isLoading = true;

            deleteApprovalReminder({recordId : event.currentTarget.dataset.recid}).then(
                result =>{

                    this.getReminderList(result);
                    this.isLoading = false;
                }
            );
        }
    }

    openRunDialog(){
        this.showRunDialog = true;
    }

    closeRunDialog(){
        this.showRunDialog = false;
    }

    inervalAdded(event){
        this.processInterval = event.detail.value;
    }

    runReminderSchedule(){
        scheduleProcess({interval: this.processInterval}).then(
            result =>{
                
                if(result.returnCode == 0){
                    this.dispatchEvent(new ShowToastEvent({title: 'Success', message: 'Scheduled successfully', variant: "success"}));
                    this.isProcessRunning = true;
                    this.showRunDialog = false;
                }
                else{
                    this.dispatchEvent(new ShowToastEvent({title: 'Error', message: result.returnMessage, variant: "error"}));
                }
            }
        );
    }

    abortProcessRun(){
        abortProcess().then(
            result =>{
                if(result.returnCode == 0){
                    this.dispatchEvent(new ShowToastEvent({title: 'Success', message: 'Aborted successfully', variant: "success"}));
                    this.isProcessRunning = false;
                }
                else{
                    this.dispatchEvent(new ShowToastEvent({title: 'Note', message: result.returnMessage, variant: "error"}));
                }
            }
        );
    }

    compareOption(a,b) {
        if (a.label < b.label){
            return -1;
        }
        if (a.label > b.label){
            return 1;
        }
        return 0;
    }
}