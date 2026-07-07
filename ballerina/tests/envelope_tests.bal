// Copyright (c) 2026 WSO2 LLC. (http://www.wso2.com).
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

// Walks a JSON object along the given keys and returns the value at the end
// of the path, or nil when the path does not exist. Keeps value assertions on
// nested parser output compact.
function jget(json value, string... keys) returns json {
    json current = value;
    foreach string key in keys {
        if current is map<json> {
            current = current[key];
        } else {
            return ();
        }
    }
    return current;
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

// EDIFACT with a UNA service string advice that declares the DEFAULT
// delimiter set (component ':', field '+', decimal '.', release '?',
// segment terminator '''). Custom-delimiter UNA handling is covered by
// EDIFACT_CUSTOM_UNA below.
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

// EDIFACT with release-character-escaped delimiters in UNB values (default
// delimiters, no UNA): sender id carries an escaped '+', recipient id an
// escaped ':'. The parsed values must be un-escaped.
const string EDIFACT_RELEASE_CHAR = "UNB+UNOA:3+SEND?+ER:14+REC?:ID:14+210527:1200+REF1'" +
    "UNH+1+ORDERS:D:03A:UN'BGM+220+PO123+9'UNT+3+1'UNZ+1+REF1'";

// EDIFACT with a UNA declaring genuinely custom delimiters:
// component '|', field '^', decimal '.', release '!', reserved '*',
// segment terminator '&'. The sender id carries an escaped field delimiter.
const string EDIFACT_CUSTOM_UNA = "UNA|^.!*&" +
    "UNB^UNOA|3^SEND!^ER|14^RECEIVERID|14^210527|1200^REF1&" +
    "UNH^1^ORDERS|D|03A|UN&BGM^220^PO123^9&UNT^3^1&UNZ^1^REF1&";

// X12 with 2 transactions where the second transaction's body is corrupted
// and contains stray envelope-trailer-coded junk (an IEA-coded and an
// SE-coded segment). The envelope parse must survive: trailers are located
// scanning backward, so the junk stays inside the corrupted body, which is
// captured as the per-transaction error while the sibling parses fine.
const string X12_STRAY_TRAILER_IN_BODY = "ISA*00*          *00*          *ZZ*SENDER         *ZZ*RECEIVER       *210527*1200*U*00401*000000001*0*P*:~" +
    "GS*PO*SENDER*RECEIVER*20210527*1200*1*X*004010~" +
    "ST*850*0001~BEG*00*SA*P1*20210527~SE*3*0001~" +
    "ST*850*0002~IEA*garbage~SE*junk~SE*4*0002~" +
    "GE*2*1~" +
    "IEA*1*000000001~";

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
    test:assertTrue(result is InvalidEnvelopeError, "Expected an InvalidEnvelopeError for non-X12 input.");
}

@test:Config {}
function testX12HeadersTooShort() {
    X12Headers|Error result = x12HeadersFromEdiString("ISA*00*~");
    test:assertTrue(result is InvalidEnvelopeError, "Expected an InvalidEnvelopeError for truncated ISA.");
}

@test:Config {}
function testX12HeadersStrictIsaValidation() {
    // An unpadded (variable-width) ISA is non-conformant: position 105 is not
    // the segment terminator, so naive parsing would silently mis-read the
    // terminator and lose GS. The parser must reject it instead.
    string unpadded = "ISA*00*A*00*B*ZZ*SENDER*ZZ*RECEIVER*210527*1200*U*00401*1*0*P*:~" +
        "GS*PO*SENDER*RECEIVER*20210527*1200*1*X*004010~" +
        "ST*850*0001~SE*1*0001~GE*1*1~IEA*1*1~";
    X12Headers|Error result = x12HeadersFromEdiString(unpadded);
    test:assertTrue(result is InvalidEnvelopeError,
            "Expected an InvalidEnvelopeError for a non-conformant (unpadded) ISA.");
}

@test:Config {}
function testX12HeadersBomStripped() returns error? {
    X12Headers headers = check x12HeadersFromEdiString("\u{FEFF}" + X12_SAMPLE);
    test:assertEquals(headers.isa.senderId, "SENDER");
    test:assertEquals(headers.isa.controlNumber, "000000001");
}

