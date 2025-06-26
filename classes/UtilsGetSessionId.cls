global class UtilsGetSessionId {
    global static String getSessionIdFromVFPage() {
        PageReference pageRef = Page.GetSessionIdPage;
        String content = pageRef.getContent().toString();
        String startTag = 'Start_Of_Session_Id';
        String endTag = 'End_Of_Session_Id';
        Integer startIdx = content.indexOf(startTag) + startTag.length();
        Integer endIdx = content.indexOf(endTag);
        if (startIdx >= 0 && endIdx > startIdx) {
            return content.substring(startIdx, endIdx);
        }
        throw new AuraHandledException('Could not extract session ID from VF page.');
    }
}