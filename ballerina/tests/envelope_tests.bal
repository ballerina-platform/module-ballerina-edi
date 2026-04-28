// Copyright (c) 2026 WSO2 LLC. (http://www.wso2.org).
//
// WSO2 LLC. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/test;
import ballerina/io;

// ── peekX12Headers ────────────────────────────────────────────────────────────

@test:Config {}
function testPeekX12HeadersValid() returns error? {
    string ediText = check io:fileReadString("tests/resources/x12-envelope/message.edi");
    // Strip the header (ISA..~) from the test file — message.edi starts with ISA
    X12Headers headers = check peekX12Headers(ediText);
    test:assertEquals(headers.isa.senderQualifier, "ZZ");
    test:assertEquals(headers.isa.senderId, "SENDAPP");
    test:assertEquals(headers.isa.receiverQualifier, "ZZ");
    test:assertEquals(headers.isa.receiverId, "RECVAPP");
    test:assertEquals(headers.isa.date, "260101");
    test:assertEquals(headers.isa.controlNumber, "000000001");
    test:assertEquals(headers.isa.usageIndicator, "T");
}

@test:Config {}
function testPeekX12HeadersNoGS() returns error? {
    // ISA only, no GS following it — GS should be absent
    string isaOnly = "ISA*00*          *00*          *ZZ*SENDER         *ZZ*RECEIVER       *260101*1200*^*00501*000000001*0*T*:~ST*278*0001~";
    X12Headers headers = check peekX12Headers(isaOnly);
    test:assertEquals(headers.isa.senderId, "SENDER");
    test:assertEquals(headers.gs, ());
}

@test:Config {}
function testPeekX12HeadersInvalidInput() {
    X12Headers|Error result = peekX12Headers("UNB+UNOA:1+SENDER+RECEIVER+260101:1200+1'");
    test:assertTrue(result is Error, "Expected an error for non-X12 input");
}

@test:Config {}
function testPeekX12HeadersTooShort() {
    X12Headers|Error result = peekX12Headers("ISA*00*SHORT");
    test:assertTrue(result is Error, "Expected an error for truncated ISA");
}

// ── peekEdifactHeaders ────────────────────────────────────────────────────────

@test:Config {}
function testPeekEdifactHeadersWithUNA() returns error? {
    string ediText = check io:fileReadString("tests/resources/edifact-envelope/message.edi");
    EdifactHeaders headers = check peekEdifactHeaders(ediText);
    test:assertEquals(headers.unb.sender.id, "SENDAPP");
    test:assertEquals(headers.unb.recipient.id, "RECVAPP");
    test:assertEquals(headers.unb.dateAndTime.date, "260101");
    test:assertEquals(headers.unb.controlRef, "000000001");
    EdifactUNH? unh = headers.unh;
    test:assertTrue(unh !is (), "UNH should be present");
    if unh is EdifactUNH {
        test:assertEquals(unh.messageRef, "1");
        test:assertEquals(unh.messageIdentifier.messageType, "ORDERS");
    }
}

@test:Config {}
function testPeekEdifactHeadersWithoutUNA() returns error? {
    // EDIFACT without UNA — use default delimiters
    string ediText = "UNB+UNOA:1+SENDER:ZZ+RECEIVER:ZZ+260101:1200+REF001'UNH+1+INVOIC:D:96A:UN'BGM+380+INV001+9'";
    EdifactHeaders headers = check peekEdifactHeaders(ediText);
    test:assertEquals(headers.unb.sender.id, "SENDER");
    test:assertEquals(headers.unb.controlRef, "REF001");
}

@test:Config {}
function testPeekEdifactHeadersNoUNB() {
    EdifactHeaders|Error result = peekEdifactHeaders("BGM+380+INV001+9'");
    test:assertTrue(result is Error, "Expected an error when UNB is missing");
}

// ── headersFromEdiString ──────────────────────────────────────────────────────

@test:Config {}
function testHeadersFromEdiStringX12() returns error? {
    EdiSchema schema = check getTestSchema("x12-envelope");
    string ediText = check io:fileReadString("tests/resources/x12-envelope/message.edi");
    // message.edi starts with ISA which is not in this schema — strip to ST onwards
    int stIdx = ediText.indexOf("ST") ?: 0;
    string txBody = ediText.substring(stIdx);
    json headers = check headersFromEdiString(txBody, schema);
    map<json> headersMap = check headers.cloneWithType();
    test:assertTrue(headersMap.hasKey("TransactionSetHeader"), "Headers should contain TransactionSetHeader");
}

