public with sharing class FormulaRiskScanner {

    public class SObjectInfo implements Comparable {
        @AuraEnabled public String label;
        @AuraEnabled public String apiName;

        public SObjectInfo(String label, String apiName) {
            this.label = label;
            this.apiName = apiName;
        }

        public Integer compareTo(Object other) {
            SObjectInfo o = (SObjectInfo) other;
            return this.label.toLowerCase().compareTo(o.label.toLowerCase());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<SObjectInfo> getAllSObjectNames() {
        List<SObjectInfo> results = new List<SObjectInfo>();
        Map<String, Schema.SObjectType> globalDesc = Schema.getGlobalDescribe();

        for (String apiName : globalDesc.keySet()) {
            Schema.DescribeSObjectResult describe = globalDesc.get(apiName).getDescribe();

            if (
                describe.isQueryable() &&
                !describe.isDeprecatedAndHidden() &&
                !describe.getLabel().startsWithIgnoreCase('__MISSING LABEL__') &&
                !describe.getName().startsWithIgnoreCase('FieldDefinition') &&
                !describe.getName().startsWithIgnoreCase('EntityDefinition') &&
                !describe.getName().startsWithIgnoreCase('Apex') &&
                !describe.getName().startsWithIgnoreCase('Auth') &&
                !describe.getName().startsWithIgnoreCase('Permission') &&
                !describe.getName().contains('Feed') &&
                !describe.getName().contains('Share') &&
                !describe.getName().endsWith('__History')
            ) {
                results.add(new SObjectInfo(describe.getLabel(), apiName));
            }
        }

        results.sort();
        return results;
    }

    public class FormulaInfo {
        @AuraEnabled public String objectName;
        @AuraEnabled public String fieldName;
        @AuraEnabled public Integer depth;
        @AuraEnabled public Integer crossObjectHops;
        @AuraEnabled public Integer heavyFunctionCount;
        @AuraEnabled public String riskLevel;
        @AuraEnabled public Boolean usesRecordTypeOrUser;
        @AuraEnabled public Boolean isFormulaTooLong;
        @AuraEnabled public String returnType;
        @AuraEnabled public Integer cpuScore;
        @AuraEnabled public String cpuRedFlags;

        public FormulaInfo(String o, String f, Integer d, Integer c, Integer h, String r, Boolean flag, Boolean tooLong, String rt, Integer score, String redFlags) {
            objectName = o;
            fieldName = f;
            depth = d;
            crossObjectHops = c;
            heavyFunctionCount = h;
            riskLevel = r;
            usesRecordTypeOrUser = flag;
            isFormulaTooLong = tooLong;
            returnType = rt;
            cpuScore = score;
            cpuRedFlags = redFlags;
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<FormulaInfo> getFormulaFields(String objectName) {
        List<FormulaInfo> results = new List<FormulaInfo>();
        try {
            Set<String> formulaFieldNames = new Set<String>();
            for (FieldDefinition fd : [
                SELECT QualifiedApiName, EntityDefinition.QualifiedApiName, DeveloperName
                FROM FieldDefinition 
                WHERE EntityDefinition.QualifiedApiName = :objectName 
                AND DataType LIKE 'Formula%'
            ]) {
                formulaFieldNames.add(fd.DeveloperName);
            }

            Http http = new Http();
            for (String fieldName : formulaFieldNames) {
                String query = 'SELECT Id, Metadata, DeveloperName FROM CustomField WHERE DeveloperName = \'' + fieldName + '\' AND TableEnumOrId = \'' + objectName + '\'';
                String toolingEndpoint = 'callout:ToolingAPI/services/data/v59.0/tooling/query/?q=' + EncodingUtil.urlEncode(query, 'UTF-8');

                HttpRequest req = new HttpRequest();
                req.setEndpoint(toolingEndpoint);
                req.setMethod('GET');
                req.setHeader('Content-Type', 'application/json');

                HttpResponse res = http.send(req);
                if (res.getStatusCode() == 200) {
                    Map<String, Object> jsonResponse = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                    List<Object> records = (List<Object>) jsonResponse.get('records');

                    if (!records.isEmpty()) {
                        Map<String, Object> rec = (Map<String, Object>) records[0];
                        Map<String, Object> metadata = (Map<String, Object>) rec.get('Metadata');
                        if (metadata != null && metadata.containsKey('formula')) {
                            String formula = (String) metadata.get('formula');
                            String returnType = (String) metadata.get('returnType');
                            Integer depth = countDotDepth(formula);
                            Integer crossObj = countMaxCrossObjectHops(formula);
                            Integer heavyFuncCount = countHeavyFunctions(formula);
                            Boolean usesSpecialFields = containsRecordTypeOrUser(formula);
                            Boolean isTooLong = formula.length() > 3000;
                            Boolean unbalanced = hasUnbalancedParentheses(formula);
                            String risk = calculateRisk(depth, crossObj, heavyFuncCount, isTooLong || unbalanced);

                            // Red flags
                            List<String> redFlags = new List<String>();
                            if (isTooLong) redFlags.add('Formula > 3000 chars');
                            if (usesSpecialFields) redFlags.add('Uses $User/$RecordType');
                            if (unbalanced) redFlags.add('Unbalanced parentheses');
                            if (heavyFuncCount > 0) redFlags.add('Heavy functions: ' + String.valueOf(heavyFuncCount));
                            if (crossObj >= 3) redFlags.add('Deep cross-object hops');
                            if (depth >= 6) redFlags.add('Excessive nesting');

                            Integer score = depth * 2 + crossObj * 2 + heavyFuncCount * 3 + (isTooLong ? 5 : 0) + (unbalanced ? 5 : 0);

                            results.add(new FormulaInfo(
                                objectName, fieldName, depth, crossObj, heavyFuncCount,
                                risk, usesSpecialFields, isTooLong, returnType, score,
                                String.join(redFlags, '; ')
                            ));
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
    }

    private static Integer countDotDepth(String formula) {
        Set<String> knownFunctions = new Set<String>{
            'AND', 'CASE', 'IF', 'NOT', 'OR', 'BLANKVALUE', 'NULLVALUE',
            'BEGINS', 'BR', 'CONTAINS', 'FIND', 'GETSESSIONID', 'HYPERLINK',
            'IMAGE', 'INCLUDES', 'ISCHANGED', 'ISNEW', 'ISPICKVAL', 'ISNUMBER',
            'LEFT', 'LEN', 'LOWER', 'LPAD', 'MID', 'RIGHT', 'RPAD', 'SUBSTITUTE',
            'TEXT', 'TRIM', 'UPPER', 'VALUE', 'ADDMONTHS', 'DATE', 'DATEVALUE',
            'DATETIMEVALUE', 'DAY', 'NOW', 'MONTH', 'TODAY', 'TIMEVALUE', 'WEEKDAY',
            'YEAR', 'ABS', 'CEILING', 'EXP', 'FLOOR', 'GCD', 'LN', 'LOG', 'MAX',
            'MIN', 'MOD', 'ROUND', 'SQRT', 'ISBLANK', 'ISNULL', 'PRIORVALUE',
            'VLOOKUP', 'DISTANCE', 'GEOLOCATION', 'TEXTVALUE', 'ISCLONE'
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

    private static Integer countHeavyFunctions(String formula) {
        Set<String> heavyFunctions = new Set<String>{ 'ISCHANGED', 'PRIORVALUE', 'VLOOKUP', 'DISTANCE', 'GEOLOCATION' };
        Integer count = 0;
        String upperFormula = formula != null ? formula.toUpperCase() : '';

        for (String func : heavyFunctions) {
            try {
                Pattern p = Pattern.compile('\\b' + func + '\\s*\\(');
                Matcher m = p.matcher(upperFormula);
                while (m.find()) count++;
            } catch (Exception ex) {
                System.debug('Regex error on func=' + func + ', formula=' + formula + ': ' + ex.getMessage());
            }
        }
        return count;
    }

    private static Boolean containsRecordTypeOrUser(String formula) {
        String upperFormula = formula.toUpperCase();
        return upperFormula.contains('$RECORDTYPE') || upperFormula.contains('$USER');
    }

    private static Boolean hasUnbalancedParentheses(String formula) {
        Integer balance = 0;
        for (Integer i = 0; i < formula.length(); i++) {
            String ch = formula.substring(i, i + 1);
            if (ch == '(') balance++;
            else if (ch == ')') balance--;
            if (balance < 0) return true;
        }
        return balance != 0;
    }

    private static String calculateRisk(Integer depth, Integer crossObj, Integer heavyFuncCount, Boolean tooLong) {
        if (depth >= 6 || crossObj >= 3 || heavyFuncCount >= 2 || tooLong) return 'High';
        if (depth >= 3 || crossObj >= 2 || heavyFuncCount >= 1) return 'Medium';
        return 'Low';
    }
}
