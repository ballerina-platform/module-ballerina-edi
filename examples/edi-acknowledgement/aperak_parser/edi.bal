// Copyright (c) 2026, WSO2 LLC. (http://www.wso2.com).
//
// WSO2 LLC. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied. See the License for the
// specific language governing permissions and limitations
// under the License.



import ballerina/edi;

# Convert EDI string to Ballerina APERAK record.
#
# + ediText - EDI string to be converted
# + return - Ballerina record or error
public isolated function fromEdiString(string ediText) returns APERAK|error {
    edi:EdiSchema ediSchema = check edi:getSchema(schemaJson);
    json dataJson = check edi:fromEdiString(ediText, ediSchema);
    return dataJson.cloneWithType();
}

# Convert Ballerina APERAK record to EDI string.
#
# + data - Ballerina record to be converted
# + return - EDI string or error
public isolated function toEdiString(APERAK data) returns string|error {
    edi:EdiSchema ediSchema = check edi:getSchema(schemaJson);
    return edi:toEdiString(data, ediSchema);
}

# Get the EDI schema.
#
# + return - EDI schema or error
public isolated function getSchema() returns edi:EdiSchema|error {
    return edi:getSchema(schemaJson);
}

# Convert EDI string to Ballerina APERAK record with schema.
#
# + ediText - EDI string to be converted
# + schema - EDI schema
# + return - Ballerina record or error
public isolated function fromEdiStringWithSchema(string ediText, edi:EdiSchema schema) returns APERAK|error {
    json dataJson = check edi:fromEdiString(ediText, schema);
    return dataJson.cloneWithType();
}

# Convert Ballerina APERAK record to EDI string with schema.
#
# + data - Ballerina record to be converted
# + ediSchema - EDI schema
# + return - EDI string or error
public isolated function toEdiStringWithSchema(APERAK data, edi:EdiSchema ediSchema) returns string|error {
    return edi:toEdiString(data, ediSchema);
}


# Parse only the envelope header segments from the given EDI string.
#
# + ediText - EDI string to parse
# + return - Parsed APERAKHeaders record, or error if the headers are malformed
public isolated function headersFromEdiString(string ediText) returns APERAKHeaders|error {
    edi:EdiSchema ediSchema = check edi:getSchema(schemaJson);
    json raw = check edi:headersFromEdiString(ediText, ediSchema);
    return raw.cloneWithType();
}

# Parse the full envelope hierarchy from the given EDI string.
# A malformed transaction body becomes an error in that transaction's body field.
#
# + ediText - EDI string to parse
# + return - Parsed APERAKInterchange, or error if the envelope is malformed
public isolated function interchangeFromEdiString(string ediText) returns APERAKInterchange|error {
    edi:EdiSchema ediSchema = check edi:getSchema(schemaJson);
    edi:EdiInterchange raw = check edi:interchangeFromEdiString(ediText, ediSchema);
    APERAKTransaction[] txns = [];
        foreach edi:EdiTransaction t in raw.transactions ?: [] {
            APERAK|error body = convertAPERAKBody(t.body);
            APERAKTransactionHeader th = check t.transactionHeader.cloneWithType();
            APERAKTransactionTrailer tt = check t.transactionTrailer.cloneWithType();
            txns.push({transactionHeader: th, body, transactionTrailer: tt});
        }
        APERAKInterchangeHeader ih = check raw.interchangeHeader.cloneWithType();
        APERAKInterchangeTrailer it = check raw.interchangeTrailer.cloneWithType();
        return {interchangeHeader: ih, transactions: txns, interchangeTrailer: it};
}

# Serialise a APERAKInterchange into EDI text; the inverse of interchangeFromEdiString.
# A transaction whose body is an error is refused — filter or replace it before calling.
#
# + msg - The interchange to serialise
# + return - EDI text, or error
public isolated function interchangeToEdiString(APERAKInterchange msg) returns string|error {
    edi:EdiSchema ediSchema = check edi:getSchema(schemaJson);
    edi:EdiInterchange raw;
    {
        edi:EdiTransaction[] rawTxns = [];
        foreach APERAKTransaction t in msg.transactions {
            json|error body = unwrapAPERAKBody(t.body);
            rawTxns.push({
                transactionHeader: t.transactionHeader.toJson(),
                body: body,
                transactionTrailer: t.transactionTrailer.toJson()
            });
        }
        edi:EdiInterchange built = {
            interchangeHeader: msg.interchangeHeader.toJson(),
            transactions: rawTxns,
            interchangeTrailer: msg.interchangeTrailer.toJson()
        };
        raw = built;
    }
    return edi:interchangeToEdiString(raw, ediSchema);
}


