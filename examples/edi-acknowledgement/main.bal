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



import ballerina/io;
import ballerina/log;
import ballerina/time;

import ballerinax/edifact.d03a.supplychain.mAPERAK;
import ballerinax/edifact.d03a.supplychain.mORDERS;

configurable string inboundFile = "resources/sample-data/order-batch.edi";
configurable string outboundFile = "resources/outbound/acknowledgement.edi";

// EDIFACT leaves ERC application error codes to the trading partners, so the code list
// responsible agency is "ZZZ" (mutually defined) rather than a UN code list.
const string ERROR_CODE_UNREADABLE = "13";
const string AGENCY_MUTUALLY_DEFINED = "ZZZ";

// Document name code 305 is "application error and acknowledgement"; 220 is "order".
const string DOC_ACKNOWLEDGEMENT = "305";
const string DOC_ORDER = "220";

public function main() returns error? {
    string ediText = check io:fileReadString(inboundFile);

    // 1. Read the inbound interchange. Bodies are fail-safe: a message the schema cannot
    // read leaves its error on that transaction, and the rest of the batch still arrives.
    mORDERS:EDI_ORDERS_ORDERSInterchange orders = check mORDERS:interchangeFromEdiString(ediText);

    // 2. Acknowledge what was read, and report what was not, in a single APERAK.
    mAPERAK:EDI_APERAK_APERAKInterchange ack = buildAcknowledgement(orders);
    string ackText = check mAPERAK:interchangeToEdiString(ack);
    check io:fileWriteString(outboundFile, ackText);

    mAPERAK:EDI_APERAK_APERAK|error ackBody = ack.transactions[0].body;
    if ackBody is mAPERAK:EDI_APERAK_APERAK {
        log:printInfo("Acknowledgement written", file = outboundFile,
                accepted = ackBody.group_1.length(), rejected = ackBody.group_4.length());
    }
}

// Build an APERAK acknowledging one inbound ORDERS interchange: a DOC segment group for
// every order that was read, and an ERC segment group for every message that was not.
function buildAcknowledgement(mORDERS:EDI_ORDERS_ORDERSInterchange orders)
        returns mAPERAK:EDI_APERAK_APERAKInterchange {
    mORDERS:Interchange_header_Type inbound = orders.interchangeHeader.interchange_header;
    time:Civil now = time:utcToCivil(time:utcNow());

    mAPERAK:Group_1_GType[] accepted = [];
    mAPERAK:Group_4_GType[] rejected = [];

    foreach mORDERS:EDI_ORDERS_ORDERSTransaction txn in orders.transactions {
        string messageRef = txn.transactionHeader.Message_header.message_reference_number;
        mORDERS:EDI_ORDERS_ORDERS|error body = txn.body;
        if body is error {
            rejected.push({
                Application_error_information: {
                    APPLICATION_ERROR_DETAIL: {
                        Application_error_code: ERROR_CODE_UNREADABLE,
                        // The component is positional, so the unused code list identifier
                        // is written as an empty component ahead of the agency code.
                        Code_list_identification_code: "",
                        Code_list_responsible_agency_code: AGENCY_MUTUALLY_DEFINED
                    }
                },
                // FTX subject code AAO marks the text as an error description.
                Free_text: {
                    TEXT_SUBJECT_CODE_QUALIFIER: "AAO",
                    TEXT_LITERAL: {Free_text: toFreeText(body.message())}
                },
                group_5: [
                    {Reference: {REFERENCE: {Reference_code_qualifier: "ACW", Reference_identifier: messageRef}}}
                ]
            });
            continue;
        }
        string orderId = body.Beginning_of_message?.DOCUMENT_MESSAGE_IDENTIFICATION?.Document_identifier ?: messageRef;
        accepted.push({
            Document_message_details: {
                DOCUMENT_MESSAGE_NAME: {Document_name_code: DOC_ORDER},
                DOCUMENT_MESSAGE_DETAILS: {Document_identifier: orderId}
            }
        });
    }

    string controlRef = string `ACK${inbound.control_reference}`;
    mAPERAK:EDI_APERAK_APERAK body = {
        Beginning_of_message: {
            DOCUMENT_MESSAGE_NAME: {Document_name_code: DOC_ACKNOWLEDGEMENT},
            DOCUMENT_MESSAGE_IDENTIFICATION: {Document_identifier: controlRef},
            MESSAGE_FUNCTION_CODE: "9"
        },
        Date_time_period: [
            {
                DATE_TIME_PERIOD: {
                    Date_or_time_or_period: "137",
                    Date_or_time_or_period_text: documentDate(now),
                    Date_or_time_or_period_format_code: "102"
                }
            }
        ],
        group_1: accepted,
        // The interchange this APERAK responds to.
        group_2: [
            {Reference: {REFERENCE: {Reference_code_qualifier: "ACW", Reference_identifier: inbound.control_reference}}}
        ],
        // Sender and recipient swap around: the receiver of the orders issues the acknowledgement.
        group_3: [
            {Name_and_address: {PARTY_FUNCTION_CODE_QUALIFIER: "MS", PARTY_IDENTIFICATION_DETAILS: {Party_identifier: inbound.recipient.id}}},
            {Name_and_address: {PARTY_FUNCTION_CODE_QUALIFIER: "MR", PARTY_IDENTIFICATION_DETAILS: {Party_identifier: inbound.sender.id}}}
        ],
        group_4: rejected
    };

    // The UNZ count and the UNT segment count are recomputed by interchangeToEdiString.
    return {
        interchangeHeader: {
            interchange_header: {
                syntax_identifier: {syntax_id: "UNOA", syntax_version: "3"},
                sender: {id: inbound.recipient.id, qualifier: inbound.recipient.qualifier},
                recipient: {id: inbound.sender.id, qualifier: inbound.sender.qualifier},
                date_and_time: {date: interchangeDate(now), time: interchangeTime(now)},
                control_reference: controlRef,
                application_reference: "APERAK"
            }
        },
        transactions: [
            {
                transactionHeader: {
                    Message_header: {
                        message_reference_number: "0001",
                        message_identifier: {
                            message_type: "APERAK",
                            message_version_number: "D",
                            message_release_number: "03A",
                            controlling_agency: "UN"
                        }
                    }
                },
                body,
                transactionTrailer: {Message_trailer: {number_of_segments: 0, message_reference_number: "0001"}}
            }
        ],
        interchangeTrailer: {interchange_trailer: {interchange_control_count: 0, interchange_control_reference: controlRef}}
    };
}

// A parse error reads back as free text, so collapse its line breaks, drop the characters
// EDIFACT reserves as delimiters, and keep it within the FTX component length.
function toFreeText(string message) returns string {
    string plain = re `\s+`.replaceAll(re `[+:'?*]`.replaceAll(message, " "), " ").trim();
    return plain.length() > 70 ? plain.substring(0, 70) : plain;
}

// UNB carries the date as YYMMDD and the time as HHMM. DTM format code 102 is CCYYMMDD.
function interchangeDate(time:Civil ts) returns string =>
    pad(ts.year % 100) + pad(ts.month) + pad(ts.day);

function interchangeTime(time:Civil ts) returns string => pad(ts.hour) + pad(ts.minute);

function documentDate(time:Civil ts) returns string => ts.year.toString() + pad(ts.month) + pad(ts.day);

function pad(int value) returns string => value < 10 ? string `0${value}` : value.toString();
