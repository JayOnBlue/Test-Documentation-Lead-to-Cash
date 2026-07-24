import { LightningElement, wire } from 'lwc';
import getRecentHotLeads from '@salesforce/apex/LeadScoringService.getRecentHotLeads';

export default class LeadScorecard extends LightningElement {
    @wire(getRecentHotLeads) leads;
}
