import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getPublishedEvents from '@salesforce/apex/EpicEventzCatalogController.getPublishedEvents';

export default class EpicEventzDiscovery extends NavigationMixin(LightningElement) {
    searchKey = '';
    category = '';
    eventType = '';
    events = [];
    selectedEvent;
    isLoading = true;
    errorMessage;

    get hasEvents() {
        return !this.isLoading && !this.errorMessage && this.events.length > 0;
    }

    get showEmptyState() {
        return !this.isLoading && !this.errorMessage && this.events.length === 0;
    }

    @wire(getPublishedEvents, {
        searchKey: '$searchKey',
        category: '$category',
        eventType: '$eventType'
    })
    wiredEvents({ data, error }) {
        if (data) {
            this.events = data.map((event) => ({
                ...event,
                displayCategory: event.Event_Category__c || 'Featured event',
                displayEventType: event.Event_Type__c || 'Event',
                displayDate: this.formatDate(event.Start_Date_Time__c || event.Start_Date__c),
                displayPrice: event.Base_Price__c ? `$${event.Base_Price__c}` : 'Price on request',
                posterStyle: event.Poster_URL__c
                    ? `background-image: linear-gradient(180deg, transparent, #0b1020), url("${event.Poster_URL__c}")`
                    : ''
            }));
            this.isLoading = false;
            this.errorMessage = undefined;
        } else if (error) {
            this.events = [];
            this.isLoading = false;
            this.errorMessage = error.body?.message || 'Events could not be loaded.';
        }
    }

    handleSearchChange(event) {
        this.searchKey = event.target.value;
        this.refreshResults();
    }

    handleCategoryChange(event) {
        this.category = event.target.value;
        this.refreshResults();
    }

    handleEventTypeChange(event) {
        this.eventType = event.target.value;
        this.refreshResults();
    }

    refreshResults() {
        this.selectedEvent = undefined;
        this.isLoading = true;
        this.errorMessage = undefined;
    }

    handleEventClick(event) {
        const eventId = event.currentTarget.dataset.eventId;
        this.selectedEvent = this.events.find((record) => record.Id === eventId);
        this.dispatchEvent(new CustomEvent('eventselected', {
            detail: { eventId },
            bubbles: true,
            composed: true
        }));
    }

    handleBackToEvents() {
        this.selectedEvent = undefined;
    }

    handleBookTickets() {
        if (!this.selectedEvent?.Id) {
            return;
        }

        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                name: 'Book_Tickets__c'
            },
            state: {
                c__eventId: this.selectedEvent.Id
            }
        });
    }

    formatDate(value) {
        return value ? new Intl.DateTimeFormat('en', { dateStyle: 'medium' }).format(new Date(value)) : 'Date to be announced';
    }
}
