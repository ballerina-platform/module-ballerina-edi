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
#
# + ediText - EDI text to be read
# + schema - Schema of the EDI text
# + return - JSON variable containing EDI data. Error if the reading fails.
public isolated function fromEdiString(string ediText, EdiSchema schema) returns json|Error {
    EdiContext context = {schema};
    EdiUnitSchema[] currentMapping = context.schema.segments;
    context.ediText = check splitSegments(ediText, context.schema.delimiters.segment);

    string fieldDelim = schema.delimiters.'field;
    int x12TxnCount = 0;
    int edifactTxnCount = 0;
    foreach string seg in context.ediText {
        string segCode = segmentCode(seg.trim(), fieldDelim);
        if segCode == X12_TRANSACTION_START {
            x12TxnCount += 1;
        } else if segCode == EDIFACT_TRANSACTION_START {
            edifactTxnCount += 1;
        }
    }
    if x12TxnCount > 1 || edifactTxnCount > 1 {
        string[] singles = check splitTransactionStrings(ediText, schema);
        if singles.length() == 0 {
            return error Error("EDI text contains multiple transaction starts but no complete transaction sets.");
        }
        json result = check fromEdiString(singles[0], schema);
        foreach int txnIndex in 1 ..< singles.length() {
            json txnBody = check fromEdiString(singles[txnIndex], schema);
            result = check mergeTransactionBodies(result, txnBody);
        }
        return result;
    }

    EdiSegmentGroup rootGroup = check readSegmentGroup(currentMapping, context, true);
    return rootGroup;
}

isolated function segmentCode(string seg, string fieldDelim) returns string {
    int? pos = seg.indexOf(fieldDelim);
    return pos is int ? seg.substring(0, pos) : seg;
}

isolated function splitTransactionStrings(string ediText, EdiSchema schema) returns string[]|Error {
    string segTerm = schema.delimiters.segment;
    string fieldDelim = schema.delimiters.'field;
    string[] rawSegs = check splitSegments(ediText, segTerm);

    boolean isX12 = false;
    foreach string rawSeg in rawSegs {
        string trimmedSeg = rawSeg.trim();
        if trimmedSeg.length() > 0 {
            string firstCode = segmentCode(trimmedSeg, fieldDelim);
            if firstCode == X12_INTERCHANGE_HEADER || firstCode == X12_GROUP_HEADER || firstCode == X12_TRANSACTION_START {
                isX12 = true;
                break;
            }
            if firstCode == EDIFACT_INTERCHANGE_HEADER || firstCode == EDIFACT_GROUP_HEADER || firstCode == EDIFACT_TRANSACTION_START {
                break;
            }
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
        string code = segmentCode(seg, fieldDelim);

        if code == ixHdrCode {
            ixHdr = seg;
            string[] segFields = check split(seg, fieldDelim);
            ixCtrlNum = isX12
                ? (segFields.length() > 13 ? segFields[13] : "")
                : (segFields.length() > 5 ? segFields[5] : "");
        } else if code == grpHdrCode {
            grpHdr = seg;
            string[] segFields = check split(seg, fieldDelim);
            // X12 GS06 (index 6) | EDIFACT UNG 0048 (index 5)
            grpCtrlNum = isX12
                ? (segFields.length() > 6 ? segFields[6] : "")
                : (segFields.length() > 5 ? segFields[5] : "");
        } else if code == txnStart {
            if inTxn {
                return error Error(string `Transaction '${txnStart}' started before previous '${txnEnd}' was closed.`);
            }
            inTxn = true;
            currentTxn = [seg];
        } else if code == txnEnd && inTxn {
            currentTxn.push(seg);
            string single = "";
            if ixHdr.length() > 0 {
                single += ixHdr + segTerm;
            }
            if grpHdr.length() > 0 {
                single += grpHdr + segTerm;
            }
            foreach string txnSeg in currentTxn {
                single += txnSeg + segTerm;
            }
            if grpHdr.length() > 0 {
                single += grpTrlCode + fieldDelim + "1" + fieldDelim + grpCtrlNum + segTerm;
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
    if inTxn {
        return error Error(string `Transaction '${txnStart}' is missing its closing '${txnEnd}'.`);
    }
    return result;
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
        if baseVal is () {
            result['key] = addVal;
        } else if addVal is json[] && baseVal is json[] {
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
    if !(msg is map<json>) {
        return error(string `Input is not compatible with the schema.`);
    }
    // Skip check here since return type must be edi:Error.
    // Clone schema to prevent modifying originals with references.
    EdiSchema|error clonedSchema = schema.cloneWithType();
    if clonedSchema is error {
        return <Error> clonedSchema;
    }
    EdiContext context = {schema: clonedSchema};
    check writeSegmentGroup(msg, clonedSchema, context);
    string ediOutput = "";
    foreach string s in context.ediText {
        ediOutput += s + (clonedSchema.delimiters.segment == "\n" ? "" : "\n");
    }
    return ediOutput;
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
