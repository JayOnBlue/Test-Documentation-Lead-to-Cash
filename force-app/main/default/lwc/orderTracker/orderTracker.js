import { LightningElement, wire } from 'lwc';
import getOpenOrders from '@salesforce/apex/OrderFulfillmentService.getOpenOrders';

export default class OrderTracker extends LightningElement {
    @wire(getOpenOrders) orders;
}
