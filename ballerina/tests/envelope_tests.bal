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

import ballerina/file;
import ballerina/io;
import ballerina/test;

// Writes EDI text to a fresh temp file and returns its absolute path. Each
// file-based test gets its own temp file so fixtures are not shared and the
// test resources directory stays untouched.
function writeTemp(string text) returns string|error {
    string path = check file:createTempDir() + "/sample.edi";
    check io:fileWriteString(path, text);
    return path;
}

// =============================================================================
// Sample EDI strings used across the envelope tests.
// =============================================================================

// Standard X12 ISA + GS + ST + body + SE + GE + IEA. Uses '*' as field delim,
// ':' as component delim, and '~' as segment terminator (ISA position 105).
const string X12_SAMPLE = "ISA*00*          *00*          *ZZ*SENDER         *ZZ*RECEIVER       *210527*1200*U*00401*000000001*0*P*:~" +
    "GS*PO*SENDER*RECEIVER*20210527*1200*1*X*004010~" +
    "ST*850*0001~" +
    "BEG*00*SA*PO12345*20210527~" +
    "REF*ZZ*RemarkableRef~" +
    "SE*4*0001~" +
    "GE*1*1~" +
    "IEA*1*000000001~";

// X12 with no GS — just ISA followed directly by ST (rare but valid for header
// peek tests where caller wants to see whether a group is present).
const string X12_NO_GS = "ISA*00*          *00*          *ZZ*SENDER         *ZZ*RECEIVER       *210527*1200*U*00401*000000001*0*P*:~" +
    "ST*850*0001~SE*1*0001~IEA*1*000000001~";

// X12 with 2 functional groups, each carrying 2 transactions. Used by
// interchangeFromEdiString.
const string X12_MULTI_GROUP = "ISA*00*          *00*          *ZZ*SENDER         *ZZ*RECEIVER       *210527*1200*U*00401*000000001*0*P*:~" +
    "GS*PO*SENDER*RECEIVER*20210527*1200*1*X*004010~" +
    "ST*850*0001~BEG*00*SA*P1*20210527~SE*2*0001~" +
    "ST*850*0002~BEG*00*SA*P2*20210528~SE*2*0002~" +
    "GE*2*1~" +
    "GS*IN*SENDER*RECEIVER*20210527*1200*2*X*004010~" +
    "ST*850*0003~BEG*00*SA*P3*20210529~SE*2*0003~" +
    "ST*850*0004~BEG*00*SA*P4*20210530~SE*2*0004~" +
    "GE*2*2~" +
    "IEA*2*000000001~";

// X12 with one valid transaction and one transaction whose body intentionally
// does not match the schema (BEG required but missing). Verifies fail-safe
// per-transaction body in interchangeFromEdiString.
const string X12_CORRUPTED_TXN = "ISA*00*          *00*          *ZZ*SENDER         *ZZ*RECEIVER       *210527*1200*U*00401*000000001*0*P*:~" +
    "GS*PO*SENDER*RECEIVER*20210527*1200*1*X*004010~" +
    "ST*850*0001~BEG*00*SA*P1*20210527~SE*2*0001~" +
    "ST*850*0002~ZZZ*UnexpectedBody~SE*2*0002~" +
    "GE*2*1~" +
    "IEA*1*000000001~";

// EDIFACT without UNA, using default delimiters '+', ':', '''. UNH-BGM-DTM-UNT
// (4 segments inclusive of UNH and UNT — matching the spec's UNT count rule).
const string EDIFACT_SAMPLE = "UNB+UNOA:3+SENDERID:14+RECEIVERID:14+210527:1200+REF1'" +
    "UNH+1+ORDERS:D:03A:UN'" +
    "BGM+220+PO123+9'" +
    "DTM+137:20210527:102'" +
    "UNT+4+1'" +
    "UNZ+1+REF1'";

// EDIFACT with UNA service string advice and a non-default release character.
const string EDIFACT_WITH_UNA = "UNA:+.? '" +
    "UNB+UNOA:3+SENDERID:14+RECEIVERID:14+210527:1200+REF1'" +
    "UNH+1+ORDERS:D:03A:UN'" +
    "BGM+220+PO123+9'" +
    "UNT+3+1'" +
    "UNZ+1+REF1'";

