import { LightningElement, track, api} from 'lwc';

export default class MBALayoutItem extends LightningElement {
    @api itemLabel;
    @api itemApi;
    @api itemValue;
    @api isEditable = false;
    @api isRequired = false;
    @api helpText;
    @api comboboxOptions;
    @api disabledCategories;        //for rich text input
    @api duelListboxSize = 5;       //for dual list box

    //For lookup input
    @api objectApiName;
    @api iconName;
    @api displayField;
    @api displayFieldInSearch;
    @api isReadOnly = false;
    @api 
    get itemType(){
        return this._itemType;
    }
    set itemType(value){
        this._itemType = value;

        this.isLookup = value == 'lookup';
        this.isRichText = value == 'richtext';
        this.isDualListbox = value == 'duallistbox';
        this.isStandardInput = this.isLookup == false && this.isRichText == false && this.isDualListbox == false;

        if(this.isStandardInput == true){
            this.showText = value == 'text' || value == 'textarea';
            this.showCombobox = value == 'combobox';
            this.showNumber = value == 'number';
            this.showDatetime = value == 'datetime';
            this.showDate = value == 'date';
            this.showCheckbox = value == 'checkbox';
            
            this.showCheckboxInput = value == 'checkbox';
            this.showTextAreaInput = value == 'textarea';
            this.showTextInput = value != 'checkbox' && value != 'textarea' && value != 'combobox';
            this.showComboboxInput = value == 'combobox';
        }
    }

    @track showText = false;
    @track showCombobox = false;
    @track showNumber = false;
    @track showDatetime = false;
    @track showDate = false;
    @track showCheckbox = false;
    
    @track showTextInput = false;
    @track showCheckboxInput = false;
    @track showTextAreaInput = false;
    @track showComboboxInput = false;

    @track isStandardInput = false; //true if it is anything other than lookup or richtext or duallistbox
    @track isLookup = false;
    @track isRichText = false;
    @track isDualListbox = false;

    valueChangeEvent(event){

        if(this.itemType == 'checkbox'){
            this.itemValue = event.detail.checked;
        }
        else{
            this.itemValue = event.detail.value;
        }
        
        this.dispatchEvent(new CustomEvent('inputvaluechange', {
            detail: {  
                data : {
                    newValue : this.itemValue,
                    field : this.itemApi
                }
            }
        }));
    }

    lookupAdded(event){

        this.dispatchEvent(new CustomEvent('inputvaluechange', {
            detail: {  
                data : {
                    newValue : (event.detail.data.record ? event.detail.data.record.Id : null),
                    field : this.itemApi
                }
            }
        }));
    }
}