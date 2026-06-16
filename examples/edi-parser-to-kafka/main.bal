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

import wso2/edi_parser_to_kafka.orders;

// Directory watched for incoming EDIFACT D03A ORDERS files.
configurable string inboxPath = "./sample-data";
// Kafka broker and the topics good orders / quarantined transactions are published to.
configurable string kafkaBootstrap = "localhost:9092";
configurable string ordersTopic = "edi.orders";
configurable string quarantineTopic = "edi.orders.quarantine";

listener file:Listener inbox = new ({path: inboxPath, recursive: false});

final kafka:Producer ediProducer = check new (kafkaBootstrap);

// Each EDI file dropped into the inbox is parsed and fanned out to Kafka.
service on inbox {
    remote function onCreate(file:FileEvent event) returns error? {
        if !event.name.endsWith(".edi") {
            return;
        }
        check publishFromFile(event.name);
    }
}

// Parse one interchange and publish each transaction body to Kafka. The parse is
// fail-safe per transaction: a malformed body becomes an `error` in that
// transaction's `body` field, so a single bad order is quarantined while the rest
// of the batch is still published.
function publishFromFile(string path) returns error? {
    string ediText = check io:fileReadString(path);
    orders:ORDERSInterchange interchange = check orders:interchangeFromEdiString(ediText);

    string partner = interchange.interchangeHeader.interchange_header.sender.id;
    log:printInfo("Parsed interchange", file = path, partner = partner,
            transactions = interchange.transactions.length());

    foreach orders:ORDERSTransaction txn in interchange.transactions {
        orders:ORDERS|error body = txn.body;
        if body is error {
            log:printError("Quarantining malformed transaction", 'error = body);
            check ediProducer->send({topic: quarantineTopic, value: body.message().toBytes()});
            continue;
        }
        string orderId = body.Beginning_of_message?.DOCUMENT_MESSAGE_IDENTIFICATION?.Document_identifier ?: "UNKNOWN";
        check ediProducer->send({
            topic: ordersTopic,
            key: orderId.toBytes(),
            value: body.toJsonString().toBytes()
        });
        log:printInfo("Published order", orderId = orderId, partner = partner, topic = ordersTopic);
    }
}