// EDIFACT with two messages in one interchange (no UNG/UNE — group level absent).
const string EDIFACT_MULTI_MSG = "UNB+UNOA:3+SENDERID:14+RECEIVERID:14+210527:1200+REF1'" +
    "UNH+1+ORDERS:D:03A:UN'BGM+220+PO123+9'UNT+3+1'" +
    "UNH+2+ORDERS:D:03A:UN'BGM+220+PO456+9'UNT+3+2'" +
    "UNZ+2+REF1'";

// =============================================================================
// X12 schema (for headersFromEdiString / interchangeFromEdiString / fromEdiString)
// =============================================================================

// Builds an EdiFieldSchema list of `count` generic string fields tagged f1..fN.
// Used in envelope test schemas where field-by-field parsing is incidental.
isolated function genericFields(int count) returns json[] {
    json[] fields = [];
    int i = 1;
    while i <= count {
        fields.push({"tag": "f" + i.toString()});
        i += 1;
    }
    return fields;
}

isolated function buildX12Schema() returns EdiSchema|error {
    json schemaJson = {
        "name": "Sample850",
        "tag": "Order",
        "delimiters": {
            "segment": "~",
            "field": "*",
            "component": ":",
            "subcomponent": "NOT_USED",
            "repetition": "NOT_USED"
        },
        "envelope": {
            "interchange": {
                "header": [{"code": "ISA", "tag": "InterchangeHeader", "fields": genericFields(17)}],
                "trailer": [{"code": "IEA", "tag": "InterchangeTrailer", "fields": genericFields(3)}]
            },
            "group": {
                "header": [{"code": "GS", "tag": "GroupHeader", "fields": genericFields(9)}],
                "trailer": [{"code": "GE", "tag": "GroupTrailer", "fields": genericFields(3)}]
            },
            "transaction": {
                "header": [{"code": "ST", "tag": "TransactionHeader", "fields": genericFields(3)}],
                "trailer": [{"code": "SE", "tag": "TransactionTrailer", "fields": genericFields(3)}]
            }
        },
        "segments": [
            {
                "code": "BEG",
                "tag": "BeginningSegment",
                "minOccurances": 1,
                "maxOccurances": 1,
                "fields": [
                    {"tag": "code"},
                    {"tag": "purposeCode"},
                    {"tag": "saleType"},
                    {"tag": "purchaseOrderNumber"},
                    {"tag": "date"}
                ]
            },
            {
                "code": "REF",
                "tag": "Reference",
                "minOccurances": 0,
                "maxOccurances": 5,
                "fields": [
                    {"tag": "code"},
                    {"tag": "qualifier"},
                    {"tag": "reference"}
                ]
            }
        ]
    };
    return getSchema(schemaJson);
}

isolated function buildEdifactOrdersSchema() returns EdiSchema|error {
    json schemaJson = {
        "name": "OrdersD03A",
        "tag": "Orders",
        "delimiters": {
            "segment": "'",
            "field": "+",
            "component": ":",
            "subcomponent": "NOT_USED",
            "repetition": "NOT_USED"
        },
        "envelope": {
            "interchange": {
                "header": [{"code": "UNB", "tag": "InterchangeHeader", "fields": genericFields(6)}],
                "trailer": [{"code": "UNZ", "tag": "InterchangeTrailer", "fields": genericFields(3)}]
            },
            "transaction": {
                "header": [{"code": "UNH", "tag": "MessageHeader", "fields": genericFields(3)}],
                "trailer": [{"code": "UNT", "tag": "MessageTrailer", "fields": genericFields(3)}]
            }
        },
        "segments": [
            {
                "code": "BGM",
                "tag": "BeginningOfMessage",
                "minOccurances": 1,
                "maxOccurances": 1,
                "fields": [
                    {"tag": "code"},
                    {"tag": "documentMessageName"},
                    {"tag": "documentNumber"},
                    {"tag": "messageFunction"}
                ]
            },
            {
                "code": "DTM",
                "tag": "DateTime",
                "minOccurances": 0,
                "maxOccurances": 5,
                "fields": [
                    {"tag": "code"},
                    {"tag": "dateTime"}
                ]
            }
        ]
    };
    return getSchema(schemaJson);
}

