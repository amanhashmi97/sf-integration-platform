import { LightningElement, track } from 'lwc';
import searchAccounts          from '@salesforce/apex/GuestApplicationController.searchAccounts';
import checkExistingApplication from '@salesforce/apex/GuestApplicationController.checkExistingApplication';
import submitApplication        from '@salesforce/apex/GuestApplicationController.submitApplication';
import getApplicationDetails    from '@salesforce/apex/GuestApplicationController.getApplicationDetails';
import resubmitApplication      from '@salesforce/apex/GuestApplicationController.resubmitApplication';

const STEPS = { LOGIN: 'login', FORM: 'form', STATUS: 'status', RESUBMIT: 'resubmit' };

const STATUS_CONFIG = {
    'Draft':     { msg: 'Your application has been submitted and is under review.', icon: '🕐', css: 'status-box submitted' },
    'Submitted': { msg: 'Application is currently being reviewed. Please wait.',    icon: '🕐', css: 'status-box submitted' },
    'Approved':  { msg: 'Congratulations! Your application has been approved.',     icon: '✅', css: 'status-box approved' },
    'Rejected':  { msg: 'Your application was not approved. See reason below.',     icon: '❌', css: 'status-box rejected' },
};

export default class GuestApplicationPortal extends LightningElement {

    @track step              = STEPS.LOGIN;
    @track name              = '';
    @track email             = '';
    @track accountSearchTerm = '';
    @track accountResults    = [];
    @track selectedAccountId = '';
    @track selectedAccountName = '';
    @track isNewAccount      = false;
    @track priority          = '';
    @track applicationType   = '';
    @track amount            = null;
    @track isLoading         = false;
    @track loginError        = '';
    @track submitError       = '';
    @track resubmitError     = '';
    @track currentStatus     = null;
    @track rejectionReason   = '';
    @track currentAppId      = null;
    @track selectedFileName  = '';
    @track selectedFileContent = '';
    @track selectedFileType  = '';
    @track fileSizeError = '';
    @track isFileReading = false;

    _searchTimeout;

    // Step getters
    get isStepLogin()    { return this.step === STEPS.LOGIN; }
    get isStepForm()     { return this.step === STEPS.FORM; }
    get isStepStatus()   { return this.step === STEPS.STATUS; }
    get isStepResubmit() { return this.step === STEPS.RESUBMIT; }

    // Status getters
    get isRejected()  { return this.currentStatus === 'Rejected'; }
    get isApproved()  { return this.currentStatus === 'Approved'; }
    get isPending()   { return this.currentStatus === 'Submitted' || this.currentStatus === 'Draft'; }

    get statusMessage()  { return STATUS_CONFIG[this.currentStatus]?.msg ?? 'No application found.'; }
    get statusIcon()     { return STATUS_CONFIG[this.currentStatus]?.icon ?? '❓'; }
    get statusBoxClass() { return STATUS_CONFIG[this.currentStatus]?.css ?? 'status-box'; }

    // Dropdown
    get showAccountDropdown() {
        return (this.accountResults.length > 0 ||
                this.accountSearchTerm.length >= 2) && !this.selectedAccountId;
    }

    // Update isReady getter
    get isReady() { return !this.isLoading && !this.isFileReading; }
    get isNotReady() { return this.isLoading || this.isFileReading; }

    // Picklist options
    get priorityOptions() {
        return [
            { label: 'High',   value: 'High' },
            { label: 'Medium', value: 'Medium' },
            { label: 'Low',    value: 'Low' }
        ];
    }
    get applicationTypeOptions() {
        return [
            { label: 'New Account', value: 'New Account' },
            { label: 'Amendment',   value: 'Amendment' },
            { label: 'Renewal',     value: 'Renewal' },
            { label: 'Closure',     value: 'Closure' }
        ];
    }

    // Field handlers
    handleName(e)            { this.name = e.target.value; }
    handleEmail(e)           { this.email = e.target.value; }
    handlePriority(e)        { this.priority = e.target.value; }
    handleApplicationType(e) { this.applicationType = e.target.value; }
    handleAmount(e)          { this.amount = e.target.value; }

