import { LightningElement, api, track, wire } from 'lwc';
import search from '@salesforce/apex/SearchRecordsController.search';
import getRecordInit from '@salesforce/apex/SearchRecordsController.getRecordInit';

const DELAY = 300;

export default class CustomSearchRecords extends LightningElement {
    @api valueId;
    @api objName = 'Account';
    @api iconName = 'standard:account';
    @api labelName;
    @api isReadOnly = false;
    @api currentRecordId;
    @api placeholder = 'Search';
    @api fields = ['Name'];
    @api displayFields = 'Name';
    @api removeLabel = 'Remove selected option';

    @track error;

    searchTerm;
    delayTimeout;

    searchRecords;
    selectedRecord;
    objectLabel;
    isLoading = false;

    field;
    field1;
    field2;

    ICON_URL = '/apexpages/slds/latest/assets/icons/{0}-sprite/svg/symbols.svg#{1}';

    connectedCallback(){
        let icons           = this.iconName.split(':');
        this.ICON_URL       = this.ICON_URL.replace('{0}',icons[0]);
        this.ICON_URL       = this.ICON_URL.replace('{1}',icons[1]);
        if(this.objName.includes('__c')){
            let obj = this.objName.substring(0, this.objName.length-3);
            this.objectLabel = obj.replaceAll('_',' ');
        }else{
            this.objectLabel = this.objName;
        }
        this.objectLabel    = this.titleCase(this.objectLabel);
        let fieldList;
        if( !Array.isArray(this.displayFields)){
            fieldList       = this.displayFields.split(',');
        }else{
            fieldList       = this.displayFields;
        }
        
        if(fieldList.length == 1){
            this.field  = fieldList[0].trim();
        }
        else if(fieldList.length > 1){
            this.field  = fieldList[0].trim();
            this.field1 = fieldList[1].trim();
        }
        else if(fieldList.length > 2){
            this.field2 = fieldList[2].trim();
        }
        let combinedFields = [];
        fieldList.forEach(field => {
            if( !this.fields.includes(field.trim()) ){
                combinedFields.push( field.trim() );
            }
        });

        this.fields = combinedFields.concat( JSON.parse(JSON.stringify(this.fields)) );
        
        if(this.valueId){
            getRecordInit({objectName : this.objName, fields : this.fields, recordId : this.valueId}).then(
                result => {
                    this.selectedRecord = result;

                    this.selectedRecord.FIELD1 = this.selectedRecord[this.field];
                    this.selectedRecord.FIELD2 = this.selectedRecord[this.field1];
                    if( this.field2 ){
                        this.selectedRecord.FIELD3 = this.selectedRecord[this.field2];
                    }
                    else{
                        this.selectedRecord.FIELD3 = '';
                    }
                }
            );
        }
    }

    handleInputChange(event){
        window.clearTimeout(this.delayTimeout);
        const searchKey = event.target.value;
        //this.isLoading = true;
        this.delayTimeout = setTimeout(() => {
            if(searchKey.length >= 2){
                search({ 
                    objectName : this.objName,
                    fields     : this.fields,
                    searchTerm : searchKey 
                })
                .then(result => {
                    let stringResult = JSON.stringify(result);
                    let allResult    = JSON.parse(stringResult);
                    allResult.forEach( record => {
                        record.FIELD1 = record[this.field];
                        record.FIELD2 = record[this.field1];
                        if( this.field2 ){
                            record.FIELD3 = record[this.field2];
                        }else{
                            record.FIELD3 = '';
                        }
                    });
                    this.searchRecords = allResult;
                    
                })
                .catch(error => {
                    console.error('Error:', error);
                })
                .finally( ()=>{
                    //this.isLoading = false;
                });
            }
        }, DELAY);
    }

    handleSelect(event){
        let recordId = event.currentTarget.dataset.recordId;
        
        let selectRecord = this.searchRecords.find((item) => {
            return item.Id === recordId;
        });
        this.selectedRecord = selectRecord;
        
        const selectedEvent = new CustomEvent('lookup', {
            bubbles    : true,
            composed   : true,
            cancelable : true,
            detail: {  
                data : {
                    record          : selectRecord,
                    recordId        : recordId,
                    currentRecordId : this.currentRecordId
                }
            }
        });
        this.dispatchEvent(selectedEvent);
    }

    handleClose(){
        this.selectedRecord = undefined;
        this.searchRecords  = undefined;
        const selectedEvent = new CustomEvent('lookup', {
            bubbles    : true,
            composed   : true,
            cancelable : true,
            detail: {  
                data : {
                    record : undefined,
                    recordId : undefined,
                    currentRecordId : this.currentRecordId
                }
            }
        });
        this.dispatchEvent(selectedEvent);
    }

    titleCase(string) {
        var sentence = string.toLowerCase().split(" ");
        for(var i = 0; i< sentence.length; i++){
            sentence[i] = sentence[i][0].toUpperCase() + sentence[i].slice(1);
        }
        return sentence;
    }
}