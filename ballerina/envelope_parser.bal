// Copyright (c) 2026 WSO2 LLC. (http://www.wso2.org) All Rights Reserved.
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

// X12 ISA segment is fixed-width. Field delimiter is always at position 3.
// Total ISA segment length is 106 characters.
const int ISA_SEGMENT_LENGTH = 106;

# Reads the X12 ISA interchange header and (if present) the GS functional-group
# header from the given EDI text without requiring a schema. This is useful for
# routing and schema selection before the full schema has been loaded.
#
# + ediText - Raw EDI text starting at or before the ISA segment
# + return - Parsed X12Headers, or Error if the ISA segment cannot be found/parsed
public isolated function peekX12Headers(string ediText) returns X12Headers|Error {
    string trimmed = ediText.trim();
    if !trimmed.startsWith("ISA") {
        return error Error("EDI text does not start with an ISA segment.");
    }
    if trimmed.length() < ISA_SEGMENT_LENGTH {
        return error Error(string `ISA segment is too short. Expected ${ISA_SEGMENT_LENGTH} characters, found ${trimmed.length()}.`);
    }

    // ISA is fixed-width: delimiter at position 3
    string fieldDelimiter = trimmed.substring(3, 4);
    // Split manually by fixed positions per X12 ISA field widths
    // ISA*AA*BBBBBBBBBB*CC*DDDDDDDDDD*EE*FFFFFFFFFFFFFFF*GG*HHHHHHHHHHHHHHH*IIIIII*JJJJ*K*MMMMMMMMM*N*
    // Positions (1-based, after the ISA tag + delimiters):
    //   ISA(0) field(1) ISA01(2) field(3) ISA02(4) ...
    string[] parts = splitByDelimiter(trimmed.substring(0, ISA_SEGMENT_LENGTH), fieldDelimiter);
    if parts.length() < 16 {
        return error Error(string `ISA segment has fewer fields than expected. Found ${parts.length()} fields.`);
    }

    X12ISA isa = {
        authInfoQualifier: parts[1].trim(),
        authInfo: parts[2].trim(),
        securityQualifier: parts[3].trim(),
        securityInfo: parts[4].trim(),
        senderQualifier: parts[5].trim(),
        senderId: parts[6].trim(),
        receiverQualifier: parts[7].trim(),
        receiverId: parts[8].trim(),
        date: parts[9].trim(),
        time: parts[10].trim(),
        version: parts[12].trim(),
        controlNumber: parts[13].trim(),
        usageIndicator: parts[15].trim()
    };

    // The segment terminator is the last character of the ISA segment (position 105)
    string segmentTerminator = trimmed.substring(ISA_SEGMENT_LENGTH - 1, ISA_SEGMENT_LENGTH);

    // Try to find the next segment (GS)
    X12GS? gs = ();
    string afterISA = trimmed.length() > ISA_SEGMENT_LENGTH ? trimmed.substring(ISA_SEGMENT_LENGTH) : "";
    // skip optional newline after segment terminator
    string remaining = afterISA.trim();
    if remaining.startsWith("GS") {
        int segEnd = remaining.indexOf(segmentTerminator) ?: remaining.length();
        string gsSegText = remaining.substring(0, segEnd);
        string[] gsFields = splitByDelimiter(gsSegText, fieldDelimiter);
        if gsFields.length() >= 9 {
            gs = {
                functionalIdentifier: gsFields[1].trim(),
                senderId: gsFields[2].trim(),
                receiverId: gsFields[3].trim(),
                date: gsFields[4].trim(),
                time: gsFields[5].trim(),
                controlNumber: gsFields[6].trim(),
                version: gsFields[8].trim()
            };
        }
    }
    return {isa, gs};
}

