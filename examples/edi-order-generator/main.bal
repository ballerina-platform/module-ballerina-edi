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
import ballerina/ftp;

import wso2/edi_order_generator.orders;

configurable string sftpHost = "localhost";
configurable int sftpPort = 2222;
configurable string sftpUser = "wso2";
configurable string sftpPassword = "wso2123";
configurable string outboundPath = "/edi/outbound";

public function main() returns error? {
    // 1. Build a purchase order from application data and serialise it to EDI.
    //    interchangeToEdiString re-pads the envelope and recomputes the UNT/UNZ
    //    trailer counts, so we never hand-maintain segment counts.
    orders:ORDERSInterchange interchange = buildOrder("PO20260615");
    string ediText = check orders:interchangeToEdiString(interchange);
    io:println("Generated EDI:\n", ediText, "\n");

    // 2. Deliver to the trading partner's SFTP drop (best effort - the steps
    //    below still run when no SFTP server is available).
    check deliver(ediText, "PO20260615.edi");

    // 3. Round-trip: the generated text re-parses cleanly through the inverse function.
    orders:ORDERSInterchange reparsed = check orders:interchangeFromEdiString(ediText);
    io:println("Round-trip OK. Transactions: ", reparsed.transactions.length());

    // 4. A transaction whose body is an error cannot be serialised.
    demonstrateSerializationError(interchange);
}

// Construct a single-transaction ORDERS interchange from plain inputs.
function buildOrder(string orderId) returns orders:ORDERSInterchange {
    orders:ORDERS body = {
        Beginning_of_message: {
            DOCUMENT_MESSAGE_NAME: {Document_name_code: "220"},
            DOCUMENT_MESSAGE_IDENTIFICATION: {Document_identifier: orderId},
            MESSAGE_FUNCTION_CODE: "9"
        },
        Date_time_period: [
            {DATE_TIME_PERIOD: {Date_or_time_or_period: "137", Date_or_time_or_period_text: "20260615", Date_or_time_or_period_format_code: "102"}}
        ],
        group_2: [
            {Name_and_address: {PARTY_FUNCTION_CODE_QUALIFIER: "BY", PARTY_IDENTIFICATION_DETAILS: {Party_identifier: "BUYER123"}}},
            {Name_and_address: {PARTY_FUNCTION_CODE_QUALIFIER: "SU", PARTY_IDENTIFICATION_DETAILS: {Party_identifier: "ACME"}}}
        ],
        group_28: [
            {Line_item: {LINE_ITEM_IDENTIFIER: "1", ITEM_NUMBER_IDENTIFICATION: {Item_identifier: "ITEM-A", Item_type_identification_code: "VP"}}, Quantity: [{QUANTITY_DETAILS: {Quantity_type_code_qualifier: "21", Quantity: "100"}}]},
            {Line_item: {LINE_ITEM_IDENTIFIER: "2", ITEM_NUMBER_IDENTIFICATION: {Item_identifier: "ITEM-B", Item_type_identification_code: "VP"}}, Quantity: [{QUANTITY_DETAILS: {Quantity_type_code_qualifier: "21", Quantity: "50"}}]}
        ],
        Section_control: {section_identification: "S"}
    };

    return {
        interchangeHeader: {
            interchange_header: {
                syntax_identifier: {syntax_id: "UNOA", syntax_version: "3"},
                sender: {id: "BUYER123", qualifier: "14"},
                recipient: {id: "ACME", qualifier: "14"},
                date_and_time: {date: "260615", time: "1200"},
                control_reference: "REF1"
            }
        },
        transactions: [
            {
                transactionHeader: {Message_header: {message_reference_number: "0001", message_information: {name: "ORDERS", catagory: "D", version: "03A", status: "UN"}}},
                body,
                transactionTrailer: {Message_trailer: {number2: "0001"}}
            }
        ],
        interchangeTrailer: {interchange_trailer: {interchange_control_count: 1, interchange_control_reference: "REF1"}}
    };
}

function deliver(string ediText, string fileName) returns error? {
    ftp:Client|ftp:Error supplierClient = new ({
        protocol: ftp:SFTP,
        host: sftpHost,
        port: sftpPort,
        auth: {credentials: {username: sftpUser, password: sftpPassword}}
    });
    if supplierClient is ftp:Error {
        log:printWarn("SFTP server unavailable; skipping delivery", 'error = supplierClient);
        return;
    }
    check supplierClient->putText(string `${outboundPath}/${fileName}`, ediText);
    log:printInfo("Delivered EDI to supplier", path = string `${outboundPath}/${fileName}`);
}

function demonstrateSerializationError(orders:ORDERSInterchange template) {
    orders:ORDERSInterchange broken = template.clone();
    broken.transactions[0].body = error("simulated upstream parse failure");
    string|error result = orders:interchangeToEdiString(broken);
    if result is error {
        io:println("Refused to serialise transaction with an error body: ", result.message());
    } else {
        io:println("Unexpected: serialisation succeeded");
    }
}