// Old-style schema (no envelope) used to verify backward compatibility for
// fromEdiString and the regenerate-schema error from envelope-aware APIs.
isolated function buildOldX12Schema() returns EdiSchema|error {
    json schemaJson = {
        "name": "OldSchema",
        "tag": "OldOrder",
        "delimiters": {
            "segment": "~",
            "field": "*",
            "component": ":",
            "subcomponent": "NOT_USED",
            "repetition": "NOT_USED"
        },
        "ignoreSegments": ["ISA", "GS", "ST", "SE", "GE", "IEA"],
        "segments": [
            {
                "code": "BEG",
                "tag": "BeginningSegment",
                "minOccurances": 1,
                "maxOccurances": 1,
                "fields": [
                    {"tag": "code"}, {"tag": "purposeCode"}, {"tag": "saleType"},
                    {"tag": "purchaseOrderNumber"}, {"tag": "date"}
                ]
            },
            {
                "code": "REF",
                "tag": "Reference",
                "minOccurances": 0,
                "maxOccurances": 5,
                "fields": [{"tag": "code"}, {"tag": "qualifier"}, {"tag": "reference"}]
            }
        ]
    };
    return getSchema(schemaJson);
}

// =============================================================================
// Schema-free X12 header tests
// =============================================================================

@test:Config {}
function testX12HeadersFromEdiStringValid() returns error? {
    X12Headers headers = check x12HeadersFromEdiString(X12_SAMPLE);
    test:assertEquals(headers.isa.senderId, "SENDER");
    test:assertEquals(headers.isa.receiverId, "RECEIVER");
    test:assertEquals(headers.isa.controlNumber, "000000001");
    test:assertEquals(headers.isa.usageIndicator, "P");
    X12GS? gs = headers.gs;
    if gs is () {
        test:assertFail("Expected GS segment to be present.");
    }
    test:assertEquals(gs.functionalIdentifier, "PO");
    test:assertEquals(gs.controlNumber, "1");
}

@test:Config {}
function testX12HeadersNoGs() returns error? {
    X12Headers headers = check x12HeadersFromEdiString(X12_NO_GS);
    test:assertEquals(headers.isa.senderId, "SENDER");
    test:assertTrue(headers.gs is (), "Expected GS segment to be absent.");
}

@test:Config {}
function testX12HeadersNonConforming() {
    X12Headers|Error result = x12HeadersFromEdiString("UNB+...'");
    test:assertTrue(result is Error, "Expected an Error for non-X12 input.");
}

@test:Config {}
function testX12HeadersTooShort() {
    X12Headers|Error result = x12HeadersFromEdiString("ISA*00*~");
    test:assertTrue(result is Error, "Expected an Error for truncated ISA.");
}

@test:Config {}
function testX12HeadersFromFile() returns error? {
    string path = check writeTemp(X12_SAMPLE);
    X12Headers headers = check x12HeadersFromEdiFile(path);
    test:assertEquals(headers.isa.senderId, "SENDER");
}

// =============================================================================
// Schema-free EDIFACT header tests
// =============================================================================

@test:Config {}
function testEdifactHeadersFromEdiStringValid() returns error? {
    EdifactHeaders headers = check edifactHeadersFromEdiString(EDIFACT_SAMPLE);
    test:assertEquals(headers.unb.sender.id, "SENDERID");
    test:assertEquals(headers.unb.recipient.id, "RECEIVERID");
    test:assertEquals(headers.unb.controlRef, "REF1");
    EdifactUNH? unh = headers.unh;
    if unh is () {
        test:assertFail("Expected UNH to be present.");
    }
    test:assertEquals(unh.messageRef, "1");
    test:assertEquals(unh.messageIdentifier.messageType, "ORDERS");
    test:assertEquals(unh.messageIdentifier.release, "03A");
}

