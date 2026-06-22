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

import ballerina/file;
import ballerina/io;
import ballerina/log;
import ballerinax/kafka;

import wso2/edi_parser;

configurable string MONITOR_PATH = "/tmp";
configurable string BOOTSTRAP_SERVERS = ?;

final kafka:Producer kafkaProducer = check new (BOOTSTRAP_SERVERS);

listener file:Listener fileListener = new (path = MONITOR_PATH, recursive = false);

service file:Service on fileListener {
    remote function onCreate(file:FileEvent event) returns error? {
        do {
            if event.name.endsWith(".edi") {
                string content = check io:fileReadString(event.name);
                edi_parser:ORDERSInterchange ordersinterchange = check edi_parser:interchangeFromEdiString(content);
                log:printInfo("Edi file parsed", file = event.name, partner = ordersinterchange.interchangeHeader.interchange_header.sender.id, trx = ordersinterchange.transactions.length());
                foreach edi_parser:ORDERSTransaction trx in ordersinterchange.transactions {
                    edi_parser:ORDERS|error body = trx.body;
                    if body is error {
                        log:printError("Quarantining malformed transaction", body);
                        check kafkaProducer->send({
                            topic: "edi.orders.quarantine",
                            value: body.message().toBytes()
                        });
                    } else {
                        string orderId = body.Beginning_of_message?.DOCUMENT_MESSAGE_IDENTIFICATION?.Document_identifier ?: "UNKNOWN";
                        check kafkaProducer->send({
                            topic: "edi.orders",
                            key: orderId,
                            value: body.toJsonString().toBytes()
                        });
                    }
                }
            }
        } on fail error err {
            return error("unhandled error", err);
        }
    }
}