isolated function convertAPERAKBody(json|error raw) returns APERAK|error {
    if raw is error {
        return raw;
    }
    return raw.cloneWithType();
}

isolated function unwrapAPERAKBody(APERAK|error typed) returns json|error {
    if typed is error {
        return typed;
    }
    return typed.toJson();
}

public type DOCUMENT_MESSAGE_NAME_GType record {|
   string Document_name_code?;
   string Code_list_identification_code?;
   string Code_list_responsible_agency_code?;
   string Document_name?;
|};

public type DOCUMENT_MESSAGE_IDENTIFICATION_GType record {|
   string Document_identifier?;
   string Version_identifier?;
   string Revision_identifier?;
|};

public type Beginning_of_message_Type record {|
   string code = "BGM";
   DOCUMENT_MESSAGE_NAME_GType? DOCUMENT_MESSAGE_NAME?;
   DOCUMENT_MESSAGE_IDENTIFICATION_GType? DOCUMENT_MESSAGE_IDENTIFICATION?;
   string MESSAGE_FUNCTION_CODE?;
   string RESPONSE_TYPE_CODE?;
|};

public type DATE_TIME_PERIOD_GType record {|
   string Date_or_time_or_period?;
   string Date_or_time_or_period_text?;
   string Date_or_time_or_period_format_code?;
|};

public type Date_time_period_Type record {|
   string code = "DTM";
   DATE_TIME_PERIOD_GType? DATE_TIME_PERIOD?;
|};

public type TEXT_REFERENCE_GType record {|
   string Free_text_description_code;
   string Code_list_identification_code?;
   string Code_list_responsible_agency_code?;
|};

public type TEXT_LITERAL_GType record {|
   string Free_text;
   string Free_text_1?;
   string Free_text_2?;
   string Free_text_3?;
   string Free_text_4?;
|};

public type Free_text_Type record {|
   string code = "FTX";
   string TEXT_SUBJECT_CODE_QUALIFIER?;
   string FREE_TEXT_FUNCTION_CODE?;
   TEXT_REFERENCE_GType? TEXT_REFERENCE?;
   TEXT_LITERAL_GType? TEXT_LITERAL?;
   string LANGUAGE_NAME_CODE?;
   string FREE_TEXT_FORMAT_CODE?;
|};

public type CONTROL_GType record {|
   string Control_total_type_code_qualifier;
   int Control_total_quantity;
   string Measurement_unit_code?;
|};

public type Control_total_Type record {|
   string code = "CNT";
   CONTROL_GType? CONTROL?;
|};

public type DOCUMENT_MESSAGE_DETAILS_GType record {|
   string Document_identifier?;
   string Document_status_code?;
   string Document_source_description?;
   string Language_name_code?;
   string Version_identifier?;
   string Revision_identifier?;
|};

public type Document_message_details_Type record {|
   string code = "DOC";
   DOCUMENT_MESSAGE_NAME_GType? DOCUMENT_MESSAGE_NAME?;
   DOCUMENT_MESSAGE_DETAILS_GType? DOCUMENT_MESSAGE_DETAILS?;
   string COMMUNICATION_MEDIUM_TYPE_CODE?;
   int? DOCUMENT_COPIES_REQUIRED_QUANTITY?;
   int? DOCUMENT_ORIGINALS_REQUIRED_QUANTITY?;
|};

public type Group_1_GType record {|
   Document_message_details_Type Document_message_details;
   Date_time_period_Type[] Date_time_period = [];
|};

public type REFERENCE_GType record {|
   string Reference_code_qualifier;
   string Reference_identifier?;
   string Document_line_identifier?;
   string Reference_version_identifier?;
   string Revision_identifier?;
|};

public type Reference_Type record {|
   string code = "RFF";
   REFERENCE_GType? REFERENCE?;
|};

public type Group_2_GType record {|
   Reference_Type Reference;
   Date_time_period_Type[] Date_time_period = [];
|};

public type PARTY_IDENTIFICATION_DETAILS_GType record {|
   string Party_identifier;
   string Code_list_identification_code?;
   string Code_list_responsible_agency_code?;
|};