# Reads the EDIFACT UNB interchange header and (if present) the UNH message
# header from the given EDI text without requiring a schema. Handles the optional
# UNA service string advice to determine delimiters.
#
# + ediText - Raw EDI text starting at or before the UNA/UNB segment
# + return - Parsed EdifactHeaders, or Error if UNB cannot be found/parsed
public isolated function peekEdifactHeaders(string ediText) returns EdifactHeaders|Error {
    string trimmed = ediText.trim();

    // EDIFACT defaults
    string fieldDelim = "+";
    string componentDelim = ":";
    string segmentTerminator = "'";

    string remaining = trimmed;

    // Parse UNA if present
    if trimmed.startsWith("UNA") {
        if trimmed.length() < 9 {
            return error Error("UNA service string is too short.");
        }
        // UNA: positions 3-8 define: component(3), field(4), decimal(5), release(6), reserved(7), segment(8)
        componentDelim = trimmed.substring(3, 4);
        fieldDelim = trimmed.substring(4, 5);
        segmentTerminator = trimmed.substring(8, 9);
        // Skip past UNA (9 chars) + optional segment terminator
        remaining = trimmed.substring(9).trim();
    }

    if !remaining.startsWith("UNB") {
        return error Error("EDI text does not contain a UNB segment after UNA (or at the start).");
    }

    // Find end of UNB segment
    int unbEnd = remaining.indexOf(segmentTerminator) ?: remaining.length();
    string unbText = remaining.substring(0, unbEnd);
    string[] unbFields = splitByDelimiter(unbText, fieldDelim);

    if unbFields.length() < 5 {
        return error Error(string `UNB segment has fewer fields than expected. Found ${unbFields.length()} fields.`);
    }

    // UNB+SYNTAX:VERSION+SENDER:QUALIFIER+RECIPIENT:QUALIFIER+DATE:TIME+CONTROLREF
    string[] syntaxParts = splitByDelimiter(unbFields[1], componentDelim);
    string[] senderParts = splitByDelimiter(unbFields[2], componentDelim);
    string[] recipientParts = splitByDelimiter(unbFields[3], componentDelim);
    string[] dateTimeParts = splitByDelimiter(unbFields[4], componentDelim);

    EdifactUNB unb = {
        syntaxIdentifier: {
            syntaxId: syntaxParts.length() > 0 ? syntaxParts[0].trim() : "",
            syntaxVersion: syntaxParts.length() > 1 ? syntaxParts[1].trim() : ""
        },
        sender: {
            id: senderParts.length() > 0 ? senderParts[0].trim() : "",
            qualifier: senderParts.length() > 1 ? senderParts[1].trim() : ""
        },
        recipient: {
            id: recipientParts.length() > 0 ? recipientParts[0].trim() : "",
            qualifier: recipientParts.length() > 1 ? recipientParts[1].trim() : ""
        },
        dateAndTime: {
            date: dateTimeParts.length() > 0 ? dateTimeParts[0].trim() : "",
            time: dateTimeParts.length() > 1 ? dateTimeParts[1].trim() : ""
        },
        controlRef: unbFields.length() > 5 ? unbFields[5].trim() : ""
    };

    // Try to find UNH
    EdifactUNH? unh = ();
    string afterUNB = remaining.length() > unbEnd + 1 ? remaining.substring(unbEnd + 1) : "";
    string nextSeg = afterUNB.trim();
    if nextSeg.startsWith("UNH") {
        int unhEnd = nextSeg.indexOf(segmentTerminator) ?: nextSeg.length();
        string unhText = nextSeg.substring(0, unhEnd);
        string[] unhFields = splitByDelimiter(unhText, fieldDelim);
        if unhFields.length() >= 3 {
            string[] msgIdParts = splitByDelimiter(unhFields[2], componentDelim);
            unh = {
                messageRef: unhFields.length() > 1 ? unhFields[1].trim() : "",
                messageIdentifier: {
                    messageType: msgIdParts.length() > 0 ? msgIdParts[0].trim() : "",
                    version: msgIdParts.length() > 1 ? msgIdParts[1].trim() : "",
                    release: msgIdParts.length() > 2 ? msgIdParts[2].trim() : "",
                    controlAgency: msgIdParts.length() > 3 ? msgIdParts[3].trim() : ""
                }
            };
        }
    }

    return {unb, unh};
}