    // Account search
    handleAccountSearch(e) {
        this.accountSearchTerm = e.target.value;
        this.selectedAccountId = '';
        this.selectedAccountName = '';
        clearTimeout(this._searchTimeout);
        if (this.accountSearchTerm.length < 2) {
            this.accountResults = [];
            return;
        }
        this._searchTimeout = setTimeout(() => {
            searchAccounts({ searchTerm: this.accountSearchTerm })
                .then(results => { this.accountResults = results; })
                .catch(() => { this.accountResults = []; });
        }, 300);
    }

    selectAccount(e) {
        const id   = e.currentTarget.dataset.id;
        const name = e.currentTarget.dataset.name;
        this.selectedAccountId   = id;
        this.selectedAccountName = name;
        this.accountSearchTerm   = '';
        this.accountResults      = [];
        this.isNewAccount        = false;

        // Check existing application for this account
        checkExistingApplication({ accountId: id })
            .then(result => {
                if (result) {
                    this.currentAppId    = result.id;
                    this.currentStatus   = result.status;
                    this.step            = STEPS.STATUS;
                }
            });
    }

    useNewAccount() {
        this.selectedAccountName = this.accountSearchTerm;
        this.selectedAccountId   = '';
        this.isNewAccount        = true;
        this.accountResults      = [];
    }

    clearAccount() {
        this.selectedAccountId   = '';
        this.selectedAccountName = '';
        this.accountSearchTerm   = '';
        this.isNewAccount        = false;
        this.accountResults      = [];
    }

    // Login — check existing application by email
    handleLogin() {
        this.loginError = '';
        if (!this.name || !this.email) {
            this.loginError = 'Name and email are required.';
            return;
        }
        if (!this.isValidEmail(this.email)) {
            this.loginError = 'Please enter a valid email address.';
            return;
        }
        this.isLoading = true;
        getApplicationDetails({ email: this.email })
            .then(result => {
                if (result) {
                    this.currentAppId    = result.id;
                    this.currentStatus   = result.status;
                    this.rejectionReason = result.rejectionReason;
                    this.step            = STEPS.STATUS;
                } else {
                    this.step = STEPS.FORM;
                }
            })
            .catch(() => { this.step = STEPS.FORM; })
            .finally(() => { this.isLoading = false; });
    }

    handleSubmit() {
        this.submitError = '';
        if (!this.selectedAccountName) {
            this.submitError = 'Please select or create an account.';
            return;
        }
        if (!this.priority || !this.applicationType || !this.amount) {
            this.submitError = 'All fields are required.';
            return;
        }
        this.isLoading = true;
        submitApplication({
            applicantName:   this.name,
            email:           this.email,
            accountId:       this.selectedAccountId,
            newAccountName:  this.isNewAccount ? this.selectedAccountName : '',
            priority:        this.priority,
            applicationType: this.applicationType,
            amount:          this.amount,
            fileName:        this.selectedFileName    ?? '',  // ✅
            fileContent:     this.selectedFileContent ?? '',  // ✅
            fileType:        this.selectedFileType    ?? ''   // ✅
        })
            .then(() => {
                this.currentStatus = 'Draft';
                this.step = STEPS.STATUS;
            })
            .catch(e => {
                this.submitError = e.body?.message ?? 'Submission failed.';
            })
            .finally(() => { this.isLoading = false; });
    }

    //File upload handler
    handleFileChange(e) {
        const file = e.target.files[0];
        if (!file) return;

        if (file.size < 100) {
            this.fileSizeError = 'File appears empty.';
            return;
        }
        const maxSize = 2 * 1024 * 1024;
        if (file.size > maxSize) {
            this.fileSizeError = 'File exceeds 2MB limit.';
            return;
        }

        this.fileSizeError       = '';
        this.selectedFileName    = file.name;
        this.selectedFileType    = file.type;
        this.selectedFileContent = '';
        this.isFileReading       = true; // ✅ disable button while reading

        const reader = new FileReader();
        reader.onload = () => {
            this.selectedFileContent = reader.result.split(',')[1];
            this.isFileReading       = false; // ✅ enable button when done
        };
        reader.onerror = () => {
            this.fileSizeError = 'Could not read file. Please try again.';
            this.isFileReading = false;
        };
        reader.readAsDataURL(file);
    }