@test:Config {}
function testX12HeadersMalformedGs() {
    // GS is present but truncated to two fields; the parser must fail fast
    // instead of silently returning only the ISA, which a caller could not
    // distinguish from genuinely GS-less input.
    string isa = X12_SAMPLE.substring(0, ISA_SEGMENT_LENGTH);
    X12Headers|Error result = x12HeadersFromEdiString(isa + "GS*PO~");
    test:assertTrue(result is Error, "Expected an Error for a truncated GS segment.");
}

@test:Config {}
function testX12HeadersFromFile() returns error? {
    string path = check writeTemp(X12_SAMPLE);
    X12Headers headers = check x12HeadersFromEdiFile(path);
    test:assertEquals(headers.isa.senderId, "SENDER");
}

@test:Config {}
function testIsa02AndIsa04() returns error? {
    string isaSegment = "ISA*00*          *00*          *ZZ*VIMLY *ZZ*MAGNACARE *260415*2028*^*00501*000213133*0*P*:~";
    json schemaJson = {
        "name": "ISATest",
        "delimiters": {"segment": "~", "field": "*", "component": ":", "repetition": "^"},
        "includeSegmentCode": true,
        "segments": [
            {
                "code": "ISA",
                "tag": "InterchangeControlHeader",
                "fields": [
                    {"tag": "code", "required": true, "dataType": "string"},
                    {"tag": "ISA01__AuthorizationInformationQualifier", "required": true, "dataType": "string"},
                    {"tag": "ISA02__AuthorizationInformation", "required": true, "dataType": "string"},
                    {"tag": "ISA03__SecurityInformationQualifier", "required": true, "dataType": "string"},
                    {"tag": "ISA04__SecurityInformation", "required": true, "dataType": "string"},
                    {"tag": "ISA05__InterchangeIDQualifier", "required": true, "dataType": "string"},
                    {"tag": "ISA06__InterchangeSenderID", "required": true, "dataType": "string"},
                    {"tag": "ISA07__InterchangeIDQualifier", "required": true, "dataType": "string"},
                    {"tag": "ISA08__InterchangeReceiverID", "required": true, "dataType": "string"},
                    {"tag": "ISA09__InterchangeDate", "required": true, "dataType": "string"},
                    {"tag": "ISA10__InterchangeTime", "required": true, "dataType": "string"},
                    {"tag": "ISA11__RepetitionSeparator", "required": true, "dataType": "string"},
                    {"tag": "ISA12__InterchangeControlVersionNumber", "required": true, "dataType": "string"},
                    {"tag": "ISA13__InterchangeControlNumber", "required": true, "dataType": "string"},
                    {"tag": "ISA14__AcknowledgmentRequested", "required": true, "dataType": "string"},
                    {"tag": "ISA15__UsageIndicator", "required": true, "dataType": "string"},
                    {"tag": "ISA16__ComponentElementSeparator", "required": true, "dataType": "string"}
                ]
            }
        ]
    };
    EdiSchema schema = check getSchema(schemaJson);
    json result = check fromEdiString(isaSegment, schema);
    map<json> msg = check result.ensureType();
    map<json> isa = check msg["InterchangeControlHeader"].ensureType();
    // Whitespace-only required fields must parse without error and store as string.
    test:assertEquals(isa["ISA02__AuthorizationInformation"], "");
    test:assertEquals(isa["ISA04__SecurityInformation"], "");
    // Other fields parsed correctly.
    test:assertEquals(isa["ISA01__AuthorizationInformationQualifier"], "00");
    test:assertEquals(isa["ISA06__InterchangeSenderID"], "VIMLY");
    test:assertEquals(isa["ISA08__InterchangeReceiverID"], "MAGNACARE");
    test:assertEquals(isa["ISA13__InterchangeControlNumber"], "000213133");
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
    test:assertTrue(result is InvalidEnvelopeError, "Expected an InvalidEnvelopeError for non-EDIFACT input.");
}

@test:Config {}
function testEdifactHeadersReleaseCharacter() returns error? {
    // `?+` and `?:` are release sequences: the delimiter is data, not a split
    // point, and the parsed value must be un-escaped.
    EdifactHeaders headers = check edifactHeadersFromEdiString(EDIFACT_RELEASE_CHAR);
    test:assertEquals(headers.unb.sender.id, "SEND+ER");
    test:assertEquals(headers.unb.sender.qualifier, "14");
    test:assertEquals(headers.unb.recipient.id, "REC:ID");
    test:assertEquals(headers.unb.controlRef, "REF1");
}

