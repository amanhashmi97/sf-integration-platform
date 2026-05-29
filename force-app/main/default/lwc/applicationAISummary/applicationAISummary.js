import { LightningElement, api, track } from 'lwc';
import generateSummary from '@salesforce/apex/AISummaryController.generateSummary';

export default class ApplicationAISummary extends LightningElement {

    @api recordId;
    @track summary;
    @track isLoading = false;
    @track error;
    @track generatedTime;

    // ✅ Auto-load on component mount
    connectedCallback() {
        this.generateSummary();
    }

    get showEmpty() {
        return !this.isLoading && !this.summary && !this.error;
    }

    generateSummary() {
        this.isLoading = true;
        this.error     = null;
        this.summary   = null;

        generateSummary({ recordId: this.recordId })
            .then(result => {
                this.summary       = result;
                this.generatedTime = new Date().toLocaleString();
                this.isLoading     = false;
            })
            .catch(e => {
                this.error     = e.body?.message ?? 'Failed to generate summary.';
                this.isLoading = false;
            });
    }
}