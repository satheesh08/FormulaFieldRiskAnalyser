import {
    LightningElement,
    track
} from 'lwc';
import getFormulaFields from '@salesforce/apex/FormulaRiskScanner.getFormulaFields';
import getAllSObjectNames from '@salesforce/apex/FormulaRiskScanner.getAllSObjectNames';
import updateFormula from '@salesforce/apex/FormulaRiskScanner.updateFormula';
import {
    ShowToastEvent
} from 'lightning/platformShowToastEvent';

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
        label: 'Return Type',
        fieldName: 'returnType',
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

    dependencyColumns = [{
            label: 'Field Name',
            fieldName: 'field'
        },
        {
            label: 'Component Type',
            fieldName: 'type'
        },
        {
            label: 'Component Name',
            fieldName: 'name'
        }
    ];


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
            console.log(JSON.stringify(this.rows[0]));

            this.formulaComparisonList = data
                .filter(row => row.originalFormula && row.optimizedFormula)
                .map((row, index) => ({
                    index,
                    originalFormula: row.originalFormula,
                    optimizedFormula: row.optimizedFormula,
                    devname: row.fieldName,
                    type: row.returnType,
                    label: row.label
                }));
            console.log(JSON.stringify(this.formulaComparisonList[0]));

            this.dependencyData = [];

            if (!this.rows || this.rows.length === 0) return;

            this.rows.forEach(row => {
                if (row.deps) {
                    const lines = row.deps.split('\n');
                    lines.forEach(line => {
                        if (line.startsWith('- ')) {
                            const parts = line.slice(2).split(':');
                            if (parts.length === 2) {
                                this.dependencyData.push({
                                    field: row.fieldName,
                                    type: parts[0].trim(),
                                    name: parts[1].trim()
                                });
                            }
                        }
                    });
                }
            });


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

    handleUseOptimized(event) {
        const index = event.currentTarget.dataset.index;
        const selected = this.formulaComparisonList[index];

        if (selected && selected.optimizedFormula) {
            updateFormula({
                    objectName: this.selectedObject,
                    fieldName: selected.devname,
                    newFormula: selected.optimizedFormula,
                    type: selected.type,
                    label: selected.label,
                })
                .then(() => {
                    this.dispatchEvent(new ShowToastEvent({
                        title: 'Success',
                        message: 'Formula updated successfully!',
                        variant: 'success'
                    }));
                    const intIndex = Number(index);

                    this.formulaComparisonList = this.formulaComparisonList
                        .filter((_, i) => i !== intIndex)
                        .map((item, idx) => ({
                            ...item,
                            index: idx
                        }));

                })

        }
    }
    get processedRows() {
        return this.rows.map(row => ({
            ...row,
            coverage: `${row.recordCount || 0} / ${row.totalRecords || 0}`
        }));
    }

    benchmarkColumns = [{
            label: 'Formula Field',
            fieldName: 'fieldName',
            type: 'text'
        },
        {
            label: 'CPU Time (ms)',
            fieldName: 'cpuTimeMs',
            type: 'number',
            cellAttributes: {
                alignment: 'left'
            }
        },
        {
            label: 'Record Coverage',
            fieldName: 'coverage',
            type: 'text'
        }
    ];

}
