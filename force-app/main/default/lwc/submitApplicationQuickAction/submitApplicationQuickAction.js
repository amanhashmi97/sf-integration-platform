import { LightningElement, api } from 'lwc';
import submitApplication from '@salesforce/apex/ApplicationSubmissionService.submitApplication';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { getRecordNotifyChange } from 'lightning/uiRecordApi';

export default class SubmitApplicationQuickAction extends LightningElement {

    @api recordId;
    isLoading = false;

    // ✅ No renderedCallback — no auto-fire
    // User must click Confirm

    handleSubmit() {
        if (!this.recordId) return;

        this.isLoading = true;

        submitApplication({ appId: this.recordId })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Success',
                    message: 'Application submitted successfully.',
                    variant: 'success'
                }));

                getRecordNotifyChange([{ recordId: this.recordId }]);
                this.dispatchEvent(new CloseActionScreenEvent());
            })
            .catch(error => {
                const message = error?.body?.message ?? 'Something went wrong.';

                this.dispatchEvent(new ShowToastEvent({
                    title: 'Error',
                    message,
                    variant: 'error'
                }));

                this.isLoading = false; // ✅ Re-show button on error so user can retry
            });
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}