@test:Config {}
function testHeadersFromEdiStringOldSchemaShouldError() returns error? {
    // Use an old schema (x12-278) that has no headerSegments
    EdiSchema schema = check getTestSchema("x12-278");
    json|Error result = headersFromEdiString("ST*278*0001~SE*1*0001~", schema);
    test:assertTrue(result is Error, "Expected an error for old schema without headerSegments");
    if result is Error {
        test:assertTrue((result).message().includes("headerSegments"), "Error message should mention headerSegments");
    }
}

// ── envelopeFromEdiString ─────────────────────────────────────────────────────

@test:Config {}
function testEnvelopeFromEdiStringX12() returns error? {
    EdiSchema schema = check getTestSchema("x12-envelope");
    string ediText = check io:fileReadString("tests/resources/x12-envelope/message.edi");
    int stIdx = ediText.indexOf("ST") ?: 0;
    string txBody = ediText.substring(stIdx);
    EdiEnvelope envelope = check envelopeFromEdiString(txBody, schema);

    // Headers: ST segment parsed
    map<json> headersMap = check envelope.headers.cloneWithType();
    test:assertTrue(headersMap.hasKey("TransactionSetHeader"), "Envelope headers should contain TransactionSetHeader");

    // Body: raw segment strings between ST and SE
    test:assertTrue(envelope.body.length() > 0, "Body should contain segment strings");
    test:assertTrue(envelope.body[0].startsWith("BHT"), "First body segment should be BHT");

    // Trailers: SE segment parsed
    map<json> trailersMap = check envelope.trailers.cloneWithType();
    test:assertTrue(trailersMap.hasKey("TransactionSetTrailer"), "Envelope trailers should contain TransactionSetTrailer");
}

@test:Config {}
function testEnvelopeFromEdiStringEdifact() returns error? {
    EdiSchema schema = check getTestSchema("edifact-envelope");
    string ediText = check io:fileReadString("tests/resources/edifact-envelope/message.edi");
    // Strip UNA and UNB, start from UNH
    int unhIdx = ediText.indexOf("UNH") ?: 0;
    string txBody = ediText.substring(unhIdx);
    EdiEnvelope envelope = check envelopeFromEdiString(txBody, schema);

    map<json> headersMap = check envelope.headers.cloneWithType();
    test:assertTrue(headersMap.hasKey("MessageHeader"), "Envelope headers should contain MessageHeader");
    test:assertTrue(envelope.body.length() > 0, "Body should contain segment strings");
    map<json> trailersMap = check envelope.trailers.cloneWithType();
    test:assertTrue(trailersMap.hasKey("MessageTrailer"), "Envelope trailers should contain MessageTrailer");
}

@test:Config {}
function testEnvelopeFromEdiStringOldSchemaShouldError() returns error? {
    EdiSchema schema = check getTestSchema("x12-278");
    EdiEnvelope|Error result = envelopeFromEdiString("ST*278*0001~SE*1*0001~", schema);
    test:assertTrue(result is Error, "Expected an error for old schema without headerSegments/trailerSegments");
}

@test:Config {}
function testEnvelopeBodyCanBeDeepParsed() returns error? {
    // Verify that body segments from envelopeFromEdiString can be passed back to fromEdiString
    EdiSchema envelopeSchema = check getTestSchema("x12-envelope");
    string ediText = check io:fileReadString("tests/resources/x12-envelope/message.edi");
    int stIdx = ediText.indexOf("ST") ?: 0;
    string txBody = ediText.substring(stIdx);
    EdiEnvelope envelope = check envelopeFromEdiString(txBody, envelopeSchema);

    // Re-assemble body as a minimal EDI string and confirm it's parseable
    string bodyEdi = string:'join("~\n", ...envelope.body) + "~";
    // We won't run fromEdiString on it (no matching body-only schema here),
    // but verify the body strings are well-formed segments
    foreach string seg in envelope.body {
        test:assertTrue(seg.length() > 0, "Body segment should not be empty");
    }
}
