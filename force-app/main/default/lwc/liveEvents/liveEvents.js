import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getEvents from '@salesforce/apex/EventController.getEvents';

export default class LiveEvents extends NavigationMixin(LightningElement) {
    events;
    error;
    loading = true;

    @wire(getEvents)
    wiredEvents({ data, error }) {
        this.loading = false;

        if (data) {
            this.events = data;
            this.error = undefined;
        } else if (error) {
            this.events = undefined;
            this.error = error;
            console.error('Error loading events:', error);
        }
    }

    handleBookTickets(event) {
        const selectedEventId = event.currentTarget?.dataset?.id;

        if (!selectedEventId) {
            console.error('Unable to resolve event ID for booking.');
            return;
        }

        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                name: 'Book_Tickets__c'
            },
            state: {
                c__eventId: selectedEventId
            }
        });
    }
}