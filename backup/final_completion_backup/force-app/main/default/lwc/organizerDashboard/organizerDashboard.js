import { LightningElement, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getDashboardData from '@salesforce/apex/OrganizerDashboardController.getDashboardData';

export default class OrganizerDashboard extends LightningElement {
    dashboardData;
    wiredDashboardResult;
    errorMessage;
    isLoading = true;

    // Load dashboard information from Apex
    @wire(getDashboardData)
    wiredDashboard(result) {
        this.wiredDashboardResult = result;

        const { data, error } = result;

        if (data) {
            this.dashboardData = data;
            this.errorMessage = undefined;
            this.isLoading = false;
        } else if (error) {
            this.dashboardData = undefined;

            this.errorMessage =
                error.body?.message ||
                'Unable to load dashboard data. Check your Salesforce permissions.';

            this.isLoading = false;
        }
    }

    // Check whether dashboard data exists
    get hasData() {
        return this.dashboardData !== undefined &&
            this.dashboardData !== null;
    }

    // Overall dashboard statistics
    get totalEvents() {
        return this.dashboardData?.totalEvents ?? 0;
    }

    get upcomingEvents() {
        return this.dashboardData?.upcomingEvents ?? 0;
    }

    get totalBookings() {
        return this.dashboardData?.totalBookings ?? 0;
    }

    get confirmedBookings() {
        return this.dashboardData?.confirmedBookings ?? 0;
    }

    get ticketsSold() {
        return this.dashboardData?.ticketsSold ?? 0;
    }

    // Format revenue in Indian Rupees
    get formattedRevenue() {
        const amount = this.dashboardData?.totalRevenue ?? 0;

        return new Intl.NumberFormat('en-IN', {
            style: 'currency',
            currency: 'INR',
            maximumFractionDigits: 2
        }).format(amount);
    }

    // Prepare event details for the HTML template
    get recentEvents() {
        const events = this.dashboardData?.recentEvents ?? [];

        return events.map((event) => {
            const percentage = Number(event.bookingPercentage) || 0;
            const capacity = Number(event.capacity) || 0;

            const safePercentage = Math.min(
                100,
                Math.max(0, percentage)
            );

            const displayStatus = event.displayStatus || 'Upcoming';

            return {
                ...event,

                displayStatus,

                formattedCapacity: capacity.toLocaleString('en-IN'),

                formattedDate: event.startDateTime
                    ? new Intl.DateTimeFormat('en-IN', {
                        dateStyle: 'medium',
                        timeStyle: 'short'
                    }).format(new Date(event.startDateTime))
                    : 'Date not specified',

                statusClass:
                    'status-badge status-' +
                    displayStatus.toLowerCase().replace(/\s+/g, '-'),

                progressClass:
                    safePercentage >= 90
                        ? 'progress-fill progress-high'
                        : safePercentage >= 60
                            ? 'progress-fill progress-medium'
                            : 'progress-fill progress-low',

                progressStyle: `width: ${safePercentage}%`
            };
        });
    }

    // Check whether events are available
    get hasEvents() {
        return this.recentEvents.length > 0;
    }

    // Refresh dashboard information
    async handleRefresh() {
        if (!this.wiredDashboardResult) {
            return;
        }

        this.isLoading = true;
        this.errorMessage = undefined;

        try {
            await refreshApex(this.wiredDashboardResult);
        } catch (error) {
            this.errorMessage =
                error.body?.message ||
                'Unable to refresh dashboard data.';
        } finally {
            this.isLoading = false;
        }
    }
}