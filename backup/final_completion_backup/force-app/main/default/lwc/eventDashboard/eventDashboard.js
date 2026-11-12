import { LightningElement, api } from 'lwc';
import processRegistration from '@salesforce/apex/EpicEventzEngine.processRegistration';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class EventDashboard extends LightningElement {
    @api title = 'EpicEventz Strategic Command & Booking Desk';
    @api subtitle = 'Production booking verification console';
    @api periodLabel = 'This month';
    @api totalEvents = '48';
    @api upcomingEvents = '12';
    @api activeAttendees = '2,846';
    @api revenue = '$128k';
    @api accentColor = '#e1262f';
    @api recordId;

    operationMessage = '';
    operationVariant = '';
    isProcessing = false;

    get operationMessageClass() {
        return `operation-message operation-message--${this.operationVariant}`;
    }

    get operationIcon() {
        const icons = {
            success: 'utility:success',
            warning: 'utility:warning',
            error: 'utility:error'
        };
        return icons[this.operationVariant] || 'utility:info';
    }

    handleTestBooking() {
        const eventInput = this.template.querySelector('[data-id="evtId"]');
        const attendeeInput = this.template.querySelector('[data-id="attId"]');
        const eventId = eventInput.value.trim();
        const attendeeId = attendeeInput.value.trim();

        if (!eventId || !attendeeId) {
            this.showToast('Validation Error', 'Please supply both Event and Attendee IDs.', 'error');
            this.setOperationMessage('Please supply both Event and Attendee IDs.', 'error');
            return;
        }

        this.isProcessing = true;
        this.operationMessage = '';

        processRegistration({
            eventId,
            attendeeId,
            ticketTypeName: 'Standard'
        })
            .then((result) => {
                if (result === 'DUPLICATE_REGISTRATION') {
                    this.setOperationMessage('Action blocked: attendee is already registered for this event.', 'error');
                    this.showToast('Blocked', 'Duplicate registration detected.', 'error');
                } else if (result === 'ADDED_TO_WAITLIST') {
                    this.setOperationMessage('Capacity reached: attendee was added to the waitlist.', 'warning');
                    this.showToast('Waitlisted', 'Attendee was added to the waitlist.', 'warning');
                } else {
                    this.setOperationMessage(`Registration created successfully. ID: ${result}`, 'success');
                    this.showToast('Success', 'Registration created.', 'success');
                }
            })
            .catch((error) => {
                const message = this.getErrorMessage(error);
                this.setOperationMessage(`Database error: ${message}`, 'error');
                this.showToast('Database Error', message, 'error');
            })
            .finally(() => {
                this.isProcessing = false;
            });
    }

    setOperationMessage(message, variant) {
        this.operationMessage = message;
        this.operationVariant = variant;
    }

    getErrorMessage(error) {
        return error?.body?.message || error?.message || 'The registration could not be processed.';
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}