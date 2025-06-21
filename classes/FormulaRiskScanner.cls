public with sharing class FormulaRiskScanner {
    public class FormulaInfo {
        @AuraEnabled public String objectName;
        @AuraEnabled public String fieldName;
        @AuraEnabled public Integer depth;
        @AuraEnabled public Integer crossObjectHops;
        @AuraEnabled public String riskLevel;
        public FormulaInfo(String o, String f, Integer d, Integer c, String r) {
            objectName = o;
            fieldName = f;
            depth = d;
            crossObjectHops = c;
            riskLevel = r;
        }
    }
    @AuraEnabled(cacheable=true)
    public static List<FormulaInfo> getFormulaFields(String objectName) {
        List<FormulaInfo> results = new List<FormulaInfo>();
        try {
            Set<String> formulaFieldNames = new Set<String>();
            Map<String, String> fieldNameToObjectMap = new Map<String, String>();
            for (FieldDefinition fd : [
                SELECT QualifiedApiName, EntityDefinition.QualifiedApiName,DeveloperName
                FROM FieldDefinition 
                WHERE EntityDefinition.QualifiedApiName = : objectName AND DataType LIKE 'Formula%'
            ]) {
                formulaFieldNames.add(fd.DeveloperName);
                fieldNameToObjectMap.put(fd.QualifiedApiName, fd.DeveloperName);
            }
            Http http = new Http();
            for (String fieldName : formulaFieldNames) {
                String query = 'SELECT Id, Metadata,DeveloperName FROM CustomField WHERE DeveloperName = \'' + fieldName + '\' AND TableEnumOrId = \'' + objectName + '\'';
                String toolingEndpoint = 'callout:ToolingAPI/services/data/v59.0/tooling/query/?q=' + EncodingUtil.urlEncode(query, 'UTF-8');
                HttpRequest req = new HttpRequest();
                req.setEndpoint(toolingEndpoint);
                req.setMethod('GET');
                req.setHeader('Content-Type', 'application/json');
                HttpResponse res = http.send(req);
                if (res.getStatusCode() == 200) {
                    Map<String, Object> jsonResponse = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                    System.debug(jsonResponse);
                    List<Object> records = (List<Object>) jsonResponse.get('records');
                    if (!records.isEmpty()) {
                        Map<String, Object> rec = (Map<String, Object>) records[0];
                        Map<String, Object> metadata = (Map<String, Object>) rec.get('Metadata');
                        if (metadata != null && metadata.containsKey('formula')) {
                            String formula = (String) metadata.get('formula');
                            Integer depth = countDotDepth(formula);
                            Integer crossObj = countMaxCrossObjectHops(formula);
                            System.debug(formula);
                            String risk = calculateRisk(depth, crossObj);
                            results.add(new FormulaInfo(objectName, fieldName, depth, crossObj, risk));
                        }
                    }
                } else {
                    System.debug('Tooling API error for ' + fieldName + ': ' + res.getBody());
                }
            }
        } catch (Exception e) {
            System.debug('Error: ' + e.getMessage());
        }
        return results;
    }private static Integer countDotDepth(String formula) {
        Set<String> knownFunctions = new Set<String>{
            'AND', 'CASE', 'IF', 'NOT', 'OR', 'BLANKVALUE', 'NULLVALUE',
                'BEGINS', 'BR', 'CONTAINS', 'FIND', 'GETSESSIONID', 'HYPERLINK',
                'IMAGE', 'INCLUDES', 'ISCHANGED', 'ISNEW', 'ISPICKVAL', 'ISNUMBER',
                'LEFT', 'LEN', 'LOWER', 'LPAD', 'MID', 'RIGHT', 'RPAD', 'SUBSTITUTE',
                'TEXT', 'TRIM', 'UPPER', 'VALUE',
                'ADDMONTHS', 'DATE', 'DATEVALUE', 'DATETIMEVALUE', 'DAY', 'NOW',
                'MONTH', 'TODAY', 'TIMEVALUE', 'WEEKDAY', 'YEAR',
                'ABS', 'CEILING', 'EXP', 'FLOOR', 'GCD', 'LN', 'LOG', 'MAX', 'MIN',
                'MOD', 'ROUND', 'SQRT',
                'ISBLANK', 'ISNULL', 'PRIORVALUE', 'VLOOKUP',
                'DISTANCE', 'GEOLOCATION',
                'TEXTVALUE', 'ISCHANGED', 'ISCLONE', 'ISNEW'
                };
                    
                    Integer maxDepth = 0;
        Integer currentDepth = 0;
        String cleaned = formula.replaceAll('\\s+', '');
        for (Integer i = 0; i < cleaned.length(); ) {
            Boolean matched = false;
            for (String func : knownFunctions) {
                Integer len = func.length();
                if (i + len + 1 <= cleaned.length() &&
                    cleaned.substring(i, i + len).toUpperCase() == func &&
                    cleaned.substring(i + len, i + len + 1) == '(') {
                        
                        currentDepth++;
                        if (currentDepth > maxDepth) maxDepth = currentDepth;
                        i += len + 1;
                        matched = true;
                        break;
                    }
            }
            
            if (!matched) {
                if (cleaned.substring(i, i + 1) == ')') {
                    currentDepth = Math.max(0, currentDepth - 1);
                }
                i++;
            }
        }
        
        return maxDepth;
    }
    private static Integer countMaxCrossObjectHops(String formula) {
        Pattern p = Pattern.compile('\\b(?:[a-zA-Z_][a-zA-Z0-9_]*__r?|[a-zA-Z_][a-zA-Z0-9_]*)\\.(?:[a-zA-Z_][a-zA-Z0-9_]*)(?:\\.[a-zA-Z_][a-zA-Z0-9_]*)*\\b');
        Matcher m = p.matcher(formula);
        
        Integer maxHops = 0;
        
        while (m.find()) {
            String match = m.group();
            Integer hopCount = match.split('\\.').size() - 1;
            if (hopCount > maxHops) maxHops = hopCount;
        }
        
        return maxHops;
    }
    private static String calculateRisk(Integer depth, Integer crossObj) {
        if (depth >= 6 || crossObj >= 3) return 'High';
        if (depth >= 3 || crossObj >= 1) return 'Medium';
        return 'Low';
    }
}