public type NAME_AND_ADDRESS_GType record {|
   string Name_and_address_description;
   string Name_and_address_description_1?;
   string Name_and_address_description_2?;
   string Name_and_address_description_3?;
   string Name_and_address_description_4?;
|};

public type PARTY_NAME_GType record {|
   string Party_name;
   string Party_name_1?;
   string Party_name_2?;
   string Party_name_3?;
   string Party_name_4?;
   string Party_name_format_code?;
|};

public type STREET_GType record {|
   string Street_and_number_or_post_office_box_identifier;
   string Street_and_number_or_post_office_box_identifier_1?;
   string Street_and_number_or_post_office_box_identifier_2?;
   string Street_and_number_or_post_office_box_identifier_3?;
|};

public type COUNTRY_SUB_ENTITY_DETAILS_GType record {|
   string Country_sub_entity_name_code?;
   string Code_list_identification_code?;
   string Code_list_responsible_agency_code?;
   string Country_sub_entity_name?;
|};

public type Name_and_address_Type record {|
   string code = "NAD";
   string PARTY_FUNCTION_CODE_QUALIFIER?;
   PARTY_IDENTIFICATION_DETAILS_GType? PARTY_IDENTIFICATION_DETAILS?;
   NAME_AND_ADDRESS_GType? NAME_AND_ADDRESS?;
   PARTY_NAME_GType? PARTY_NAME?;
   STREET_GType? STREET?;
   string CITY_NAME?;
   COUNTRY_SUB_ENTITY_DETAILS_GType? COUNTRY_SUB_ENTITY_DETAILS?;
   string POSTAL_IDENTIFICATION_CODE?;
   string COUNTRY_NAME_CODE?;
|};

public type DEPARTMENT_OR_EMPLOYEE_DETAILS_GType record {|
   string Department_or_employee_name_code?;
   string Department_or_employee_name?;
|};

public type Contact_information_Type record {|
   string code = "CTA";
   string CONTACT_FUNCTION_CODE?;
   DEPARTMENT_OR_EMPLOYEE_DETAILS_GType? DEPARTMENT_OR_EMPLOYEE_DETAILS?;
|};

public type COMMUNICATION_CONTACT_GType record {|
   string Communication_address_identifier;
   string Communication_address_code_qualifier;
|};

public type Communication_contact_Type record {|
   string code = "COM";
   COMMUNICATION_CONTACT_GType[] COMMUNICATION_CONTACT = [];
|};

public type Group_3_GType record {|
   Name_and_address_Type Name_and_address;
   Contact_information_Type[] Contact_information = [];
   Communication_contact_Type[] Communication_contact = [];
|};

public type APPLICATION_ERROR_DETAIL_GType record {|
   string Application_error_code;
   string Code_list_identification_code?;
   string Code_list_responsible_agency_code?;
|};

public type Application_error_information_Type record {|
   string code = "ERC";
   APPLICATION_ERROR_DETAIL_GType? APPLICATION_ERROR_DETAIL?;
|};

public type Group_5_GType record {|
   Reference_Type Reference;
   Free_text_Type[] Free_text = [];
|};

public type Group_4_GType record {|
   Application_error_information_Type Application_error_information;
   Free_text_Type? Free_text?;
   Group_5_GType[] group_5 = [];
|};

public type APERAK record {|
   Beginning_of_message_Type Beginning_of_message;
   Date_time_period_Type[] Date_time_period = [];
   Free_text_Type[] Free_text = [];
   Control_total_Type[] Control_total = [];
   Group_1_GType[] group_1 = [];
   Group_2_GType[] group_2 = [];
   Group_3_GType[] group_3 = [];
   Group_4_GType[] group_4 = [];
|};

public type Syntax_identifier_GType record {|
   string syntax_id;
   string syntax_version;
   string service_code_list_directory_version?;
   string character_encoding?;
|};

public type Sender_GType record {|
   string id;
   string qualifier?;
   string internal_id?;
   string internal_sub_id?;
|};

public type Recipient_GType record {|
   string id;
   string qualifier?;
   string internal_id?;
   string internal_sub_id?;
|};

public type Date_and_time_GType record {|
   string date;
   string time;
|};

public type Recipient_reference_password_GType record {|
   string reference_password?;
   string qualifier?;
|};

