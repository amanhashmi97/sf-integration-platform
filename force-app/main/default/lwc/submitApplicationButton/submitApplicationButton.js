import { LightningElement, api, wire } from 'lwc';
import submitApplication from '@salesforce/apex/ApplicationSubmissionService.submitApplication';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { refreshApex } from '@salesforce/apex';

import STATUS_FIELD from '@salesforce/schema/Application__c.Status__c';

export default class SubmitApplicationButton extends LightningElement {

    @api recordId;

    isLoading = false;
    wiredRecord;

    // 🔹 Fetch record status
    @wire(getRecord, { recordId: '$recordId', fields: [STATUS_FIELD] })
    recordHandler(value) {
        this.wiredRecord = value;
    }

    // 🔹 Check if Draft
    get isDraft() {
        const status = getFieldValue(this.wiredRecord?.data, STATUS_FIELD);
        return status === 'Draft';
    }

    // 🔹 Submit handler
    handleSubmit() {
        this.isLoading = true;

        submitApplication({ appId: this.recordId })
            .then(() => {
                this.showToast('Success', 'Application submitted successfully', 'success');

                // Refresh record data
                return refreshApex(this.wiredRecord);
            })
            .catch(error => {
                let message = 'Something went wrong';

                if (error?.body?.message) {
                    message = error.body.message;
                }

                this.showToast('Error', message, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    // 🔹 Toast helper
    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }
    
    connectedCallback() {
        console.log('SubmitApplicationButton loaded');
    }
}