@test:Config {}
function testEdifactHeadersWithUNA() returns error? {
    EdifactHeaders headers = check edifactHeadersFromEdiString(EDIFACT_WITH_UNA);
    test:assertEquals(headers.unb.sender.id, "SENDERID");
    test:assertEquals(headers.unb.controlRef, "REF1");
}

@test:Config {}
function testEdifactHeadersNonConforming() {
    EdifactHeaders|Error result = edifactHeadersFromEdiString("ISA*00*...~");
    test:assertTrue(result is Error, "Expected an Error for non-EDIFACT input.");
}

@test:Config {}
function testEdifactHeadersFromFile() returns error? {
    string path = check writeTemp(EDIFACT_SAMPLE);
    EdifactHeaders headers = check edifactHeadersFromEdiFile(path);
    test:assertEquals(headers.unb.sender.id, "SENDERID");
}

// =============================================================================
// Schema-driven header tests
// =============================================================================

@test:Config {}
function testHeadersFromEdiStringX12() returns error? {
    EdiSchema schema = check buildX12Schema();
    json result = check headersFromEdiString(X12_SAMPLE, schema);
    if !(result is map<json>) {
        test:assertFail("Expected a JSON object");
    }
    test:assertTrue(result.hasKey("interchange"));
    test:assertTrue(result.hasKey("group"));
    test:assertTrue(result.hasKey("transaction"));
}

@test:Config {}
function testHeadersFromEdiStringEdifact() returns error? {
    EdiSchema schema = check buildEdifactOrdersSchema();
    json result = check headersFromEdiString(EDIFACT_SAMPLE, schema);
    if !(result is map<json>) {
        test:assertFail("Expected a JSON object");
    }
    test:assertTrue(result.hasKey("interchange"));
    test:assertFalse(result.hasKey("group"), "EDIFACT schema has no group level.");
    test:assertTrue(result.hasKey("transaction"));
}

@test:Config {}
function testHeadersFromEdiStringOldSchemaError() returns error? {
    EdiSchema oldSchema = check buildOldX12Schema();
    json|Error result = headersFromEdiString(X12_SAMPLE, oldSchema);
    if !(result is Error) {
        test:assertFail("Expected an Error for old schema without envelope.");
    }
    test:assertTrue(result.message().includes("Regenerate the schema"),
            "Error should direct user to regenerate the schema.");
}

@test:Config {}
function testHeadersFromEdiFile() returns error? {
    string path = check writeTemp(X12_SAMPLE);
    EdiSchema schema = check buildX12Schema();
    json result = check headersFromEdiFile(path, schema);
    if !(result is map<json>) {
        test:assertFail("Expected a JSON object");
    }
    test:assertTrue(result.hasKey("interchange"));
}

// =============================================================================
// Hierarchical interchange tests (interchangeFromEdiString)
// =============================================================================

@test:Config {}
function testInterchangeFromEdiStringX12MultiGroup() returns error? {
    EdiSchema schema = check buildX12Schema();
    EdiInterchange ix = check interchangeFromEdiString(X12_MULTI_GROUP, schema);
    EdiFunctionalGroup[]? groups = ix?.groups;
    if groups is () {
        test:assertFail("Expected groups to be present for X12 schema with group level.");
    }
    test:assertEquals(groups.length(), 2, "Expected two functional groups.");
    test:assertEquals(groups[0].transactions.length(), 2, "First group should have two transactions.");
    test:assertEquals(groups[1].transactions.length(), 2, "Second group should have two transactions.");
    // Bodies should parse into JSON, not error.
    test:assertFalse(groups[0].transactions[0].body is error, "Body 1 should parse cleanly.");
    test:assertFalse(groups[1].transactions[1].body is error, "Body 4 should parse cleanly.");
}

@test:Config {}
function testInterchangeFromEdiStringEdifactNoGroup() returns error? {
    EdiSchema schema = check buildEdifactOrdersSchema();
    EdiInterchange ix = check interchangeFromEdiString(EDIFACT_MULTI_MSG, schema);
    EdiTransaction[]? transactions = ix?.transactions;
    if transactions is () {
        test:assertFail("Expected transactions to be present for EDIFACT schema without group.");
    }
    test:assertEquals(transactions.length(), 2);
    test:assertTrue(ix?.groups is (), "EDIFACT no-group schema should not yield groups.");
}

