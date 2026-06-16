
import ballerina/edi;

# Convert EDI string to Ballerina ORDERS record.
#
# + ediText - EDI string to be converted
# + return - Ballerina record or error
public isolated function fromEdiString(string ediText) returns ORDERS|error {
    edi:EdiSchema ediSchema = check edi:getSchema(schemaJson);
    json dataJson = check edi:fromEdiString(ediText, ediSchema);
    return dataJson.cloneWithType();
}

# Convert Ballerina ORDERS record to EDI string.
#
# + data - Ballerina record to be converted
# + return - EDI string or error
public isolated function toEdiString(ORDERS data) returns string|error {
    edi:EdiSchema ediSchema = check edi:getSchema(schemaJson);
    return edi:toEdiString(data, ediSchema);
}

# Get the EDI schema.
#
# + return - EDI schema or error
public isolated function getSchema() returns edi:EdiSchema|error {
    return edi:getSchema(schemaJson);
}

# Convert EDI string to Ballerina ORDERS record with schema.
#
# + ediText - EDI string to be converted
# + schema - EDI schema
# + return - Ballerina record or error
public isolated function fromEdiStringWithSchema(string ediText, edi:EdiSchema schema) returns ORDERS|error {
    json dataJson = check edi:fromEdiString(ediText, schema);
    return dataJson.cloneWithType();
}

# Convert Ballerina ORDERS record to EDI string with schema.
#
# + data - Ballerina record to be converted
# + ediSchema - EDI schema
# + return - EDI string or error
public isolated function toEdiStringWithSchema(ORDERS data, edi:EdiSchema ediSchema) returns string|error {
    return edi:toEdiString(data, ediSchema);
}


# Parse only the envelope header segments from the given EDI string.
#
# + ediText - EDI string to parse
# + return - Parsed ORDERSHeaders record, or error if the headers are malformed
public isolated function headersFromEdiString(string ediText) returns ORDERSHeaders|error {
    edi:EdiSchema ediSchema = check edi:getSchema(schemaJson);
    json raw = check edi:headersFromEdiString(ediText, ediSchema);
    return raw.cloneWithType();
}

# Parse the full envelope hierarchy from the given EDI string.
# Envelope headers and trailers are fail-fast; transaction body is fail-safe —
# a malformed body becomes an error in that transaction's body field
# without aborting the rest of the interchange.
#
# + ediText - EDI string to parse
# + return - Parsed ORDERSInterchange, or error if the envelope is malformed
public isolated function interchangeFromEdiString(string ediText) returns ORDERSInterchange|error {
    edi:EdiSchema ediSchema = check edi:getSchema(schemaJson);
    edi:EdiInterchange raw = check edi:interchangeFromEdiString(ediText, ediSchema);
    ORDERSTransaction[] txns = [];
        foreach var t in raw.transactions ?: [] {
            ORDERS|error body = convertORDERSBody(t.body);
            ORDERSTransactionHeader th = check t.transactionHeader.cloneWithType();
            ORDERSTransactionTrailer tt = check t.transactionTrailer.cloneWithType();
            txns.push({transactionHeader: th, body, transactionTrailer: tt});
        }
        ORDERSInterchangeHeader ih = check raw.interchangeHeader.cloneWithType();
        ORDERSInterchangeTrailer it = check raw.interchangeTrailer.cloneWithType();
        return {interchangeHeader: ih, transactions: txns, interchangeTrailer: it};
}