public type Interchange_header_Type record {|
   string code = "UNB";
   Syntax_identifier_GType syntax_identifier;
   Sender_GType sender;
   Recipient_GType recipient;
   Date_and_time_GType date_and_time;
   string control_reference;
   Recipient_reference_password_GType? recipient_reference_password?;
   string application_reference?;
   string processing_priority_code?;
   string acknowledgement_request?;
   string communications_agreement_id?;
   string test_indicator?;
|};

public type APERAKInterchangeHeader record {|
   Interchange_header_Type interchange_header;
|};

public type Interchange_trailer_Type record {|
   string code = "UNZ";
   int interchange_control_count;
   string interchange_control_reference;
|};

public type APERAKInterchangeTrailer record {|
   Interchange_trailer_Type interchange_trailer;
|};

public type Message_identifier_GType record {|
   string message_type;
   string message_version_number;
   string message_release_number;
   string controlling_agency;
   string association_assigned_code?;
   string code_list_directory_version?;
   string message_type_sub_function?;
|};

public type Message_header_Type record {|
   string code = "UNH";
   string message_reference_number;
   Message_identifier_GType message_identifier;
|};

public type APERAKTransactionHeader record {|
   Message_header_Type Message_header;
|};

public type Message_trailer_Type record {|
   string code = "UNT";
   int number_of_segments;
   string message_reference_number;
|};

public type APERAKTransactionTrailer record {|
   Message_trailer_Type Message_trailer;
|};



# A single transaction within a APERAK interchange.
#
# + transactionHeader - Transaction header segment
# + body - Parsed APERAK body, or the parse error when the body is malformed
# + transactionTrailer - Transaction trailer segment
public type APERAKTransaction record {|
    APERAKTransactionHeader transactionHeader;
    APERAK|error body;
    APERAKTransactionTrailer transactionTrailer;
|};

# A parsed APERAK interchange with its full envelope hierarchy.
#
# + interchangeHeader - Interchange header segment
# + transactions - Transactions in the interchange
# + interchangeTrailer - Interchange trailer segment
public type APERAKInterchange record {|
    APERAKInterchangeHeader interchangeHeader;
    APERAKTransaction[] transactions;
    APERAKInterchangeTrailer interchangeTrailer;
|};

# Envelope headers of a APERAK interchange.
#
# + interchange - Interchange header
# + 'transaction - Transaction header
public type APERAKHeaders record {|
    APERAKInterchangeHeader interchange;
    APERAKTransactionHeader 'transaction;
|};


