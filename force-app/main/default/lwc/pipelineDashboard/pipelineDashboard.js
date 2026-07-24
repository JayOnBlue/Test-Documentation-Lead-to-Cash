import { LightningElement, wire } from 'lwc';
import pipelineByStage from '@salesforce/apex/SalesMetricsService.pipelineByStage';

export default class PipelineDashboard extends LightningElement {
    stages;

    @wire(pipelineByStage)
    wiredPipeline({ data }) {
        if (data) {
            this.stages = Object.keys(data).map((stage) => ({ stage, total: data[stage] }));
        }
    }
}