@test:Config {}
function testEdifactHeadersCustomUnaDelimiters() returns error? {
    // UNA declares component '|', field '^', release '!', terminator '&'.
    // The schema-free parser must honour all of them, including the escaped
    // field delimiter inside the sender id.
    EdifactHeaders headers = check edifactHeadersFromEdiString(EDIFACT_CUSTOM_UNA);
    test:assertEquals(headers.unb.syntaxIdentifier.syntaxId, "UNOA");
    test:assertEquals(headers.unb.sender.id, "SEND^ER");
    test:assertEquals(headers.unb.sender.qualifier, "14");
    test:assertEquals(headers.unb.recipient.id, "RECEIVERID");
    test:assertEquals(headers.unb.controlRef, "REF1");
    EdifactUNH? unh = headers.unh;
    if unh is () {
        test:assertFail("Expected UNH to be present.");
    }
    test:assertEquals(unh.messageIdentifier.messageType, "ORDERS");
    test:assertEquals(unh.messageIdentifier.release, "03A");
}

@test:Config {}
function testEdifactHeadersBomStripped() returns error? {
    EdifactHeaders headers = check edifactHeadersFromEdiString("\u{FEFF}" + EDIFACT_SAMPLE);
    test:assertEquals(headers.unb.sender.id, "SENDERID");
}

@test:Config {}
function testEdifactHeadersMissingUnbTerminator() {
    // UNB has no segment terminator, so it cannot be bounded; the parser must
    // error rather than consuming the remainder as a single garbage UNB.
    EdifactHeaders|Error result = edifactHeadersFromEdiString(
            "UNB+UNOA:3+SENDERID:14+RECEIVERID:14+210527:1200+REF1");
    test:assertTrue(result is Error, "Expected an Error for a UNB without a terminator.");
}

@test:Config {}
function testEdifactHeadersMalformedUnh() {
    // UNB is well-formed but UNH is truncated; the parser must fail fast instead
    // of silently dropping the UNH and returning only the UNB.
    EdifactHeaders|Error result = edifactHeadersFromEdiString(
            "UNB+UNOA:3+SENDERID:14+RECEIVERID:14+210527:1200+REF1'UNH+1'");
    test:assertTrue(result is Error, "Expected an Error for a truncated UNH segment.");
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
    // ISA values (fixed-width padding trimmed on parse).
    test:assertEquals(jget(result, "interchange", "InterchangeHeader", "f7"), "SENDER");
    test:assertEquals(jget(result, "interchange", "InterchangeHeader", "f9"), "RECEIVER");
    test:assertEquals(jget(result, "interchange", "InterchangeHeader", "f10"), "210527");
    test:assertEquals(jget(result, "interchange", "InterchangeHeader", "f14"), "000000001");
    test:assertEquals(jget(result, "interchange", "InterchangeHeader", "f16"), "P");
    // GS values.
    test:assertEquals(jget(result, "group", "GroupHeader", "f2"), "PO");
    test:assertEquals(jget(result, "group", "GroupHeader", "f5"), "20210527");
    test:assertEquals(jget(result, "group", "GroupHeader", "f7"), "1");
    // ST values.
    test:assertEquals(jget(result, "transaction", "TransactionHeader", "f2"), "850");
    test:assertEquals(jget(result, "transaction", "TransactionHeader", "f3"), "0001");
}

@test:Config {}
function testHeadersFromEdiStringEdifact() returns error? {
    EdiSchema schema = check buildEdifactOrdersSchema();
    json result = check headersFromEdiString(EDIFACT_SAMPLE, schema);
    if result !is map<json> {
        test:assertFail("Expected a JSON object");
    }
    test:assertFalse(result.hasKey("group"), "EDIFACT schema has no group level.");
    // UNB values (composites are unsplit strings in this generic-field schema).
    test:assertEquals(jget(result, "interchange", "InterchangeHeader", "f2"), "UNOA:3");
    test:assertEquals(jget(result, "interchange", "InterchangeHeader", "f3"), "SENDERID:14");
    test:assertEquals(jget(result, "interchange", "InterchangeHeader", "f5"), "210527:1200");
    test:assertEquals(jget(result, "interchange", "InterchangeHeader", "f6"), "REF1");
    // UNH values.
    test:assertEquals(jget(result, "transaction", "MessageHeader", "f2"), "1");
    test:assertEquals(jget(result, "transaction", "MessageHeader", "f3"), "ORDERS:D:03A:UN");
}

