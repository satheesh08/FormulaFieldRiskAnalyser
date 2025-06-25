import {
    LightningElement,
    track
} from 'lwc';
import getFormulaFields from '@salesforce/apex/FormulaRiskScanner.getFormulaFields';
import getAllSObjectNames from '@salesforce/apex/FormulaRiskScanner.getAllSObjectNames';

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
        label: 'Hops',
        fieldName: 'crossObjectHops',
        type: 'text'
    },
    {
        label: 'Heavy Functions',
        fieldName: 'heavyFunctionCount',
        type: 'text'
    },
    {
        label: 'Risk Level',
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
    },
    {
        label: 'Score',
        fieldName: 'cpuScore',
        type: 'number'
    },
    {
        label: 'Red Flags',
        fieldName: 'cpuRedFlags',
        type: 'text',
        wrapText: true,
        cellAttributes: {
            title: {
                fieldName: 'cpuRedFlags'
            }
        }
    },
    {
        label: 'Uses $User/$RecordType',
        fieldName: 'usesRecordTypeOrUser',
        type: 'text'
    },
    {
        label: 'Formula Too Long',
        fieldName: 'isFormulaTooLong',
        type: 'text'
    }
];


export default class FormulaRiskAnalyzer extends LightningElement {
    @track objectOptions = [];
    @track selectedObject = '';
    @track formulaComparisonList = [];
    @track rows = [];
    @track isDataAvailable = false;
    @track isLoading = false;
    columns = COLS;

    connectedCallback() {
        this.fetchSObjectOptions();
    }

    async fetchSObjectOptions() {
        this.isLoading = true;
        try {
            const data = await getAllSObjectNames();
            this.objectOptions = data.map(obj => ({
                label: obj.label,
                value: obj.apiName
            }));
        } catch (error) {
            console.error('Error fetching object names:', error);
        } finally {
            this.isLoading = false;
        }
    }

    handleObjectChange(event) {
        this.selectedObject = event.detail.value;
        this.loadFormulaFields();
    }

    async loadFormulaFields() {
        this.isLoading = true;
        this.isDataAvailable = false;
        this.rows = [];

        try {
            const data = await getFormulaFields({
                objectName: this.selectedObject
            });
            this.rows = data.map(row => ({
                ...row,
                riskLevelClass: this.getRiskClass(row.riskLevel),
                riskLevelIcon: this.getRiskIcon(row.riskLevel)
            }));
            this.formulaComparisonList = data
                .filter(row => row.originalFormula && row.optimizedFormula)
                .map(row => ({
                    originalFormula: row.originalFormula,
                    optimizedFormula: row.optimizedFormula
                }));
            this.isDataAvailable = this.rows.length > 0;
        } catch (error) {
            console.error('Error loading formula fields:', error);
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
