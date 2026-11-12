declare module "@salesforce/apex/EpicEventzEngine.processRegistration" {
  export default function processRegistration(param: {eventId: any, attendeeId: any, ticketTypeName: any}): Promise<any>;
}
declare module "@salesforce/apex/EpicEventzEngine.finalizeRegistration" {
  export default function finalizeRegistration(param: {regId: any, paymentStatus: any}): Promise<any>;
}
