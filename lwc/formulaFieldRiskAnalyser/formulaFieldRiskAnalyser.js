import {
    LightningElement,
    track
} from 'lwc';
import getFormulaFields from '@salesforce/apex/FormulaRiskScanner.getFormulaFields';
import getAllSObjectNames from '@salesforce/apex/FormulaRiskScanner.getAllSObjectNames';
import updateFormula from '@salesforce/apex/FormulaRiskScanner.updateFormula';
import sendForecastEmail from '@salesforce/apex/FormulaRiskScanner.sendForecastEmail';
import {
    ShowToastEvent
} from 'lightning/platformShowToastEvent';
import {
    loadScript
} from 'lightning/platformResourceLoader';
import ChartJS from '@salesforce/resourceUrl/ChartJs';
import ECharts from '@salesforce/resourceUrl/EChartJS';
import html2canvasLib from '@salesforce/resourceUrl/html2canvas';
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
        label: 'Uses Non-Deterministic Logic',
        fieldName: 'isNonDeterministic',
        type: 'text'
    },
    {
        label: 'Formula Too Long',
        fieldName: 'isFormulaTooLong',
        type: 'text'
    },
    {
        label: 'Forecast',
        type: 'button-icon',
        typeAttributes: {
            iconName: 'utility:chart',
            name: 'forecast',
            title: 'Forecast the complexity',
            variant: 'border-filled',
            alternativeText: 'Forecast'
        }
    }


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

    isForecastModalOpen = false;
    forecastData = [];
    forecastChart;
    selectedForecastLabel = '';

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }

    handleSendEmail() {
        const chartCanvas = this.template.querySelector('.forecastChart');
        if (!chartCanvas) {
            this.showToast('Error', 'Chart not found.', 'error');
            return;
        }

        this.addWatermark(chartCanvas, 'FormulaSniffR');
        const chartImage = chartCanvas.toDataURL('image/png');
        this.isForecastModalOpen = false;

        if (this.forecastChart) {
            this.forecastChart.destroy();
            this.forecastChart = null;
        }

        setTimeout(() => {
            const matchingRow = this.rows?.find(
                row => row.fieldName == this.selectedForecastLabel
            );

            if (!matchingRow) {
                this.showToast('Error', 'Matching forecast record not found.', 'error');
                return;
            }

            let tableHtml = `
      <table border="1" cellpadding="8" cellspacing="0" style="border-collapse:collapse; font-family:sans-serif; width:100%; max-width:600px;">
        <thead style="background:#f0f0f0;">
          <tr><th colspan="2" style="text-align:left;">FormulaSniffR Summary - ${this.selectedForecastLabel}</th></tr>
        </thead>
        <tbody>`;

            for (let key in matchingRow) {
                if (matchingRow.hasOwnProperty(key)) {

                    if (key === 'riskLevelIcon' || key === 'riskLevelClass') {
                        continue;
                    }

                    let displayKey = key
                        .replace(/([a-z])([A-Z])/g, '$1 $2')
                        .replace(/^./, str => str.toUpperCase());

                    let value = matchingRow[key];

                    if (key === 'cpuScore') {
                        value = `
        ${value} (Calculated as: 
          (+2) × Nesting level + 
          (+2) × Cross-object references + 
          (+3) × Heavy functions + 
          (+5) if too long + 
          (+5) if unbalanced + 
          (+5) if non-deterministic logic
        )
      `;
                    }

                    if (key === 'forecastScore' && typeof value === 'string') {
                        const now = value.match(/Now Score:\s*(\d+)/)?.[1] || '';
                        const sixMonths = value.match(/In 6 months:\s*(\d+)/)?.[1] || '';
                        const oneYear = value.match(/In 1 year:\s*(\d+)/)?.[1] || '';
                        value = `
        Now: ${now}<br/>
        In 6 months: ${sixMonths}<br/>
        In 1 year: ${oneYear}
      `;
                    }

                    if (key === 'dna' && typeof value === 'object') {
                        const dnaMetrics = value;

                        const dnaLegendMap = {
                            complexity: 'Formula length & nested functions',
                            chainDepth: 'Depth of field dependencies',
                            blastRadius: 'Used in Apex, Flows, etc.',
                            volatility: 'Depends on frequently changing fields',
                            fragility: 'Hardcoded values or risky constructs',
                            usage: 'How often it appears in UI & reports'
                        };

                        let dnaHtml = `<table style="border-collapse: collapse; width: 100%;">`;

                        for (let metric in dnaMetrics) {
                            let metricLabel = metric
                                .replace(/([a-z])([A-Z])/g, '$1 $2')
                                .replace(/^./, str => str.toUpperCase());

                            let metricValue = dnaMetrics[metric];
                            let legend = dnaLegendMap[metric] || '';
                            dnaHtml += `
              <tr>
                <td style="padding: 4px; font-weight: bold; background: #f5f5f5;">${metricLabel}</td>
                <td style="padding: 4px;">${metricValue}<br />
                <span style="font-size: 0.75rem; color: #888;">${legend}</span></td>
              </tr>`;
                        }

                        dnaHtml += `</table>`;
                        value = dnaHtml;
                    }

                    tableHtml += `
      <tr>
        <td style="font-weight:bold; background:#fafafa;">${displayKey}</td>
        <td>${value}</td>
      </tr>`;
                }
            }
            tableHtml += `</tbody></table>`;

            sendForecastEmail({
                    chartImage: chartImage,
                    formulaLabel: this.selectedForecastLabel || 'Forecast',
                    recordSummaryHtml: tableHtml
                })
                .then(() => {
                    this.showToast('Email Sent', 'Forecast summary sent to Admins.', 'success');
                })
                .catch(error => {
                    console.error('Email send failed:', error);
                    this.showToast('Email Failed', 'Something went wrong while sending the email.', 'error');
                });
        }, 400);
    }




    addWatermark(canvas, text) {
        const ctx = canvas.getContext('2d');
        ctx.font = '20px Arial';
        ctx.fillStyle = 'rgba(0, 0, 0, 0.3)';
        ctx.textAlign = 'right';
        ctx.fillText(text, canvas.width - 20, canvas.height - 20);
    }



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
            this.renderDnaChart();


        } catch (error) {
            console.error('Error loading formula fields:', error);
        } finally {
            this.isLoading = false;
        }
    }

    @track showLegend = false;

    get legendToggleLabel() {
        return this.showLegend ? 'Hide DNA Metric Legend' : 'Show DNA Metric Legend';
    }

    toggleLegend() {
        this.showLegend = !this.showLegend;
    }


    renderDnaChart() {
        const container = this.template.querySelector('.dna-chart');
        if (!container || !window.echarts) return;

        if (this.dnaChart) {
            this.dnaChart.dispose();
        }

        const chart = window.echarts.init(container);
        this.dnaChart = chart;

        const metrics = ['complexity', 'chainDepth', 'blastRadius', 'volatility', 'fragility', 'usage'];
        const fields = this.rows.map(f => f.fieldName);

        const seriesData = [];
        this.rows.forEach((row, rowIndex) => {
            if (!row.dna) return;
            metrics.forEach((metric, colIndex) => {
                seriesData.push({
                    value: [colIndex, rowIndex, row.dna[metric]]
                });
            });
        });

        const getHeatColor = (val) => {
            switch (val) {
                case 'high':
                    return '#e74c3c';
                case 'medium':
                    return '#f39c12';
                case 'low':
                    return '#2ecc71';
                default:
                    return '#bdc3c7';
            }
        };

        chart.setOption({
            tooltip: {
                formatter: function(params) {
                    const [col, row, value] = params.data.value;
                    return `${fields[row]}<br/>${metrics[col]}: ${value}`;
                }
            },
            grid: {
                left: 20,
                right: 20,
                top: 40,
                bottom: 40,
                containLabel: true
            },
            xAxis: {
                type: 'category',
                data: metrics,
                axisLabel: {
                    rotate: 90
                }
            },
            yAxis: {
                type: 'category',
                data: fields
            },
            series: [{
                type: 'custom',
                renderItem: (params, api) => {
                    const value = api.value(2);
                    const color = getHeatColor(value);
                    const [x, y] = api.coord([api.value(0), api.value(1)]);
                    const [width, height] = api.size([1, 1]);
                    return {
                        type: 'rect',
                        shape: {
                            x: x - width / 2,
                            y: y - height / 2,
                            width,
                            height
                        },
                        style: {
                            fill: color
                        }
                    };
                },
                data: seriesData
            }]
        });
    }


    async loadChartLibrary() {
        if (!this.chartJsInitialized) {
            await Promise.all([
                loadScript(this, ChartJS),
                loadScript(this, ECharts),
                loadScript(this, html2canvasLib)
            ]);
            this.chartJsInitialized = true;
        }
    }
    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        if (actionName === 'forecast') {
            this.selectedForecastLabel = row.devname || row.fieldName || 'Formula';
            this.forecastData = this.parseForecast(row.forecastScore);
            this.isForecastModalOpen = true;
            this.drawChart();
        }
    }



    parseForecast(raw) {
        const scoreMap = {
            now: 0,
            '6 months': 0,
            '1 year': 0
        };

        const lines = raw.split('\n');
        lines.forEach(line => {
            const match = line.match(/(Now|6\s*months|1\s*year)[^\d]*(\d+)/i);
            if (match) {
                const label = match[1].toLowerCase();
                const score = parseInt(match[2], 10);

                if (label.includes('now')) scoreMap['now'] = score;
                else if (label.includes('6')) scoreMap['6 months'] = score;
                else if (label.includes('1')) scoreMap['1 year'] = score;
            }
        });

        return {
            labels: ['Now', '6 Months', '1 Year'],
            scores: [scoreMap['now'], scoreMap['6 months'], scoreMap['1 year']]
        };
    }

    drawChart() {
        setTimeout(() => {
            const ctx = this.template.querySelector('.forecastChart');
            if (!ctx) return;

            if (this.forecastChart) {
                this.forecastChart.destroy();
                this.forecastChart = null;
            }

            this.forecastChart = new window.Chart(ctx, {
                type: 'radar',
                data: {
                    labels: this.forecastData.labels,
                    datasets: [{
                        label: `Forecast Score - ${this.selectedForecastLabel}`,
                        data: this.forecastData.scores,
                        backgroundColor: 'rgba(0, 112, 210, 0.2)',
                        borderColor: '#0070d2',
                        borderWidth: 2,
                        pointBackgroundColor: '#0070d2'
                    }]
                },
                options: {
                    responsive: true,
                    scales: {
                        r: {
                            angleLines: {
                                display: true
                            },
                            suggestedMin: 0,
                            suggestedMax: Math.max(...this.forecastData.scores) + 10,
                            ticks: {
                                stepSize: 5,
                                backdropColor: 'transparent'
                            },
                            pointLabels: {
                                font: {
                                    size: 14
                                }
                            }
                        }
                    },
                    plugins: {
                        tooltip: {
                            callbacks: {
                                label: (context) => `Score: ${context.formattedValue}`
                            }
                        },
                        legend: {
                            display: false
                        },
                        title: {
                            display: true,
                            text: 'Forecasted CPU Complexity',
                            font: {
                                size: 16
                            }
                        }
                    }
                }
            });
        }, 0);
    }



    closeForecastModal() {
        this.isForecastModalOpen = false;
        if (this.forecastChart) {
            this.forecastChart.destroy();
            this.forecastChart = null;
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
                datasets: [{
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

        const getColor = (type) => {
            switch (type.toLowerCase()) {
                case 'flow':
                    return '#4caf50';
                case 'apex':
                    return '#e91e63';
                case 'field':
                    return '#0070d2';
                case 'object':
                    return '#9c27b0';
                case 'validation':
                    return '#3f51b5';
                case 'trigger':
                    return '#ff5722';
                case 'workflow':
                    return '#009688';
                case 'process':
                    return '#8bc34a';
                case 'component':
                    return '#00bcd4';
                case 'permission':
                    return '#795548';
                case 'profile':
                    return '#673ab7';
                case 'layout':
                    return '#cddc39';
                case 'page':
                    return '#ffc107';
                case 'customlabel':
                    return '#607d8b';
                default:
                    return '#ff9800';
            }
        };


        this.dependencyData.forEach(({
            field,
            type,
            name
        }) => {
            const from = field;
            const to = name;
            const typeKey = type.toLowerCase();

            if (!nodeMap.has(from)) {
                nodeMap.set(from, true);
                nodes.push({
                    name: from,
                    itemStyle: {
                        color: getColor('field')
                    }
                });
            }

            if (!nodeMap.has(to)) {
                nodeMap.set(to, true);
                nodes.push({
                    name: to,
                    itemStyle: {
                        color: getColor(typeKey)
                    }
                });
            }

            links.push({
                source: from,
                target: to,
                label: {
                    show: true,
                    formatter: type
                },
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
                formatter: function(params) {
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
