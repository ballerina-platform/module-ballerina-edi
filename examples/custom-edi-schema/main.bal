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

import wso2/custom_edi_schema.orders;

public function main() returns error? {
    string ediText = check io:fileReadString("sample.edi");

    // Parse with the typed module generated from the customised schema.
    orders:ORDERSInterchange interchange = check orders:interchangeFromEdiString(ediText);
    orders:Message_information_GType? messageInfo =
            interchange.transactions[0].transactionHeader.Message_header?.message_information;

    io:println("Standard message type: ", messageInfo?.name, " D", messageInfo?.version, " ", messageInfo?.status);
    // `new_field` is the partner-specific extension added to the generated schema by hand.
    io:println("Partner extension (custom new_field): ", messageInfo?.new_field);

    orders:ORDERS|error body = interchange.transactions[0].body;
    if body is error {
        io:println("Transaction body failed to parse: ", body.message());
        return;
    }
    io:println("Order id: ", body.Beginning_of_message?.DOCUMENT_MESSAGE_IDENTIFICATION?.Document_identifier);
    io:println("Line items: ", body.group_28.length());
}
