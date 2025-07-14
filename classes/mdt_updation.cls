public class mdt_updation {
    public static String SOAP_M_URI = 'http://soap.sforce.com/2006/04/metadata';
    
    public virtual class Metadata {
        public String fullName;
    }
    
    public class Error {
        public String[] fields;
        public String message;
        public String statusCode;
        
        private String[] fields_type_info = new String[]{'fields', SOAP_M_URI, null, '0', '-1', 'false'};
            private String[] message_type_info = new String[]{'message', SOAP_M_URI, null, '1', '1', 'false'};
                private String[] statusCode_type_info = new String[]{'statusCode', SOAP_M_URI, null, '1', '1', 'false'};
                    private String[] apex_schema_type_info = new String[]{SOAP_M_URI, 'true', 'false'};
                        private String[] field_order_type_info = new String[]{'fields', 'message', 'statusCode'};
                            }
    
    public class SaveResult {
        public mdt_updation.Error[] errors;
        public String fullName;
        public Boolean success;
        
        private String[] errors_type_info = new String[]{'errors', SOAP_M_URI, null, '0', '-1', 'false'};
            private String[] fullName_type_info = new String[]{'fullName', SOAP_M_URI, null, '1', '1', 'false'};
                private String[] success_type_info = new String[]{'success', SOAP_M_URI, null, '1', '1', 'false'};
                    private String[] apex_schema_type_info = new String[]{SOAP_M_URI, 'true', 'false'};
                        private String[] field_order_type_info = new String[]{'errors', 'fullName', 'success'};
                            }
    
    public class CustomField extends Metadata {
        public String type = 'CustomField';
        public String fullName;
        public String formula;
        public String type_x;
        public String label;
        public Integer precision;
        public Integer scale;
        
        private String[] fullName_type_info = new String[]{'fullName', SOAP_M_URI, null, '0', '1', 'false'};
            private String[] formula_type_info = new String[]{'formula', SOAP_M_URI, null, '0', '1', 'false'};
                private String[] type_x_type_info = new String[]{'type', SOAP_M_URI, null, '0', '1', 'false'};
                    private String[] label_type_info = new String[]{'label', SOAP_M_URI, null, '0', '1', 'false'};
                        private String[] precision_type_info = new String[]{'precision', SOAP_M_URI, null, '0', '1', 'false'};
                            private String[] scale_type_info = new String[]{'scale', SOAP_M_URI, null, '0', '1', 'false'};
                                
                                private String[] type_att_info = new String[]{'xsi:type'};
                                    
                                    private String[] apex_schema_type_info = new String[]{SOAP_M_URI, 'true', 'false'};
                                        private String[] field_order_type_info = new String[]{'fullName', 'formula', 'type_x', 'label', 'precision', 'scale'};
                                            }
    
    
    public class SessionHeader_element {
        public String sessionId;
        
        private String[] sessionId_type_info = new String[]{'sessionId', SOAP_M_URI, null, '1', '1', 'false'};
            private String[] apex_schema_type_info = new String[]{SOAP_M_URI, 'true', 'false'};
                private String[] field_order_type_info = new String[]{'sessionId'};
                    }
    
    public class updateMetadata_element {
        public mdt_updation.Metadata[] metadata;
        
        private String[] metadata_type_info = new String[]{'metadata', SOAP_M_URI, null, '0', '-1', 'false'};
            private String[] apex_schema_type_info = new String[]{SOAP_M_URI, 'true', 'false'};
                private String[] field_order_type_info = new String[]{'metadata'};
                    }
    
    public class updateMetadataResponse_element {
        public mdt_updation.SaveResult[] result;
        
        private String[] result_type_info = new String[]{'result', SOAP_M_URI, null, '0', '-1', 'false'};
            private String[] apex_schema_type_info = new String[]{SOAP_M_URI, 'true', 'false'};
                private String[] field_order_type_info = new String[]{'result'};
                    }
    
    public class MetadataPort {
        public String endpoint_x = URL.getOrgDomainUrl().toExternalForm() + '/services/Soap/m/42.0';
        public mdt_updation.SessionHeader_element SessionHeader;
        private String SessionHeader_hns = 'SessionHeader=http://soap.sforce.com/2006/04/metadata';
        
        private String[] ns_map_type_info = new String[]{SOAP_M_URI, 'mdt_updation'};
            
            public mdt_updation.SaveResult[] updateMetadata(mdt_updation.Metadata[] metadata) {
                mdt_updation.updateMetadata_element request_x = new mdt_updation.updateMetadata_element();
                request_x.metadata = metadata;
                
                mdt_updation.updateMetadataResponse_element response_x;
                Map<String, mdt_updation.updateMetadataResponse_element> response_map_x = new Map<String, mdt_updation.updateMetadataResponse_element>();
                response_map_x.put('response_x', response_x);
                
                WebServiceCallout.invoke(
                    this,
                    request_x,
                    response_map_x,
                    new String[]{
                        endpoint_x,
                            '',
                            SOAP_M_URI,
                            'updateMetadata',
                            SOAP_M_URI,
                            'updateMetadataResponse',
                            'mdt_updation.updateMetadataResponse_element'
                            }
                );
                
                response_x = response_map_x.get('response_x');
                return response_x.result;
            }
    }
}
