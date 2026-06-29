// Copyright (c) 2023 WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
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

import ballerina/io;

// X12 segment codes
const string X12_INTERCHANGE_HEADER = "ISA";
const string X12_GROUP_HEADER = "GS";
const string X12_TRANSACTION_START = "ST";
const string X12_TRANSACTION_END = "SE";
const string X12_GROUP_TRAILER = "GE";
const string X12_INTERCHANGE_TRAILER = "IEA";

const string LINE_BREAK = "\n";

// EDIFACT segment codes
const string EDIFACT_INTERCHANGE_HEADER = "UNB";
const string EDIFACT_GROUP_HEADER = "UNG";
const string EDIFACT_TRANSACTION_START = "UNH";
const string EDIFACT_TRANSACTION_END = "UNT";
const string EDIFACT_GROUP_TRAILER = "UNE";
const string EDIFACT_INTERCHANGE_TRAILER = "UNZ";

type EdiContext record {|
    EdiSchema schema;
    string[] ediText = [];
    int rawIndex = 0;
|};

# Reads the given EDI text according to the provided schema.
# When the schema declares an `envelope`, envelope segments are skipped and only the
# single transaction body is parsed; use `interchangeFromEdiString` for multi-transaction input.
#
# + ediText - EDI text to be read
# + schema - Schema of the EDI text
# + return - JSON value containing the EDI data, or an `Error` when reading fails
public isolated function fromEdiString(string ediText, EdiSchema schema) returns json|Error {
    EdiContext context = {schema};
    EdiUnitSchema[] currentMapping = context.schema.segments;

    string text = ediText;
    EdiEnvelopeSchema? env = schema.envelope;
    if env is EdiEnvelopeSchema {
        check checkEnvelopeFixedLengthSupport(schema);
        text = stripBom(text);
        text = check stripUnaIfPresent(text, schema);
    }
    context.ediText = check splitSegments(text, context.schema.delimiters.segment);

    if env is EdiEnvelopeSchema {
        context.ediText = check stripEnvelopeSegmentsPositional(context.ediText, env, schema.delimiters.'field);
    } else {
        string trimmedText = text.trim();
        string txnStartCode = trimmedText.startsWith(X12_INTERCHANGE_HEADER) ? X12_TRANSACTION_START : EDIFACT_TRANSACTION_START;
        string fieldDelim = schema.delimiters.'field;
        int txnCount = 0;
        foreach string seg in context.ediText {
            if getSegmentCode(seg.trim(), fieldDelim) == txnStartCode {
                txnCount += 1;
            }
        }
        if txnCount > 1 {
            string[] singles = check splitTransactionStrings(ediText, schema);
            json result = check fromEdiString(singles[0], schema);
            foreach int txnIndex in 1 ..< singles.length() {
                json txnBody = check fromEdiString(singles[txnIndex], schema);
                result = check mergeTransactionBodies(result, txnBody);
            }
            return result;
        }
    }

    EdiSegmentGroup rootGroup = check readSegmentGroup(currentMapping, context, true);
    return rootGroup;
}

isolated function splitTransactionStrings(string ediText, EdiSchema schema) returns string[]|Error {
    string segTerm   = schema.delimiters.segment;
    string fieldDelim = schema.delimiters.'field;
    string[] rawSegs = check splitSegments(stripBom(ediText), segTerm);

    boolean isX12 = false;
    foreach string rawSeg in rawSegs {
        string trimmedSeg = rawSeg.trim();
        if trimmedSeg.length() > 0 {
            isX12 = trimmedSeg.startsWith(X12_INTERCHANGE_HEADER);
            break;
        }
    }

    string ixHdrCode  = isX12 ? X12_INTERCHANGE_HEADER  : EDIFACT_INTERCHANGE_HEADER;
    string grpHdrCode = isX12 ? X12_GROUP_HEADER         : EDIFACT_GROUP_HEADER;
    string txnStart   = isX12 ? X12_TRANSACTION_START    : EDIFACT_TRANSACTION_START;
    string txnEnd     = isX12 ? X12_TRANSACTION_END      : EDIFACT_TRANSACTION_END;
    string grpTrlCode = isX12 ? X12_GROUP_TRAILER        : EDIFACT_GROUP_TRAILER;
    string ixTrlCode  = isX12 ? X12_INTERCHANGE_TRAILER  : EDIFACT_INTERCHANGE_TRAILER;

    string ixHdr      = "";
    string grpHdr     = "";
    string ixCtrlNum  = "";
    string grpCtrlNum = "";
    string[] currentTxn = [];
    boolean inTxn     = false;
    string[] result   = [];

    foreach string raw in rawSegs {
        string seg = raw.trim();
        if seg.length() == 0 { continue; }
        string code = getSegmentCode(seg, fieldDelim);

        if code == ixHdrCode {
            ixHdr = seg;
            string[] segFields = segmentFields(seg, fieldDelim);
            ixCtrlNum = isX12 
                ? (segFields.length() > 13 ? segFields[13] : "") 
                : (segFields.length() > 5 ? segFields[5] : "");
        } else if code == grpHdrCode {
            grpHdr = seg;
            string[] segFields = segmentFields(seg, fieldDelim);
            grpCtrlNum = isX12 
                ? (segFields.length() > 6 ? segFields[6] : "") 
                : (segFields.length() > 1 ? segFields[1] : "");
        } else if code == txnStart {
            inTxn = true;
            currentTxn = [seg];
        } else if code == txnEnd && inTxn {
            currentTxn.push(seg);
            string single = "";
            if ixHdr.length() > 0 {
                single += ixHdr + segTerm + LINE_BREAK;
            }
            if grpHdr.length() > 0 {
                single += grpHdr + segTerm + LINE_BREAK;
            }
            foreach string txnSeg in currentTxn {
                single += txnSeg + segTerm + LINE_BREAK;
            }
            if grpHdr.length() > 0 {
                single += grpTrlCode + fieldDelim + "1" + fieldDelim + grpCtrlNum + segTerm + LINE_BREAK;
            }
            if ixHdr.length() > 0 {
                single += ixTrlCode + fieldDelim + "1" + fieldDelim + ixCtrlNum + segTerm;
            }
            result.push(single.trim());
            currentTxn = [];
            inTxn = false;
        } else if inTxn {
            currentTxn.push(seg);
        }
    }
    return result;
}

isolated function segmentFields(string seg, string delim) returns string[] {
    string[] parts = [];
    int startIdx = 0;
    int? pos = seg.indexOf(delim, startIdx);
    while pos is int {
        parts.push(seg.substring(startIdx, pos));
        startIdx = pos + delim.length();
        pos = seg.indexOf(delim, startIdx);
    }
    parts.push(seg.substring(startIdx));
    return parts;
}

isolated function mergeTransactionBodies(json base, json addition) returns json|Error {
    if base !is map<json> || addition !is map<json> {
        return base;
    }
    map<json> baseMap = base;
    map<json> addMap = addition;
    map<json> result = {};
    foreach string 'key in baseMap.keys() {
        json? baseValue = baseMap['key];
        if baseValue is json {
            result['key] = baseValue;
        }
    }
    foreach string 'key in addMap.keys() {
        json? addVal = addMap['key];
        if addVal is () {
            continue;
        }
        json? baseVal = result['key];
        if addVal is json[] && baseVal is json[] {
            json[] merged = [];
            foreach json item in baseVal {
                merged.push(item);
            }
            foreach json item in addVal {
                merged.push(item);
            }
            result['key] = merged;
        } else if addVal is map<json> && baseVal is map<json> {
            result['key] = check mergeTransactionBodies(baseVal, addVal);
        }
    }
    return result;
}

# Writes the given JSON varibale into a EDI text according to the provided schema.
#
# + msg - JSON value to be written into EDI
# + schema - Schema of the EDI text
# + return - EDI text containing the data provided in the JSON variable. Error if the reading fails.
public isolated function toEdiString(json msg, EdiSchema schema) returns string|Error {
    if msg !is map<json> {
        return error(string `Input is not compatible with the schema.`);
    }
    // Clone schema to prevent modifying originals with references.
    // `cloneWithType` returns a plain `error`, which is not a subtype of the
    // distinct `Error`, so `check` cannot be used here — cast instead.
    EdiSchema|error clonedSchema = schema.cloneWithType();
    if clonedSchema is error {
        return <Error>clonedSchema;
    }
    EdiContext context = {schema: clonedSchema};
    check writeSegmentGroup(msg, clonedSchema, context);
    string[] ediText = context.ediText;
    if ediText.length() == 0 {
        return "";
    }
    // A single join (suffix after every entry) avoids the quadratic cost of
    // repeated `+=` concatenation when serialising large messages.
    string suffix = clonedSchema.delimiters.segment == "\n" ? "" : "\n";
    return string:'join(suffix, ...ediText) + suffix;
}

# Creates an EDI schema from a string or a JSON.
#
# + schema - Schema of the EDI type 
# + return - Error is returned if the given schema is not valid
public isolated function getSchema(string|json schema) returns EdiSchema|error {
    if !(schema is map<json> || schema is string) {
        return error("Schema is not valid.");
    }
    json schemaJson;
    if schema is string {
        io:StringReader sr = new (schema);
        schemaJson = check sr.readJson();
    } else {
        schemaJson = schema;
    }
    // Clone schema to prevent modifying originals with references.
    json clonedSchema = check schemaJson.cloneWithType();
    check denormalizeSchema(clonedSchema);
    return clonedSchema.cloneWithType(EdiSchema);
}

# Represents EDI module related errors
public type Error distinct error;

# Represents an input EDI text that does not conform to the expected envelope structure
# (e.g. a missing or malformed envelope segment, or multiple interchanges in one call).
public type InvalidEnvelopeError distinct Error;

# Represents a schema that cannot support the requested operation
# (e.g. no `envelope` declaration, or a fixed-length "FL" schema used with envelope-aware APIs).
public type SchemaCompatibilityError distinct Error;

# Represents a refusal to serialize an `EdiInterchange`
# (e.g. a transaction `body` holds an `error` from a fail-safe parse).
public type SerializationError distinct Error;
