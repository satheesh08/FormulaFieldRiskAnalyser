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
        @AuraEnabled public String originalFormula;
        @AuraEnabled public String optimizedFormula;
        @AuraEnabled public Integer depth;
        @AuraEnabled public Integer crossObjectHops;
        @AuraEnabled public Integer heavyFunctionCount;
        @AuraEnabled public String riskLevel;
        @AuraEnabled public Boolean usesRecordTypeOrUser;
        @AuraEnabled public Boolean isFormulaTooLong;
        @AuraEnabled public String returnType;
        @AuraEnabled public String label;
        @AuraEnabled public Integer cpuScore;
        @AuraEnabled public String cpuRedFlags;
        
        public FormulaInfo(String o, String f, Integer d, Integer c, Integer h, String r, Boolean flag, Boolean tooLong, String rt,String lb, Integer score, String redFlags,String ogFx, String optFx) {
            objectName = o;
            fieldName = f;
            depth = d;
            crossObjectHops = c;
            heavyFunctionCount = h;
            riskLevel = r;
            usesRecordTypeOrUser = flag;
            isFormulaTooLong = tooLong;
            returnType = rt;
            label = lb;
            cpuScore = score;
            cpuRedFlags = redFlags;
            originalFormula=ogFx;
            optimizedFormula=optFx;
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<FormulaInfo> getFormulaFields(String objectName) {
        List<FormulaInfo> results = new List<FormulaInfo>();
        try {
            Set<String> formulaFieldNames = new Set<String>();
            Map<String,String> formulaMap = new Map<String,String>();
            for (FieldDefinition fd : [
                SELECT QualifiedApiName, EntityDefinition.QualifiedApiName, DeveloperName
                FROM FieldDefinition 
                WHERE EntityDefinition.QualifiedApiName = :objectName 
                AND DataType LIKE 'Formula%'
            ]) {
                formulaFieldNames.add(fd.DeveloperName);
                formulaMap.put(fd.DeveloperName,fd.QualifiedApiName);
            }
            
            String objectQuery = 'SELECT Id FROM CustomObject WHERE DeveloperName = \'' + objectName.replace('__c', '') + '\'';
            String objectEndpoint = 'callout:ToolingAPI/services/data/v59.0/tooling/query/?q=' + EncodingUtil.urlEncode(objectQuery, 'UTF-8');
            
            HttpRequest objectReq = new HttpRequest();
            objectReq.setEndpoint(objectEndpoint);
            objectReq.setMethod('GET');
            objectReq.setHeader('Content-Type', 'application/json');
            
            Http http2 = new Http();
            HttpResponse objectRes = http2.send(objectReq);
            
            Map<String, Object> objectJson = (Map<String, Object>) JSON.deserializeUntyped(objectRes.getBody());
            List<Object> objectRecords = (List<Object>) objectJson.get('records');
            
            if (objectRecords == null || objectRecords.isEmpty()) {
                System.debug('CustomObject not found for: ' + objectName);
                return null;
            }
            
            Map<String, Object> objectRecord = (Map<String, Object>) objectRecords[0];
            String customObjectId = (String) objectRecord.get('Id');
            
            Http http = new Http();
            for (String fieldName : formulaFieldNames) {
                String query = 'SELECT Id, Metadata, DeveloperName FROM CustomField WHERE DeveloperName = \'' + fieldName + '\' AND TableEnumOrId = \'' + customObjectId + '\'';
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
                            String optimizedFormulaString=optimizeFormula(formula);
                            String returnType = (String) metadata.get('type');
                            String label = (String) metadata.get('label');
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
                            
                            String finalFormula = formula;
                            String finalOptimizedFormula = optimizedFormulaString;
                            
                            if (formula != null && optimizedFormulaString != null && formula.trim() == optimizedFormulaString.trim()) {
                                finalOptimizedFormula = null; 
                            }
                            String devname=formulaMap.get(fieldName);
                            results.add(new FormulaInfo(
                                objectName, devname, depth, crossObj, heavyFuncCount,
                                risk, usesSpecialFields, isTooLong, returnType,label, score,
                                String.join(redFlags, '; '),
                                finalFormula,
                                finalOptimizedFormula
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
    
    @AuraEnabled(cacheable=true)
    public static String optimizeFormula(String formula) {
        String endpoint = 'https://api.openai.com/v1/chat/completions';
        String GPT_API_KEY = '';  // Add Your Key Here
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Authorization', 'Bearer ' + GPT_API_KEY);
        
        String prompt = 'You are a Salesforce formula field optimizer. Your goal is to simplify and optimize Salesforce formulas only if it can be done safely, without changing their logic, behavior, or output. Follow these strict rules: 1. Maintain the original meaning, logic, and output of the formula. 2. Follow Salesforce formula syntax strictly. Ensure that all formulas you return are valid and compile without syntax errors. 3. Always include required literals like 0 or "" when they serve as fallback or default values. 4. Preserve all data types (e.g., Number, Text, Boolean) and ensure all functions and operators are used correctly per Salesforce formula syntax. 5. Retain cross-object references, field references, and session variables (e.g., CreatedBy.Name, $User.Name) exactly as-is. 6. Do not alter any IF, CASE, ISBLANK, ISNUMBER, TEXT, or logical structures unless it results in a logically equivalent and safer simplification. 7. Maintain proper use of parentheses to ensure logical grouping and operator precedence. 8. Do not introduce or remove any fields, variables, functions, or logic not present in the original formula. 9. If the formula cannot be safely optimized without changing meaning or risking syntax errors, return the original formula as-is. Return only the optimized formula as a plain text string with no explanation, no markdown, and no formatting.';

        String requestBody = System.JSON.serialize(new Map<String, Object>{
            'model' => 'gpt-4o-mini',
                'temperature' => 0.2,
                'messages' => new List<Map<String, String>>{
                    new Map<String, String>{
                        'role' => 'system',
                            'content' => prompt
                            },
                                new Map<String, String>{
                                    'role' => 'user',
                                        'content' => formula
                                        }
                }
        });
        req.setBody(requestBody);        
        Http http = new Http();
        HttpResponse res = http.send(req);
        String optimizedFormula = '';
        
        if (res.getStatusCode() == 200) {
            Map<String, Object> parsedResponse = (Map<String, Object>)System.JSON.deserializeUntyped(res.getBody());
            List<Object> choicesList = (List<Object>) parsedResponse.get('choices'); 
            optimizedFormula = (String) ((Map<String, Object>) ((Map<String, Object>) choicesList.get(0)).get('message')).get('content');
            return optimizedFormula;
        } else {
            return 'Error optimizing formula: ' + res.getBody();
        }
    }
    
    @AuraEnabled
    public static Boolean updateFormula(String objectName, String fieldName, String newFormula, String type, String label) {
        
        if (!isCustomUnmanagedField(fieldName)) {
            System.debug('Skipping update: Not a custom unmanaged field => ' + fieldName);
            return false;
        }
        
        mdt_updation.MetadataPort service = new mdt_updation.MetadataPort();
        service.SessionHeader = new mdt_updation.SessionHeader_element();
        service.SessionHeader.sessionId = UtilsGetSessionId.getSessionIdFromVFPage();
        
        mdt_updation.CustomField formulaField = new mdt_updation.CustomField();
        formulaField.fullName = objectName + '.' + fieldName;
        formulaField.formula = newFormula;
        formulaField.type_x = type;
        formulaField.label = label;
        
        switch on type {
            when 'Number' {
                formulaField.precision = 18;
                formulaField.scale = 2;
            }
            when 'Currency' {
                formulaField.precision = 16;
                formulaField.scale = 2;
            }
            when 'Percent' {
                formulaField.precision = 3;
                formulaField.scale = 2;
            }
            when 'Text' {
                formulaField.length = 255;
            }
            when 'Checkbox' {
                // no additional properties needed
            }
            when 'Date' {
                // no additional properties needed
            }
            when 'DateTime' {
                // no additional properties needed
            }
            when 'Time' {
                // no additional properties needed
            }
            when else {
                System.debug('Unsupported return type: ' + type);
                return false;
            }
        }
        
        try {
            mdt_updation.SaveResult[] results = service.updateMetadata(new mdt_updation.Metadata[] { formulaField });
            
            if (results != null && results.size() > 0) {
                if (results[0].success) {
                    System.debug('Formula field updated successfully.');
                    return true;
                } else {
                    for (mdt_updation.Error error : results[0].errors) {
                        System.debug('Error: ' + error.message);
                    }
                    return false;
                }
            } else {
                System.debug('No results returned from updateMetadata call.');
                return false;
            }
        } catch (Exception e) {
            System.debug('Exception: ' + e.getMessage());
            return false;
        }
    }
    
    public static Boolean isCustomUnmanagedField(String fieldName) {
        // Must end with __c and NOT be namespaced like xyz__Field__c
        // So we allow only fields that match: Field__c (no double __ before __c)
        return fieldName.endsWith('__c') && !Pattern.matches('.*__.+__c', fieldName);
    }
    
    
}
