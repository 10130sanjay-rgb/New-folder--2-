declare module "@salesforce/apex/BookingController.getTicketTypes" {
  export default function getTicketTypes(param: {eventId: any}): Promise<any>;
}
declare module "@salesforce/apex/BookingController.createBooking" {
  export default function createBooking(param: {eventId: any, ticketTypeId: any, firstName: any, lastName: any, email: any, phone: any, quantity: any}): Promise<any>;
}