    /*handleFileChange(e) {
        console.log('=== handleFileChange fired ===');
        const file = e.target.files[0];
        console.log('file:', file);
        console.log('file name:', file?.name);
        console.log('file size:', file?.size);
        console.log('file type:', file?.type);
        
        if (!file) {
            console.log('NO FILE - returning');
            return;
        }

        if (file.size < 100) {
            console.log('FILE TOO SMALL');
            this.fileSizeError = 'File appears empty.';
            return;
        }

        const maxSize = 2 * 1024 * 1024;
        if (file.size > maxSize) {
            console.log('FILE TOO LARGE');
            this.fileSizeError = 'File exceeds 2MB limit.';
            return;
        }

        this.fileSizeError       = '';
        this.selectedFileName    = file.name;
        this.selectedFileType    = file.type;
        this.selectedFileContent = '';
        this.isFileReading       = true;
        console.log('isFileReading set to true');

        const reader = new FileReader();
        reader.onload = () => {
            console.log('FileReader onload fired');
            console.log('result length:', reader.result?.length);
            this.selectedFileContent = reader.result.split(',')[1];
            console.log('selectedFileContent length:', this.selectedFileContent?.length);
            this.isFileReading = false;
            console.log('isFileReading set to false');
        };
        reader.onerror = (err) => {
            console.log('FileReader ERROR:', err);
            this.fileSizeError = 'Could not read file.';
            this.isFileReading = false;
        };
        reader.readAsDataURL(file);
        console.log('readAsDataURL called');
    }*/

    handleResubmit() {
        this.resubmitError = '';
        console.log('=== handleResubmit fired ===');
        console.log('currentAppId:', this.currentAppId);
        console.log('selectedFileName:', this.selectedFileName);
        console.log('selectedFileContent length:', this.selectedFileContent?.length);
        console.log('selectedFileType:', this.selectedFileType);
        
        if (!this.selectedFileContent) {
            this.resubmitError = 'Please upload a document before resubmitting.';
            return;
        }
        this.isLoading = true;
        resubmitApplication({
            originalAppId: this.currentAppId,  // ✅ correct param name
            fileName:      this.selectedFileName,
            fileContent:   this.selectedFileContent,
            fileType:      this.selectedFileType
        })
            .then(newAppId => {               // ✅ capture new app Id
                this.currentAppId    = newAppId;
                this.currentStatus   = 'Draft';
                this.rejectionReason = '';
                this.selectedFileName    = '';
                this.selectedFileContent = '';
                this.step = STEPS.STATUS;
            })
            .catch(e => {
                this.resubmitError = e.body?.message ?? 'Resubmission failed.';
            })
            .finally(() => { this.isLoading = false; });
    }

    // Navigation
    goBack()       { this.step = STEPS.LOGIN; }
    goToStatus()   { this.step = STEPS.STATUS; }
    goToResubmit() {
        this.selectedFileName    = '';
        this.selectedFileContent = '';
        this.step = STEPS.RESUBMIT;
    }

    resetAll() {
        this.step              = STEPS.LOGIN;
        this.accountSearchTerm = '';
        this.selectedAccountId = '';
        this.selectedAccountName = '';
        this.priority          = '';
        this.applicationType   = '';
        this.amount            = null;
        this.currentStatus     = null;
        this.currentAppId      = null;
        this.rejectionReason   = '';
        this.isNewAccount      = false;
        this.selectedFileName    = '';  
        this.selectedFileContent = '';  
        this.selectedFileType    = '';  
        this.fileSizeError       = '';  
    }

    isValidEmail(email) {
        return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
    }
}