# Parses only the header segments of the given EDI text according to the schema's
# `headerSegments` definition, and returns immediately without scanning the body.
# Use this when you need envelope routing information quickly.
#
# Requires `schema.headerSegments` to be non-empty. Returns an `EdiError` if called
# with a schema that has no `headerSegments` (i.e. an older schema.json file).
#
# + ediText - EDI text to read
# + schema - Schema containing a `headerSegments` definition
# + return - JSON representation of the parsed header segments, or Error
public isolated function headersFromEdiString(string ediText, EdiSchema schema) returns json|Error {
    if schema.headerSegments.length() == 0 {
        return error Error(
            string `Schema '${schema.name}' has no headerSegments defined. ` +
            "Regenerate the schema using the latest edi-tools to use this function."
        );
    }
    EdiContext context = {schema};
    context.ediText = check splitSegments(ediText, schema.delimiters.segment);
    EdiSegmentGroup headers = check readSegmentGroup(schema.headerSegments, context, false);
    return headers;
}

# Parses the EDI text in a single pass, returning the parsed envelope header and
# trailer segments together with the transaction body left as raw (unparsed) segment
# strings. Useful for forwarding, splitting, or envelope-level validation without
# the cost of a full deep parse.
#
# Requires both `schema.headerSegments` and `schema.trailerSegments` to be non-empty.
# Returns an `EdiError` if called with an older schema that lacks these fields.
#
# + ediText - EDI text to read
# + schema - Schema containing both `headerSegments` and `trailerSegments` definitions
# + return - EdiEnvelope with parsed headers, raw body strings, and parsed trailers; or Error
public isolated function envelopeFromEdiString(string ediText, EdiSchema schema) returns EdiEnvelope|Error {
    if schema.headerSegments.length() == 0 {
        return error Error(
            string `Schema '${schema.name}' has no headerSegments defined. ` +
            "Regenerate the schema using the latest edi-tools to use this function."
        );
    }
    if schema.trailerSegments.length() == 0 {
        return error Error(
            string `Schema '${schema.name}' has no trailerSegments defined. ` +
            "Regenerate the schema using the latest edi-tools to use this function."
        );
    }

    string[] allSegments = check splitSegments(ediText, schema.delimiters.segment);

    // Build a set of trailer segment codes for quick lookup
    string[] trailerCodes = getSegmentCodes(schema.trailerSegments);

    // Parse header segments
    EdiContext headerContext = {schema, ediText: allSegments};
    EdiSegmentGroup headers = check readSegmentGroup(schema.headerSegments, headerContext, false);
    int bodyStart = headerContext.rawIndex;

    // Collect body segments (everything before the first trailer segment code)
    string[] body = [];
    int bodyEnd = bodyStart;
    while bodyEnd < allSegments.length() {
        string segText = allSegments[bodyEnd].trim();
        boolean isTrailer = false;
        foreach string trailerCode in trailerCodes {
            if segText.startsWith(trailerCode) {
                isTrailer = true;
                break;
            }
        }
        if isTrailer {
            break;
        }
        body.push(segText);
        bodyEnd += 1;
    }

    // Parse trailer segments
    EdiContext trailerContext = {schema, ediText: allSegments, rawIndex: bodyEnd};
    EdiSegmentGroup trailers = check readSegmentGroup(schema.trailerSegments, trailerContext, false);

    return {headers, body, trailers};
}

// Returns the top-level segment codes declared in a list of EdiUnitSchemas.
// Only EdiSegSchema entries are considered (group schemas use their first child).
isolated function getSegmentCodes(EdiUnitSchema[] schemas) returns string[] {
    string[] codes = [];
    foreach EdiUnitSchema s in schemas {
        if s is EdiSegSchema {
            codes.push(s.code);
        } else if s is EdiSegGroupSchema {
            // Use the code of the first segment in the group as the trigger
            foreach EdiUnitSchema child in s.segments {
                if child is EdiSegSchema {
                    codes.push(child.code);
                    break;
                }
            }
        }
    }
    return codes;
}

// Splits a string by a single-character delimiter without using regex
// (avoids the overhead and escape issues of regex-based split for single chars).
isolated function splitByDelimiter(string text, string delimiter) returns string[] {
    string[] parts = [];
    int startIdx = 0;
    int i = 0;
    while i < text.length() {
        if text.substring(i, i + 1) == delimiter {
            parts.push(text.substring(startIdx, i));
            startIdx = i + 1;
        }
        i += 1;
    }
    parts.push(text.substring(startIdx));
    return parts;
}
