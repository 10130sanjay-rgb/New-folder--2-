import { LightningElement, api, wire } from 'lwc';
import {
    CurrentPageReference,
    NavigationMixin
} from 'lightning/navigation';

import getEvents from '@salesforce/apex/EventController.getEvents';
import getTicketTypes from '@salesforce/apex/BookingController.getTicketTypes';
import createBooking from '@salesforce/apex/BookingController.createBooking';

export default class EventBooking extends NavigationMixin(LightningElement) {
    @api recordId;

    eventOptions = [];
    ticketOptions = [];

    selectedEventId = '';
    selectedTicketId = '';
    selectedTicket = null;

    quantity = 1;
    firstName = '';
    lastName = '';
    email = '';
    phone = '';

    isLoading = true;
    isSubmitting = false;

    errorMessage = '';
    successMessage = '';

    ticketCode = '';
    totalAmount = 0;

    eventsLoaded = false;
    lastLoadedEventId = '';
    urlEventId = '';

    connectedCallback() {
        if (
            !this.urlEventId &&
            typeof window !== 'undefined' &&
            window.location?.search
        ) {
            const searchParams = new URLSearchParams(
                window.location.search
            );

            const paramEventId = searchParams.get('c__eventId');

            if (paramEventId) {
                this.urlEventId = paramEventId;
                this.selectedEventId = paramEventId;
            }
        }

        this.loadEvents();
    }

    @wire(CurrentPageReference)
    getPageReference(pageReference) {
        const eventId = pageReference?.state?.c__eventId;

        if (eventId) {
            this.urlEventId = eventId;

            if (this.selectedEventId !== eventId) {
                this.selectedEventId = eventId;

                if (this.eventsLoaded) {
                    this.syncEventSelectionAndTickets();
                }
            }
        }
    }

    get showForm() {
        return !this.isLoading && !this.successMessage;
    }

    get ticketTypesDisabled() {
        return this.ticketOptions.length === 0;
    }

    get submitDisabled() {
        return this.isSubmitting || this.isLoading;
    }

    get estimatedTotal() {
        const price = Number(this.selectedTicket?.price || 0);
        const count = Number(this.quantity || 0);

        return (price * count).toFixed(2);
    }

    async loadEvents() {
        this.isLoading = true;
        this.errorMessage = '';

        try {
            const records = await getEvents();

            this.eventOptions = records.map((eventRecord) => ({
                label: eventRecord.Name,
                value: eventRecord.Id
            }));

            this.eventsLoaded = true;

            await this.syncEventSelectionAndTickets();
        } catch (error) {
            this.errorMessage = this.getErrorMessage(error);
        } finally {
            this.isLoading = false;
        }
    }

    async syncEventSelectionAndTickets() {
        if (!this.eventsLoaded) {
            return;
        }

        const candidateId =
            this.urlEventId ||
            this.selectedEventId ||
            this.recordId ||
            '';

        const matchedOption = this.eventOptions.find(
            (option) => option.value === candidateId
        );

        if (matchedOption) {
            this.selectedEventId = matchedOption.value;

            if (this.lastLoadedEventId !== this.selectedEventId) {
                await this.loadTickets();
            }
        } else {
            this.selectedEventId = '';
            this.ticketOptions = [];
            this.selectedTicketId = '';
            this.selectedTicket = null;
            this.lastLoadedEventId = '';
        }
    }

    async loadTickets() {
        this.ticketOptions = [];
        this.selectedTicketId = '';
        this.selectedTicket = null;
        this.errorMessage = '';

        if (!this.selectedEventId) {
            this.lastLoadedEventId = '';
            return;
        }

        try {
            const tickets = await getTicketTypes({
                eventId: this.selectedEventId
            });

            this.ticketOptions = tickets.map((ticket) => ({
                label: `${ticket.name} - ₹${ticket.price}`,
                value: ticket.id,
                ticket
            }));

            this.lastLoadedEventId = this.selectedEventId;
        } catch (error) {
            this.errorMessage = this.getErrorMessage(error);
            this.lastLoadedEventId = '';
        }
    }

    async handleEventChange(event) {
        this.selectedEventId = event.detail.value;
        this.urlEventId = '';

        await this.loadTickets();
    }

    handleTicketChange(event) {
        this.selectedTicketId = event.detail.value;

        const option = this.ticketOptions.find(
            (item) => item.value === this.selectedTicketId
        );

        this.selectedTicket = option ? option.ticket : null;
        this.quantity = 1;
    }

    handleQuantityChange(event) {
        this.quantity = Number(event.detail.value);
    }

    handleInputChange(event) {
        const field = event.target.name;
        this[field] = event.detail.value;
    }

    async handleSubmit(event) {
        event.preventDefault();

        if (this.isSubmitting) {
            return;
        }

        this.errorMessage = '';

        const form = this.template.querySelector('form');

        if (!form || !form.reportValidity()) {
            return;
        }

        if (!this.selectedEventId || !this.selectedTicketId) {
            this.errorMessage =
                'Please select an event and ticket type.';
            return;
        }

        const count = Number(this.quantity);

        if (!Number.isInteger(count) || count < 1 || count > 10) {
            this.errorMessage =
                'Choose between 1 and 10 tickets.';
            return;
        }

        if (
            this.selectedTicket &&
            count > Number(this.selectedTicket.availableQuantity)
        ) {
            this.errorMessage =
                'Not enough tickets are available.';
            return;
        }

        this.isSubmitting = true;

        try {
            const result = await createBooking({
                eventId: this.selectedEventId,
                ticketTypeId: this.selectedTicketId,
                firstName: this.firstName,
                lastName: this.lastName,
                email: this.email.trim(),
                phone: this.phone,
                quantity: count
            });

            if (!result || !result.bookingId) {
                throw new Error(
                    'The booking was created without returning a booking ID. Please check your bookings before trying again.'
                );
            }

            this.ticketCode = result.ticketCode;
            this.totalAmount = Number(
                result.totalAmount
            ).toFixed(2);

            this[NavigationMixin.Navigate](
                {
                    type: 'comm__namedPage',
                    attributes: {
                        name: 'Payment__c'
                    },
                    state: {
                        c__bookingId: result.bookingId
                    }
                },
                false
            );

        } catch (error) {
            this.errorMessage = this.getErrorMessage(error);
        } finally {
            this.isSubmitting = false;
        }
    }

    getErrorMessage(error) {
        return (
            error?.body?.message ||
            error?.message ||
            'Something went wrong. Please try again.'
        );
    }
}