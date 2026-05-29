import { LightningElement, api, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';

import STATUS_FIELD from '@salesforce/schema/Application__c.Status__c';
import IS_RESUBMISSION from '@salesforce/schema/Application__c.Is_Resubmission__c';

import PENDING_LABEL from '@salesforce/label/c.Approver_Banner_Message';
import APPROVED_LABEL from '@salesforce/label/c.Approved_Banner_Message';
import REJECTED_LABEL from '@salesforce/label/c.Rejected_Banner_Message';
import RESUBMIT_LABEL from '@salesforce/label/c.Resubmit_Banner_Message';

import SLA_BREACH_LABEL from '@salesforce/label/c.SLA_Breach_Banner_Message';
import SLA_WARNING_LABEL from '@salesforce/label/c.SLA_Warning_Banner_Message';
import SLA_BREACH_FIELD from '@salesforce/schema/Application__c.SLA_Breach_Date__c';

import isUserInApproverGroup from '@salesforce/apex/ApprovalHelper.isUserInApproverGroup';

export default class ApproverBanner extends LightningElement {

    @api recordId;

    showBanner = false;
    labelMessage;
    bannerClass = 'slds-theme_warning';

    @wire(getRecord, { recordId: '$recordId', fields: [STATUS_FIELD, IS_RESUBMISSION, SLA_BREACH_FIELD] })
    wiredApp({ data }) {

        console.log('WIRE FIRED');

        if (data) {
            const status = data.fields.Status__c.value;
            const isResub = data.fields.Is_Resubmission__c.value;
            const slaBreachDate = data.fields.SLA_Breach_Date__c.value;

            console.log('STATUS VALUE:', status);
            console.log('IS_RESUBMISSION:', isResub);

            // Only check group if status is relevant
            if (['Submitted', 'Approved', 'Rejected', 'Draft'].includes(status) && (isResub !== undefined)) {
                this.checkAccess(status, isResub, slaBreachDate);
            } else {
                this.showBanner = false;
            }

        }
    }

    /*checkAccess(status, isResub) {
        isUserInApproverGroup()
            .then(result => {
                if (!result) {
                    this.showBanner = false;
                    return;
                }

                console.log('result: ', result);

                // Set message + styling
                if (status === 'Submitted') {
                    this.labelMessage = PENDING_LABEL;
                    this.bannerClass = 'slds-theme_warning';
                } 
                else if (status === 'Approved') {
                    this.labelMessage = APPROVED_LABEL;
                    this.bannerClass = 'slds-theme_success';
                } 
                else if (status === 'Rejected') {
                    this.labelMessage = REJECTED_LABEL;
                    this.bannerClass = 'slds-theme_error';
                }
                else if (status === 'Draft' && isResub === true) {
                    this.labelMessage = RESUBMIT_LABEL;
                    this.bannerClass = 'slds-theme_warning';
                }

                this.showBanner = true;
            })
            .catch(() => {
                console.log('Full error:', err);
                console.log('Error body:', err?.body);
                console.log('Error message:', err?.body?.message);
                this.showBanner = false;
            });
    }*/

    checkAccess(status, isResub, slaBreachDate) {
        isUserInApproverGroup()
            .then(result => {
                if (!result) {
                    this.showBanner = false;
                    return;
                }

                const now = new Date();
                const breachDate = slaBreachDate ? new Date(slaBreachDate) : null;
                const twentyFourHours = new Date(now.getTime() + 24 * 60 * 60 * 1000);

                // ✅ SLA already breached — highest priority
                if (breachDate && breachDate < now && status === 'Submitted') {
                    this.labelMessage = SLA_BREACH_LABEL;
                    this.bannerClass  = 'slds-theme_error';
                    this.showBanner   = true;
                    return;
                }

                // ✅ SLA breaching within 24 hours
                if (breachDate && breachDate < twentyFourHours && status === 'Submitted') {
                    this.labelMessage = SLA_WARNING_LABEL;
                    this.bannerClass  = 'slds-theme_warning';
                    this.showBanner   = true;
                    return;
                }

                // ✅ Resubmission
                if (status === 'Draft' && isResub === true) {
                    this.labelMessage = RESUBMIT_LABEL;
                    this.bannerClass  = 'slds-theme_warning';
                    this.showBanner   = true;
                    return;
                }

                // ✅ Standard statuses
                if (status === 'Submitted') {
                    this.labelMessage = PENDING_LABEL;
                    this.bannerClass  = 'slds-theme_warning';
                } else if (status === 'Approved') {
                    this.labelMessage = APPROVED_LABEL;
                    this.bannerClass  = 'slds-theme_success';
                } else if (status === 'Rejected') {
                    this.labelMessage = REJECTED_LABEL;
                    this.bannerClass  = 'slds-theme_error';
                } else {
                    this.showBanner = false;
                    return;
                }
                this.showBanner = true;
            })
            .catch(() => {
                this.showBanner = false;
            });
    }

    get computedClass() {
        return `${this.bannerClass} slds-box slds-m-bottom_small`;
    }
}