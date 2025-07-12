public with sharing class FormulaRiskScanner {
    public class FormulaFieldTimeResult {
        @AuraEnabled public String fieldName;
        @AuraEnabled public Integer cpuTimeMs;
        @AuraEnabled public Integer wallTimeMs;
        @AuraEnabled public Integer recordCount;
        @AuraEnabled public Integer totalRecords;
    }
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
        @AuraEnabled public String deps;
        @AuraEnabled public Boolean isNonDeterministic;
        @AuraEnabled public String forecastScore;
        @AuraEnabled public Integer cpuTimeMs;
        @AuraEnabled public Integer wallTimeMs;
        @AuraEnabled public Integer recordCount;
        @AuraEnabled public Integer totalRecords;
        public FormulaInfo(
            String o, String f, Integer d, Integer c, Integer h, String r,
            Boolean flag, Boolean tooLong, String rt, String lb, Integer score,
            String redFlags, String ogFx, String optFx, String d2,
            Integer cpuMs, Integer recordCountVal, Integer totalRec,Integer wallMs,Boolean nonDet, String frScore
        ) {
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
            originalFormula = ogFx;
            optimizedFormula = optFx;
            deps = d2;
            wallTimeMs = wallMs;
            cpuTimeMs = cpuMs;
            recordCount = recordCountVal;
            totalRecords = totalRec;
            isNonDeterministic=nonDet;
            forecastScore=frScore;
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
            String objectQuery = 'SELECT DurableId FROM EntityDefinition WHERE QualifiedApiName = \'' + objectName + '\'';
            String entityDefEndpoint = 'callout:ToolingAPI/services/data/v59.0/tooling/query/?q=' + EncodingUtil.urlEncode(objectQuery, 'UTF-8');
            HttpRequest objectReq = new HttpRequest();
            objectReq.setEndpoint(entityDefEndpoint);
            objectReq.setMethod('GET');
            objectReq.setHeader('Content-Type', 'application/json');
            Http http = new Http();
            HttpResponse objectRes = http.send(objectReq);
            Map<String, Object> objectJson = (Map<String, Object>) JSON.deserializeUntyped(objectRes.getBody());
            List<Object> objectRecords = (List<Object>) objectJson.get('records');
            if (objectRecords == null || objectRecords.isEmpty()) {
                System.debug('EntityDefinition not found for: ' + objectName);
                return null;
            }
            Map<String, Object> objectRecord = (Map<String, Object>) objectRecords[0];
            String durableId = (String) objectRecord.get('DurableId'); 
            for (String fieldName : formulaFieldNames) {
                String fieldQuery = 'SELECT Id, Metadata, DeveloperName FROM CustomField WHERE DeveloperName = \'' + fieldName + '\' AND TableEnumOrId = \'' + durableId + '\'';
                String toolingEndpoint = 'callout:ToolingAPI/services/data/v59.0/tooling/query/?q=' + EncodingUtil.urlEncode(fieldQuery, 'UTF-8');
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
                        String fieldId=(String)rec.get('Id');
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
                            Boolean isNonDeterministic = isNonDeterministicFormula(formula);
                            List<String> redFlags = new List<String>();
                            if (isTooLong) redFlags.add('Formula > 3000 chars');
                            if (usesSpecialFields) redFlags.add('Uses $User/$RecordType');
                            if (unbalanced) redFlags.add('Unbalanced parentheses');
                            if (heavyFuncCount > 0) redFlags.add('Heavy functions: ' + String.valueOf(heavyFuncCount));
                            if (crossObj >= 3) redFlags.add('Deep cross-object hops');
                            if (depth >= 6) redFlags.add('Excessive nesting');
                            if (isNonDeterministic) redFlags.add('Uses Non-Deterministic Logic');
                            Integer score = depth * 2 + crossObj * 2 + heavyFuncCount * 3 + (isTooLong ? 5 : 0) + (unbalanced ? 5 : 0) + (isNonDeterministic ? 5 : 0);
                            String finalFormula = formula;
                            String finalOptimizedFormula = optimizedFormulaString;
                            if (formula != null && optimizedFormulaString != null && formula.trim() == optimizedFormulaString.trim()) {
                                finalOptimizedFormula = null; 
                            }
                            if(optimizedFormulaString=='Do not touch PROD'){
                                finalOptimizedFormula = null;
                            }
                            String devname=formulaMap.get(fieldName);
                            String dependencies = getMetadataDependencies(fieldId,fieldName);
                            dependencies = getListViewsUsingField(objectName,devname,dependencies);
                            String forecastScore = forecastFormulaScore(formula, objectName, devname,score);
                            List<FormulaFieldTimeResult> result = FormulaRiskScanner.getFormulaEvaluationTimes(objectName, devname);
                            FormulaFieldTimeResult benchmark = result[0];
                            Integer cpuTime = benchmark.cpuTimeMs;
                            Integer wallTime = benchmark.wallTimeMs;
                            Integer recordsTested = benchmark.recordCount;
                            Integer totalAvailable = benchmark.totalRecords;
                            if (!isCustomUnmanagedField(devname)) {
                                System.debug('Skipping update: Not a custom unmanaged field => ' + devname);
                            } else {
                                results.add(new FormulaInfo(
                                    objectName, devname, depth, crossObj, heavyFuncCount,
                                    risk, usesSpecialFields, isTooLong, returnType, label, score,
                                    String.join(redFlags, '; '),
                                    finalFormula,
                                    finalOptimizedFormula,dependencies,cpuTime,recordsTested,totalAvailable,wallTime,isNonDeterministic,forecastScore
                                ));
                            }
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
    private static final List<String> NON_DETERMINISTIC_PATTERNS = new List<String>{
        '(?i)\\bNOW\\s*\\(',
            '(?i)\\bTODAY\\s*\\(',
            '(?i)\\bDATEVALUE\\s*\\(',
            '(?i)\\bDATETIMEVALUE\\s*\\(',
            '(?i)\\bTIMEVALUE\\s*\\(',
            '(?i)\\bYEAR\\s*\\(\\s*(NOW|TODAY)\\s*\\(',
            '(?i)\\bMONTH\\s*\\(\\s*(NOW|TODAY)\\s*\\(',
            '(?i)\\bDAY\\s*\\(\\s*(NOW|TODAY)\\s*\\(',
            '(?i)\\bWEEKDAY\\s*\\(\\s*(NOW|TODAY)\\s*\\(',
            '(?i)\\$USER',
            '(?i)\\$PROFILE',
            '(?i)\\$PERMISSION',
            '(?i)\\$SETUP',
            '(?i)\\$USERROLE',
            '(?i)\\$ORGANIZATION',
            '(?i)\\$RECORDTYPE',
            '(?i)\\bISCHANGED\\s*\\(',
            '(?i)\\bPRIORVALUE\\s*\\(',
            '(?i)\\bISNEW\\s*\\(',
            '(?i)\\bDISTANCE\\s*\\(',
            '(?i)\\bGEOLOCATION\\s*\\(',
            '(?i)\\bVLOOKUP\\s*\\(',
            '(?i)\\$CUSTOMMETADATA',
            '(?i)\\$CUSTOMSETTING',
            '(?i)\\$LABEL',
            '(?i)\\b[a-zA-Z_][a-zA-Z0-9_]*__r(?:\\.[a-zA-Z_][a-zA-Z0-9_]*){1,}',
            '(?i)\\bSYSTEM\\.',
            '(?i)\\bUSER\\.',
            '(?i)\\bUSERROLE\\.',
            '(?i)\\bOWNER\\.(MANAGER|USERROLE|PROFILE|NAME)'
            };
                private static Boolean isNonDeterministicFormula(String formula) {
                    if (String.isBlank(formula)) return false;
                    for (String pattern : NON_DETERMINISTIC_PATTERNS) {
                        System.Pattern p = System.Pattern.compile(pattern);
                        System.Matcher m = p.matcher(formula);
                        if (m.find()) {
                            return true;
                        }
                    }
                    return false;
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
        HttpRequest req = new HttpRequest();
        String domain = System.Url.getOrgDomainUrl().getHost().toLowerCase();
        Boolean isSandbox = domain.contains('sandbox') || domain.contains('dev-ed');
        if (!isSandbox) {
            return 'Do not touch PROD';
        }
        req.setEndpoint('callout:Open_AI_API_Named_Cred/v1/chat/completions');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        String prompt = 'You are a Salesforce formula field optimizer. Your goal is to simplify and optimize Salesforce formulas wherever possible. You should preserve the formulas logic and output, but you are allowed to safely restructure or flatten logic for clarity and performance. Maintain correct Salesforce syntax and preserve field references, but you may refactor nested IFs, remove redundant conditions, and consolidate logic where behavior remains equivalent. Return the optimized formula as a plain text string with no explanation, no markdown, and no formatting.';
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
    @AuraEnabled(cacheable=true)
    public static String forecastFormulaScore(String formula, String objectName, String fieldName, Integer nowScore) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Open_AI_API_Named_Cred/v1/chat/completions');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        
        String prompt =
            'You are a Salesforce formula complexity forecaster. Your task is to simulate how formula complexity may evolve over time.\n\n' +
            'Scoring system (already applied to compute the current score):\n' +
            '- +2 points per level of nesting (depth)\n' +
            '- +2 points for each cross-object reference (e.g., Account.Owner.Name)\n' +
            '- +3 points for each heavy function (e.g., ISCHANGED, ISPICKVAL, VLOOKUP, CASESAFEID, REGEX)\n' +
            '- +5 if the formula length exceeds 3000 characters\n' +
            '- +5 if the formula has unbalanced parentheses\n' +
            '- +5 if the formula is non-deterministic (e.g., uses TODAY, $User, $Profile, $Permission, $RecordType, etc.)\n\n' +
            'Instructions:\n' +
            '- The formula currently has a score of ' + nowScore + '.\n' +
            '- Forecast how the score might grow in 6 months and in 1 year.\n' +
            '- Consider realistic business growth, added complexity, new conditions, or user-specific logic being added over time.\n\n' +
            'Return only the forecast in this exact format:\n' +
            'Now Score: ' + nowScore + '\n' +
            'In 6 months: <score>\n' +
            'In 1 year: <score>\n\n' +
            'Do not add any explanation or comments.\n\n' +
            'Formula for context (no need to rescore):\n' + formula;
        
        String requestBody = JSON.serialize(new Map<String, Object>{
            'model' => 'gpt-4o-mini',
                'temperature' => 0.2,
                'messages' => new List<Map<String, String>>{
                    new Map<String, String>{ 'role' => 'system', 'content' => prompt },
                        new Map<String, String>{ 'role' => 'user', 'content' => 'Formula from ' + objectName + '.' + fieldName }
                }
        });
        
        req.setBody(requestBody);
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        if (res.getStatusCode() == 200) {
            Map<String, Object> parsedResponse = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            List<Object> choicesList = (List<Object>) parsedResponse.get('choices');
            String forecast = (String) ((Map<String, Object>) ((Map<String, Object>) choicesList[0]).get('message')).get('content');
            return forecast;
        } else {
            return 'Forecast error: ' + res.getBody();
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
            }
            when 'Checkbox' {
            }
            when 'Date' {
            }
            when 'DateTime' {
            }
            when 'Time' {
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
    public static String getMetadataDependencies(String fieldId, String fieldDeveloperName) {
        try {
            String depQuery = 'SELECT MetadataComponentId, MetadataComponentName, MetadataComponentType ' +
                'FROM MetadataComponentDependency ' +
                'WHERE RefMetadataComponentId = \'' + fieldId + '\'';
            String encodedDepQuery = EncodingUtil.urlEncode(depQuery, 'UTF-8');
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:ToolingAPI/services/data/v59.0/tooling/query/?q=' + encodedDepQuery);
            req.setMethod('GET');
            Http http = new Http();
            HttpResponse res = http.send(req);
            if (res.getStatusCode() != 200) {
                return 'Error fetching dependencies for ' + fieldDeveloperName + '__c: ' + res.getStatus();
            }
            Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            List<Object> records = (List<Object>) result.get('records');
            if (records.isEmpty()) {
                return 'No metadata components reference the field "' + fieldDeveloperName + '__c".';
            }
            String summary = 'Components referencing "' + fieldDeveloperName + '__c":\n';
            for (Object obj : records) {
                Map<String, Object> rec = (Map<String, Object>) obj;
                String compType = (String) rec.get('MetadataComponentType');
                String compName = (String) rec.get('MetadataComponentName');
                summary += '- ' + compType + ': ' + compName + '\n';
            }
            return summary;
        } catch (Exception ex) {
            return 'Exception occurred while checking dependencies: ' + ex.getMessage();
        }
    }
    public static String getListViewsUsingField(String objectApiName, String formulaField,String summary) {
        Map<String, String> developerNameToLabel = new Map<String, String>();
        List<String> listViewDeveloperNames = new List<String>();
        for (ListView lv : [SELECT DeveloperName, Name FROM ListView WHERE SObjectType = :objectApiName]) {
            developerNameToLabel.put(lv.DeveloperName, lv.Name);
            listViewDeveloperNames.add(lv.DeveloperName);
        }
        Http http = new Http();
        List<String> listViewsWithField = new List<String>();
        for (String devName : listViewDeveloperNames) {
            String fullName = objectApiName + '.' + devName;
            String sessionId = UtilsGetSessionId.getSessionIdFromVFPage(); // Assumes you have a VF method for session ID
            String requestBody = ''
                + '<?xml version="1.0" encoding="UTF-8"?>'
                + '<soapenv:Envelope xmlns:xsd="http://www.w3.org/2001/XMLSchema" '
                + 'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
                + 'xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" '
                + 'xmlns:sf="http://soap.sforce.com/2006/04/metadata">'
                + '<soapenv:Header>'
                + '<sf:SessionHeader>'
                + '<sf:sessionId>' + sessionId + '</sf:sessionId>'
                + '</sf:SessionHeader>'
                + '</soapenv:Header>'
                + '<soapenv:Body>'
                + '<sf:readMetadata>'
                + '<sf:type>ListView</sf:type>'
                + '<sf:fullNames>' + fullName + '</sf:fullNames>'
                + '</sf:readMetadata>'
                + '</soapenv:Body>'
                + '</soapenv:Envelope>';
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:ToolingAPI/services/Soap/m/59.0');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'text/xml');
            req.setHeader('SOAPAction', 'readMetadata');
            req.setBody(requestBody);
            HttpResponse res = http.send(req);
            String body = res.getBody();
            Dom.Document doc = new Dom.Document();
            doc.load(body);
            Dom.XmlNode root = doc.getRootElement();
            Dom.XmlNode bodyNode = root.getChildElements()[0];
            Dom.XmlNode responseNode = bodyNode.getChildElements()[0];
            Dom.XmlNode resultNode = responseNode.getChildElements()[0];
            Dom.XmlNode recordsNode;
            for (Dom.XmlNode node : resultNode.getChildElements()) {
                if (node.getName() == 'records') {
                    recordsNode = node;
                    break;
                }
            }
            if (recordsNode == null) {
                continue;
            }
            List<String> allColumns = new List<String>();
            collectColumns(recordsNode, allColumns);
            for (String val : allColumns) {
                if (
                    val != null &&
                    (val.toLowerCase() == formulaField.toLowerCase() ||
                     val.toLowerCase().endsWith('.' + formulaField.toLowerCase()))
                ) {
                    String label = developerNameToLabel.get(devName);
                    listViewsWithField.add(label);
                    summary += '- List View: ' + label + '\n';
                    break;
                }
            }
        }
        if (listViewsWithField.isEmpty()) {
            summary = summary;
        }
        return summary;
    }
    private static void collectColumns(Dom.XmlNode node, List<String> out) {
        for (Dom.XmlNode child : node.getChildElements()) {
            if (child.getName() == 'columns') {
                out.add(child.getText().trim());
            }
            collectColumns(child, out);
        }
    }  
    public static List<FormulaFieldTimeResult> getFormulaEvaluationTimes(String objectApiName, String fieldName) {
        final Integer sampleSize = 4000;
        List<FormulaFieldTimeResult> resultList = new List<FormulaFieldTimeResult>();
        if (String.isBlank(objectApiName) || String.isBlank(fieldName)) {
            return resultList; 
        }
        Integer totalRecords = (Integer) Database.countQuery('SELECT COUNT() FROM ' + objectApiName);
        String baseQuery = 'SELECT Id FROM ' + objectApiName + ' LIMIT ' + sampleSize;
        List<SObject> baseRecords = Database.query(baseQuery);
        if (baseRecords.isEmpty()) return resultList;
        Set<Id> recordIds = new Map<Id, SObject>(baseRecords).keySet();
        try {
            String query = 'SELECT Id, ' + fieldName + ' FROM ' + objectApiName + ' WHERE Id IN :recordIds';
            Long cpuStart = Limits.getCpuTime();
            Long wallStart = System.currentTimeMillis();
            List<SObject> records = Database.query(query);
            for (SObject s : records) {
                Object val = s.get(fieldName);
                if (val != null) {
                    String dummy = val.toString().trim().toLowerCase(); // force full eval
                }
            }
            Long cpuEnd = Limits.getCpuTime();
            Long wallEnd = System.currentTimeMillis();
            Long wallTime = wallEnd - wallStart;
            Long cpuTime = cpuEnd - cpuStart;
            FormulaFieldTimeResult res = new FormulaFieldTimeResult();
            res.fieldName = fieldName;
            res.cpuTimeMs = (Integer)cpuTime;
            res.wallTimeMs = (Integer)wallTime;
            res.recordCount = records.size();
            res.totalRecords = totalRecords;
            resultList.add(res);
        } catch (Exception e) {
        }
        return resultList;
    }
    
    @AuraEnabled(cacheable=true)
    public static void sendForecastEmail(String chartImage, String formulaLabel, String recordSummaryHtml) {
        List<User> admins = [SELECT Email FROM User WHERE Profile.Name = 'System Administrator' AND IsActive = TRUE AND Id != :UserInfo.getUserId()];
        if (admins.isEmpty()) return;
        
        String chartBase64 = chartImage.replaceFirst('^data:image\\/png;base64,', '');
        
        Messaging.EmailFileAttachment chartAttachment = new Messaging.EmailFileAttachment();
        chartAttachment.setFileName('Forecast_' + formulaLabel + '_Chart.png');
        chartAttachment.setBody(EncodingUtil.base64Decode(chartBase64));
        chartAttachment.setContentType('image/png');
        
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setSubject('FormulaSniffR Forecast & Summary: ' + formulaLabel);
        email.setSenderDisplayName('FormulaSniffR Notifier');
        User currentUser = [SELECT Email FROM User WHERE Id = :UserInfo.getUserId()];
        email.setReplyTo(currentUser.Email);
        
        String htmlBody = ''
            + '<p>Hi Admin,</p>'
            + '<p>Attached is the forecast chart for <strong>' + formulaLabel + '</strong>.</p>'
            + '<p>Below is a summary of the record:</p>'
            + recordSummaryHtml
            + '<p style="margin-top:16px;">Thanks,<br/>FormulaSniffR Bot</p>';
        
        email.setHtmlBody(htmlBody);
        email.setFileAttachments(new List<Messaging.EmailFileAttachment>{ chartAttachment });
        
        List<String> toEmails = new List<String>();
        for (User u : admins) {
            toEmails.add(u.Email);
        }
        email.setToAddresses(toEmails);
        
        Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email });
    }
    
    
}