# Serialise a fully populated ORDERSInterchange into EDI text. Inverse of
# interchangeFromEdiString. A transaction whose body is an error cannot
# be serialised — filter or replace such transactions before calling.
#
# + msg - The interchange to serialise
# + return - EDI text, or error
public isolated function interchangeToEdiString(ORDERSInterchange msg) returns string|error {
    edi:EdiSchema ediSchema = check edi:getSchema(schemaJson);
    edi:EdiInterchange raw;
    {
        edi:EdiTransaction[] rawTxns = [];
        foreach var t in msg.transactions {
            json|error body = unwrapORDERSBody(t.body);
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


isolated function convertORDERSBody(json|error raw) returns ORDERS|error {
    if raw is error {
        return raw;
    }
    return raw.cloneWithType();
}

isolated function unwrapORDERSBody(ORDERS|error typed) returns json|error {
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

public type PAYMENT_INSTRUCTION_DETAILS_GType record {|
   string Payment_conditions_code?;
   string Payment_guarantee_means_code?;
   string Payment_means_code?;
   string Code_list_identification_code?;
   string Code_list_responsible_agency_code?;
   string Payment_channel_code?;
|};

public type Payment_instructions_Type record {|
   string code = "PAI";
   PAYMENT_INSTRUCTION_DETAILS_GType? PAYMENT_INSTRUCTION_DETAILS?;
|};

public type Additional_information_Type record {|
   string code = "ALI";
   string COUNTRY_OF_ORIGIN_NAME_CODE?;
   string DUTY_REGIME_TYPE_CODE?;
   string SPECIAL_CONDITION_CODE?;
   string SPECIAL_CONDITION_CODE_3?;
   string SPECIAL_CONDITION_CODE_4?;
   string SPECIAL_CONDITION_CODE_5?;
   string SPECIAL_CONDITION_CODE_6?;
|};

public type ITEM_CHARACTERISTIC_GType record {|
   string Item_characteristic_code?;
   string Code_list_identification_code?;
   string Code_list_responsible_agency_code?;
|};

public type ITEM_DESCRIPTION_GType record {|
   string Item_description_code?;
   string Code_list_identification_code?;
   string Code_list_responsible_agency_code?;
   string Item_description?;
   string Item_description_4?;
   string Language_name_code?;
|};

public type Item_description_Type record {|
   string code = "IMD";
   string DESCRIPTION_FORMAT_CODE?;
   ITEM_CHARACTERISTIC_GType? ITEM_CHARACTERISTIC?;
   ITEM_DESCRIPTION_GType? ITEM_DESCRIPTION?;
   string SURFACE_OR_LAYER_CODE?;
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

public type IDENTIFICATION_NUMBER_GType record {|
   string Object_identifier;
   string Object_identification_code_qualifier?;
   string Status_description_code?;
|};

public type IDENTIFICATION_NUMBER_2_GType record {|
   string Object_identifier;
   string Object_identification_code_qualifier?;
   string Status_description_code?;
|};

public type IDENTIFICATION_NUMBER_3_GType record {|
   string Object_identifier;
   string Object_identification_code_qualifier?;
   string Status_description_code?;
|};

public type IDENTIFICATION_NUMBER_4_GType record {|
   string Object_identifier;
   string Object_identification_code_qualifier?;
   string Status_description_code?;
|};

public type IDENTIFICATION_NUMBER_5_GType record {|
   string Object_identifier;
   string Object_identification_code_qualifier?;
   string Status_description_code?;
|};

public type Related_identification_numbers_Type record {|
   string code = "GIR";
   string SET_TYPE_CODE_QUALIFIER?;
   IDENTIFICATION_NUMBER_GType? IDENTIFICATION_NUMBER?;
   IDENTIFICATION_NUMBER_2_GType? IDENTIFICATION_NUMBER_2?;
   IDENTIFICATION_NUMBER_3_GType? IDENTIFICATION_NUMBER_3?;
   IDENTIFICATION_NUMBER_4_GType? IDENTIFICATION_NUMBER_4?;
   IDENTIFICATION_NUMBER_5_GType? IDENTIFICATION_NUMBER_5?;
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

public type Group_1_GType record {|
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

public type LOCATION_IDENTIFICATION_GType record {|
   string Location_name_code?;
   string Code_list_identification_code?;
   string Code_list_responsible_agency_code?;
   string Location_name?;
|};

public type RELATED_LOCATION_ONE_IDENTIFICATION_GType record {|
   string First_related_location_name_code?;
   string Code_list_identification_code?;
   string Code_list_responsible_agency_code?;
   string First_related_location_name?;
|};

public type RELATED_LOCATION_TWO_IDENTIFICATION_GType record {|
   string Second_related_location_name_code?;
   string Code_list_identification_code?;
   string Code_list_responsible_agency_code?;
   string Second_related_location_name?;
|};

public type Place_location_identification_Type record {|
   string code = "LOC";
   string LOCATION_FUNCTION_CODE_QUALIFIER?;
   LOCATION_IDENTIFICATION_GType? LOCATION_IDENTIFICATION?;
   RELATED_LOCATION_ONE_IDENTIFICATION_GType? RELATED_LOCATION_ONE_IDENTIFICATION?;
   RELATED_LOCATION_TWO_IDENTIFICATION_GType? RELATED_LOCATION_TWO_IDENTIFICATION?;
   string RELATION_CODE?;
|};

public type ACCOUNT_HOLDER_IDENTIFICATION_GType record {|
   string Account_holder_identifier?;
   string Account_holder_name?;
   string Account_holder_name_2?;
   string Currency_identification_code?;
|};

public type INSTITUTION_IDENTIFICATION_GType record {|
   string Institution_name_code?;
   string Code_list_identification_code?;
   string Code_list_responsible_agency_code?;
   string Institution_branch_identifier?;
   string Code_list_identification_code_4?;
   string Code_list_responsible_agency_code_5?;
   string Institution_name?;
   string Institution_branch_location_name?;
|};

public type Financial_institution_information_Type record {|
   string code = "FII";
   string PARTY_FUNCTION_CODE_QUALIFIER?;
   ACCOUNT_HOLDER_IDENTIFICATION_GType? ACCOUNT_HOLDER_IDENTIFICATION?;
   INSTITUTION_IDENTIFICATION_GType? INSTITUTION_IDENTIFICATION?;
   string COUNTRY_NAME_CODE?;
|};

public type Group_3_GType record {|
   Reference_Type Reference;
   Date_time_period_Type[] Date_time_period = [];
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

public type Group_4_GType record {|
   Document_message_details_Type Document_message_details;
   Date_time_period_Type[] Date_time_period = [];
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

public type Group_5_GType record {|
   Contact_information_Type Contact_information;
   Communication_contact_Type[] Communication_contact = [];
|};

public type Group_2_GType record {|
   Name_and_address_Type Name_and_address;
   Place_location_identification_Type[] Place_location_identification = [];
   Financial_institution_information_Type[] Financial_institution_information = [];
   Group_3_GType[] group_3 = [];
   Group_4_GType[] group_4 = [];
   Group_5_GType[] group_5 = [];
|};

public type DUTY_TAX_FEE_TYPE_GType record {|
   string Duty_or_tax_or_fee_type_name_code?;
   string Code_list_identification_code?;
   string Code_list_responsible_agency_code?;
   string Duty_or_tax_or_fee_type_name?;
|};

public type DUTY_TAX_FEE_ACCOUNT_DETAIL_GType record {|
   string Duty_or_tax_or_fee_account_code;
   string Code_list_identification_code?;
   string Code_list_responsible_agency_code?;
|};

public type DUTY_TAX_FEE_DETAIL_GType record {|
   string Duty_or_tax_or_fee_rate_code?;
   string Code_list_identification_code?;
   string Code_list_responsible_agency_code?;
   string Duty_or_tax_or_fee_rate?;
   string Duty_or_tax_or_fee_rate_basis_code?;
   string Code_list_identification_code_5?;
   string Code_list_responsible_agency_code_6?;
|};

public type Duty_tax_fee_details_Type record {|
   string code = "TAX";
   string DUTY_OR_TAX_OR_FEE_FUNCTION_CODE_QUALIFIER?;
   DUTY_TAX_FEE_TYPE_GType? DUTY_TAX_FEE_TYPE?;
   DUTY_TAX_FEE_ACCOUNT_DETAIL_GType? DUTY_TAX_FEE_ACCOUNT_DETAIL?;
   DUTY_TAX_FEE_DETAIL_GType? DUTY_TAX_FEE_DETAIL?;
   string DUTY_OR_TAX_OR_FEE_CATEGORY_CODE?;
   string PARTY_TAX_IDENTIFIER?;
   string CALCULATION_SEQUENCE_CODE?;
|};

public type MONETARY_AMOUNT_GType record {|
   string Monetary_amount_type_code_qualifier;
   int? Monetary_amount?;
   string Currency_identification_code?;
   string Currency_type_code_qualifier?;
   string Status_description_code?;
|};

public type Monetary_amount_Type record {|
   string code = "MOA";
   MONETARY_AMOUNT_GType? MONETARY_AMOUNT?;
|};

public type Group_6_GType record {|
   Duty_tax_fee_details_Type Duty_tax_fee_details;
   Monetary_amount_Type? Monetary_amount?;
   Place_location_identification_Type[] Place_location_identification = [];
|};

public type CURRENCY_DETAILS_GType record {|
   string Currency_usage_code_qualifier;
   string Currency_identification_code?;
   string Currency_type_code_qualifier?;
   int? Currency_rate?;
|};

public type CURRENCY_DETAILS_1_GType record {|
   string Currency_usage_code_qualifier;
   string Currency_identification_code?;
   string Currency_type_code_qualifier?;
   int? Currency_rate?;
|};

public type Currencies_Type record {|
   string code = "CUX";
   CURRENCY_DETAILS_GType? CURRENCY_DETAILS?;
   CURRENCY_DETAILS_1_GType? CURRENCY_DETAILS_1?;
   int? CURRENCY_EXCHANGE_RATE?;
   string EXCHANGE_RATE_CURRENCY_MARKET_IDENTIFIER?;
|};

public type PERCENTAGE_DETAILS_GType record {|
   string Percentage_type_code_qualifier;
   int? Percentage?;
   string Percentage_basis_identification_code?;
   string Code_list_identification_code?;
   string Code_list_responsible_agency_code?;
|};

public type Percentage_details_Type record {|
   string code = "PCD";
   PERCENTAGE_DETAILS_GType? PERCENTAGE_DETAILS?;
   string STATUS_DESCRIPTION_CODE?;
|};

public type Group_7_GType record {|
   Currencies_Type Currencies;
   Percentage_details_Type[] Percentage_details = [];
   Date_time_period_Type[] Date_time_period = [];
|};

public type PAYMENT_TERMS_GType record {|
   string Payment_terms_description_identifier?;
   string Code_list_identification_code?;
   string Code_list_responsible_agency_code?;
   string Payment_terms_description?;
|};

public type Payment_terms_Type record {|
   string code = "PYT";
   string PAYMENT_TERMS_TYPE_CODE_QUALIFIER?;
   PAYMENT_TERMS_GType? PAYMENT_TERMS?;
   string TIME_REFERENCE_CODE?;
   string TERMS_TIME_RELATION_CODE?;
   string PERIOD_TYPE_CODE?;
   int? PERIOD_COUNT_QUANTITY?;
|};

public type ACCOUNTING_JOURNAL_IDENTIFICATION_GType record {|
   string Accounting_journal_identifier;
   string Code_list_identification_code?;
   string Code_list_responsible_agency_code?;
   string Accounting_journal_name?;
|};

public type ACCOUNTING_ENTRY_TYPE_DETAILS_GType record {|
   string Accounting_entry_type_name_code;
   string Code_list_identification_code?;
   string Code_list_responsible_agency_code?;
   string Accounting_entry_type_name?;
|};

public type Accounting_journal_identification_Type record {|
   string code = "RJL";
   ACCOUNTING_JOURNAL_IDENTIFICATION_GType? ACCOUNTING_JOURNAL_IDENTIFICATION?;
   ACCOUNTING_ENTRY_TYPE_DETAILS_GType? ACCOUNTING_ENTRY_TYPE_DETAILS?;
|};

public type Group_9_GType record {|
   Monetary_amount_Type Monetary_amount;
   Related_identification_numbers_Type[] Related_identification_numbers = [];
   Accounting_journal_identification_Type[] Accounting_journal_identification = [];
|};

public type Group_8_GType record {|
   Payment_terms_Type Payment_terms;
   Date_time_period_Type[] Date_time_period = [];
   Percentage_details_Type? Percentage_details?;
   Group_9_GType[] group_9 = [];
|};

public type MODE_OF_TRANSPORT_GType record {|
   string Transport_mode_name_code?;
   string Transport_mode_name?;
|};

public type TRANSPORT_MEANS_GType record {|
   string Transport_means_description_code?;
   string Code_list_identification_code?;
   string Code_list_responsible_agency_code?;
   string Transport_means_description?;
|};

public type CARRIER_GType record {|
   string Carrier_identifier?;
   string Code_list_identification_code?;
   string Code_list_responsible_agency_code?;
   string Carrier_name?;
|};

public type EXCESS_TRANSPORTATION_INFORMATION_GType record {|
   string Excess_transportation_reason_code;
   string Excess_transportation_responsibility_code;
   string Customer_shipment_authorisation_identifier?;
|};

public type TRANSPORT_IDENTIFICATION_GType record {|
   string Transport_means_identification_name_identifier?;
   string Code_list_identification_code?;
   string Code_list_responsible_agency_code?;
   string Transport_means_identification_name?;
   string Transport_means_nationality_code?;
|};

public type Transport_information_Type record {|
   string code = "TDT";
   string TRANSPORT_STAGE_CODE_QUALIFIER?;
   string MEANS_OF_TRANSPORT_JOURNEY_IDENTIFIER?;
   MODE_OF_TRANSPORT_GType? MODE_OF_TRANSPORT?;
   TRANSPORT_MEANS_GType? TRANSPORT_MEANS?;
   CARRIER_GType? CARRIER?;
   string TRANSIT_DIRECTION_INDICATOR_CODE?;
   EXCESS_TRANSPORTATION_INFORMATION_GType? EXCESS_TRANSPORTATION_INFORMATION?;
   TRANSPORT_IDENTIFICATION_GType? TRANSPORT_IDENTIFICATION?;
   string TRANSPORT_MEANS_OWNERSHIP_INDICATOR_CODE?;
|};

public type Group_11_GType record {|
   Place_location_identification_Type Place_location_identification;
   Date_time_period_Type[] Date_time_period = [];
|};

public type Group_10_GType record {|
   Transport_information_Type Transport_information;
   Group_11_GType[] group_11 = [];
|};

public type TERMS_OF_DELIVERY_OR_TRANSPORT_GType record {|
   string Delivery_or_transport_terms_description_code?;
   string Code_list_identification_code?;
   string Code_list_responsible_agency_code?;
   string Delivery_or_transport_terms_description?;
   string Delivery_or_transport_terms_description_4?;
|};

public type Terms_of_delivery_or_transport_Type record {|
   string code = "TOD";
   string DELIVERY_OR_TRANSPORT_TERMS_FUNCTION_CODE?;
   string TRANSPORT_CHARGES_PAYMENT_METHOD_CODE?;
   TERMS_OF_DELIVERY_OR_TRANSPORT_GType? TERMS_OF_DELIVERY_OR_TRANSPORT?;
|};

public type Group_12_GType record {|
   Terms_of_delivery_or_transport_Type Terms_of_delivery_or_transport;
   Place_location_identification_Type[] Place_location_identification = [];
|};

public type PACKAGING_DETAILS_GType record {|
   string Packaging_level_code?;
   string Packaging_related_description_code?;
   string Packaging_terms_and_conditions_code?;
|};

public type PACKAGE_TYPE_GType record {|
   string Package_type_description_code?;
   string Code_list_identification_code?;
   string Code_list_responsible_agency_code?;
   string Type_of_packages?;
|};

public type PACKAGE_TYPE_IDENTIFICATION_GType record {|
   string Description_format_code;
   string Type_of_packages;
   string Item_type_identification_code?;
   string Type_of_packages_3?;
   string Item_type_identification_code_4?;
|};

public type RETURNABLE_PACKAGE_DETAILS_GType record {|
   string Returnable_package_freight_payment_responsibility_code?;
   string Returnable_package_load_contents_code?;
|};

public type Package_Type record {|
   string code = "PAC";
   int? PACKAGE_QUANTITY?;
   PACKAGING_DETAILS_GType? PACKAGING_DETAILS?;
   PACKAGE_TYPE_GType? PACKAGE_TYPE?;
   PACKAGE_TYPE_IDENTIFICATION_GType? PACKAGE_TYPE_IDENTIFICATION?;
   RETURNABLE_PACKAGE_DETAILS_GType? RETURNABLE_PACKAGE_DETAILS?;
|};

public type MEASUREMENT_DETAILS_GType record {|
   string Measured_attribute_code?;
   string Measurement_significance_code?;
   string Non_discrete_measurement_name_code?;
   string Non_discrete_measurement_name?;
|};

public type VALUE_RANGE_GType record {|
   string Measurement_unit_code;
   string Measure?;
   int? Range_minimum_quantity?;
   int? Range_maximum_quantity?;
   int? Significant_digits_quantity?;
|};

public type Measurements_Type record {|
   string code = "MEA";
   string MEASUREMENT_PURPOSE_CODE_QUALIFIER?;
   MEASUREMENT_DETAILS_GType? MEASUREMENT_DETAILS?;
   VALUE_RANGE_GType? VALUE_RANGE?;
   string SURFACE_OR_LAYER_CODE?;
|};

public type MARKS___LABELS_GType record {|
   string Shipping_marks_description;
   string Shipping_marks_description_1?;
   string Shipping_marks_description_2?;
   string Shipping_marks_description_3?;
   string Shipping_marks_description_4?;
   string Shipping_marks_description_5?;
   string Shipping_marks_description_6?;
   string Shipping_marks_description_7?;
   string Shipping_marks_description_8?;
   string Shipping_marks_description_9?;
|};

public type TYPE_OF_MARKING_GType record {|
   string Marking_type_code;
   string Code_list_identification_code?;
   string Code_list_responsible_agency_code?;
|};

public type Package_identification_Type record {|
   string code = "PCI";
   string MARKING_INSTRUCTIONS_CODE?;
   MARKS___LABELS_GType? MARKS___LABELS?;
   TYPE_OF_MARKING_GType? TYPE_OF_MARKING?;
|};

public type IDENTITY_NUMBER_RANGE_GType record {|
   string Object_identifier;
   string Object_identifier_1?;
|};

public type IDENTITY_NUMBER_RANGE_2_GType record {|
   string Object_identifier;
   string Object_identifier_1?;
|};

public type IDENTITY_NUMBER_RANGE_3_GType record {|
   string Object_identifier;
   string Object_identifier_1?;
|};

public type IDENTITY_NUMBER_RANGE_4_GType record {|
   string Object_identifier;
   string Object_identifier_1?;
|};

public type IDENTITY_NUMBER_RANGE_5_GType record {|
   string Object_identifier;
   string Object_identifier_1?;
|};

public type Goods_identity_number_Type record {|
   string code = "GIN";
   string OBJECT_IDENTIFICATION_CODE_QUALIFIER?;
   IDENTITY_NUMBER_RANGE_GType? IDENTITY_NUMBER_RANGE?;
   IDENTITY_NUMBER_RANGE_2_GType? IDENTITY_NUMBER_RANGE_2?;
   IDENTITY_NUMBER_RANGE_3_GType? IDENTITY_NUMBER_RANGE_3?;
   IDENTITY_NUMBER_RANGE_4_GType? IDENTITY_NUMBER_RANGE_4?;
   IDENTITY_NUMBER_RANGE_5_GType? IDENTITY_NUMBER_RANGE_5?;
|};

public type Group_14_GType record {|
   Package_identification_Type Package_identification;
   Reference_Type? Reference?;
   Date_time_period_Type[] Date_time_period = [];
   Goods_identity_number_Type[] Goods_identity_number = [];
|};

public type Group_13_GType record {|
   Package_Type Package;
   Measurements_Type[] Measurements = [];
   Group_14_GType[] group_14 = [];
|};

public type EQUIPMENT_IDENTIFICATION_GType record {|
   string Equipment_identifier?;
   string Code_list_identification_code?;
   string Code_list_responsible_agency_code?;
   string Country_name_code?;
|};

public type EQUIPMENT_SIZE_AND_TYPE_GType record {|
   string Equipment_size_and_type_description_code?;
   string Code_list_identification_code?;
   string Code_list_responsible_agency_code?;
   string Equipment_size_and_type_description?;
|};

public type Equipment_details_Type record {|
   string code = "EQD";
   string EQUIPMENT_TYPE_CODE_QUALIFIER?;
   EQUIPMENT_IDENTIFICATION_GType? EQUIPMENT_IDENTIFICATION?;
   EQUIPMENT_SIZE_AND_TYPE_GType? EQUIPMENT_SIZE_AND_TYPE?;
   string EQUIPMENT_SUPPLIER_CODE?;
   string EQUIPMENT_STATUS_CODE?;
   string FULL_OR_EMPTY_INDICATOR_CODE?;
|};

public type HANDLING_INSTRUCTIONS_GType record {|
   string Handling_instruction_description_code?;
   string Code_list_identification_code?;
   string Code_list_responsible_agency_code?;
   string Handling_instruction_description?;
|};

public type HAZARDOUS_MATERIAL_GType record {|
   string Hazardous_material_category_name_code?;
   string Code_list_identification_code?;
   string Code_list_responsible_agency_code?;
   string Hazardous_material_category_name?;
|};

public type Handling_instructions_Type record {|
   string code = "HAN";
   HANDLING_INSTRUCTIONS_GType? HANDLING_INSTRUCTIONS?;
   HAZARDOUS_MATERIAL_GType? HAZARDOUS_MATERIAL?;
|};

public type Group_15_GType record {|
   Equipment_details_Type Equipment_details;
   Handling_instructions_Type[] Handling_instructions = [];
   Measurements_Type[] Measurements = [];
   Free_text_Type[] Free_text = [];
|};

public type PATTERN_DESCRIPTION_GType record {|
   string Frequency_code?;
   string Despatch_pattern_code?;
   string Despatch_pattern_timing_code?;
|};

public type Scheduling_conditions_Type record {|
   string code = "SCC";
   string DELIVERY_PLAN_COMMITMENT_LEVEL_CODE?;
   string DELIVERY_INSTRUCTION_CODE?;
   PATTERN_DESCRIPTION_GType? PATTERN_DESCRIPTION?;
|};

public type QUANTITY_DETAILS_GType record {|
   string Quantity_type_code_qualifier;
   string Quantity;
   string Measurement_unit_code?;
|};

public type Quantity_Type record {|
   string code = "QTY";
   QUANTITY_DETAILS_GType? QUANTITY_DETAILS?;
|};

public type Group_17_GType record {|
   Quantity_Type Quantity;
   Date_time_period_Type[] Date_time_period = [];
|};

public type Group_16_GType record {|
   Scheduling_conditions_Type Scheduling_conditions;
   Free_text_Type[] Free_text = [];
   Reference_Type[] Reference = [];
   Group_17_GType[] group_17 = [];
|};

public type PRICE_MULTIPLIER_INFORMATION_GType record {|
   int Price_multiplier_rate;
   string Price_multiplier_type_code_qualifier?;
|};

public type REASON_FOR_CHANGE_GType record {|
   string Change_reason_description_code?;
   string Code_list_identification_code?;
   string Code_list_responsible_agency_code?;
   string Change_reason_description?;
|};

public type Additional_price_information_Type record {|
   string code = "APR";
   string TRADE_CLASS_CODE?;
   PRICE_MULTIPLIER_INFORMATION_GType? PRICE_MULTIPLIER_INFORMATION?;
   REASON_FOR_CHANGE_GType? REASON_FOR_CHANGE?;
|};

public type RANGE_GType record {|
   string Measurement_unit_code;
   int? Range_minimum_quantity?;
   int? Range_maximum_quantity?;
|};

public type Range_details_Type record {|
   string code = "RNG";
   string RANGE_TYPE_CODE_QUALIFIER?;
   RANGE_GType? RANGE?;
|};

public type Group_18_GType record {|
   Additional_price_information_Type Additional_price_information;
   Date_time_period_Type[] Date_time_period = [];
   Range_details_Type? Range_details?;
|};

public type ALLOWANCE_CHARGE_INFORMATION_GType record {|
   string Allowance_or_charge_identifier?;
   string Allowance_or_charge_identification_code?;
|};

public type SPECIAL_SERVICES_IDENTIFICATION_GType record {|
   string Special_service_description_code?;
   string Code_list_identification_code?;
   string Code_list_responsible_agency_code?;
   string Special_service_description?;
   string Special_service_description_4?;
|};

public type Allowance_or_charge_Type record {|
   string code = "ALC";
   string ALLOWANCE_OR_CHARGE_CODE_QUALIFIER?;
   ALLOWANCE_CHARGE_INFORMATION_GType? ALLOWANCE_CHARGE_INFORMATION?;
   string SETTLEMENT_MEANS_CODE?;
   string CALCULATION_SEQUENCE_CODE?;
   SPECIAL_SERVICES_IDENTIFICATION_GType? SPECIAL_SERVICES_IDENTIFICATION?;
|};

public type Group_20_GType record {|
   Quantity_Type Quantity;
   Range_details_Type? Range_details?;
|};

public type Group_21_GType record {|
   Percentage_details_Type Percentage_details;
   Range_details_Type? Range_details?;
|};

public type Group_22_GType record {|
   Monetary_amount_Type Monetary_amount;
   Range_details_Type? Range_details?;
|};

public type RATE_DETAILS_GType record {|
   string Rate_type_code_qualifier;
   int Unit_price_basis_rate;
   int? Unit_price_basis_quantity?;
   string Measurement_unit_code?;
|};

public type Rate_details_Type record {|
   string code = "RTE";
   RATE_DETAILS_GType? RATE_DETAILS?;
   string STATUS_DESCRIPTION_CODE?;
|};

public type Group_23_GType record {|
   Rate_details_Type Rate_details;
   Range_details_Type? Range_details?;
|};

public type Group_24_GType record {|
   Duty_tax_fee_details_Type Duty_tax_fee_details;
   Monetary_amount_Type? Monetary_amount?;
|};

public type Group_19_GType record {|
   Allowance_or_charge_Type Allowance_or_charge;
   Additional_information_Type[] Additional_information = [];
   Date_time_period_Type[] Date_time_period = [];
   Group_20_GType? group_20?;
   Group_21_GType? group_21?;
   Group_22_GType[] group_22 = [];
   Group_23_GType? group_23?;
   Group_24_GType[] group_24 = [];
|};

public type REQUIREMENT_CONDITION_IDENTIFICATION_GType record {|
   string Requirement_or_condition_description_identifier;
   string Code_list_identification_code?;
   string Code_list_responsible_agency_code?;
   string Requirement_or_condition_description?;
|};

public type Requirements_and_conditions_Type record {|
   string code = "RCS";
   string SECTOR_AREA_IDENTIFICATION_CODE_QUALIFIER?;
   REQUIREMENT_CONDITION_IDENTIFICATION_GType? REQUIREMENT_CONDITION_IDENTIFICATION?;
   string COUNTRY_NAME_CODE?;
|};

public type Group_25_GType record {|
   Requirements_and_conditions_Type Requirements_and_conditions;
   Reference_Type[] Reference = [];
   Date_time_period_Type[] Date_time_period = [];
   Free_text_Type[] Free_text = [];
|};

public type HAZARD_CODE_GType record {|
   string Hazard_identification_code;
   string Additional_hazard_classification_identifier?;
   string Hazard_code_version_identifier?;
|};

public type UNDG_INFORMATION_GType record {|
   string Dangerous_goods_flashpoint_description?;
|};

public type DANGEROUS_GOODS_SHIPMENT_FLASHPOINT_GType record {|
   string Shipment_flashpoint_degree?;
   string Measurement_unit_code?;
|};

public type HAZARD_IDENTIFICATION_PLACARD_DETAILS_GType record {|
   string Orange_hazard_placard_upper_part_identifier?;
   string Orange_hazard_placard_lower_part_identifier?;
|};

public type DANGEROUS_GOODS_LABEL_GType record {|
   string Dangerous_goods_marking_identifier?;
   string Dangerous_goods_marking_identifier_1?;
   string Dangerous_goods_marking_identifier_2?;
|};

public type Dangerous_goods_Type record {|
   string code = "DGS";
   string DANGEROUS_GOODS_REGULATIONS_CODE?;
   HAZARD_CODE_GType? HAZARD_CODE?;
   UNDG_INFORMATION_GType? UNDG_INFORMATION?;
   DANGEROUS_GOODS_SHIPMENT_FLASHPOINT_GType? DANGEROUS_GOODS_SHIPMENT_FLASHPOINT?;
   string PACKAGING_DANGER_LEVEL_CODE?;
   string EMERGENCY_PROCEDURE_FOR_SHIPS_IDENTIFIER?;
   string HAZARD_MEDICAL_FIRST_AID_GUIDE_IDENTIFIER?;
   string TRANSPORT_EMERGENCY_CARD_IDENTIFIER?;
   HAZARD_IDENTIFICATION_PLACARD_DETAILS_GType? HAZARD_IDENTIFICATION_PLACARD_DETAILS?;
   DANGEROUS_GOODS_LABEL_GType? DANGEROUS_GOODS_LABEL?;
   string PACKING_INSTRUCTION_TYPE_CODE?;
   string HAZARDOUS_MEANS_OF_TRANSPORT_CATEGORY_CODE?;
|};

public type Group_27_GType record {|
   Contact_information_Type Contact_information;
   Communication_contact_Type[] Communication_contact = [];
|};

public type Group_26_GType record {|
   Dangerous_goods_Type Dangerous_goods;
   Free_text_Type[] Free_text = [];
   Group_27_GType[] group_27 = [];
|};

public type ITEM_NUMBER_IDENTIFICATION_GType record {|
   string Item_identifier?;
   string Item_type_identification_code?;
   string Code_list_identification_code?;
   string Code_list_responsible_agency_code?;
|};

public type SUB_LINE_INFORMATION_GType record {|
   string Sub_line_indicator_code?;
   string Line_item_identifier?;
|};

public type Line_item_Type record {|
   string code = "LIN";
   string LINE_ITEM_IDENTIFIER?;
   ITEM_NUMBER_IDENTIFICATION_GType? ITEM_NUMBER_IDENTIFICATION?;
   SUB_LINE_INFORMATION_GType? SUB_LINE_INFORMATION?;
   int? CONFIGURATION_LEVEL_NUMBER?;
   string CONFIGURATION_OPERATION_CODE?;
|};

public type ITEM_NUMBER_IDENTIFICATION_2_GType record {|
   string Item_identifier?;
   string Item_type_identification_code?;
   string Code_list_identification_code?;
   string Code_list_responsible_agency_code?;
|};

public type ITEM_NUMBER_IDENTIFICATION_3_GType record {|
   string Item_identifier?;
   string Item_type_identification_code?;
   string Code_list_identification_code?;
   string Code_list_responsible_agency_code?;
|};

public type ITEM_NUMBER_IDENTIFICATION_4_GType record {|
   string Item_identifier?;
   string Item_type_identification_code?;
   string Code_list_identification_code?;
   string Code_list_responsible_agency_code?;
|};

public type ITEM_NUMBER_IDENTIFICATION_5_GType record {|
   string Item_identifier?;
   string Item_type_identification_code?;
   string Code_list_identification_code?;
   string Code_list_responsible_agency_code?;
|};

public type Additional_product_id_Type record {|
   string code = "PIA";
   string PRODUCT_IDENTIFIER_CODE_QUALIFIER?;
   ITEM_NUMBER_IDENTIFICATION_GType? ITEM_NUMBER_IDENTIFICATION?;
   ITEM_NUMBER_IDENTIFICATION_2_GType? ITEM_NUMBER_IDENTIFICATION_2?;
   ITEM_NUMBER_IDENTIFICATION_3_GType? ITEM_NUMBER_IDENTIFICATION_3?;
   ITEM_NUMBER_IDENTIFICATION_4_GType? ITEM_NUMBER_IDENTIFICATION_4?;
   ITEM_NUMBER_IDENTIFICATION_5_GType? ITEM_NUMBER_IDENTIFICATION_5?;
|};

public type PROCESSING_INDICATOR_GType record {|
   string Processing_indicator_description_code?;
   string Code_list_identification_code?;
   string Code_list_responsible_agency_code?;
   string Processing_indicator_description?;
|};

public type Processing_information_Type record {|
   string code = "GEI";
   string PROCESSING_INFORMATION_CODE_QUALIFIER?;
   PROCESSING_INDICATOR_GType? PROCESSING_INDICATOR?;
   string PROCESS_TYPE_DESCRIPTION_CODE?;
|};

public type QUANTITY_DIFFERENCE_INFORMATION_GType record {|
   int Variance_quantity;
   string Quantity_type_code_qualifier?;
|};

public type Quantity_variances_Type record {|
   string code = "QVR";
   QUANTITY_DIFFERENCE_INFORMATION_GType? QUANTITY_DIFFERENCE_INFORMATION?;
   string DISCREPANCY_NATURE_IDENTIFICATION_CODE?;
   REASON_FOR_CHANGE_GType? REASON_FOR_CHANGE?;
|};

public type Maintenance_operation_details_Type record {|
   string code = "MTD";
   string OBJECT_TYPE_CODE_QUALIFIER?;
   string MAINTENANCE_OPERATION_CODE?;
   string MAINTENANCE_OPERATION_OPERATOR_CODE?;
   string MAINTENANCE_OPERATION_PAYER_CODE?;
|};

public type CHARACTERISTIC_DESCRIPTION_GType record {|
   string Characteristic_description_code;
   string Code_list_identification_code?;
   string Code_list_responsible_agency_code?;
   string Characteristic_description?;
   string Characteristic_description_4?;
|};

public type Characteristic_class_id_Type record {|
   string code = "CCI";
   string CLASS_TYPE_CODE?;
   MEASUREMENT_DETAILS_GType? MEASUREMENT_DETAILS?;
   CHARACTERISTIC_DESCRIPTION_GType? CHARACTERISTIC_DESCRIPTION?;
   string CHARACTERISTIC_RELEVANCE_CODE?;
|};

public type CHARACTERISTIC_VALUE_GType record {|
   string Characteristic_value_description_code?;
   string Code_list_identification_code?;
   string Code_list_responsible_agency_code?;
   string Characteristic_value_description?;
   string Characteristic_value_description_4?;
|};

public type Characteristic_value_Type record {|
   string code = "CAV";
   CHARACTERISTIC_VALUE_GType? CHARACTERISTIC_VALUE?;
|};

public type Group_29_GType record {|
   Characteristic_class_id_Type Characteristic_class_id;
   Characteristic_value_Type[] Characteristic_value = [];
   Measurements_Type[] Measurements = [];
|};

public type Group_31_GType record {|
   Monetary_amount_Type Monetary_amount;
   Related_identification_numbers_Type[] Related_identification_numbers = [];
|};

public type Group_30_GType record {|
   Payment_terms_Type Payment_terms;
   Date_time_period_Type[] Date_time_period = [];
   Percentage_details_Type? Percentage_details?;
   Group_31_GType[] group_31 = [];
|};

public type PRICE_INFORMATION_GType record {|
   string Price_code_qualifier;
   int? Price_amount?;
   string Price_type_code?;
   string Price_specification_code?;
   int? Unit_price_basis_quantity?;
   string Measurement_unit_code?;
|};

public type Price_details_Type record {|
   string code = "PRI";
   PRICE_INFORMATION_GType? PRICE_INFORMATION?;
   string SUB_LINE_ITEM_PRICE_CHANGE_OPERATION_CODE?;
|};

public type Group_32_GType record {|
   Price_details_Type Price_details;
   Currencies_Type? Currencies?;
   Additional_price_information_Type[] Additional_price_information = [];
   Range_details_Type? Range_details?;
   Date_time_period_Type[] Date_time_period = [];
|};

public type Group_33_GType record {|
   Reference_Type Reference;
   Date_time_period_Type[] Date_time_period = [];
   Processing_information_Type[] Processing_information = [];
   Monetary_amount_Type[] Monetary_amount = [];
|};

public type Group_35_GType record {|
   Reference_Type Reference;
   Date_time_period_Type[] Date_time_period = [];
|};

public type Group_36_GType record {|
   Package_identification_Type Package_identification;
   Reference_Type? Reference?;
   Date_time_period_Type[] Date_time_period = [];
   Goods_identity_number_Type[] Goods_identity_number = [];
|};

public type Group_34_GType record {|
   Package_Type Package;
   Measurements_Type[] Measurements = [];
   Quantity_Type[] Quantity = [];
   Date_time_period_Type[] Date_time_period = [];
   Group_35_GType? group_35?;
   Group_36_GType[] group_36 = [];
|};

public type Group_37_GType record {|
   Place_location_identification_Type Place_location_identification;
   Quantity_Type? Quantity?;
   Percentage_details_Type? Percentage_details?;
   Date_time_period_Type[] Date_time_period = [];
|};

public type Group_38_GType record {|
   Duty_tax_fee_details_Type Duty_tax_fee_details;
   Monetary_amount_Type? Monetary_amount?;
   Place_location_identification_Type[] Place_location_identification = [];
|};

public type Group_40_GType record {|
   Reference_Type Reference;
   Date_time_period_Type[] Date_time_period = [];
|};

public type Group_41_GType record {|
   Document_message_details_Type Document_message_details;
   Date_time_period_Type[] Date_time_period = [];
|};

public type Group_42_GType record {|
   Contact_information_Type Contact_information;
   Communication_contact_Type[] Communication_contact = [];
|};

public type Group_39_GType record {|
   Name_and_address_Type Name_and_address;
   Place_location_identification_Type[] Place_location_identification = [];
   Financial_institution_information_Type[] Financial_institution_information = [];
   Group_40_GType[] group_40 = [];
   Group_41_GType[] group_41 = [];
   Group_42_GType[] group_42 = [];
|};

public type Group_44_GType record {|
   Quantity_Type Quantity;
   Range_details_Type? Range_details?;
|};

public type Group_45_GType record {|
   Percentage_details_Type Percentage_details;
   Range_details_Type? Range_details?;
|};

public type Group_46_GType record {|
   Monetary_amount_Type Monetary_amount;
   Range_details_Type? Range_details?;
|};

public type Group_47_GType record {|
   Rate_details_Type Rate_details;
   Range_details_Type? Range_details?;
|};

public type Group_48_GType record {|
   Duty_tax_fee_details_Type Duty_tax_fee_details;
   Monetary_amount_Type? Monetary_amount?;
|};

public type Group_43_GType record {|
   Allowance_or_charge_Type Allowance_or_charge;
   Additional_information_Type[] Additional_information = [];
   Date_time_period_Type[] Date_time_period = [];
   Group_44_GType? group_44?;
   Group_45_GType? group_45?;
   Group_46_GType[] group_46 = [];
   Group_47_GType? group_47?;
   Group_48_GType[] group_48 = [];
|};

public type Group_50_GType record {|
   Place_location_identification_Type Place_location_identification;
   Date_time_period_Type[] Date_time_period = [];
|};

public type Group_49_GType record {|
   Transport_information_Type Transport_information;
   Group_50_GType[] group_50 = [];
|};

public type Group_51_GType record {|
   Terms_of_delivery_or_transport_Type Terms_of_delivery_or_transport;
   Place_location_identification_Type[] Place_location_identification = [];
|};

public type Group_52_GType record {|
   Equipment_details_Type Equipment_details;
   Handling_instructions_Type[] Handling_instructions = [];
   Measurements_Type[] Measurements = [];
   Free_text_Type[] Free_text = [];
|};

public type Group_54_GType record {|
   Quantity_Type Quantity;
   Date_time_period_Type[] Date_time_period = [];
|};

public type Group_53_GType record {|
   Scheduling_conditions_Type Scheduling_conditions;
   Free_text_Type[] Free_text = [];
   Reference_Type[] Reference = [];
   Group_54_GType[] group_54 = [];
|};

public type Group_55_GType record {|
   Requirements_and_conditions_Type Requirements_and_conditions;
   Reference_Type[] Reference = [];
   Date_time_period_Type[] Date_time_period = [];
   Free_text_Type[] Free_text = [];
|};

public type Stages_Type record {|
   string code = "STG";
   string PROCESS_STAGE_CODE_QUALIFIER?;
   int? PROCESS_STAGES_QUANTITY?;
   int? PROCESS_STAGES_ACTUAL_QUANTITY?;
|};

public type Group_57_GType record {|
   Quantity_Type Quantity;
   Monetary_amount_Type? Monetary_amount?;
|};

public type Group_56_GType record {|
   Stages_Type Stages;
   Group_57_GType[] group_57 = [];
|};

public type Group_59_GType record {|
   Contact_information_Type Contact_information;
   Communication_contact_Type[] Communication_contact = [];
|};

public type Group_58_GType record {|
   Dangerous_goods_Type Dangerous_goods;
   Free_text_Type[] Free_text = [];
   Group_59_GType[] group_59 = [];
|};

public type Group_28_GType record {|
   Line_item_Type Line_item;
   Additional_product_id_Type[] Additional_product_id = [];
   Item_description_Type[] Item_description = [];
   Measurements_Type[] Measurements = [];
   Quantity_Type[] Quantity = [];
   Percentage_details_Type[] Percentage_details = [];
   Additional_information_Type[] Additional_information = [];
   Date_time_period_Type[] Date_time_period = [];
   Monetary_amount_Type[] Monetary_amount = [];
   Processing_information_Type[] Processing_information = [];
   Goods_identity_number_Type[] Goods_identity_number = [];
   Related_identification_numbers_Type[] Related_identification_numbers = [];
   Quantity_variances_Type? Quantity_variances?;
   Document_message_details_Type[] Document_message_details = [];
   Payment_instructions_Type? Payment_instructions?;
   Maintenance_operation_details_Type[] Maintenance_operation_details = [];
   Free_text_Type[] Free_text = [];
   Group_29_GType[] group_29 = [];
   Group_30_GType[] group_30 = [];
   Group_32_GType[] group_32 = [];
   Group_33_GType[] group_33 = [];
   Group_34_GType[] group_34 = [];
   Group_37_GType[] group_37 = [];
   Group_38_GType[] group_38 = [];
   Group_39_GType[] group_39 = [];
   Group_43_GType[] group_43 = [];
   Group_49_GType[] group_49 = [];
   Group_51_GType[] group_51 = [];
   Group_52_GType[] group_52 = [];
   Group_53_GType[] group_53 = [];
   Group_55_GType[] group_55 = [];
   Group_56_GType[] group_56 = [];
   Group_58_GType[] group_58 = [];
|};

public type Section_control_Type record {|
   string code = "UNS";
   string section_identification;
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

public type Group_60_GType record {|
   Allowance_or_charge_Type Allowance_or_charge;
   Additional_information_Type? Additional_information?;
   Monetary_amount_Type[] Monetary_amount = [];
|};

public type ORDERS record {|
   Beginning_of_message_Type Beginning_of_message;
   Date_time_period_Type[] Date_time_period = [];
   Payment_instructions_Type? Payment_instructions?;
   Additional_information_Type[] Additional_information = [];
   Item_description_Type[] Item_description = [];
   Free_text_Type[] Free_text = [];
   Related_identification_numbers_Type[] Related_identification_numbers = [];
   Group_1_GType[] group_1 = [];
   Group_2_GType[] group_2 = [];
   Group_6_GType[] group_6 = [];
   Group_7_GType[] group_7 = [];
   Group_8_GType[] group_8 = [];
   Group_10_GType[] group_10 = [];
   Group_12_GType[] group_12 = [];
   Group_13_GType[] group_13 = [];
   Group_15_GType[] group_15 = [];
   Group_16_GType[] group_16 = [];
   Group_18_GType[] group_18 = [];
   Group_19_GType[] group_19 = [];
   Group_25_GType[] group_25 = [];
   Group_26_GType[] group_26 = [];
   Group_28_GType[] group_28 = [];
   Section_control_Type Section_control;
   Monetary_amount_Type[] Monetary_amount = [];
   Control_total_Type[] Control_total = [];
   Group_60_GType[] group_60 = [];
|};

public type Syntax_identifier_GType record {|
   string syntax_id;
   string syntax_version;
|};

public type Sender_GType record {|
   string id;
   string qualifier?;
|};

public type Recipient_GType record {|
   string id;
   string qualifier?;
|};

public type Date_and_time_GType record {|
   string date;
   string time;
|};

public type Interchange_header_Type record {|
   string code = "UNB";
   Syntax_identifier_GType syntax_identifier;
   Sender_GType sender;
   Recipient_GType recipient;
   Date_and_time_GType date_and_time;
   string control_reference;
   string recipient_reference_password?;
   string application_reference?;
   string processing_priority_code?;
   string acknowledgement_request?;
   string communications_agreement_id?;
   string test_indicator?;
|};

public type ORDERSInterchangeHeader record {|
   Interchange_header_Type interchange_header;
|};

public type Interchange_trailer_Type record {|
   string code = "UNZ";
   int interchange_control_count;
   string interchange_control_reference;
|};

public type ORDERSInterchangeTrailer record {|
   Interchange_trailer_Type interchange_trailer;
|};

public type Message_information_GType record {|
   string name?;
   string catagory?;
   string version?;
   string status?;
   string new_field?;
|};

public type Message_header_Type record {|
   string code = "UNH";
   string message_reference_number?;
   Message_information_GType? message_information?;
|};

public type ORDERSTransactionHeader record {|
   Message_header_Type Message_header;
|};

public type Message_trailer_Type record {|
   string code = "UNT";
   string number1?;
   string number2?;
|};

public type ORDERSTransactionTrailer record {|
   Message_trailer_Type Message_trailer;
|};



public type ORDERSTransaction record {|
    ORDERSTransactionHeader transactionHeader;
    ORDERS|error body;
    ORDERSTransactionTrailer transactionTrailer;
|};

public type ORDERSInterchange record {|
    ORDERSInterchangeHeader interchangeHeader;
    ORDERSTransaction[] transactions;
    ORDERSInterchangeTrailer interchangeTrailer;
|};

public type ORDERSHeaders record {|
    ORDERSInterchangeHeader interchange;
    ORDERSTransactionHeader 'transaction;
|};


final readonly & json schemaJson = {"name":"ORDERS", "ignoreSegments":[], "delimiters":{"segment":"'", "field":"+", "component":":", "repetition":"*", "decimalSeparator":"."}, "envelope":{"interchange":{"header":[{"ref":"UNB", "tag":"interchange_header", "minOccurances":1, "maxOccurances":1}], "trailer":[{"ref":"UNZ", "tag":"interchange_trailer", "minOccurances":1, "maxOccurances":1}]}, "transaction":{"header":[{"ref":"UNH", "tag":"Message_header", "minOccurances":1, "maxOccurances":1}], "trailer":[{"ref":"UNT", "tag":"Message_trailer", "minOccurances":1, "maxOccurances":1}]}}, "segments":[{"ref":"BGM", "tag":"Beginning_of_message", "minOccurances":1, "maxOccurances":1}, {"ref":"DTM", "tag":"Date_time_period", "minOccurances":1, "maxOccurances":35}, {"ref":"PAI", "tag":"Payment_instructions", "maxOccurances":1}, {"ref":"ALI", "tag":"Additional_information", "maxOccurances":5}, {"ref":"IMD", "tag":"Item_description", "maxOccurances":999}, {"ref":"FTX", "tag":"Free_text", "maxOccurances":99}, {"ref":"GIR", "tag":"Related_identification_numbers", "maxOccurances":10}, {"tag":"group_1", "maxOccurances":9999, "segments":[{"ref":"RFF", "tag":"Reference", "minOccurances":1, "maxOccurances":1}, {"ref":"DTM", "tag":"Date_time_period", "maxOccurances":5}]}, {"tag":"group_2", "maxOccurances":99, "segments":[{"ref":"NAD", "tag":"Name_and_address", "minOccurances":1, "maxOccurances":1}, {"ref":"LOC", "tag":"Place_location_identification", "maxOccurances":99}, {"ref":"FII", "tag":"Financial_institution_information", "maxOccurances":5}, {"tag":"group_3", "maxOccurances":99, "segments":[{"ref":"RFF", "tag":"Reference", "minOccurances":1, "maxOccurances":1}, {"ref":"DTM", "tag":"Date_time_period", "maxOccurances":5}]}, {"tag":"group_4", "maxOccurances":5, "segments":[{"ref":"DOC", "tag":"Document_message_details", "minOccurances":1, "maxOccurances":1}, {"ref":"DTM", "tag":"Date_time_period", "maxOccurances":5}]}, {"tag":"group_5", "maxOccurances":5, "segments":[{"ref":"CTA", "tag":"Contact_information", "minOccurances":1, "maxOccurances":1}, {"ref":"COM", "tag":"Communication_contact", "maxOccurances":5}]}]}, {"tag":"group_6", "maxOccurances":5, "segments":[{"ref":"TAX", "tag":"Duty_tax_fee_details", "minOccurances":1, "maxOccurances":1}, {"ref":"MOA", "tag":"Monetary_amount", "maxOccurances":1}, {"ref":"LOC", "tag":"Place_location_identification", "maxOccurances":9}]}, {"tag":"group_7", "maxOccurances":5, "segments":[{"ref":"CUX", "tag":"Currencies", "minOccurances":1, "maxOccurances":1}, {"ref":"PCD", "tag":"Percentage_details", "maxOccurances":5}, {"ref":"DTM", "tag":"Date_time_period", "maxOccurances":5}]}, {"tag":"group_8", "maxOccurances":10, "segments":[{"ref":"PYT", "tag":"Payment_terms", "minOccurances":1, "maxOccurances":1}, {"ref":"DTM", "tag":"Date_time_period", "maxOccurances":5}, {"ref":"PCD", "tag":"Percentage_details", "maxOccurances":1}, {"tag":"group_9", "maxOccurances":9999, "segments":[{"ref":"MOA", "tag":"Monetary_amount", "minOccurances":1, "maxOccurances":1}, {"ref":"GIR", "tag":"Related_identification_numbers", "maxOccurances":9}, {"ref":"RJL", "tag":"Accounting_journal_identification", "maxOccurances":99}]}]}, {"tag":"group_10", "maxOccurances":10, "segments":[{"ref":"TDT", "tag":"Transport_information", "minOccurances":1, "maxOccurances":1}, {"tag":"group_11", "maxOccurances":10, "segments":[{"ref":"LOC", "tag":"Place_location_identification", "minOccurances":1, "maxOccurances":1}, {"ref":"DTM", "tag":"Date_time_period", "maxOccurances":5}]}]}, {"tag":"group_12", "maxOccurances":5, "segments":[{"ref":"TOD", "tag":"Terms_of_delivery_or_transport", "minOccurances":1, "maxOccurances":1}, {"ref":"LOC", "tag":"Place_location_identification", "maxOccurances":2}]}, {"tag":"group_13", "maxOccurances":99, "segments":[{"ref":"PAC", "tag":"Package", "minOccurances":1, "maxOccurances":1}, {"ref":"MEA", "tag":"Measurements", "maxOccurances":5}, {"tag":"group_14", "maxOccurances":5, "segments":[{"ref":"PCI", "tag":"Package_identification", "minOccurances":1, "maxOccurances":1}, {"ref":"RFF", "tag":"Reference", "maxOccurances":1}, {"ref":"DTM", "tag":"Date_time_period", "maxOccurances":5}, {"ref":"GIN", "tag":"Goods_identity_number", "maxOccurances":10}]}]}, {"tag":"group_15", "maxOccurances":10, "segments":[{"ref":"EQD", "tag":"Equipment_details", "minOccurances":1, "maxOccurances":1}, {"ref":"HAN", "tag":"Handling_instructions", "maxOccurances":5}, {"ref":"MEA", "tag":"Measurements", "maxOccurances":5}, {"ref":"FTX", "tag":"Free_text", "maxOccurances":5}]}, {"tag":"group_16", "maxOccurances":10, "segments":[{"ref":"SCC", "tag":"Scheduling_conditions", "minOccurances":1, "maxOccurances":1}, {"ref":"FTX", "tag":"Free_text", "maxOccurances":5}, {"ref":"RFF", "tag":"Reference", "maxOccurances":5}, {"tag":"group_17", "maxOccurances":10, "segments":[{"ref":"QTY", "tag":"Quantity", "minOccurances":1, "maxOccurances":1}, {"ref":"DTM", "tag":"Date_time_period", "maxOccurances":5}]}]}, {"tag":"group_18", "maxOccurances":25, "segments":[{"ref":"APR", "tag":"Additional_price_information", "minOccurances":1, "maxOccurances":1}, {"ref":"DTM", "tag":"Date_time_period", "maxOccurances":5}, {"ref":"RNG", "tag":"Range_details", "maxOccurances":1}]}, {"tag":"group_19", "maxOccurances":99, "segments":[{"ref":"ALC", "tag":"Allowance_or_charge", "minOccurances":1, "maxOccurances":1}, {"ref":"ALI", "tag":"Additional_information", "maxOccurances":5}, {"ref":"DTM", "tag":"Date_time_period", "maxOccurances":5}, {"tag":"group_20", "maxOccurances":1, "segments":[{"ref":"QTY", "tag":"Quantity", "minOccurances":1, "maxOccurances":1}, {"ref":"RNG", "tag":"Range_details", "maxOccurances":1}]}, {"tag":"group_21", "maxOccurances":1, "segments":[{"ref":"PCD", "tag":"Percentage_details", "minOccurances":1, "maxOccurances":1}, {"ref":"RNG", "tag":"Range_details", "maxOccurances":1}]}, {"tag":"group_22", "maxOccurances":2, "segments":[{"ref":"MOA", "tag":"Monetary_amount", "minOccurances":1, "maxOccurances":1}, {"ref":"RNG", "tag":"Range_details", "maxOccurances":1}]}, {"tag":"group_23", "maxOccurances":1, "segments":[{"ref":"RTE", "tag":"Rate_details", "minOccurances":1, "maxOccurances":1}, {"ref":"RNG", "tag":"Range_details", "maxOccurances":1}]}, {"tag":"group_24", "maxOccurances":5, "segments":[{"ref":"TAX", "tag":"Duty_tax_fee_details", "minOccurances":1, "maxOccurances":1}, {"ref":"MOA", "tag":"Monetary_amount", "maxOccurances":1}]}]}, {"tag":"group_25", "maxOccurances":999, "segments":[{"ref":"RCS", "tag":"Requirements_and_conditions", "minOccurances":1, "maxOccurances":1}, {"ref":"RFF", "tag":"Reference", "maxOccurances":5}, {"ref":"DTM", "tag":"Date_time_period", "maxOccurances":5}, {"ref":"FTX", "tag":"Free_text", "maxOccurances":99999}]}, {"tag":"group_26", "maxOccurances":999, "segments":[{"ref":"DGS", "tag":"Dangerous_goods", "minOccurances":1, "maxOccurances":1}, {"ref":"FTX", "tag":"Free_text", "maxOccurances":5}, {"tag":"group_27", "maxOccurances":99, "segments":[{"ref":"CTA", "tag":"Contact_information", "minOccurances":1, "maxOccurances":1}, {"ref":"COM", "tag":"Communication_contact", "maxOccurances":5}]}]}, {"tag":"group_28", "maxOccurances":200000, "segments":[{"ref":"LIN", "tag":"Line_item", "minOccurances":1, "maxOccurances":1}, {"ref":"PIA", "tag":"Additional_product_id", "maxOccurances":25}, {"ref":"IMD", "tag":"Item_description", "maxOccurances":99}, {"ref":"MEA", "tag":"Measurements", "maxOccurances":99}, {"ref":"QTY", "tag":"Quantity", "maxOccurances":99}, {"ref":"PCD", "tag":"Percentage_details", "maxOccurances":5}, {"ref":"ALI", "tag":"Additional_information", "maxOccurances":5}, {"ref":"DTM", "tag":"Date_time_period", "maxOccurances":35}, {"ref":"MOA", "tag":"Monetary_amount", "maxOccurances":10}, {"ref":"GEI", "tag":"Processing_information", "maxOccurances":99}, {"ref":"GIN", "tag":"Goods_identity_number", "maxOccurances":1000}, {"ref":"GIR", "tag":"Related_identification_numbers", "maxOccurances":1000}, {"ref":"QVR", "tag":"Quantity_variances", "maxOccurances":1}, {"ref":"DOC", "tag":"Document_message_details", "maxOccurances":99}, {"ref":"PAI", "tag":"Payment_instructions", "maxOccurances":1}, {"ref":"MTD", "tag":"Maintenance_operation_details", "maxOccurances":99}, {"ref":"FTX", "tag":"Free_text", "maxOccurances":99}, {"tag":"group_29", "maxOccurances":999, "segments":[{"ref":"CCI", "tag":"Characteristic_class_id", "minOccurances":1, "maxOccurances":1}, {"ref":"CAV", "tag":"Characteristic_value", "maxOccurances":10}, {"ref":"MEA", "tag":"Measurements", "maxOccurances":10}]}, {"tag":"group_30", "maxOccurances":10, "segments":[{"ref":"PYT", "tag":"Payment_terms", "minOccurances":1, "maxOccurances":1}, {"ref":"DTM", "tag":"Date_time_period", "maxOccurances":5}, {"ref":"PCD", "tag":"Percentage_details", "maxOccurances":1}, {"tag":"group_31", "maxOccurances":9999, "segments":[{"ref":"MOA", "tag":"Monetary_amount", "minOccurances":1, "maxOccurances":1}, {"ref":"GIR", "tag":"Related_identification_numbers", "maxOccurances":9}]}]}, {"tag":"group_32", "maxOccurances":25, "segments":[{"ref":"PRI", "tag":"Price_details", "minOccurances":1, "maxOccurances":1}, {"ref":"CUX", "tag":"Currencies", "maxOccurances":1}, {"ref":"APR", "tag":"Additional_price_information", "maxOccurances":99}, {"ref":"RNG", "tag":"Range_details", "maxOccurances":1}, {"ref":"DTM", "tag":"Date_time_period", "maxOccurances":5}]}, {"tag":"group_33", "maxOccurances":9999, "segments":[{"ref":"RFF", "tag":"Reference", "minOccurances":1, "maxOccurances":1}, {"ref":"DTM", "tag":"Date_time_period", "maxOccurances":5}, {"ref":"GEI", "tag":"Processing_information", "maxOccurances":99}, {"ref":"MOA", "tag":"Monetary_amount", "maxOccurances":99}]}, {"tag":"group_34", "maxOccurances":99, "segments":[{"ref":"PAC", "tag":"Package", "minOccurances":1, "maxOccurances":1}, {"ref":"MEA", "tag":"Measurements", "maxOccurances":5}, {"ref":"QTY", "tag":"Quantity", "maxOccurances":5}, {"ref":"DTM", "tag":"Date_time_period", "maxOccurances":5}, {"tag":"group_35", "maxOccurances":1, "segments":[{"ref":"RFF", "tag":"Reference", "minOccurances":1, "maxOccurances":1}, {"ref":"DTM", "tag":"Date_time_period", "maxOccurances":5}]}, {"tag":"group_36", "maxOccurances":5, "segments":[{"ref":"PCI", "tag":"Package_identification", "minOccurances":1, "maxOccurances":1}, {"ref":"RFF", "tag":"Reference", "maxOccurances":1}, {"ref":"DTM", "tag":"Date_time_period", "maxOccurances":5}, {"ref":"GIN", "tag":"Goods_identity_number", "maxOccurances":10}]}]}, {"tag":"group_37", "maxOccurances":9999, "segments":[{"ref":"LOC", "tag":"Place_location_identification", "minOccurances":1, "maxOccurances":1}, {"ref":"QTY", "tag":"Quantity", "maxOccurances":1}, {"ref":"PCD", "tag":"Percentage_details", "maxOccurances":1}, {"ref":"DTM", "tag":"Date_time_period", "maxOccurances":5}]}, {"tag":"group_38", "maxOccurances":10, "segments":[{"ref":"TAX", "tag":"Duty_tax_fee_details", "minOccurances":1, "maxOccurances":1}, {"ref":"MOA", "tag":"Monetary_amount", "maxOccurances":1}, {"ref":"LOC", "tag":"Place_location_identification", "maxOccurances":5}]}, {"tag":"group_39", "maxOccurances":999, "segments":[{"ref":"NAD", "tag":"Name_and_address", "minOccurances":1, "maxOccurances":1}, {"ref":"LOC", "tag":"Place_location_identification", "maxOccurances":5}, {"ref":"FII", "tag":"Financial_institution_information", "maxOccurances":5}, {"tag":"group_40", "maxOccurances":99, "segments":[{"ref":"RFF", "tag":"Reference", "minOccurances":1, "maxOccurances":1}, {"ref":"DTM", "tag":"Date_time_period", "maxOccurances":5}]}, {"tag":"group_41", "maxOccurances":5, "segments":[{"ref":"DOC", "tag":"Document_message_details", "minOccurances":1, "maxOccurances":1}, {"ref":"DTM", "tag":"Date_time_period", "maxOccurances":5}]}, {"tag":"group_42", "maxOccurances":5, "segments":[{"ref":"CTA", "tag":"Contact_information", "minOccurances":1, "maxOccurances":1}, {"ref":"COM", "tag":"Communication_contact", "maxOccurances":5}]}]}, {"tag":"group_43", "maxOccurances":99, "segments":[{"ref":"ALC", "tag":"Allowance_or_charge", "minOccurances":1, "maxOccurances":1}, {"ref":"ALI", "tag":"Additional_information", "maxOccurances":5}, {"ref":"DTM", "tag":"Date_time_period", "maxOccurances":5}, {"tag":"group_44", "maxOccurances":1, "segments":[{"ref":"QTY", "tag":"Quantity", "minOccurances":1, "maxOccurances":1}, {"ref":"RNG", "tag":"Range_details", "maxOccurances":1}]}, {"tag":"group_45", "maxOccurances":1, "segments":[{"ref":"PCD", "tag":"Percentage_details", "minOccurances":1, "maxOccurances":1}, {"ref":"RNG", "tag":"Range_details", "maxOccurances":1}]}, {"tag":"group_46", "maxOccurances":2, "segments":[{"ref":"MOA", "tag":"Monetary_amount", "minOccurances":1, "maxOccurances":1}, {"ref":"RNG", "tag":"Range_details", "maxOccurances":1}]}, {"tag":"group_47", "maxOccurances":1, "segments":[{"ref":"RTE", "tag":"Rate_details", "minOccurances":1, "maxOccurances":1}, {"ref":"RNG", "tag":"Range_details", "maxOccurances":1}]}, {"tag":"group_48", "maxOccurances":5, "segments":[{"ref":"TAX", "tag":"Duty_tax_fee_details", "minOccurances":1, "maxOccurances":1}, {"ref":"MOA", "tag":"Monetary_amount", "maxOccurances":1}]}]}, {"tag":"group_49", "maxOccurances":10, "segments":[{"ref":"TDT", "tag":"Transport_information", "minOccurances":1, "maxOccurances":1}, {"tag":"group_50", "maxOccurances":10, "segments":[{"ref":"LOC", "tag":"Place_location_identification", "minOccurances":1, "maxOccurances":1}, {"ref":"DTM", "tag":"Date_time_period", "maxOccurances":5}]}]}, {"tag":"group_51", "maxOccurances":5, "segments":[{"ref":"TOD", "tag":"Terms_of_delivery_or_transport", "minOccurances":1, "maxOccurances":1}, {"ref":"LOC", "tag":"Place_location_identification", "maxOccurances":2}]}, {"tag":"group_52", "maxOccurances":10, "segments":[{"ref":"EQD", "tag":"Equipment_details", "minOccurances":1, "maxOccurances":1}, {"ref":"HAN", "tag":"Handling_instructions", "maxOccurances":5}, {"ref":"MEA", "tag":"Measurements", "maxOccurances":5}, {"ref":"FTX", "tag":"Free_text", "maxOccurances":5}]}, {"tag":"group_53", "maxOccurances":100, "segments":[{"ref":"SCC", "tag":"Scheduling_conditions", "minOccurances":1, "maxOccurances":1}, {"ref":"FTX", "tag":"Free_text", "maxOccurances":5}, {"ref":"RFF", "tag":"Reference", "maxOccurances":5}, {"tag":"group_54", "maxOccurances":10, "segments":[{"ref":"QTY", "tag":"Quantity", "minOccurances":1, "maxOccurances":1}, {"ref":"DTM", "tag":"Date_time_period", "maxOccurances":5}]}]}, {"tag":"group_55", "maxOccurances":999, "segments":[{"ref":"RCS", "tag":"Requirements_and_conditions", "minOccurances":1, "maxOccurances":1}, {"ref":"RFF", "tag":"Reference", "maxOccurances":5}, {"ref":"DTM", "tag":"Date_time_period", "maxOccurances":5}, {"ref":"FTX", "tag":"Free_text", "maxOccurances":99999}]}, {"tag":"group_56", "maxOccurances":10, "segments":[{"ref":"STG", "tag":"Stages", "minOccurances":1, "maxOccurances":1}, {"tag":"group_57", "maxOccurances":3, "segments":[{"ref":"QTY", "tag":"Quantity", "minOccurances":1, "maxOccurances":1}, {"ref":"MOA", "tag":"Monetary_amount", "maxOccurances":1}]}]}, {"tag":"group_58", "maxOccurances":999, "segments":[{"ref":"DGS", "tag":"Dangerous_goods", "minOccurances":1, "maxOccurances":1}, {"ref":"FTX", "tag":"Free_text", "maxOccurances":5}, {"tag":"group_59", "maxOccurances":99, "segments":[{"ref":"CTA", "tag":"Contact_information", "minOccurances":1, "maxOccurances":1}, {"ref":"COM", "tag":"Communication_contact", "maxOccurances":5}]}]}]}, {"ref":"UNS", "tag":"Section_control", "minOccurances":1, "maxOccurances":1}, {"ref":"MOA", "tag":"Monetary_amount", "maxOccurances":99}, {"ref":"CNT", "tag":"Control_total", "maxOccurances":10}, {"tag":"group_60", "maxOccurances":10, "segments":[{"ref":"ALC", "tag":"Allowance_or_charge", "minOccurances":1, "maxOccurances":1}, {"ref":"ALI", "tag":"Additional_information", "maxOccurances":1}, {"ref":"MOA", "tag":"Monetary_amount", "minOccurances":1, "maxOccurances":2}]}], "segmentDefinitions":{"UNH":{"code":"UNH", "tag":"message_header", "fields":[{"tag":"code", "required":true, "repeat":false}, {"tag":"message_reference_number", "dataType":"string", "required":false, "repeat":false}, {"tag":"message_information", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"name", "required":false, "dataType":"string"}, {"tag":"catagory", "required":false, "dataType":"string"}, {"tag":"version", "required":false, "dataType":"string"}, {"tag":"status", "required":false, "dataType":"string"}, {"tag":"new_field", "required":false, "dataType":"string"}]}]}, "BGM":{"code":"BGM", "tag":"Beginning_of_message", "fields":[{"tag":"code", "required":true, "repeat":false}, {"tag":"DOCUMENT_MESSAGE_NAME", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Document_name_code", "required":false, "dataType":"string"}, {"tag":"Code_list_identification_code", "required":false, "dataType":"string"}, {"tag":"Code_list_responsible_agency_code", "required":false, "dataType":"string"}, {"tag":"Document_name", "required":false, "dataType":"string"}]}, {"tag":"DOCUMENT_MESSAGE_IDENTIFICATION", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Document_identifier", "required":false, "dataType":"string"}, {"tag":"Version_identifier", "required":false, "dataType":"string"}, {"tag":"Revision_identifier", "required":false, "dataType":"string"}]}, {"tag":"MESSAGE_FUNCTION_CODE", "dataType":"string", "required":false, "repeat":false, "components":[]}, {"tag":"RESPONSE_TYPE_CODE", "dataType":"string", "required":false, "repeat":false, "components":[]}]}, "DTM":{"code":"DTM", "tag":"Date_time_period", "fields":[{"tag":"code", "required":true, "repeat":false}, {"tag":"DATE_TIME_PERIOD", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Date_or_time_or_period", "required":false, "dataType":"string"}, {"tag":"Date_or_time_or_period_text", "required":false, "dataType":"string"}, {"tag":"Date_or_time_or_period_format_code", "required":false, "dataType":"string"}]}]}, "PAI":{"code":"PAI", "tag":"Payment_instructions", "fields":[{"tag":"code", "required":true, "repeat":false}, {"tag":"PAYMENT_INSTRUCTION_DETAILS", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Payment_conditions_code", "required":false, "dataType":"string"}, {"tag":"Payment_guarantee_means_code", "required":false, "dataType":"string"}, {"tag":"Payment_means_code", "required":false, "dataType":"string"}, {"tag":"Code_list_identification_code", "required":false, "dataType":"string"}, {"tag":"Code_list_responsible_agency_code", "required":false, "dataType":"string"}, {"tag":"Payment_channel_code", "required":false, "dataType":"string"}]}]}, "ALI":{"code":"ALI", "tag":"Additional_information", "fields":[{"tag":"code", "required":true, "repeat":false}, {"tag":"COUNTRY_OF_ORIGIN_NAME_CODE", "dataType":"string", "required":false, "repeat":false, "components":[]}, {"tag":"DUTY_REGIME_TYPE_CODE", "dataType":"string", "required":false, "repeat":false, "components":[]}, {"tag":"SPECIAL_CONDITION_CODE", "dataType":"string", "required":false, "repeat":false, "components":[]}, {"tag":"SPECIAL_CONDITION_CODE_3", "dataType":"string", "required":false, "repeat":false, "components":[]}, {"tag":"SPECIAL_CONDITION_CODE_4", "dataType":"string", "required":false, "repeat":false, "components":[]}, {"tag":"SPECIAL_CONDITION_CODE_5", "dataType":"string", "required":false, "repeat":false, "components":[]}, {"tag":"SPECIAL_CONDITION_CODE_6", "dataType":"string", "required":false, "repeat":false, "components":[]}]}, "IMD":{"code":"IMD", "tag":"Item_description", "fields":[{"tag":"code", "required":true, "repeat":false}, {"tag":"DESCRIPTION_FORMAT_CODE", "dataType":"string", "required":false, "repeat":false, "components":[]}, {"tag":"ITEM_CHARACTERISTIC", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Item_characteristic_code", "required":false, "dataType":"string"}, {"tag":"Code_list_identification_code", "required":false, "dataType":"string"}, {"tag":"Code_list_responsible_agency_code", "required":false, "dataType":"string"}]}, {"tag":"ITEM_DESCRIPTION", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Item_description_code", "required":false, "dataType":"string"}, {"tag":"Code_list_identification_code", "required":false, "dataType":"string"}, {"tag":"Code_list_responsible_agency_code", "required":false, "dataType":"string"}, {"tag":"Item_description", "required":false, "dataType":"string"}, {"tag":"Item_description_4", "required":false, "dataType":"string"}, {"tag":"Language_name_code", "required":false, "dataType":"string"}]}, {"tag":"SURFACE_OR_LAYER_CODE", "dataType":"string", "required":false, "repeat":false, "components":[]}]}, "FTX":{"code":"FTX", "tag":"Free_text", "fields":[{"tag":"code", "required":true, "repeat":false}, {"tag":"TEXT_SUBJECT_CODE_QUALIFIER", "dataType":"string", "required":false, "repeat":false, "components":[]}, {"tag":"FREE_TEXT_FUNCTION_CODE", "dataType":"string", "required":false, "repeat":false, "components":[]}, {"tag":"TEXT_REFERENCE", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Free_text_description_code", "required":true, "dataType":"string"}, {"tag":"Code_list_identification_code", "required":false, "dataType":"string"}, {"tag":"Code_list_responsible_agency_code", "required":false, "dataType":"string"}]}, {"tag":"TEXT_LITERAL", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Free_text", "required":true, "dataType":"string"}, {"tag":"Free_text_1", "required":false, "dataType":"string"}, {"tag":"Free_text_2", "required":false, "dataType":"string"}, {"tag":"Free_text_3", "required":false, "dataType":"string"}, {"tag":"Free_text_4", "required":false, "dataType":"string"}]}, {"tag":"LANGUAGE_NAME_CODE", "dataType":"string", "required":false, "repeat":false, "components":[]}, {"tag":"FREE_TEXT_FORMAT_CODE", "dataType":"string", "required":false, "repeat":false, "components":[]}]}, "GIR":{"code":"GIR", "tag":"Related_identification_numbers", "fields":[{"tag":"code", "required":true, "repeat":false}, {"tag":"SET_TYPE_CODE_QUALIFIER", "dataType":"string", "required":false, "repeat":false, "components":[]}, {"tag":"IDENTIFICATION_NUMBER", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Object_identifier", "required":true, "dataType":"string"}, {"tag":"Object_identification_code_qualifier", "required":false, "dataType":"string"}, {"tag":"Status_description_code", "required":false, "dataType":"string"}]}, {"tag":"IDENTIFICATION_NUMBER_2", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Object_identifier", "required":true, "dataType":"string"}, {"tag":"Object_identification_code_qualifier", "required":false, "dataType":"string"}, {"tag":"Status_description_code", "required":false, "dataType":"string"}]}, {"tag":"IDENTIFICATION_NUMBER_3", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Object_identifier", "required":true, "dataType":"string"}, {"tag":"Object_identification_code_qualifier", "required":false, "dataType":"string"}, {"tag":"Status_description_code", "required":false, "dataType":"string"}]}, {"tag":"IDENTIFICATION_NUMBER_4", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Object_identifier", "required":true, "dataType":"string"}, {"tag":"Object_identification_code_qualifier", "required":false, "dataType":"string"}, {"tag":"Status_description_code", "required":false, "dataType":"string"}]}, {"tag":"IDENTIFICATION_NUMBER_5", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Object_identifier", "required":true, "dataType":"string"}, {"tag":"Object_identification_code_qualifier", "required":false, "dataType":"string"}, {"tag":"Status_description_code", "required":false, "dataType":"string"}]}]}, "RFF":{"code":"RFF", "tag":"Reference", "fields":[{"tag":"code", "required":true, "repeat":false}, {"tag":"REFERENCE", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Reference_code_qualifier", "required":true, "dataType":"string"}, {"tag":"Reference_identifier", "required":false, "dataType":"string"}, {"tag":"Document_line_identifier", "required":false, "dataType":"string"}, {"tag":"Reference_version_identifier", "required":false, "dataType":"string"}, {"tag":"Revision_identifier", "required":false, "dataType":"string"}]}]}, "NAD":{"code":"NAD", "tag":"Name_and_address", "fields":[{"tag":"code", "required":true, "repeat":false}, {"tag":"PARTY_FUNCTION_CODE_QUALIFIER", "dataType":"string", "required":false, "repeat":false, "components":[]}, {"tag":"PARTY_IDENTIFICATION_DETAILS", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Party_identifier", "required":true, "dataType":"string"}, {"tag":"Code_list_identification_code", "required":false, "dataType":"string"}, {"tag":"Code_list_responsible_agency_code", "required":false, "dataType":"string"}]}, {"tag":"NAME_AND_ADDRESS", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Name_and_address_description", "required":true, "dataType":"string"}, {"tag":"Name_and_address_description_1", "required":false, "dataType":"string"}, {"tag":"Name_and_address_description_2", "required":false, "dataType":"string"}, {"tag":"Name_and_address_description_3", "required":false, "dataType":"string"}, {"tag":"Name_and_address_description_4", "required":false, "dataType":"string"}]}, {"tag":"PARTY_NAME", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Party_name", "required":true, "dataType":"string"}, {"tag":"Party_name_1", "required":false, "dataType":"string"}, {"tag":"Party_name_2", "required":false, "dataType":"string"}, {"tag":"Party_name_3", "required":false, "dataType":"string"}, {"tag":"Party_name_4", "required":false, "dataType":"string"}, {"tag":"Party_name_format_code", "required":false, "dataType":"string"}]}, {"tag":"STREET", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Street_and_number_or_post_office_box_identifier", "required":true, "dataType":"string"}, {"tag":"Street_and_number_or_post_office_box_identifier_1", "required":false, "dataType":"string"}, {"tag":"Street_and_number_or_post_office_box_identifier_2", "required":false, "dataType":"string"}, {"tag":"Street_and_number_or_post_office_box_identifier_3", "required":false, "dataType":"string"}]}, {"tag":"CITY_NAME", "dataType":"string", "required":false, "repeat":false, "components":[]}, {"tag":"COUNTRY_SUB_ENTITY_DETAILS", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Country_sub_entity_name_code", "required":false, "dataType":"string"}, {"tag":"Code_list_identification_code", "required":false, "dataType":"string"}, {"tag":"Code_list_responsible_agency_code", "required":false, "dataType":"string"}, {"tag":"Country_sub_entity_name", "required":false, "dataType":"string"}]}, {"tag":"POSTAL_IDENTIFICATION_CODE", "dataType":"string", "required":false, "repeat":false, "components":[]}, {"tag":"COUNTRY_NAME_CODE", "dataType":"string", "required":false, "repeat":false, "components":[]}]}, "LOC":{"code":"LOC", "tag":"Place_location_identification", "fields":[{"tag":"code", "required":true, "repeat":false}, {"tag":"LOCATION_FUNCTION_CODE_QUALIFIER", "dataType":"string", "required":false, "repeat":false, "components":[]}, {"tag":"LOCATION_IDENTIFICATION", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Location_name_code", "required":false, "dataType":"string"}, {"tag":"Code_list_identification_code", "required":false, "dataType":"string"}, {"tag":"Code_list_responsible_agency_code", "required":false, "dataType":"string"}, {"tag":"Location_name", "required":false, "dataType":"string"}]}, {"tag":"RELATED_LOCATION_ONE_IDENTIFICATION", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"First_related_location_name_code", "required":false, "dataType":"string"}, {"tag":"Code_list_identification_code", "required":false, "dataType":"string"}, {"tag":"Code_list_responsible_agency_code", "required":false, "dataType":"string"}, {"tag":"First_related_location_name", "required":false, "dataType":"string"}]}, {"tag":"RELATED_LOCATION_TWO_IDENTIFICATION", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Second_related_location_name_code", "required":false, "dataType":"string"}, {"tag":"Code_list_identification_code", "required":false, "dataType":"string"}, {"tag":"Code_list_responsible_agency_code", "required":false, "dataType":"string"}, {"tag":"Second_related_location_name", "required":false, "dataType":"string"}]}, {"tag":"RELATION_CODE", "dataType":"string", "required":false, "repeat":false, "components":[]}]}, "FII":{"code":"FII", "tag":"Financial_institution_information", "fields":[{"tag":"code", "required":true, "repeat":false}, {"tag":"PARTY_FUNCTION_CODE_QUALIFIER", "dataType":"string", "required":false, "repeat":false, "components":[]}, {"tag":"ACCOUNT_HOLDER_IDENTIFICATION", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Account_holder_identifier", "required":false, "dataType":"string"}, {"tag":"Account_holder_name", "required":false, "dataType":"string"}, {"tag":"Account_holder_name_2", "required":false, "dataType":"string"}, {"tag":"Currency_identification_code", "required":false, "dataType":"string"}]}, {"tag":"INSTITUTION_IDENTIFICATION", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Institution_name_code", "required":false, "dataType":"string"}, {"tag":"Code_list_identification_code", "required":false, "dataType":"string"}, {"tag":"Code_list_responsible_agency_code", "required":false, "dataType":"string"}, {"tag":"Institution_branch_identifier", "required":false, "dataType":"string"}, {"tag":"Code_list_identification_code_4", "required":false, "dataType":"string"}, {"tag":"Code_list_responsible_agency_code_5", "required":false, "dataType":"string"}, {"tag":"Institution_name", "required":false, "dataType":"string"}, {"tag":"Institution_branch_location_name", "required":false, "dataType":"string"}]}, {"tag":"COUNTRY_NAME_CODE", "dataType":"string", "required":false, "repeat":false, "components":[]}]}, "DOC":{"code":"DOC", "tag":"Document_message_details", "fields":[{"tag":"code", "required":true, "repeat":false}, {"tag":"DOCUMENT_MESSAGE_NAME", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Document_name_code", "required":false, "dataType":"string"}, {"tag":"Code_list_identification_code", "required":false, "dataType":"string"}, {"tag":"Code_list_responsible_agency_code", "required":false, "dataType":"string"}, {"tag":"Document_name", "required":false, "dataType":"string"}]}, {"tag":"DOCUMENT_MESSAGE_DETAILS", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Document_identifier", "required":false, "dataType":"string"}, {"tag":"Document_status_code", "required":false, "dataType":"string"}, {"tag":"Document_source_description", "required":false, "dataType":"string"}, {"tag":"Language_name_code", "required":false, "dataType":"string"}, {"tag":"Version_identifier", "required":false, "dataType":"string"}, {"tag":"Revision_identifier", "required":false, "dataType":"string"}]}, {"tag":"COMMUNICATION_MEDIUM_TYPE_CODE", "dataType":"string", "required":false, "repeat":false, "components":[]}, {"tag":"DOCUMENT_COPIES_REQUIRED_QUANTITY", "dataType":"int", "required":false, "repeat":false, "components":[]}, {"tag":"DOCUMENT_ORIGINALS_REQUIRED_QUANTITY", "dataType":"int", "required":false, "repeat":false, "components":[]}]}, "CTA":{"code":"CTA", "tag":"Contact_information", "fields":[{"tag":"code", "required":true, "repeat":false}, {"tag":"CONTACT_FUNCTION_CODE", "dataType":"string", "required":false, "repeat":false, "components":[]}, {"tag":"DEPARTMENT_OR_EMPLOYEE_DETAILS", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Department_or_employee_name_code", "required":false, "dataType":"string"}, {"tag":"Department_or_employee_name", "required":false, "dataType":"string"}]}]}, "COM":{"code":"COM", "tag":"Communication_contact", "fields":[{"tag":"code", "required":true, "repeat":false}, {"tag":"COMMUNICATION_CONTACT", "dataType":"composite", "required":false, "repeat":true, "components":[{"tag":"Communication_address_identifier", "required":true, "dataType":"string"}, {"tag":"Communication_address_code_qualifier", "required":true, "dataType":"string"}]}]}, "TAX":{"code":"TAX", "tag":"Duty_tax_fee_details", "fields":[{"tag":"code", "required":true, "repeat":false}, {"tag":"DUTY_OR_TAX_OR_FEE_FUNCTION_CODE_QUALIFIER", "dataType":"string", "required":false, "repeat":false, "components":[]}, {"tag":"DUTY_TAX_FEE_TYPE", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Duty_or_tax_or_fee_type_name_code", "required":false, "dataType":"string"}, {"tag":"Code_list_identification_code", "required":false, "dataType":"string"}, {"tag":"Code_list_responsible_agency_code", "required":false, "dataType":"string"}, {"tag":"Duty_or_tax_or_fee_type_name", "required":false, "dataType":"string"}]}, {"tag":"DUTY_TAX_FEE_ACCOUNT_DETAIL", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Duty_or_tax_or_fee_account_code", "required":true, "dataType":"string"}, {"tag":"Code_list_identification_code", "required":false, "dataType":"string"}, {"tag":"Code_list_responsible_agency_code", "required":false, "dataType":"string"}]}, {"tag":"DUTY_TAX_FEE_DETAIL", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Duty_or_tax_or_fee_rate_code", "required":false, "dataType":"string"}, {"tag":"Code_list_identification_code", "required":false, "dataType":"string"}, {"tag":"Code_list_responsible_agency_code", "required":false, "dataType":"string"}, {"tag":"Duty_or_tax_or_fee_rate", "required":false, "dataType":"string"}, {"tag":"Duty_or_tax_or_fee_rate_basis_code", "required":false, "dataType":"string"}, {"tag":"Code_list_identification_code_5", "required":false, "dataType":"string"}, {"tag":"Code_list_responsible_agency_code_6", "required":false, "dataType":"string"}]}, {"tag":"DUTY_OR_TAX_OR_FEE_CATEGORY_CODE", "dataType":"string", "required":false, "repeat":false, "components":[]}, {"tag":"PARTY_TAX_IDENTIFIER", "dataType":"string", "required":false, "repeat":false, "components":[]}, {"tag":"CALCULATION_SEQUENCE_CODE", "dataType":"string", "required":false, "repeat":false, "components":[]}]}, "MOA":{"code":"MOA", "tag":"Monetary_amount", "fields":[{"tag":"code", "required":true, "repeat":false}, {"tag":"MONETARY_AMOUNT", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Monetary_amount_type_code_qualifier", "required":true, "dataType":"string"}, {"tag":"Monetary_amount", "required":false, "dataType":"int"}, {"tag":"Currency_identification_code", "required":false, "dataType":"string"}, {"tag":"Currency_type_code_qualifier", "required":false, "dataType":"string"}, {"tag":"Status_description_code", "required":false, "dataType":"string"}]}]}, "CUX":{"code":"CUX", "tag":"Currencies", "fields":[{"tag":"code", "required":true, "repeat":false}, {"tag":"CURRENCY_DETAILS", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Currency_usage_code_qualifier", "required":true, "dataType":"string"}, {"tag":"Currency_identification_code", "required":false, "dataType":"string"}, {"tag":"Currency_type_code_qualifier", "required":false, "dataType":"string"}, {"tag":"Currency_rate", "required":false, "dataType":"int"}]}, {"tag":"CURRENCY_DETAILS_1", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Currency_usage_code_qualifier", "required":true, "dataType":"string"}, {"tag":"Currency_identification_code", "required":false, "dataType":"string"}, {"tag":"Currency_type_code_qualifier", "required":false, "dataType":"string"}, {"tag":"Currency_rate", "required":false, "dataType":"int"}]}, {"tag":"CURRENCY_EXCHANGE_RATE", "dataType":"int", "required":false, "repeat":false, "components":[]}, {"tag":"EXCHANGE_RATE_CURRENCY_MARKET_IDENTIFIER", "dataType":"string", "required":false, "repeat":false, "components":[]}]}, "PCD":{"code":"PCD", "tag":"Percentage_details", "fields":[{"tag":"code", "required":true, "repeat":false}, {"tag":"PERCENTAGE_DETAILS", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Percentage_type_code_qualifier", "required":true, "dataType":"string"}, {"tag":"Percentage", "required":false, "dataType":"int"}, {"tag":"Percentage_basis_identification_code", "required":false, "dataType":"string"}, {"tag":"Code_list_identification_code", "required":false, "dataType":"string"}, {"tag":"Code_list_responsible_agency_code", "required":false, "dataType":"string"}]}, {"tag":"STATUS_DESCRIPTION_CODE", "dataType":"string", "required":false, "repeat":false, "components":[]}]}, "PYT":{"code":"PYT", "tag":"Payment_terms", "fields":[{"tag":"code", "required":true, "repeat":false}, {"tag":"PAYMENT_TERMS_TYPE_CODE_QUALIFIER", "dataType":"string", "required":false, "repeat":false, "components":[]}, {"tag":"PAYMENT_TERMS", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Payment_terms_description_identifier", "required":false, "dataType":"string"}, {"tag":"Code_list_identification_code", "required":false, "dataType":"string"}, {"tag":"Code_list_responsible_agency_code", "required":false, "dataType":"string"}, {"tag":"Payment_terms_description", "required":false, "dataType":"string"}]}, {"tag":"TIME_REFERENCE_CODE", "dataType":"string", "required":false, "repeat":false, "components":[]}, {"tag":"TERMS_TIME_RELATION_CODE", "dataType":"string", "required":false, "repeat":false, "components":[]}, {"tag":"PERIOD_TYPE_CODE", "dataType":"string", "required":false, "repeat":false, "components":[]}, {"tag":"PERIOD_COUNT_QUANTITY", "dataType":"int", "required":false, "repeat":false, "components":[]}]}, "RJL":{"code":"RJL", "tag":"Accounting_journal_identification", "fields":[{"tag":"code", "required":true, "repeat":false}, {"tag":"ACCOUNTING_JOURNAL_IDENTIFICATION", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Accounting_journal_identifier", "required":true, "dataType":"string"}, {"tag":"Code_list_identification_code", "required":false, "dataType":"string"}, {"tag":"Code_list_responsible_agency_code", "required":false, "dataType":"string"}, {"tag":"Accounting_journal_name", "required":false, "dataType":"string"}]}, {"tag":"ACCOUNTING_ENTRY_TYPE_DETAILS", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Accounting_entry_type_name_code", "required":true, "dataType":"string"}, {"tag":"Code_list_identification_code", "required":false, "dataType":"string"}, {"tag":"Code_list_responsible_agency_code", "required":false, "dataType":"string"}, {"tag":"Accounting_entry_type_name", "required":false, "dataType":"string"}]}]}, "TDT":{"code":"TDT", "tag":"Transport_information", "fields":[{"tag":"code", "required":true, "repeat":false}, {"tag":"TRANSPORT_STAGE_CODE_QUALIFIER", "dataType":"string", "required":false, "repeat":false, "components":[]}, {"tag":"MEANS_OF_TRANSPORT_JOURNEY_IDENTIFIER", "dataType":"string", "required":false, "repeat":false, "components":[]}, {"tag":"MODE_OF_TRANSPORT", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Transport_mode_name_code", "required":false, "dataType":"string"}, {"tag":"Transport_mode_name", "required":false, "dataType":"string"}]}, {"tag":"TRANSPORT_MEANS", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Transport_means_description_code", "required":false, "dataType":"string"}, {"tag":"Code_list_identification_code", "required":false, "dataType":"string"}, {"tag":"Code_list_responsible_agency_code", "required":false, "dataType":"string"}, {"tag":"Transport_means_description", "required":false, "dataType":"string"}]}, {"tag":"CARRIER", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Carrier_identifier", "required":false, "dataType":"string"}, {"tag":"Code_list_identification_code", "required":false, "dataType":"string"}, {"tag":"Code_list_responsible_agency_code", "required":false, "dataType":"string"}, {"tag":"Carrier_name", "required":false, "dataType":"string"}]}, {"tag":"TRANSIT_DIRECTION_INDICATOR_CODE", "dataType":"string", "required":false, "repeat":false, "components":[]}, {"tag":"EXCESS_TRANSPORTATION_INFORMATION", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Excess_transportation_reason_code", "required":true, "dataType":"string"}, {"tag":"Excess_transportation_responsibility_code", "required":true, "dataType":"string"}, {"tag":"Customer_shipment_authorisation_identifier", "required":false, "dataType":"string"}]}, {"tag":"TRANSPORT_IDENTIFICATION", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Transport_means_identification_name_identifier", "required":false, "dataType":"string"}, {"tag":"Code_list_identification_code", "required":false, "dataType":"string"}, {"tag":"Code_list_responsible_agency_code", "required":false, "dataType":"string"}, {"tag":"Transport_means_identification_name", "required":false, "dataType":"string"}, {"tag":"Transport_means_nationality_code", "required":false, "dataType":"string"}]}, {"tag":"TRANSPORT_MEANS_OWNERSHIP_INDICATOR_CODE", "dataType":"string", "required":false, "repeat":false, "components":[]}]}, "TOD":{"code":"TOD", "tag":"Terms_of_delivery_or_transport", "fields":[{"tag":"code", "required":true, "repeat":false}, {"tag":"DELIVERY_OR_TRANSPORT_TERMS_FUNCTION_CODE", "dataType":"string", "required":false, "repeat":false, "components":[]}, {"tag":"TRANSPORT_CHARGES_PAYMENT_METHOD_CODE", "dataType":"string", "required":false, "repeat":false, "components":[]}, {"tag":"TERMS_OF_DELIVERY_OR_TRANSPORT", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Delivery_or_transport_terms_description_code", "required":false, "dataType":"string"}, {"tag":"Code_list_identification_code", "required":false, "dataType":"string"}, {"tag":"Code_list_responsible_agency_code", "required":false, "dataType":"string"}, {"tag":"Delivery_or_transport_terms_description", "required":false, "dataType":"string"}, {"tag":"Delivery_or_transport_terms_description_4", "required":false, "dataType":"string"}]}]}, "PAC":{"code":"PAC", "tag":"Package", "fields":[{"tag":"code", "required":true, "repeat":false}, {"tag":"PACKAGE_QUANTITY", "dataType":"int", "required":false, "repeat":false, "components":[]}, {"tag":"PACKAGING_DETAILS", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Packaging_level_code", "required":false, "dataType":"string"}, {"tag":"Packaging_related_description_code", "required":false, "dataType":"string"}, {"tag":"Packaging_terms_and_conditions_code", "required":false, "dataType":"string"}]}, {"tag":"PACKAGE_TYPE", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Package_type_description_code", "required":false, "dataType":"string"}, {"tag":"Code_list_identification_code", "required":false, "dataType":"string"}, {"tag":"Code_list_responsible_agency_code", "required":false, "dataType":"string"}, {"tag":"Type_of_packages", "required":false, "dataType":"string"}]}, {"tag":"PACKAGE_TYPE_IDENTIFICATION", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Description_format_code", "required":true, "dataType":"string"}, {"tag":"Type_of_packages", "required":true, "dataType":"string"}, {"tag":"Item_type_identification_code", "required":false, "dataType":"string"}, {"tag":"Type_of_packages_3", "required":false, "dataType":"string"}, {"tag":"Item_type_identification_code_4", "required":false, "dataType":"string"}]}, {"tag":"RETURNABLE_PACKAGE_DETAILS", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Returnable_package_freight_payment_responsibility_code", "required":false, "dataType":"string"}, {"tag":"Returnable_package_load_contents_code", "required":false, "dataType":"string"}]}]}, "MEA":{"code":"MEA", "tag":"Measurements", "fields":[{"tag":"code", "required":true, "repeat":false}, {"tag":"MEASUREMENT_PURPOSE_CODE_QUALIFIER", "dataType":"string", "required":false, "repeat":false, "components":[]}, {"tag":"MEASUREMENT_DETAILS", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Measured_attribute_code", "required":false, "dataType":"string"}, {"tag":"Measurement_significance_code", "required":false, "dataType":"string"}, {"tag":"Non_discrete_measurement_name_code", "required":false, "dataType":"string"}, {"tag":"Non_discrete_measurement_name", "required":false, "dataType":"string"}]}, {"tag":"VALUE_RANGE", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Measurement_unit_code", "required":true, "dataType":"string"}, {"tag":"Measure", "required":false, "dataType":"string"}, {"tag":"Range_minimum_quantity", "required":false, "dataType":"int"}, {"tag":"Range_maximum_quantity", "required":false, "dataType":"int"}, {"tag":"Significant_digits_quantity", "required":false, "dataType":"int"}]}, {"tag":"SURFACE_OR_LAYER_CODE", "dataType":"string", "required":false, "repeat":false, "components":[]}]}, "PCI":{"code":"PCI", "tag":"Package_identification", "fields":[{"tag":"code", "required":true, "repeat":false}, {"tag":"MARKING_INSTRUCTIONS_CODE", "dataType":"string", "required":false, "repeat":false, "components":[]}, {"tag":"MARKS___LABELS", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Shipping_marks_description", "required":true, "dataType":"string"}, {"tag":"Shipping_marks_description_1", "required":false, "dataType":"string"}, {"tag":"Shipping_marks_description_2", "required":false, "dataType":"string"}, {"tag":"Shipping_marks_description_3", "required":false, "dataType":"string"}, {"tag":"Shipping_marks_description_4", "required":false, "dataType":"string"}, {"tag":"Shipping_marks_description_5", "required":false, "dataType":"string"}, {"tag":"Shipping_marks_description_6", "required":false, "dataType":"string"}, {"tag":"Shipping_marks_description_7", "required":false, "dataType":"string"}, {"tag":"Shipping_marks_description_8", "required":false, "dataType":"string"}, {"tag":"Shipping_marks_description_9", "required":false, "dataType":"string"}]}, {"tag":"TYPE_OF_MARKING", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Marking_type_code", "required":true, "dataType":"string"}, {"tag":"Code_list_identification_code", "required":false, "dataType":"string"}, {"tag":"Code_list_responsible_agency_code", "required":false, "dataType":"string"}]}]}, "GIN":{"code":"GIN", "tag":"Goods_identity_number", "fields":[{"tag":"code", "required":true, "repeat":false}, {"tag":"OBJECT_IDENTIFICATION_CODE_QUALIFIER", "dataType":"string", "required":false, "repeat":false, "components":[]}, {"tag":"IDENTITY_NUMBER_RANGE", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Object_identifier", "required":true, "dataType":"string"}, {"tag":"Object_identifier_1", "required":false, "dataType":"string"}]}, {"tag":"IDENTITY_NUMBER_RANGE_2", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Object_identifier", "required":true, "dataType":"string"}, {"tag":"Object_identifier_1", "required":false, "dataType":"string"}]}, {"tag":"IDENTITY_NUMBER_RANGE_3", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Object_identifier", "required":true, "dataType":"string"}, {"tag":"Object_identifier_1", "required":false, "dataType":"string"}]}, {"tag":"IDENTITY_NUMBER_RANGE_4", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Object_identifier", "required":true, "dataType":"string"}, {"tag":"Object_identifier_1", "required":false, "dataType":"string"}]}, {"tag":"IDENTITY_NUMBER_RANGE_5", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Object_identifier", "required":true, "dataType":"string"}, {"tag":"Object_identifier_1", "required":false, "dataType":"string"}]}]}, "EQD":{"code":"EQD", "tag":"Equipment_details", "fields":[{"tag":"code", "required":true, "repeat":false}, {"tag":"EQUIPMENT_TYPE_CODE_QUALIFIER", "dataType":"string", "required":false, "repeat":false, "components":[]}, {"tag":"EQUIPMENT_IDENTIFICATION", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Equipment_identifier", "required":false, "dataType":"string"}, {"tag":"Code_list_identification_code", "required":false, "dataType":"string"}, {"tag":"Code_list_responsible_agency_code", "required":false, "dataType":"string"}, {"tag":"Country_name_code", "required":false, "dataType":"string"}]}, {"tag":"EQUIPMENT_SIZE_AND_TYPE", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Equipment_size_and_type_description_code", "required":false, "dataType":"string"}, {"tag":"Code_list_identification_code", "required":false, "dataType":"string"}, {"tag":"Code_list_responsible_agency_code", "required":false, "dataType":"string"}, {"tag":"Equipment_size_and_type_description", "required":false, "dataType":"string"}]}, {"tag":"EQUIPMENT_SUPPLIER_CODE", "dataType":"string", "required":false, "repeat":false, "components":[]}, {"tag":"EQUIPMENT_STATUS_CODE", "dataType":"string", "required":false, "repeat":false, "components":[]}, {"tag":"FULL_OR_EMPTY_INDICATOR_CODE", "dataType":"string", "required":false, "repeat":false, "components":[]}]}, "HAN":{"code":"HAN", "tag":"Handling_instructions", "fields":[{"tag":"code", "required":true, "repeat":false}, {"tag":"HANDLING_INSTRUCTIONS", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Handling_instruction_description_code", "required":false, "dataType":"string"}, {"tag":"Code_list_identification_code", "required":false, "dataType":"string"}, {"tag":"Code_list_responsible_agency_code", "required":false, "dataType":"string"}, {"tag":"Handling_instruction_description", "required":false, "dataType":"string"}]}, {"tag":"HAZARDOUS_MATERIAL", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Hazardous_material_category_name_code", "required":false, "dataType":"string"}, {"tag":"Code_list_identification_code", "required":false, "dataType":"string"}, {"tag":"Code_list_responsible_agency_code", "required":false, "dataType":"string"}, {"tag":"Hazardous_material_category_name", "required":false, "dataType":"string"}]}]}, "SCC":{"code":"SCC", "tag":"Scheduling_conditions", "fields":[{"tag":"code", "required":true, "repeat":false}, {"tag":"DELIVERY_PLAN_COMMITMENT_LEVEL_CODE", "dataType":"string", "required":false, "repeat":false, "components":[]}, {"tag":"DELIVERY_INSTRUCTION_CODE", "dataType":"string", "required":false, "repeat":false, "components":[]}, {"tag":"PATTERN_DESCRIPTION", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Frequency_code", "required":false, "dataType":"string"}, {"tag":"Despatch_pattern_code", "required":false, "dataType":"string"}, {"tag":"Despatch_pattern_timing_code", "required":false, "dataType":"string"}]}]}, "QTY":{"code":"QTY", "tag":"Quantity", "fields":[{"tag":"code", "required":true, "repeat":false}, {"tag":"QUANTITY_DETAILS", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Quantity_type_code_qualifier", "required":true, "dataType":"string"}, {"tag":"Quantity", "required":true, "dataType":"string"}, {"tag":"Measurement_unit_code", "required":false, "dataType":"string"}]}]}, "APR":{"code":"APR", "tag":"Additional_price_information", "fields":[{"tag":"code", "required":true, "repeat":false}, {"tag":"TRADE_CLASS_CODE", "dataType":"string", "required":false, "repeat":false, "components":[]}, {"tag":"PRICE_MULTIPLIER_INFORMATION", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Price_multiplier_rate", "required":true, "dataType":"int"}, {"tag":"Price_multiplier_type_code_qualifier", "required":false, "dataType":"string"}]}, {"tag":"REASON_FOR_CHANGE", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Change_reason_description_code", "required":false, "dataType":"string"}, {"tag":"Code_list_identification_code", "required":false, "dataType":"string"}, {"tag":"Code_list_responsible_agency_code", "required":false, "dataType":"string"}, {"tag":"Change_reason_description", "required":false, "dataType":"string"}]}]}, "RNG":{"code":"RNG", "tag":"Range_details", "fields":[{"tag":"code", "required":true, "repeat":false}, {"tag":"RANGE_TYPE_CODE_QUALIFIER", "dataType":"string", "required":false, "repeat":false, "components":[]}, {"tag":"RANGE", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Measurement_unit_code", "required":true, "dataType":"string"}, {"tag":"Range_minimum_quantity", "required":false, "dataType":"int"}, {"tag":"Range_maximum_quantity", "required":false, "dataType":"int"}]}]}, "ALC":{"code":"ALC", "tag":"Allowance_or_charge", "fields":[{"tag":"code", "required":true, "repeat":false}, {"tag":"ALLOWANCE_OR_CHARGE_CODE_QUALIFIER", "dataType":"string", "required":false, "repeat":false, "components":[]}, {"tag":"ALLOWANCE_CHARGE_INFORMATION", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Allowance_or_charge_identifier", "required":false, "dataType":"string"}, {"tag":"Allowance_or_charge_identification_code", "required":false, "dataType":"string"}]}, {"tag":"SETTLEMENT_MEANS_CODE", "dataType":"string", "required":false, "repeat":false, "components":[]}, {"tag":"CALCULATION_SEQUENCE_CODE", "dataType":"string", "required":false, "repeat":false, "components":[]}, {"tag":"SPECIAL_SERVICES_IDENTIFICATION", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Special_service_description_code", "required":false, "dataType":"string"}, {"tag":"Code_list_identification_code", "required":false, "dataType":"string"}, {"tag":"Code_list_responsible_agency_code", "required":false, "dataType":"string"}, {"tag":"Special_service_description", "required":false, "dataType":"string"}, {"tag":"Special_service_description_4", "required":false, "dataType":"string"}]}]}, "RTE":{"code":"RTE", "tag":"Rate_details", "fields":[{"tag":"code", "required":true, "repeat":false}, {"tag":"RATE_DETAILS", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Rate_type_code_qualifier", "required":true, "dataType":"string"}, {"tag":"Unit_price_basis_rate", "required":true, "dataType":"int"}, {"tag":"Unit_price_basis_quantity", "required":false, "dataType":"int"}, {"tag":"Measurement_unit_code", "required":false, "dataType":"string"}]}, {"tag":"STATUS_DESCRIPTION_CODE", "dataType":"string", "required":false, "repeat":false, "components":[]}]}, "RCS":{"code":"RCS", "tag":"Requirements_and_conditions", "fields":[{"tag":"code", "required":true, "repeat":false}, {"tag":"SECTOR_AREA_IDENTIFICATION_CODE_QUALIFIER", "dataType":"string", "required":false, "repeat":false, "components":[]}, {"tag":"REQUIREMENT_CONDITION_IDENTIFICATION", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Requirement_or_condition_description_identifier", "required":true, "dataType":"string"}, {"tag":"Code_list_identification_code", "required":false, "dataType":"string"}, {"tag":"Code_list_responsible_agency_code", "required":false, "dataType":"string"}, {"tag":"Requirement_or_condition_description", "required":false, "dataType":"string"}]}, {"tag":"COUNTRY_NAME_CODE", "dataType":"string", "required":false, "repeat":false, "components":[]}]}, "DGS":{"code":"DGS", "tag":"Dangerous_goods", "fields":[{"tag":"code", "required":true, "repeat":false}, {"tag":"DANGEROUS_GOODS_REGULATIONS_CODE", "dataType":"string", "required":false, "repeat":false, "components":[]}, {"tag":"HAZARD_CODE", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Hazard_identification_code", "required":true, "dataType":"string"}, {"tag":"Additional_hazard_classification_identifier", "required":false, "dataType":"string"}, {"tag":"Hazard_code_version_identifier", "required":false, "dataType":"string"}]}, {"tag":"UNDG_INFORMATION", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Dangerous_goods_flashpoint_description", "required":false, "dataType":"string"}]}, {"tag":"DANGEROUS_GOODS_SHIPMENT_FLASHPOINT", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Shipment_flashpoint_degree", "required":false}, {"tag":"Measurement_unit_code", "required":false, "dataType":"string"}]}, {"tag":"PACKAGING_DANGER_LEVEL_CODE", "dataType":"string", "required":false, "repeat":false, "components":[]}, {"tag":"EMERGENCY_PROCEDURE_FOR_SHIPS_IDENTIFIER", "dataType":"string", "required":false, "repeat":false, "components":[]}, {"tag":"HAZARD_MEDICAL_FIRST_AID_GUIDE_IDENTIFIER", "dataType":"string", "required":false, "repeat":false, "components":[]}, {"tag":"TRANSPORT_EMERGENCY_CARD_IDENTIFIER", "dataType":"string", "required":false, "repeat":false, "components":[]}, {"tag":"HAZARD_IDENTIFICATION_PLACARD_DETAILS", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Orange_hazard_placard_upper_part_identifier", "required":false, "dataType":"string"}, {"tag":"Orange_hazard_placard_lower_part_identifier", "required":false}]}, {"tag":"DANGEROUS_GOODS_LABEL", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Dangerous_goods_marking_identifier", "required":false, "dataType":"string"}, {"tag":"Dangerous_goods_marking_identifier_1", "required":false, "dataType":"string"}, {"tag":"Dangerous_goods_marking_identifier_2", "required":false, "dataType":"string"}]}, {"tag":"PACKING_INSTRUCTION_TYPE_CODE", "dataType":"string", "required":false, "repeat":false, "components":[]}, {"tag":"HAZARDOUS_MEANS_OF_TRANSPORT_CATEGORY_CODE", "dataType":"string", "required":false, "repeat":false, "components":[]}]}, "LIN":{"code":"LIN", "tag":"Line_item", "fields":[{"tag":"code", "required":true, "repeat":false}, {"tag":"LINE_ITEM_IDENTIFIER", "dataType":"string", "required":false, "repeat":false, "components":[]}, {"tag":"ITEM_NUMBER_IDENTIFICATION", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Item_identifier", "required":false, "dataType":"string"}, {"tag":"Item_type_identification_code", "required":false, "dataType":"string"}, {"tag":"Code_list_identification_code", "required":false, "dataType":"string"}, {"tag":"Code_list_responsible_agency_code", "required":false, "dataType":"string"}]}, {"tag":"SUB_LINE_INFORMATION", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Sub_line_indicator_code", "required":false, "dataType":"string"}, {"tag":"Line_item_identifier", "required":false, "dataType":"string"}]}, {"tag":"CONFIGURATION_LEVEL_NUMBER", "dataType":"int", "required":false, "repeat":false, "components":[]}, {"tag":"CONFIGURATION_OPERATION_CODE", "dataType":"string", "required":false, "repeat":false, "components":[]}]}, "PIA":{"code":"PIA", "tag":"Additional_product_id", "fields":[{"tag":"code", "required":true, "repeat":false}, {"tag":"PRODUCT_IDENTIFIER_CODE_QUALIFIER", "dataType":"string", "required":false, "repeat":false, "components":[]}, {"tag":"ITEM_NUMBER_IDENTIFICATION", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Item_identifier", "required":false, "dataType":"string"}, {"tag":"Item_type_identification_code", "required":false, "dataType":"string"}, {"tag":"Code_list_identification_code", "required":false, "dataType":"string"}, {"tag":"Code_list_responsible_agency_code", "required":false, "dataType":"string"}]}, {"tag":"ITEM_NUMBER_IDENTIFICATION_2", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Item_identifier", "required":false, "dataType":"string"}, {"tag":"Item_type_identification_code", "required":false, "dataType":"string"}, {"tag":"Code_list_identification_code", "required":false, "dataType":"string"}, {"tag":"Code_list_responsible_agency_code", "required":false, "dataType":"string"}]}, {"tag":"ITEM_NUMBER_IDENTIFICATION_3", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Item_identifier", "required":false, "dataType":"string"}, {"tag":"Item_type_identification_code", "required":false, "dataType":"string"}, {"tag":"Code_list_identification_code", "required":false, "dataType":"string"}, {"tag":"Code_list_responsible_agency_code", "required":false, "dataType":"string"}]}, {"tag":"ITEM_NUMBER_IDENTIFICATION_4", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Item_identifier", "required":false, "dataType":"string"}, {"tag":"Item_type_identification_code", "required":false, "dataType":"string"}, {"tag":"Code_list_identification_code", "required":false, "dataType":"string"}, {"tag":"Code_list_responsible_agency_code", "required":false, "dataType":"string"}]}, {"tag":"ITEM_NUMBER_IDENTIFICATION_5", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Item_identifier", "required":false, "dataType":"string"}, {"tag":"Item_type_identification_code", "required":false, "dataType":"string"}, {"tag":"Code_list_identification_code", "required":false, "dataType":"string"}, {"tag":"Code_list_responsible_agency_code", "required":false, "dataType":"string"}]}]}, "GEI":{"code":"GEI", "tag":"Processing_information", "fields":[{"tag":"code", "required":true, "repeat":false}, {"tag":"PROCESSING_INFORMATION_CODE_QUALIFIER", "dataType":"string", "required":false, "repeat":false, "components":[]}, {"tag":"PROCESSING_INDICATOR", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Processing_indicator_description_code", "required":false, "dataType":"string"}, {"tag":"Code_list_identification_code", "required":false, "dataType":"string"}, {"tag":"Code_list_responsible_agency_code", "required":false, "dataType":"string"}, {"tag":"Processing_indicator_description", "required":false, "dataType":"string"}]}, {"tag":"PROCESS_TYPE_DESCRIPTION_CODE", "dataType":"string", "required":false, "repeat":false, "components":[]}]}, "QVR":{"code":"QVR", "tag":"Quantity_variances", "fields":[{"tag":"code", "required":true, "repeat":false}, {"tag":"QUANTITY_DIFFERENCE_INFORMATION", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Variance_quantity", "required":true, "dataType":"int"}, {"tag":"Quantity_type_code_qualifier", "required":false, "dataType":"string"}]}, {"tag":"DISCREPANCY_NATURE_IDENTIFICATION_CODE", "dataType":"string", "required":false, "repeat":false, "components":[]}, {"tag":"REASON_FOR_CHANGE", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Change_reason_description_code", "required":false, "dataType":"string"}, {"tag":"Code_list_identification_code", "required":false, "dataType":"string"}, {"tag":"Code_list_responsible_agency_code", "required":false, "dataType":"string"}, {"tag":"Change_reason_description", "required":false, "dataType":"string"}]}]}, "MTD":{"code":"MTD", "tag":"Maintenance_operation_details", "fields":[{"tag":"code", "required":true, "repeat":false}, {"tag":"OBJECT_TYPE_CODE_QUALIFIER", "dataType":"string", "required":false, "repeat":false, "components":[]}, {"tag":"MAINTENANCE_OPERATION_CODE", "dataType":"string", "required":false, "repeat":false, "components":[]}, {"tag":"MAINTENANCE_OPERATION_OPERATOR_CODE", "dataType":"string", "required":false, "repeat":false, "components":[]}, {"tag":"MAINTENANCE_OPERATION_PAYER_CODE", "dataType":"string", "required":false, "repeat":false, "components":[]}]}, "CCI":{"code":"CCI", "tag":"Characteristic_class_id", "fields":[{"tag":"code", "required":true, "repeat":false}, {"tag":"CLASS_TYPE_CODE", "dataType":"string", "required":false, "repeat":false, "components":[]}, {"tag":"MEASUREMENT_DETAILS", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Measured_attribute_code", "required":false, "dataType":"string"}, {"tag":"Measurement_significance_code", "required":false, "dataType":"string"}, {"tag":"Non_discrete_measurement_name_code", "required":false, "dataType":"string"}, {"tag":"Non_discrete_measurement_name", "required":false, "dataType":"string"}]}, {"tag":"CHARACTERISTIC_DESCRIPTION", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Characteristic_description_code", "required":true, "dataType":"string"}, {"tag":"Code_list_identification_code", "required":false, "dataType":"string"}, {"tag":"Code_list_responsible_agency_code", "required":false, "dataType":"string"}, {"tag":"Characteristic_description", "required":false, "dataType":"string"}, {"tag":"Characteristic_description_4", "required":false, "dataType":"string"}]}, {"tag":"CHARACTERISTIC_RELEVANCE_CODE", "dataType":"string", "required":false, "repeat":false, "components":[]}]}, "CAV":{"code":"CAV", "tag":"Characteristic_value", "fields":[{"tag":"code", "required":true, "repeat":false}, {"tag":"CHARACTERISTIC_VALUE", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Characteristic_value_description_code", "required":false, "dataType":"string"}, {"tag":"Code_list_identification_code", "required":false, "dataType":"string"}, {"tag":"Code_list_responsible_agency_code", "required":false, "dataType":"string"}, {"tag":"Characteristic_value_description", "required":false, "dataType":"string"}, {"tag":"Characteristic_value_description_4", "required":false, "dataType":"string"}]}]}, "PRI":{"code":"PRI", "tag":"Price_details", "fields":[{"tag":"code", "required":true, "repeat":false}, {"tag":"PRICE_INFORMATION", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Price_code_qualifier", "required":true, "dataType":"string"}, {"tag":"Price_amount", "required":false, "dataType":"int"}, {"tag":"Price_type_code", "required":false, "dataType":"string"}, {"tag":"Price_specification_code", "required":false, "dataType":"string"}, {"tag":"Unit_price_basis_quantity", "required":false, "dataType":"int"}, {"tag":"Measurement_unit_code", "required":false, "dataType":"string"}]}, {"tag":"SUB_LINE_ITEM_PRICE_CHANGE_OPERATION_CODE", "dataType":"string", "required":false, "repeat":false, "components":[]}]}, "STG":{"code":"STG", "tag":"Stages", "fields":[{"tag":"code", "required":true, "repeat":false}, {"tag":"PROCESS_STAGE_CODE_QUALIFIER", "dataType":"string", "required":false, "repeat":false, "components":[]}, {"tag":"PROCESS_STAGES_QUANTITY", "dataType":"int", "required":false, "repeat":false, "components":[]}, {"tag":"PROCESS_STAGES_ACTUAL_QUANTITY", "dataType":"int", "required":false, "repeat":false, "components":[]}]}, "UNS":{"code":"UNS", "tag":"section_control", "fields":[{"tag":"code", "required":true, "repeat":false}, {"tag":"section_identification", "dataType":"string", "required":true, "repeat":false}]}, "CNT":{"code":"CNT", "tag":"Control_total", "fields":[{"tag":"code", "required":true, "repeat":false}, {"tag":"CONTROL", "dataType":"composite", "required":false, "repeat":false, "components":[{"tag":"Control_total_type_code_qualifier", "required":true, "dataType":"string"}, {"tag":"Control_total_quantity", "required":true, "dataType":"int"}, {"tag":"Measurement_unit_code", "required":false, "dataType":"string"}]}]}, "UNT":{"code":"UNT", "tag":"message_trailer", "fields":[{"tag":"code", "required":true, "repeat":false}, {"tag":"number1", "dataType":"string", "required":false, "repeat":false}, {"tag":"number2", "dataType":"string", "required":false, "repeat":false}]}, "UNB":{"code":"UNB", "tag":"interchange_header", "fields":[{"tag":"code", "required":true, "repeat":false}, {"tag":"syntax_identifier", "dataType":"composite", "required":true, "repeat":false, "components":[{"tag":"syntax_id", "required":true, "dataType":"string"}, {"tag":"syntax_version", "required":true, "dataType":"string"}]}, {"tag":"sender", "dataType":"composite", "required":true, "repeat":false, "components":[{"tag":"id", "required":true, "dataType":"string"}, {"tag":"qualifier", "required":false, "dataType":"string"}]}, {"tag":"recipient", "dataType":"composite", "required":true, "repeat":false, "components":[{"tag":"id", "required":true, "dataType":"string"}, {"tag":"qualifier", "required":false, "dataType":"string"}]}, {"tag":"date_and_time", "dataType":"composite", "required":true, "repeat":false, "components":[{"tag":"date", "required":true, "dataType":"string"}, {"tag":"time", "required":true, "dataType":"string"}]}, {"tag":"control_reference", "dataType":"string", "required":true, "repeat":false}, {"tag":"recipient_reference_password", "dataType":"string", "required":false, "repeat":false}, {"tag":"application_reference", "dataType":"string", "required":false, "repeat":false}, {"tag":"processing_priority_code", "dataType":"string", "required":false, "repeat":false}, {"tag":"acknowledgement_request", "dataType":"string", "required":false, "repeat":false}, {"tag":"communications_agreement_id", "dataType":"string", "required":false, "repeat":false}, {"tag":"test_indicator", "dataType":"string", "required":false, "repeat":false}]}, "UNZ":{"code":"UNZ", "tag":"interchange_trailer", "fields":[{"tag":"code", "required":true, "repeat":false}, {"tag":"interchange_control_count", "dataType":"int", "required":true, "repeat":false}, {"tag":"interchange_control_reference", "dataType":"string", "required":true, "repeat":false}]}}};
    