final readonly & json schemaJson = {"name":"APERAK", "ignoreSegments":["UNA"], "delimiters":{"segment":"'", "field":"+", "component":":", "repetition":"*", "decimalSeparator":","}, "envelope":{"interchange":{"header":[{"ref":"UNB", "tag":"interchange_header", "minOccurances":1, "maxOccurances":1}], "trailer":[{"ref":"UNZ", "tag":"interchange_trailer", "minOccurances":1, "maxOccurances":1}]}, "transaction":{"header":[{"ref":"UNH", "tag":"Message_header", "minOccurances":1, "maxOccurances":1}], "trailer":[{"ref":"UNT", "tag":"Message_trailer", "minOccurances":1, "maxOccurances":1}]}}, "segments":[{"ref":"BGM", "tag":"Beginning_of_message", "minOccurances":1, "maxOccurances":1}, {"ref":"DTM", "tag":"Date_time_period", "maxOccurances":9}, {"ref":"FTX", "tag":"Free_text", "maxOccurances":9}, {"ref":"CNT", "tag":"Control_total", "maxOccurances":9}, {"tag":"group_1", "maxOccurances":99, "segments":[{"ref":"DOC", "tag":"Document_message_details", "minOccurances":1, "maxOccurances":1}, {"ref":"DTM", "tag":"Date_time_period", "maxOccurances":99}]}, {"tag":"group_2", "maxOccurances":9, "segments":[{"ref":"RFF", "tag":"Reference", "minOccurances":1, "maxOccurances":1}, {"ref":"DTM", "tag":"Date_time_period", "maxOccurances":9}]}, {"tag":"group_3", "maxOccurances":9, "segments":[{"ref":"NAD", "tag":"Name_and_address", "minOccurances":1, "maxOccurances":1}, {"ref":"CTA", "tag":"Contact_information", "maxOccurances":9}, {"ref":"COM", "tag":"Communication_contact", "maxOccurances":9}]}, {"tag":"group_4", "maxOccurances":99999, "segments":[{"ref":"ERC", "tag":"Application_error_information", "minOccurances":1, "maxOccurances":1}, {"ref":"FTX", "tag":"Free_text", "maxOccurances":1}, {"tag":"group_5", "maxOccurances":9, "segments":[{"ref":"RFF", "tag":"Reference", "minOccurances":1, "maxOccurances":1}, {"ref":"FTX", "tag":"Free_text", "maxOccurances":9}]}]}], "segmentDefinitions":{"UNH":{"code":"UNH", "tag":"message_header", "fields":[{"tag":"code", "required":true, "repeat":false}, {"tag":"message_reference_number", "dataType":"string", "required":true, "repeat":false}, {"tag":"message_identifier", "dataType":"composite", "required":true, "repeat":false, "components":[{"tag":"message_type", "required":true, "dataType":"string"}, {"tag":"message_version_number", "required":true, "dataType":"string"}, {"tag":"message_release_number", "required":true, "dataType":"string"}, {"tag":"controlling_agency", "required":true, "dataType":"string"}, {"tag":"association_assigned_code", "required":false, "dataType":"string"}, {"tag":"code_list_directory_version", "required":false, "dataType":"string"}, {"tag":"message_type_sub_function", "required":false, "dataType":"string"}]}]}, "BGM":{"code":"BGM", "tag":"Beginning_of_message", "fields":[{"tag":"code", "required":true, "repeat":false}, {"tag":"DOCUMENT_MESSAGE_NAME", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Document_name_code", "required":false, "dataType":"string"}, {"tag":"Code_list_identification_code", "required":false, "dataType":"string"}, {"tag":"Code_list_responsible_agency_code", "required":false, "dataType":"string"}, {"tag":"Document_name", "required":false, "dataType":"string"}]}, {"tag":"DOCUMENT_MESSAGE_IDENTIFICATION", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Document_identifier", "required":false, "dataType":"string"}, {"tag":"Version_identifier", "required":false, "dataType":"string"}, {"tag":"Revision_identifier", "required":false, "dataType":"string"}]}, {"tag":"MESSAGE_FUNCTION_CODE", "dataType":"string", "required":false, "repeat":false, "components":[]}, {"tag":"RESPONSE_TYPE_CODE", "dataType":"string", "required":false, "repeat":false, "components":[]}]}, "DTM":{"code":"DTM", "tag":"Date_time_period", "fields":[{"tag":"code", "required":true, "repeat":false}, {"tag":"DATE_TIME_PERIOD", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Date_or_time_or_period", "required":false, "dataType":"string"}, {"tag":"Date_or_time_or_period_text", "required":false, "dataType":"string"}, {"tag":"Date_or_time_or_period_format_code", "required":false, "dataType":"string"}]}]}, "FTX":{"code":"FTX", "tag":"Free_text", "fields":[{"tag":"code", "required":true, "repeat":false}, {"tag":"TEXT_SUBJECT_CODE_QUALIFIER", "dataType":"string", "required":false, "repeat":false, "components":[]}, {"tag":"FREE_TEXT_FUNCTION_CODE", "dataType":"string", "required":false, "repeat":false, "components":[]}, {"tag":"TEXT_REFERENCE", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Free_text_description_code", "required":true, "dataType":"string"}, {"tag":"Code_list_identification_code", "required":false, "dataType":"string"}, {"tag":"Code_list_responsible_agency_code", "required":false, "dataType":"string"}]}, {"tag":"TEXT_LITERAL", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Free_text", "required":true, "dataType":"string"}, {"tag":"Free_text_1", "required":false, "dataType":"string"}, {"tag":"Free_text_2", "required":false, "dataType":"string"}, {"tag":"Free_text_3", "required":false, "dataType":"string"}, {"tag":"Free_text_4", "required":false, "dataType":"string"}]}, {"tag":"LANGUAGE_NAME_CODE", "dataType":"string", "required":false, "repeat":false, "components":[]}, {"tag":"FREE_TEXT_FORMAT_CODE", "dataType":"string", "required":false, "repeat":false, "components":[]}]}, "CNT":{"code":"CNT", "tag":"Control_total", "fields":[{"tag":"code", "required":true, "repeat":false}, {"tag":"CONTROL", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Control_total_type_code_qualifier", "required":true, "dataType":"string"}, {"tag":"Control_total_quantity", "required":true, "dataType":"int"}, {"tag":"Measurement_unit_code", "required":false, "dataType":"string"}]}]}, "DOC":{"code":"DOC", "tag":"Document_message_details", "fields":[{"tag":"code", "required":true, "repeat":false}, {"tag":"DOCUMENT_MESSAGE_NAME", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Document_name_code", "required":false, "dataType":"string"}, {"tag":"Code_list_identification_code", "required":false, "dataType":"string"}, {"tag":"Code_list_responsible_agency_code", "required":false, "dataType":"string"}, {"tag":"Document_name", "required":false, "dataType":"string"}]}, {"tag":"DOCUMENT_MESSAGE_DETAILS", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Document_identifier", "required":false, "dataType":"string"}, {"tag":"Document_status_code", "required":false, "dataType":"string"}, {"tag":"Document_source_description", "required":false, "dataType":"string"}, {"tag":"Language_name_code", "required":false, "dataType":"string"}, {"tag":"Version_identifier", "required":false, "dataType":"string"}, {"tag":"Revision_identifier", "required":false, "dataType":"string"}]}, {"tag":"COMMUNICATION_MEDIUM_TYPE_CODE", "dataType":"string", "required":false, "repeat":false, "components":[]}, {"tag":"DOCUMENT_COPIES_REQUIRED_QUANTITY", "dataType":"int", "required":false, "repeat":false, "components":[]}, {"tag":"DOCUMENT_ORIGINALS_REQUIRED_QUANTITY", "dataType":"int", "required":false, "repeat":false, "components":[]}]}, "RFF":{"code":"RFF", "tag":"Reference", "fields":[{"tag":"code", "required":true, "repeat":false}, {"tag":"REFERENCE", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Reference_code_qualifier", "required":true, "dataType":"string"}, {"tag":"Reference_identifier", "required":false, "dataType":"string"}, {"tag":"Document_line_identifier", "required":false, "dataType":"string"}, {"tag":"Reference_version_identifier", "required":false, "dataType":"string"}, {"tag":"Revision_identifier", "required":false, "dataType":"string"}]}]}, "NAD":{"code":"NAD", "tag":"Name_and_address", "fields":[{"tag":"code", "required":true, "repeat":false}, {"tag":"PARTY_FUNCTION_CODE_QUALIFIER", "dataType":"string", "required":false, "repeat":false, "components":[]}, {"tag":"PARTY_IDENTIFICATION_DETAILS", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Party_identifier", "required":true, "dataType":"string"}, {"tag":"Code_list_identification_code", "required":false, "dataType":"string"}, {"tag":"Code_list_responsible_agency_code", "required":false, "dataType":"string"}]}, {"tag":"NAME_AND_ADDRESS", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Name_and_address_description", "required":true, "dataType":"string"}, {"tag":"Name_and_address_description_1", "required":false, "dataType":"string"}, {"tag":"Name_and_address_description_2", "required":false, "dataType":"string"}, {"tag":"Name_and_address_description_3", "required":false, "dataType":"string"}, {"tag":"Name_and_address_description_4", "required":false, "dataType":"string"}]}, {"tag":"PARTY_NAME", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Party_name", "required":true, "dataType":"string"}, {"tag":"Party_name_1", "required":false, "dataType":"string"}, {"tag":"Party_name_2", "required":false, "dataType":"string"}, {"tag":"Party_name_3", "required":false, "dataType":"string"}, {"tag":"Party_name_4", "required":false, "dataType":"string"}, {"tag":"Party_name_format_code", "required":false, "dataType":"string"}]}, {"tag":"STREET", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Street_and_number_or_post_office_box_identifier", "required":true, "dataType":"string"}, {"tag":"Street_and_number_or_post_office_box_identifier_1", "required":false, "dataType":"string"}, {"tag":"Street_and_number_or_post_office_box_identifier_2", "required":false, "dataType":"string"}, {"tag":"Street_and_number_or_post_office_box_identifier_3", "required":false, "dataType":"string"}]}, {"tag":"CITY_NAME", "dataType":"string", "required":false, "repeat":false, "components":[]}, {"tag":"COUNTRY_SUB_ENTITY_DETAILS", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Country_sub_entity_name_code", "required":false, "dataType":"string"}, {"tag":"Code_list_identification_code", "required":false, "dataType":"string"}, {"tag":"Code_list_responsible_agency_code", "required":false, "dataType":"string"}, {"tag":"Country_sub_entity_name", "required":false, "dataType":"string"}]}, {"tag":"POSTAL_IDENTIFICATION_CODE", "dataType":"string", "required":false, "repeat":false, "components":[]}, {"tag":"COUNTRY_NAME_CODE", "dataType":"string", "required":false, "repeat":false, "components":[]}]}, "CTA":{"code":"CTA", "tag":"Contact_information", "fields":[{"tag":"code", "required":true, "repeat":false}, {"tag":"CONTACT_FUNCTION_CODE", "dataType":"string", "required":false, "repeat":false, "components":[]}, {"tag":"DEPARTMENT_OR_EMPLOYEE_DETAILS", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Department_or_employee_name_code", "required":false, "dataType":"string"}, {"tag":"Department_or_employee_name", "required":false, "dataType":"string"}]}]}, "COM":{"code":"COM", "tag":"Communication_contact", "fields":[{"tag":"code", "required":true, "repeat":false}, {"tag":"COMMUNICATION_CONTACT", "dataType":"composite", "required":false, "repeat":true, "components":[{"tag":"Communication_address_identifier", "required":true, "dataType":"string"}, {"tag":"Communication_address_code_qualifier", "required":true, "dataType":"string"}]}]}, "ERC":{"code":"ERC", "tag":"Application_error_information", "fields":[{"tag":"code", "required":true, "repeat":false}, {"tag":"APPLICATION_ERROR_DETAIL", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Application_error_code", "required":true, "dataType":"string"}, {"tag":"Code_list_identification_code", "required":false, "dataType":"string"}, {"tag":"Code_list_responsible_agency_code", "required":false, "dataType":"string"}]}]}, "UNT":{"code":"UNT", "tag":"message_trailer", "fields":[{"tag":"code", "required":true, "repeat":false}, {"tag":"number_of_segments", "dataType":"int", "required":true, "repeat":false}, {"tag":"message_reference_number", "dataType":"string", "required":true, "repeat":false}]}, "UNB":{"code":"UNB", "tag":"interchange_header", "fields":[{"tag":"code", "required":true, "repeat":false}, {"tag":"syntax_identifier", "dataType":"composite", "required":true, "repeat":false, "components":[{"tag":"syntax_id", "required":true, "dataType":"string"}, {"tag":"syntax_version", "required":true, "dataType":"string"}, {"tag":"service_code_list_directory_version", "required":false, "dataType":"string"}, {"tag":"character_encoding", "required":false, "dataType":"string"}]}, {"tag":"sender", "dataType":"composite", "required":true, "repeat":false, "components":[{"tag":"id", "required":true, "dataType":"string"}, {"tag":"qualifier", "required":false, "dataType":"string"}, {"tag":"internal_id", "required":false, "dataType":"string"}, {"tag":"internal_sub_id", "required":false, "dataType":"string"}]}, {"tag":"recipient", "dataType":"composite", "required":true, "repeat":false, "components":[{"tag":"id", "required":true, "dataType":"string"}, {"tag":"qualifier", "required":false, "dataType":"string"}, {"tag":"internal_id", "required":false, "dataType":"string"}, {"tag":"internal_sub_id", "required":false, "dataType":"string"}]}, {"tag":"date_and_time", "dataType":"composite", "required":true, "repeat":false, "components":[{"tag":"date", "required":true, "dataType":"string"}, {"tag":"time", "required":true, "dataType":"string"}]}, {"tag":"control_reference", "dataType":"string", "required":true, "repeat":false}, {"tag":"recipient_reference_password", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"reference_password", "required":false, "dataType":"string"}, {"tag":"qualifier", "required":false, "dataType":"string"}]}, {"tag":"application_reference", "dataType":"string", "required":false, "repeat":false}, {"tag":"processing_priority_code", "dataType":"string", "required":false, "repeat":false}, {"tag":"acknowledgement_request", "dataType":"string", "required":false, "repeat":false}, {"tag":"communications_agreement_id", "dataType":"string", "required":false, "repeat":false}, {"tag":"test_indicator", "dataType":"string", "required":false, "repeat":false}]}, "UNZ":{"code":"UNZ", "tag":"interchange_trailer", "fields":[{"tag":"code", "required":true, "repeat":false}, {"tag":"interchange_control_count", "dataType":"int", "required":true, "repeat":false}, {"tag":"interchange_control_reference", "dataType":"string", "required":true, "repeat":false}]}}};
    