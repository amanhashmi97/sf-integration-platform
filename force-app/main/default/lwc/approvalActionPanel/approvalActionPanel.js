import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getRecordNotifyChange } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import processApproval from '@salesforce/apex/ApprovalActionController.processApproval';
import getApprovalDetails from '@salesforce/apex/ApprovalActionController.getApprovalDetails';
import canUserAct from '@salesforce/apex/ApprovalActionController.canUserAct';
import { refreshApex } from '@salesforce/apex';

const FIELDS = ['Application__c.Status__c'];

export default class ApprovalActionPanel extends LightningElement {

    @api recordId;
    @track status;
    @track actionTakenBy;
    @track approvalComments;
    @track rejectComments = '';
    @track showRejectModal = false;
    @track isActing = false;
    @track isLoading = true;
    @track isApprover = false;
    @track showApproveModal = false;
    @track approveComments = 'Approved by admin.';

    _wiredRecord;

    // Add wire
    @wire(canUserAct)
    wiredApprover({ data }) {
        if (data !== undefined) {
            this.isApprover = data;
        }
    }

    // Update isPending getter
    get isPending() {
        return this.status === 'Submitted' && this.isApprover;
    }

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredRecord(result) {
        this._wiredRecord = result;
        if (result.data) {
            this.status = result.data.fields.Status__c.value;
            this.loadApprovalDetails();
        }
    }

    loadApprovalDetails() {
        getApprovalDetails({ recordId: this.recordId })
            .then(result => {
                this.actionTakenBy = result.actorName;
                this.approvalComments = result.comments;
            })
            .catch(() => {})
            .finally(() => { this.isLoading = false; });
    }

    get isReady() { return !this.isLoading; }
    get isPending() { return this.status === 'Submitted'; }
    get isActed() { return this.status === 'Approved' || this.status === 'Rejected'; }
    get noActionYet() { return !this.actionTakenBy; }

    get statusBadgeClass() {
        const map = {
            'Draft':     'slds-badge status-draft',
            'Submitted': 'slds-badge status-submitted',
            'Approved':  'slds-badge status-approved',
            'Rejected':  'slds-badge status-rejected'
        };
        return map[this.status] ?? 'slds-badge';
    }

    openApproveModal()  { this.showApproveModal = true; }
    closeApproveModal() { this.showApproveModal = false; }
    handleApproveCommentsChange(e) { this.approveComments = e.target.value; }

    handleApprove() {
        this.isActing = true;
        processApproval({ 
            recordId: this.recordId, 
            action: 'Approve', 
            comments: this.approveComments 
        })
            .then(() => {
                this.showToast('Success', 'Application approved.', 'success');
                this.closeApproveModal();
                return refreshApex(this._wiredRecord);
            })
            .then(() => {
                this.loadApprovalDetails(); // ✅ re-fetches approval details
                getRecordNotifyChange([{ recordId: this.recordId }]);
            })
            .catch(e => this.showToast('Error', e?.body?.message ?? 'Approval failed.', 'error'))
            .finally(() => { this.isActing = false; });
    }

    openRejectModal() { this.showRejectModal = true; }
    closeRejectModal() { this.showRejectModal = false; }
    handleCommentsChange(e) { this.rejectComments = e.target.value; }

    handleReject() {
        if (!this.rejectComments) {
            this.showToast('Error', 'Comments required for rejection.', 'error');
            return;
        }
        this.isActing = true;
        processApproval({ recordId: this.recordId, action: 'Reject', comments: this.rejectComments })
            .then(() => {
                this.showToast('Success', 'Application rejected.', 'success');
                this.closeRejectModal();
                return refreshApex(this._wiredRecord);
            })
            .then(() => {
                this.loadApprovalDetails(); // ✅ re-fetches approval details
                getRecordNotifyChange([{ recordId: this.recordId }]);
            })
            .catch(e => this.showToast('Error', e?.body?.message ?? 'Rejection failed.', 'error'))
            .finally(() => { this.isActing = false; });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}