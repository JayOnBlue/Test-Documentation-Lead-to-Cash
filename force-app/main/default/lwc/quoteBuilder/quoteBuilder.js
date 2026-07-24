import { LightningElement, wire } from 'lwc';
import getQuotableOpportunities from '@salesforce/apex/QuoteGenerationService.getQuotableOpportunities';

export default class QuoteBuilder extends LightningElement {
    @wire(getQuotableOpportunities) opportunities;
}
