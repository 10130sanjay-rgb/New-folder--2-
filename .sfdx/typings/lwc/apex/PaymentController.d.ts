declare module "@salesforce/apex/PaymentController.getPaymentDetails" {
  export default function getPaymentDetails(param: {bookingId: any}): Promise<any>;
}
declare module "@salesforce/apex/PaymentController.simulatePayment" {
  export default function simulatePayment(param: {bookingId: any, paymentMethod: any, simulateSuccess: any}): Promise<any>;
}