@test:Config {}
function testInterchangeFromEdiStringFailSafeBody() returns error? {
    EdiSchema schema = check buildX12Schema();
    EdiInterchange ix = check interchangeFromEdiString(X12_CORRUPTED_TXN, schema);
    EdiFunctionalGroup[]? groups = ix?.groups;
    if groups is () {
        test:assertFail("Expected groups for X12 schema.");
    }
    test:assertEquals(groups.length(), 1);
    test:assertEquals(groups[0].transactions.length(), 2);
    // First transaction parses; second fails fail-safe with body containing an error.
    test:assertFalse(groups[0].transactions[0].body is error, "First body should parse cleanly.");
    test:assertTrue(groups[0].transactions[1].body is error,
            "Second (corrupted) body should be captured as an error, not abort the parse.");
}

@test:Config {}
function testInterchangeFromEdiStringOldSchemaError() returns error? {
    EdiSchema oldSchema = check buildOldX12Schema();
    EdiInterchange|Error result = interchangeFromEdiString(X12_SAMPLE, oldSchema);
    if !(result is Error) {
        test:assertFail("Expected an Error for old schema without envelope.");
    }
}

// =============================================================================
// fromEdiString backward-compatibility and envelope-skip behaviour
// =============================================================================

@test:Config {}
function testFromEdiStringNewSchemaSkipsEnvelope() returns error? {
    EdiSchema schema = check buildX12Schema();
    json body = check fromEdiString(X12_SAMPLE, schema);
    if !(body is map<json>) {
        test:assertFail("Expected a JSON object body.");
    }
    // Envelope segments stripped; only BEG and REF in body.
    test:assertTrue(body.hasKey("BeginningSegment"));
    test:assertTrue(body.hasKey("Reference"));
    test:assertFalse(body.hasKey("InterchangeHeader"), "Envelope segments must not appear in the body output.");
    test:assertFalse(body.hasKey("TransactionHeader"), "Envelope segments must not appear in the body output.");
}

@test:Config {}
function testFromEdiStringOldSchemaUnchanged() returns error? {
    EdiSchema oldSchema = check buildOldX12Schema();
    json body = check fromEdiString(X12_SAMPLE, oldSchema);
    if !(body is map<json>) {
        test:assertFail("Expected a JSON object body.");
    }
    // Old schemas use ignoreSegments to skip envelope; same body is produced.
    test:assertTrue(body.hasKey("BeginningSegment"));
    test:assertTrue(body.hasKey("Reference"));
}

// =============================================================================
// convertToType regression for decimalSeparator regex bug (issue #8771)
// =============================================================================

@test:Config {}
function testConvertToTypeDecimalSeparatorDot() returns error? {
    // "."  is the EDIFACT default decimal separator and is also a regex
    // metacharacter — the old `regexp:fromString(".")` would match every
    // character and corrupt the value. With the literal-replace fix, "." is
    // recognised as already-canonical and the value is parsed correctly.
    SimpleType|error v = convertToType("12.34", FLOAT, ".");
    test:assertTrue(v is float, "Expected float value for decimalSeparator='.'.");
    if v is float {
        test:assertEquals(v, 12.34);
    }

    SimpleType|error v2 = convertToType("567", INT, ".");
    test:assertTrue(v2 is int, "Expected int value for decimalSeparator='.'.");
    if v2 is int {
        test:assertEquals(v2, 567);
    }
}

@test:Config {}
function testConvertToTypeDecimalSeparatorComma() returns error? {
    // Comma is non-default in EDIFACT but used in some X12 / regional flavours.
    // The replaceLiteral helper must rewrite "," to "." before parsing.
    SimpleType|error v = convertToType("12,34", FLOAT, ",");
    test:assertTrue(v is float);
    if v is float {
        test:assertEquals(v, 12.34);
    }
}
