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
import ballerina/log;
import ballerina/ftp;

configurable string sftpHost = "localhost";
configurable int sftpPort = 22;
configurable string sftpUser = "wso2";
configurable string sftpPassword = "wso2123";
configurable string inboxPath = "/edi/inbox";
configurable string fallbackPath = "/edi/vendors/unknown";

// Trading-partner sender id -> destination directory on the SFTP server.
final readonly & map<string> vendorRoutes = {
    "ACME": "/edi/vendors/acme",
    "SENDER": "/edi/vendors/globex"
};

// Client used to move routed files into their destination directories.
final ftp:Client fileClient = check new ({
    protocol: ftp:SFTP,
    host: sftpHost,
    port: sftpPort,
    auth: {credentials: {username: sftpUser, password: sftpPassword}}
});

listener ftp:Listener inbox = check new ({
    protocol: ftp:SFTP,
    host: sftpHost,
    port: sftpPort,
    auth: {credentials: {username: sftpUser, password: sftpPassword}},
    pollingInterval: 5
});

@ftp:ServiceConfig {
    path: inboxPath,
    fileNamePattern: "(.*)\\.edi"
}
service on inbox {
    // The listener reads each new file as text; we inspect only the envelope
    // headers (no schema) and move the untouched file to its trading partner's folder.
    remote function onFileText(string content, ftp:FileInfo fileInfo) returns error? {
        string senderId = check senderIdOf(content);
        string destination = vendorRoutes[senderId] ?: fallbackPath;
        check fileClient->move(fileInfo.path, string `${destination}/${fileInfo.name}`);
        log:printInfo("Routed EDI file", sender = senderId, file = fileInfo.name, destination = destination);
    }
}

// Inspect the interchange envelope cheaply: X12 ISA or EDIFACT UNB, no schema required.
function senderIdOf(string ediText) returns string|error {
    if ediText.trim().startsWith("ISA") {
        edi:X12Headers headers = check edi:x12HeadersFromEdiString(ediText);
        return headers.isa.senderId;
    }
    edi:EdifactHeaders headers = check edi:edifactHeadersFromEdiString(ediText);
    return headers.unb.sender.id;
}
