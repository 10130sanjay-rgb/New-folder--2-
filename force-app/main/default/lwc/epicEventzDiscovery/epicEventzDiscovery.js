import { LightningElement, wire } from 'lwc';
import getPublishedEvents from '@salesforce/apex/EpicEventzCatalogController.getPublishedEvents';

export default class EpicEventzDiscovery extends LightningElement {
    searchKey = '';
    category = '';
    city = '';
    events = [];
    errorMessage;

    @wire(getPublishedEvents, {
        searchKey: '$searchKey',
        category: '$category',
        city: '$city'
    })
    wiredEvents({ data, error }) {
        if (data) {
            this.events = data.map((event) => ({
                ...event,
                displayCategory: event.Category__c || 'Featured event',
                displayCity: event.City__c || 'Your city',
                displayDate: this.formatDate(event.Start_Date_Time__c || event.Start_Date__c),
                displayPrice: event.Base_Price__c ? `$${event.Base_Price__c}` : 'Price on request',
                posterStyle: event.Poster_URL__c
                    ? `background-image: linear-gradient(180deg, transparent, #0b1020), url("${event.Poster_URL__c}")`
                    : ''
            }));
            this.errorMessage = undefined;
        } else if (error) {
            this.events = [];
            this.errorMessage = error.body?.message || 'Events could not be loaded.';
        }
    }

    handleSearchChange(event) {
        this.searchKey = event.target.value;
    }

    handleCategoryChange(event) {
        this.category = event.target.value;
    }

    handleCityChange(event) {
        this.city = event.target.value;
    }

    handleEventClick(event) {
        this.dispatchEvent(new CustomEvent('eventselected', {
            detail: { eventId: event.currentTarget.dataset.eventId },
            bubbles: true,
            composed: true
        }));
    }

    formatDate(value) {
        return value ? new Intl.DateTimeFormat('en', { dateStyle: 'medium' }).format(new Date(value)) : 'Date to be announced';
    }
}