@test:Config {}
function testHeadersFromEdiStringOldSchemaError() returns error? {
    EdiSchema oldSchema = check buildOldX12Schema();
    json|Error result = headersFromEdiString(X12_SAMPLE, oldSchema);
    if result !is SchemaCompatibilityError {
        test:assertFail("Expected a SchemaCompatibilityError for old schema without envelope.");
    }
    test:assertTrue(result.message().includes("'envelope' field"),
            "Error should state the actual requirement: a top-level 'envelope' field.");
}

@test:Config {}
function testHeadersFromEdiFile() returns error? {
    string path = check writeTemp(X12_SAMPLE);
    EdiSchema schema = check buildX12Schema();
    json result = check headersFromEdiFile(path, schema);
    test:assertEquals(jget(result, "interchange", "InterchangeHeader", "f7"), "SENDER");
    test:assertEquals(jget(result, "interchange", "InterchangeHeader", "f14"), "000000001");
    test:assertEquals(jget(result, "group", "GroupHeader", "f7"), "1");
    test:assertEquals(jget(result, "transaction", "TransactionHeader", "f3"), "0001");
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
    if result !is SchemaCompatibilityError {
        test:assertFail("Expected a SchemaCompatibilityError for old schema without envelope.");
    }
}

@test:Config {}
function testInterchangeFromEdiStringRejectsMultipleInterchanges() returns error? {
    EdiSchema schema = check buildX12Schema();
    EdiInterchange|Error result = interchangeFromEdiString(X12_SAMPLE + X12_SAMPLE, schema);
    if result !is InvalidEnvelopeError {
        test:assertFail("Expected an InvalidEnvelopeError for concatenated interchanges.");
    }
    test:assertTrue(result.message().includes("single interchange"),
            "Error should tell the user only a single interchange per call is supported.");
}

@test:Config {}
function testInterchangeFromEdiStringRejectsTrailingContent() returns error? {
    EdiSchema schema = check buildX12Schema();
    EdiInterchange|Error result = interchangeFromEdiString(X12_SAMPLE + "JUNK*1~", schema);
    if result !is InvalidEnvelopeError {
        test:assertFail("Expected an InvalidEnvelopeError for content after the interchange trailer.");
    }
    test:assertTrue(result.message().includes("single interchange"),
            "Error should tell the user only a single interchange per call is supported.");
}

@test:Config {}
function testInterchangeFromEdiStringStrayTrailerInCorruptedBody() returns error? {
    // A corrupted transaction body containing stray IEA-coded and SE-coded
    // junk must NOT abort the parse: trailers are located scanning backward,
    // so the junk stays inside that body, which is captured as the
    // per-transaction error while the sibling transaction parses fine.
    EdiSchema schema = check buildX12Schema();
    EdiInterchange ix = check interchangeFromEdiString(X12_STRAY_TRAILER_IN_BODY, schema);
    EdiFunctionalGroup[]? groups = ix?.groups;
    if groups is () {
        test:assertFail("Expected groups for X12 schema.");
    }
    test:assertEquals(groups.length(), 1);
    test:assertEquals(groups[0].transactions.length(), 2);
    test:assertFalse(groups[0].transactions[0].body is error, "First body should parse cleanly.");
    test:assertTrue(groups[0].transactions[1].body is error,
            "Corrupted body with stray trailer junk should be captured as the per-transaction error.");
    // The real trailer (SE*4*0002), not the stray junk, must be the trailer.
    test:assertEquals(jget(groups[0].transactions[1].transactionTrailer, "TransactionTrailer", "f2"), "4");
}

@test:Config {}
function testInterchangeFromEdiStringGarbageInputFailsFast() returns error? {
    // EDIFACT text against an X12 schema must fail fast with an
    // InvalidEnvelopeError — not return empty envelope sections.
    EdiSchema schema = check buildX12Schema();
    EdiInterchange|Error result = interchangeFromEdiString(EDIFACT_SAMPLE, schema);
    test:assertTrue(result is InvalidEnvelopeError,
            "Expected an InvalidEnvelopeError for garbage (non-X12) input.");
}

