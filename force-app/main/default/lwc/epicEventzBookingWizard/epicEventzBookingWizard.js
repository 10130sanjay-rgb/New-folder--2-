import { LightningElement, api } from 'lwc';
import executeTransaction from '@salesforce/apex/EpicEventzBookingEngine.executeTransaction';

export default class EpicEventzBookingWizard extends LightningElement {
    @api eventId;
    @api attendeeId;
    @api ticketCount = 1;
    step = 1;
    message;
    isSubmitting = false;

    get isSelectionStep() { return this.step === 1; }
    get isInformationStep() { return this.step === 2; }
    get isConfirmationStep() { return this.step === 3; }
    get stepOneClass() { return `step ${this.step === 1 ? 'step--active' : ''}`; }
    get stepTwoClass() { return `step ${this.step === 2 ? 'step--active' : ''}`; }
    get stepThreeClass() { return `step ${this.step === 3 ? 'step--active' : ''}`; }

    handleEventIdChange(event) { this.eventId = event.target.value.trim(); }
    handleAttendeeIdChange(event) { this.attendeeId = event.target.value.trim(); }
    handleTicketCountChange(event) { this.ticketCount = Number(event.target.value); }
    goToSelection() { this.step = 1; }
    goToInformation() {
        if (this.eventId && this.ticketCount > 0) this.step = 2;
        else this.message = 'Enter a valid event Id and ticket count.';
    }
    goToConfirmation() {
        if (this.attendeeId) this.step = 3;
        else this.message = 'Enter an attendee record Id.';
    }
    submitBooking() {
        this.isSubmitting = true;
        this.message = undefined;
        executeTransaction({ eventId: this.eventId, attendeeId: this.attendeeId, ticketCount: this.ticketCount })
            .then((response) => {
                this.message = response.success
                    ? `Booking created. Reference: ${response.referenceId}`
                    : `Booking not completed: ${response.status}`;
            })
            .catch((error) => { this.message = error.body?.message || 'Booking could not be completed.'; })
            .finally(() => { this.isSubmitting = false; });
    }
}
