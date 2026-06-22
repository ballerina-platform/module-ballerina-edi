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

import ballerina/ftp;
import ballerina/log;
import ballerinax/postgresql;
import ballerinax/postgresql.driver as _;

import wso2/edi_parser;

configurable string sftpHost = "localhost";
configurable int sftpPort = 2222;
configurable string sftpUser = ?;
configurable string sftpPassword = ?;
configurable string outboundPath = "/edi/outbound";

configurable string dbHost = "localhost";
configurable int dbPort = 5432;
configurable string dbUser = ?;
configurable string dbPassword = ?;
configurable string dbName = "edi";

// The purchase order to pick from the database and send.
configurable string orderId = "PO20260615";

// Source database holding the purchase orders to send.
final postgresql:Client orderDb = check new (host = dbHost, username = dbUser, password = dbPassword, database = dbName, port = dbPort);

// SFTP client used to deliver the generated EDI to the supplier.
final ftp:Client supplierClient = check new ({
    protocol: ftp:SFTP,
    host: sftpHost,
    port: sftpPort,
    auth: {credentials: {username: sftpUser, password: sftpPassword}}
});

type OrderHeader record {|
    string order_id;
    string buyer_id;
    string supplier_id;
    string order_date;
|};

type OrderItem record {|
    string item_code;
    int quantity;
|};

public function main() returns error? {
    // 1. Pick the order and its line items from the database.
    OrderHeader header = check orderDb->queryRow(
        `SELECT order_id, buyer_id, supplier_id, order_date FROM orders WHERE order_id = ${orderId}`);
    OrderItem[] items = check from OrderItem item in orderDb->query(
            `SELECT item_code, quantity FROM order_items WHERE order_id = ${orderId} ORDER BY line_no`, OrderItem)
        select item;

    // 2. Build a typed ORDERS interchange and serialise it to conforming EDI text.
    edi_parser:ORDERSInterchange interchange = buildOrder(header, items);
    string ediText = check edi_parser:interchangeToEdiString(interchange);

    // 3. Deliver to the trading partner's SFTP drop.
    string fileName = string `${header.order_id}.edi`;
    check supplierClient->putText(string `${outboundPath}/${fileName}`, ediText);
    log:printInfo("Delivered EDI to supplier", file = fileName, items = items.length());
}

// Construct a single-transaction ORDERS interchange from the order read out of the database.
function buildOrder(OrderHeader header, OrderItem[] items) returns edi_parser:ORDERSInterchange {
    edi_parser:Group_28_GType[] lines = [];
    int lineNo = 1;
    foreach OrderItem item in items {
        lines.push({
            Line_item: {LINE_ITEM_IDENTIFIER: lineNo.toString(), ITEM_NUMBER_IDENTIFICATION: {Item_identifier: item.item_code, Item_type_identification_code: "VP"}},
            Quantity: [{QUANTITY_DETAILS: {Quantity_type_code_qualifier: "21", Quantity: item.quantity.toString()}}]
        });
        lineNo += 1;
    }

    edi_parser:ORDERS body = {
        Beginning_of_message: {
            DOCUMENT_MESSAGE_NAME: {Document_name_code: "220"},
            DOCUMENT_MESSAGE_IDENTIFICATION: {Document_identifier: header.order_id},
            MESSAGE_FUNCTION_CODE: "9"
        },
        Date_time_period: [
            {DATE_TIME_PERIOD: {Date_or_time_or_period: "137", Date_or_time_or_period_text: header.order_date, Date_or_time_or_period_format_code: "102"}}
        ],
        group_2: [
            {Name_and_address: {PARTY_FUNCTION_CODE_QUALIFIER: "BY", PARTY_IDENTIFICATION_DETAILS: {Party_identifier: header.buyer_id}}},
            {Name_and_address: {PARTY_FUNCTION_CODE_QUALIFIER: "SU", PARTY_IDENTIFICATION_DETAILS: {Party_identifier: header.supplier_id}}}
        ],
        group_28: lines,
        Section_control: {section_identification: "S"}
    };

    return {
        interchangeHeader: {
            interchange_header: {
                syntax_identifier: {syntax_id: "UNOA", syntax_version: "3"},
                sender: {id: header.buyer_id, qualifier: "14"},
                recipient: {id: header.supplier_id, qualifier: "14"},
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
