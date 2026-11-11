import { LightningElement, wire } from 'lwc';
import getMyBookings from '@salesforce/apex/BookingController.getMyBookings';

export default class EpicEventzMyBookings extends LightningElement {
    bookings = [];
    isLoading = true;
    errorMessage;

    @wire(getMyBookings)
    wiredBookings({ data, error }) {
        if (data) {
            this.bookings = data.map((booking) => ({
                ...booking,
                eventName: booking.Event__r?.Name || 'Event details unavailable',
                eventDate: this.formatDate(booking.Event__r?.Start_Date_Time__c),
                ticketName: booking.Ticket_Type__r?.Name || 'Ticket details unavailable',
                displayTotal: this.formatCurrency(booking.Total_Amount__c)
            }));
            this.errorMessage = undefined;
            this.isLoading = false;
        } else if (error) {
            this.bookings = [];
            this.errorMessage =
                error?.body?.message ||
                error?.message ||
                'Your bookings could not be loaded.';
            this.isLoading = false;
        }
    }

    get hasBookings() {
        return !this.isLoading && !this.errorMessage && this.bookings.length > 0;
    }

    get showEmptyState() {
        return !this.isLoading && !this.errorMessage && this.bookings.length === 0;
    }

    formatDate(value) {
        return value
            ? new Intl.DateTimeFormat('en-IN', {
                dateStyle: 'medium',
                timeZone: 'Asia/Kolkata'
            }).format(new Date(value))
            : 'Date to be announced';
    }

    formatCurrency(value) {
        const amount = Number(value);
        return Number.isFinite(amount)
            ? new Intl.NumberFormat('en-IN', {
                style: 'currency',
                currency: 'INR',
                minimumFractionDigits: 2,
                maximumFractionDigits: 2
            }).format(amount)
            : 'Amount unavailable';
    }
}
