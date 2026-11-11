import { LightningElement, wire } from 'lwc';
import {
    CurrentPageReference,
    NavigationMixin
} from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import getPaymentDetails from '@salesforce/apex/PaymentController.getPaymentDetails';
import simulatePayment from '@salesforce/apex/PaymentController.simulatePayment';

export default class EventPayment extends NavigationMixin(LightningElement) {
    bookingId;
    paymentDetails;

    selectedMethod = 'UPI';
    paymentOutcome = 'success';

    isLoading = true;
    isProcessing = false;
    errorMessage;
    paymentResult;
    isComplete = false;

    paymentMethods = [
        { label: 'UPI', value: 'UPI' },
        { label: 'Credit Card', value: 'Credit Card' },
        { label: 'Debit Card', value: 'Debit Card' },
        { label: 'Net Banking', value: 'Net Banking' },
        { label: 'Wallet', value: 'Wallet' }
    ];

    outcomeOptions = [
        { label: 'Simulate successful payment', value: 'success' },
        { label: 'Simulate failed payment', value: 'failure' }
    ];

    @wire(CurrentPageReference)
    getPageReference(pageRef) {
        if (!pageRef) {
            return;
        }

        const newBookingId = pageRef.state?.c__bookingId;

        if (!newBookingId) {
            this.bookingId = undefined;
            this.paymentDetails = undefined;
            this.paymentResult = undefined;
            this.isComplete = false;
            this.isLoading = false;
            this.errorMessage =
                'Booking ID is missing. Please return to the events page and book your tickets first.';
            return;
        }

        if (newBookingId !== this.bookingId) {
            this.bookingId = newBookingId;
            this.paymentDetails = undefined;
            this.paymentResult = undefined;
            this.isComplete = false;

            this.loadPaymentDetails();
        }
    }

    async loadPaymentDetails() {
        if (!this.bookingId) {
            this.isLoading = false;
            this.paymentDetails = undefined;
            this.errorMessage =
                'Booking ID is missing. Please book an event first.';
            return;
        }

        this.isLoading = true;
        this.errorMessage = undefined;
        this.paymentDetails = undefined;

        try {
            const details = await getPaymentDetails({
                bookingId: this.bookingId
            });

            this.paymentDetails = details;
        } catch (error) {
            this.paymentDetails = undefined;

            this.errorMessage =
                error?.body?.message ||
                error?.message ||
                'Unable to load booking details. Please try again.';
        } finally {
            this.isLoading = false;
        }
    }

    get formattedAmount() {
        return this.paymentDetails?.totalAmount ?? 0;
    }

    get canPay() {
        return this.paymentDetails?.canPay === true &&
            !this.isProcessing &&
            !this.isComplete;
    }

    get isPaymentDisabled() {
        return !this.canPay;
    }

    get showPaymentForm() {
        return !this.isLoading &&
            !this.errorMessage &&
            !!this.paymentDetails &&
            this.paymentDetails.canUseSimulator === true &&
            !this.isComplete;
    }

    get showSuccess() {
        return this.isComplete &&
            this.paymentResult?.simulationOutcome === 'Success';
    }

    get showFailure() {
        return this.isComplete &&
            this.paymentResult?.simulationOutcome === 'Failure';
    }

    get showSimulatorUnavailable() {
        return !this.isLoading &&
            !this.errorMessage &&
            !!this.paymentDetails &&
            this.paymentDetails.canUseSimulator !== true;
    }

    handleMethodChange(event) {
        this.selectedMethod = event.detail.value;
    }

    handleOutcomeChange(event) {
        this.paymentOutcome = event.detail.value;
    }

    async handlePay() {
        if (!this.bookingId || !this.canPay) {
            return;
        }

        this.isProcessing = true;
        this.errorMessage = undefined;

        try {
            const result = await simulatePayment({
                bookingId: this.bookingId,
                paymentMethod: this.selectedMethod,
                simulateSuccess: this.paymentOutcome === 'success'
            });

            this.paymentResult = result;
            this.isComplete = true;

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Payment simulation complete',
                    message: result.message,
                    variant: 'info'
                })
            );

            this.paymentDetails = {
                ...this.paymentDetails,
                canPay: false
            };
        } catch (error) {
            this.errorMessage =
                error?.body?.message ||
                error?.message ||
                'Unable to process payment. Please try again.';
        } finally {
            this.isProcessing = false;
        }
    }

    async handleRetry() {
        this.isComplete = false;
        this.paymentResult = undefined;

        await this.loadPaymentDetails();
    }

    handleBackToEvents() {
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                name: 'Home'
            }
        });
    }
}