import {
    LightningElement,
    api
} from 'lwc';
import getFormulaFields from '@salesforce/apex/FormulaRiskScanner.getFormulaFields';

const COLS = [{
        label: 'Object',
        fieldName: 'objectName'
    },
    {
        label: 'Field',
        fieldName: 'fieldName'
    },
    {
        label: 'Depth',
        fieldName: 'depth',
        type: 'text'
    },
    {
        label: 'Object Hops',
        fieldName: 'crossObjectHops',
        type: 'text'
    },
    {
        label: 'CPU Risk Level',
        fieldName: 'riskLevel',
        cellAttributes: {
            class: {
                fieldName: 'riskLevelClass'
            },
            iconName: {
                fieldName: 'riskLevelIcon'
            },
            iconPosition: 'left'
        }
    }
];


export default class FormulaRiskAnalyzer extends LightningElement {
    rows = [];
    isDataAvailable = false;
    isLoading = true;
    @api objectApiName;
    columns = COLS;

    connectedCallback() {
        this.loadFormulaFields();
    }

    async loadFormulaFields() {
        this.isLoading = true;
        try {
            const data = await getFormulaFields({
                objectName: this.objectApiName
            });
            this.rows = data.map(row => ({
                ...row,
                riskLevelClass: this.getRiskClass(row.riskLevel),
                riskLevelIcon: this.getRiskIcon(row.riskLevel)
            }));

            this.isDataAvailable = true;
            console.log('Data:', data);
            console.dir(this.rows);
        } catch (error) {
            console.error('Error fetching formula fields:', error);
            this.isDataAvailable = false;
        } finally {
            this.isLoading = false;
        }
    }

    getRiskClass(level) {
        switch (level) {
            case 'High':
                return 'slds-text-color_error';
            case 'Medium':
                return 'slds-text-color_warning';
            case 'Low':
                return 'slds-text-color_success';
            default:
                return '';
        }
    }

    getRiskIcon(level) {
        switch (level) {
            case 'High':
                return 'utility:warning';
            case 'Medium':
                return 'utility:info';
            case 'Low':
                return 'utility:check';
            default:
                return '';
        }
    }
}