// =============================================================================
// fromEdiString backward-compatibility and envelope-skip behaviour
// =============================================================================

@test:Config {}
function testFromEdiStringNewSchemaSkipsEnvelope() returns error? {
    EdiSchema schema = check buildX12Schema();
    json body = check fromEdiString(X12_SAMPLE, schema);
    if body !is map<json> {
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
    if body !is map<json> {
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

// =============================================================================
// interchangeToEdiString — write side (BEP-1441 follow-up)
// =============================================================================

@test:Config {}
function testInterchangeToEdiStringX12RoundTrip() returns error? {
    EdiSchema schema = check buildX12Schema();
    EdiInterchange parsed = check interchangeFromEdiString(X12_MULTI_GROUP, schema);
    string written = check interchangeToEdiString(parsed, schema);
    EdiInterchange reparsed = check interchangeFromEdiString(written, schema);

    EdiFunctionalGroup[]? groups = reparsed?.groups;
    if groups is () {
        test:assertFail("Round-tripped X12 interchange should keep its functional groups.");
    }
    test:assertEquals(groups.length(), 2, "Expected two functional groups after round-trip.");
    test:assertEquals(groups[0].transactions.length(), 2, "First group should have two transactions.");
    test:assertEquals(groups[1].transactions.length(), 2, "Second group should have two transactions.");
}

@test:Config {}
function testInterchangeToEdiStringEdifactRoundTrip() returns error? {
    EdiSchema schema = check buildEdifactOrdersSchema();
    EdiInterchange parsed = check interchangeFromEdiString(EDIFACT_MULTI_MSG, schema);
    string written = check interchangeToEdiString(parsed, schema);
    EdiInterchange reparsed = check interchangeFromEdiString(written, schema);

    EdiTransaction[]? transactions = reparsed?.transactions;
    if transactions is () {
        test:assertFail("EDIFACT round-trip should keep transactions on the interchange.");
    }
    test:assertEquals(transactions.length(), 2);
}

@test:Config {}
function testInterchangeToEdiStringOldSchemaError() returns error? {
    EdiSchema oldSchema = check buildOldX12Schema();
    EdiInterchange dummy = {
        interchangeHeader: {},
        transactions: [],
        interchangeTrailer: {}
    };
    string|Error result = interchangeToEdiString(dummy, oldSchema);
    if result !is SchemaCompatibilityError {
        test:assertFail("Expected a SchemaCompatibilityError for old schema without envelope.");
    }
}

@test:Config {}
function testInterchangeToEdiStringRefusesErrorBody() returns error? {
    EdiSchema schema = check buildEdifactOrdersSchema();
    EdiInterchange parsed = check interchangeFromEdiString(EDIFACT_MULTI_MSG, schema);
    EdiTransaction[]? transactions = parsed?.transactions;
    if transactions is () {
        test:assertFail("Setup failed — expected transactions array.");
    }
    // Replace the first transaction's body with an error.
    transactions[0].body = error("simulated bad body");
    string|Error result = interchangeToEdiString(parsed, schema);
    if result !is SerializationError {
        test:assertFail("Should refuse (with SerializationError) to serialise an interchange whose transaction body is an error.");
    }
    test:assertTrue(result.message().includes("error body"),
            "Error message should mention the offending body.");
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

// =============================================================================
// Writer conformance: ISA re-padding and count / control-number recomputation
// =============================================================================

@test:Config {}
function testInterchangeToEdiStringRepadsIsa() returns error? {
    EdiSchema schema = check buildX12Schema();
    EdiInterchange parsed = check interchangeFromEdiString(X12_SAMPLE, schema);
    string written = check interchangeToEdiString(parsed, schema);

    // The emitted ISA must be exactly 106 chars: terminator at position 105.
    test:assertEquals(written.indexOf("~"), 105,
            "Emitted ISA segment must be the standard fixed width of 106 characters.");

    // The module's own schema-free parser must read the output cleanly,
    // including the GS that follows the fixed-width ISA.
    X12Headers headers = check x12HeadersFromEdiString(written);
    test:assertEquals(headers.isa.senderId, "SENDER");
    test:assertEquals(headers.isa.receiverId, "RECEIVER");
    test:assertEquals(headers.isa.controlNumber, "000000001");
    X12GS? gs = headers.gs;
    if gs is () {
        test:assertFail("GS must be parseable after the re-padded ISA (no silent mis-parse).");
    }
    test:assertEquals(gs.functionalIdentifier, "PO");
    test:assertEquals(gs.controlNumber, "1");
}

@test:Config {}
function testInterchangeToEdiStringRecomputesX12Counts() returns error? {
    EdiSchema schema = check buildX12Schema();
    EdiInterchange parsed = check interchangeFromEdiString(X12_MULTI_GROUP, schema);
    EdiFunctionalGroup[]? groups = parsed?.groups;
    if groups is () {
        test:assertFail("Setup failed — expected groups.");
    }
    // Mutate: drop the second transaction of the second group. Counts in the
    // stale parsed trailers (GE01=2, IEA01=2) no longer match.
    _ = groups[1].transactions.remove(1);

    string written = check interchangeToEdiString(parsed, schema);
    EdiInterchange reparsed = check interchangeFromEdiString(written, schema);
    EdiFunctionalGroup[]? regroups = reparsed?.groups;
    if regroups is () {
        test:assertFail("Expected groups after round-trip.");
    }
    test:assertEquals(regroups.length(), 2);
    test:assertEquals(regroups[1].transactions.length(), 1);

    // SE01 recomputed: ST + BEG + SE = 3 segments inclusive; SE02 = ST02.
    test:assertEquals(jget(regroups[0].transactions[0].transactionTrailer, "TransactionTrailer", "f2"), "3");
    test:assertEquals(jget(regroups[0].transactions[0].transactionTrailer, "TransactionTrailer", "f3"), "0001");
    test:assertEquals(jget(regroups[1].transactions[0].transactionTrailer, "TransactionTrailer", "f3"), "0003");

    // GE01 recomputed per group; GE02 mirrored from GS06.
    test:assertEquals(jget(regroups[0].groupTrailer, "GroupTrailer", "f2"), "2");
    test:assertEquals(jget(regroups[0].groupTrailer, "GroupTrailer", "f3"), "1");
    test:assertEquals(jget(regroups[1].groupTrailer, "GroupTrailer", "f2"), "1");
    test:assertEquals(jget(regroups[1].groupTrailer, "GroupTrailer", "f3"), "2");

    // IEA01 = number of groups; IEA02 mirrored from ISA13.
    test:assertEquals(jget(reparsed.interchangeTrailer, "InterchangeTrailer", "f2"), "2");
    test:assertEquals(jget(reparsed.interchangeTrailer, "InterchangeTrailer", "f3"), "000000001");
}

@test:Config {}
function testInterchangeToEdiStringRecomputesEdifactCounts() returns error? {
    EdiSchema schema = check buildEdifactOrdersSchema();
    EdiInterchange parsed = check interchangeFromEdiString(EDIFACT_MULTI_MSG, schema);
    EdiTransaction[]? transactions = parsed?.transactions;
    if transactions is () {
        test:assertFail("Setup failed — expected transactions.");
    }
    // Mutate: drop the second message. UNZ01 in the stale trailer (2) no
    // longer matches.
    _ = transactions.remove(1);

    string written = check interchangeToEdiString(parsed, schema);
    EdiInterchange reparsed = check interchangeFromEdiString(written, schema);
    EdiTransaction[]? remsgs = reparsed?.transactions;
    if remsgs is () {
        test:assertFail("Expected transactions after round-trip.");
    }
    test:assertEquals(remsgs.length(), 1);

    // UNT01 recomputed: UNH + BGM + UNT = 3 segments; UNT02 = UNH 0062.
    test:assertEquals(jget(remsgs[0].transactionTrailer, "MessageTrailer", "f2"), "3");
    test:assertEquals(jget(remsgs[0].transactionTrailer, "MessageTrailer", "f3"), "1");

    // UNZ01 = number of messages; UNZ02 mirrored from UNB 0020.
    test:assertEquals(jget(reparsed.interchangeTrailer, "InterchangeTrailer", "f2"), "1");
    test:assertEquals(jget(reparsed.interchangeTrailer, "InterchangeTrailer", "f3"), "REF1");
}

// =============================================================================
// Schema-driven fail-fast and UNA semantics
// =============================================================================

@test:Config {}
function testHeadersFromEdiStringGarbageFailsFast() returns error? {
    // EDIFACT text against an X12 schema must produce InvalidEnvelopeError,
    // not empty header sections.
    EdiSchema schema = check buildX12Schema();
    json|Error result = headersFromEdiString(EDIFACT_SAMPLE, schema);
    test:assertTrue(result is InvalidEnvelopeError,
            "Expected an InvalidEnvelopeError for garbage (non-X12) input, not empty headers.");

    json|Error result2 = headersFromEdiString("complete garbage, not EDI at all", schema);
    test:assertTrue(result2 is InvalidEnvelopeError,
            "Expected an InvalidEnvelopeError for non-EDI input.");
}

@test:Config {}
function testHeadersFromEdiStringUnaConflict() returns error? {
    // UNA declares custom delimiters that conflict with the schema's — the
    // schema-driven parser must reject instead of skipping UNA blindly.
    EdiSchema schema = check buildEdifactOrdersSchema();
    json|Error result = headersFromEdiString(EDIFACT_CUSTOM_UNA, schema);
    if result !is InvalidEnvelopeError {
        test:assertFail("Expected an InvalidEnvelopeError for UNA delimiters conflicting with the schema.");
    }
    test:assertTrue(result.message().includes("UNA"),
            "Error should mention the conflicting UNA service string advice.");
}

@test:Config {}
function testHeadersFromEdiStringUnaMatchIsSkipped() returns error? {
    // UNA declaring the same delimiters as the schema is skipped and the
    // headers parse normally (previously UNA caused a silent mis-parse).
    EdiSchema schema = check buildEdifactOrdersSchema();
    json result = check headersFromEdiString(EDIFACT_WITH_UNA, schema);
    test:assertEquals(jget(result, "interchange", "InterchangeHeader", "f3"), "SENDERID:14");
    test:assertEquals(jget(result, "interchange", "InterchangeHeader", "f6"), "REF1");
    test:assertEquals(jget(result, "transaction", "MessageHeader", "f2"), "1");
}

@test:Config {}
function testInterchangeFromEdiStringUnaMatch() returns error? {
    EdiSchema schema = check buildEdifactOrdersSchema();
    EdiInterchange ix = check interchangeFromEdiString(EDIFACT_WITH_UNA, schema);
    EdiTransaction[]? transactions = ix?.transactions;
    if transactions is () {
        test:assertFail("Expected transactions.");
    }
    test:assertEquals(transactions.length(), 1);
    test:assertFalse(transactions[0].body is error, "Body should parse cleanly after the UNA is skipped.");
}

@test:Config {}
function testHeadersFromEdiStringBomStripped() returns error? {
    EdiSchema schema = check buildX12Schema();
    json result = check headersFromEdiString("\u{FEFF}" + X12_SAMPLE, schema);
    test:assertEquals(jget(result, "interchange", "InterchangeHeader", "f7"), "SENDER");
}

@test:Config {}
function testHeadersFromEdiFileWindowOverflow() returns error? {
    // Build a file whose envelope header section cannot be completed within
    // the 4096-character read window: ISA + GS followed by several thousand
    // characters of non-envelope segments before the ST.
    string filler = "";
    foreach int i in 0 ..< 400 {
        filler += "REF*ZZ*FillerSegmentValue~";
    }
    string content = "ISA*00*          *00*          *ZZ*SENDER         *ZZ*RECEIVER       *210527*1200*U*00401*000000001*0*P*:~" +
        "GS*PO*SENDER*RECEIVER*20210527*1200*1*X*004010~" + filler +
        "ST*850*0001~BEG*00*SA*PO12345*20210527~SE*3*0001~GE*1*1~IEA*1*000000001~";
    string path = check writeTemp(content);
    EdiSchema schema = check buildX12Schema();
    json|Error result = headersFromEdiFile(path, schema);
    if result !is InvalidEnvelopeError {
        test:assertFail("Expected an InvalidEnvelopeError when headers exceed the read window.");
    }
    test:assertTrue(result.message().includes("4096"),
            "Error should mention the read window size.");
}

// =============================================================================
// fromEdiString envelope-skip limits
// =============================================================================

@test:Config {}
function testFromEdiStringMergesMultipleTransactions() returns error? {
    EdiSchema schema = check buildX12Schema();
    json body = check fromEdiString(X12_MULTI_GROUP, schema);
    test:assertTrue(body is map<json>, "Expected a JSON object from merged transactions.");
    if body is map<json> {
        test:assertFalse(body.hasKey("InterchangeHeader"), "Envelope segments must not appear in merged body.");
    }   
}

// =============================================================================
// Component overflow must error, never panic
// =============================================================================

// EDIFACT-style schema whose UNB sender composite (S002) declares only two
// components. Input carrying a third component must produce an Error — not an
// IndexOutOfRange panic.
isolated function buildEdifactCompositeSchema() returns EdiSchema|error {
    json schemaJson = {
        "name": "CompositeOrders",
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
                "header": [
                    {
                        "code": "UNB",
                        "tag": "InterchangeHeader",
                        "fields": [
                            {"tag": "f1"},
                            {"tag": "syntax", "components": [{"tag": "id"}, {"tag": "version"}]},
                            {"tag": "sender", "components": [{"tag": "id"}, {"tag": "qualifier"}]},
                            {"tag": "recipient", "components": [{"tag": "id"}, {"tag": "qualifier"}]},
                            {"tag": "dateTime", "components": [{"tag": "date"}, {"tag": "time"}]},
                            {"tag": "controlRef"}
                        ]
                    }
                ],
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
                "fields": [{"tag": "code"}, {"tag": "documentMessageName"}, {"tag": "documentNumber"}]
            }
        ]
    };
    return getSchema(schemaJson);
}

@test:Config {}
function testComponentOverflowReturnsErrorNotPanic() returns error? {
    EdiSchema schema = check buildEdifactCompositeSchema();
    // Sender S002 carries 3 components ("SENDER", "ZZ", "INTERNAL") while the
    // schema declares 2 — previously an IndexOutOfRange panic.
    string input = "UNB+UNOA:2+SENDER:ZZ:INTERNAL+RECEIVER:ZZ+210527:1200+REF1'" +
        "UNH+1+ORDERS:D:03A:UN'BGM+220+PO123'UNT+3+1'UNZ+1+REF1'";
    json|Error result = headersFromEdiString(input, schema);
    if result !is Error {
        test:assertFail("Expected an Error for input with more components than the schema declares.");
    }
    test:assertTrue(result.message().includes("components"),
            "Error should mention the component overflow.");
}

// =============================================================================
// Fixed-length ("FL") schemas are not supported by envelope APIs
// =============================================================================

isolated function buildFixedLengthEnvelopeSchema() returns EdiSchema|error {
    json schemaJson = {
        "name": "FixedLengthWithEnvelope",
        "tag": "Root",
        "delimiters": {
            "segment": "~",
            "field": "FL",
            "component": "NOT_USED",
            "subcomponent": "NOT_USED",
            "repetition": "NOT_USED"
        },
        "envelope": {
            "interchange": {
                "header": [{"code": "ISA", "tag": "InterchangeHeader", "fields": genericFields(3)}],
                "trailer": [{"code": "IEA", "tag": "InterchangeTrailer", "fields": genericFields(3)}]
            },
            "transaction": {
                "header": [{"code": "ST", "tag": "TransactionHeader", "fields": genericFields(3)}],
                "trailer": [{"code": "SE", "tag": "TransactionTrailer", "fields": genericFields(3)}]
            }
        },
        "segments": []
    };
    return getSchema(schemaJson);
}

@test:Config {}
function testEnvelopeApisRejectFixedLengthSchema() returns error? {
    EdiSchema flSchema = check buildFixedLengthEnvelopeSchema();

    json|Error headers = headersFromEdiString("ISA...~", flSchema);
    test:assertTrue(headers is SchemaCompatibilityError,
            "headersFromEdiString must reject FL schemas with SchemaCompatibilityError.");

    EdiInterchange|Error ix = interchangeFromEdiString("ISA...~", flSchema);
    test:assertTrue(ix is SchemaCompatibilityError,
            "interchangeFromEdiString must reject FL schemas with SchemaCompatibilityError.");

    EdiInterchange dummy = {interchangeHeader: {}, transactions: [], interchangeTrailer: {}};
    string|Error written = interchangeToEdiString(dummy, flSchema);
    test:assertTrue(written is SchemaCompatibilityError,
            "interchangeToEdiString must reject FL schemas with SchemaCompatibilityError.");

    json|Error body = fromEdiString("ISA...~", flSchema);
    test:assertTrue(body is SchemaCompatibilityError,
            "fromEdiString with an FL envelope schema must reject with SchemaCompatibilityError.");
}
