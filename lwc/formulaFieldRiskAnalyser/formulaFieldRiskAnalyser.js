import { LightningElement, track } from 'lwc';
import getFormulaFields from '@salesforce/apex/FormulaRiskScanner.getFormulaFields';
import getAllSObjectNames from '@salesforce/apex/FormulaRiskScanner.getAllSObjectNames';
import updateFormula from '@salesforce/apex/FormulaRiskScanner.updateFormula';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { loadScript } from 'lightning/platformResourceLoader';
import ChartJS from '@salesforce/resourceUrl/ChartJs';
import ECharts from '@salesforce/resourceUrl/EChartJS';

const COLS = [
    { label: 'Object', fieldName: 'objectName' },
    { label: 'Field', fieldName: 'fieldName' },
    { label: 'Depth', fieldName: 'depth', type: 'text' },
    { label: 'Hops', fieldName: 'crossObjectHops', type: 'text' },
    { label: 'Return Type', fieldName: 'returnType', type: 'text' },
    { label: 'Heavy Functions', fieldName: 'heavyFunctionCount', type: 'text' },
    {
        label: 'Risk Level',
        fieldName: 'riskLevel',
        cellAttributes: {
            class: { fieldName: 'riskLevelClass' },
            iconName: { fieldName: 'riskLevelIcon' },
            iconPosition: 'left'
        }
    },
    { label: 'Score', fieldName: 'cpuScore', type: 'number' },
    {
        label: 'Red Flags',
        fieldName: 'cpuRedFlags',
        type: 'text',
        wrapText: true,
        cellAttributes: {
            title: { fieldName: 'cpuRedFlags' }
        }
    },
    { label: 'Uses $User/$RecordType', fieldName: 'usesRecordTypeOrUser', type: 'text' },
    { label: 'Formula Too Long', fieldName: 'isFormulaTooLong', type: 'text' }
];

export default class FormulaRiskAnalyzer extends LightningElement {
    @track objectOptions = [];
    @track selectedObject = '';
    @track formulaComparisonList = [];
    @track rows = [];
    @track isDataAvailable = false;
    @track isLoading = false;
    @track dependencyData = [];

    columns = COLS;
    chartJsInitialized = false;
    chart;

    connectedCallback() {
        this.fetchSObjectOptions();
    }

    async fetchSObjectOptions() {
        this.isLoading = true;
        try {
            const data = await getAllSObjectNames();
            this.objectOptions = data.map(obj => ({ label: obj.label, value: obj.apiName }));
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
            const data = await getFormulaFields({ objectName: this.selectedObject });

            this.rows = data.map(row => ({
                ...row,
                riskLevelClass: this.getRiskClass(row.riskLevel),
                riskLevelIcon: this.getRiskIcon(row.riskLevel)
            }));

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

            this.dependencyData = [];
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

            await this.loadChartLibrary();
            this.renderChart();
            this.renderGraph();

        } catch (error) {
            console.error('Error loading formula fields:', error);
        } finally {
            this.isLoading = false;
        }
    }

    async loadChartLibrary() {
        if (!this.chartJsInitialized) {
            await Promise.all([
                loadScript(this, ChartJS),
                loadScript(this, ECharts)
            ]);
            this.chartJsInitialized = true;
        }
    }

    renderChart() {
        const canvas = this.template.querySelector('canvas');
        if (!canvas) return;

        if (this.chart) {
            this.chart.destroy();
        }

        const labels = this.rows.map(r => r.fieldName);
        const cpuTimes = this.rows.map(r => r.cpuTimeMs || 0);
        const wallTimes = this.rows.map(r => r.wallTimeMs || 0);
        const recordCounts = this.rows.map(r => r.recordCount || 0);

        const ctx = canvas.getContext('2d');
        this.chart = new window.Chart(ctx, {
            type: 'bar',
            data: {
                labels,
                datasets: [
                    {
                        label: 'CPU Time (ms)',
                        data: cpuTimes,
                        backgroundColor: 'rgba(54, 162, 235, 0.7)'
                    },
                    {
                        label: 'Wall Time (ms)',
                        data: wallTimes,
                        backgroundColor: 'rgba(255, 99, 132, 0.7)'
                    }
                ]
            },
            options: {
                responsive: true,
                plugins: {
                    title: {
                        display: true,
                        text: 'Formula Field Evaluation Times'
                    },
                    tooltip: {
                        callbacks: {
                            afterBody: context => {
                                const index = context[0].dataIndex;
                                return 'Records: ' + recordCounts[index];
                            }
                        }
                    }
                },
                scales: {
                    y: {
                        beginAtZero: true,
                        title: {
                            display: true,
                            text: 'Time (ms)'
                        }
                    }
                }
            }
        });
    }

renderGraph() {
    const container = this.template.querySelector('.sankey-chart');
    if (!container || !window.echarts) return;

    const nodes = [];
    const links = [];
    const nodeMap = new Map();

    // Assign colors based on type
    const getColor = (type) => {
        switch (type.toLowerCase()) {
            case 'flow': return '#4caf50';
            case 'apex': return '#e91e63';
            case 'field': return '#0070d2';
            default: return '#ff9800'; // fallback for others
        }
    };

    this.dependencyData.forEach(({ field, type, name }) => {
        const from = field;
        const to = name;
        const typeKey = type.toLowerCase();

        // Add nodes if not already added
        if (!nodeMap.has(from)) {
            nodeMap.set(from, true);
            nodes.push({
                name: from,
                itemStyle: { color: getColor('field') }
            });
        }

        if (!nodeMap.has(to)) {
            nodeMap.set(to, true);
            nodes.push({
                name: to,
                itemStyle: { color: getColor(typeKey) }
            });
        }

        links.push({
            source: from,
            target: to,
            label: { show: true, formatter: type }, // shows Flow/Apex/etc.
            lineStyle: {
                color: getColor(typeKey),
                width: 2
            }
        });
    });

    const chart = window.echarts.init(container);

    chart.setOption({
        backgroundColor: '#111',
        tooltip: {
            trigger: 'item',
            formatter: function (params) {
                if (params.dataType === 'edge') {
                    return `${params.data.source} → ${params.data.target}<br/>Type: ${params.data.label.formatter}`;
                } else {
                    return params.data.name;
                }
            }
        },
        series: [{
            type: 'graph',
            layout: 'force',
            data: nodes,
            links: links,
            roam: true,
            focusNodeAdjacency: true,
            force: {
                repulsion: 150,
                edgeLength: 100
            },
            label: {
                show: true,
                position: 'right',
                color: '#fff',
                fontSize: 12
            },
            lineStyle: {
                opacity: 0.9,
                curveness: 0.3
            },
            emphasis: {
                focus: 'adjacency',
                lineStyle: {
                    width: 3
                }
            }
        }]
    });
}

    getRiskClass(level) {
        switch (level) {
            case 'High': return 'slds-text-color_error';
            case 'Medium': return 'slds-text-color_warning';
            case 'Low': return 'slds-text-color_success';
            default: return '';
        }
    }

    getRiskIcon(level) {
        switch (level) {
            case 'High': return 'utility:warning';
            case 'Medium': return 'utility:info';
            case 'Low': return 'utility:check';
            default: return '';
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
                });
        }
    }

    get processedRows() {
        return this.rows.map(row => ({
            ...row,
            coverage: `${row.recordCount || 0} / ${row.totalRecords || 0}`
        }));
    }
}
