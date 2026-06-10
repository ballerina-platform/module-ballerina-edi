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

import ballerina/io;

// X12 ISA segment is fixed-width by standard: total length is 106 characters
// (including the trailing segment terminator). Field delimiter is at position 3.
const int ISA_SEGMENT_LENGTH = 106;

// Default file-read sizes for the two file-based header APIs.
// 512 chars covers ISA(106) + GS or UNA(9) + UNB + UNH for any conforming input.
// 4096 chars covers a schema-driven envelope header section even with multiple
// auxiliary segments (UNG, BIN, etc.) at the interchange / group level.
const int SCHEMA_FREE_READ_CHARS = 512;
const int SCHEMA_DRIVEN_READ_CHARS = 4096;

// =============================================================================
// Schema-free X12
// =============================================================================

# Parses X12 interchange headers (ISA and optionally GS) from raw EDI text
# without requiring a schema. The X12 ISA segment is fixed-width (106 chars)
# and the field delimiter is determined from position 3 of the input.
#
# + ediText - raw X12 EDI text
# + return - parsed X12Headers, or Error when the ISA segment cannot be parsed
public isolated function x12HeadersFromEdiString(string ediText) returns X12Headers|Error {
    string trimmed = ediText.trim();
    if !trimmed.startsWith("ISA") {
        return error Error("EDI text does not start with an ISA segment.");
    }
    if trimmed.length() < ISA_SEGMENT_LENGTH {
        return error Error(string `ISA segment is too short. Expected ${ISA_SEGMENT_LENGTH} characters, found ${trimmed.length()}.`);
    }

    string fieldDelimiter = trimmed.substring(3, 4);
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

    // Segment terminator is the last character of the fixed-width ISA segment.
    string segmentTerminator = trimmed.substring(ISA_SEGMENT_LENGTH - 1, ISA_SEGMENT_LENGTH);

    X12GS? gs = ();
    string afterISA = trimmed.length() > ISA_SEGMENT_LENGTH ? trimmed.substring(ISA_SEGMENT_LENGTH) : "";
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
    if gs is X12GS {
        return {isa, gs};
    }
    return {isa};
}

# Reads X12 interchange headers from a file without requiring a schema.
# Reads only the first 512 characters using a `ReadableCharacterChannel`,
# which is enough for ISA (106) plus GS (well under 100).
#
# + filePath - path to the EDI file
# + return - parsed X12Headers, or Error when the file cannot be read or parsed
public isolated function x12HeadersFromEdiFile(string filePath) returns X12Headers|Error {
    string text = check readFileChars(filePath, SCHEMA_FREE_READ_CHARS);
    return x12HeadersFromEdiString(text);
}

// =============================================================================
// Schema-free EDIFACT
// =============================================================================

# Parses EDIFACT interchange headers (UNB and optionally UNH) from raw EDI text
# without requiring a schema. Honours an optional UNA service string advice
# segment to discover delimiters.
#
# + ediText - raw EDIFACT EDI text
# + return - parsed EdifactHeaders, or Error when UNB cannot be parsed
public isolated function edifactHeadersFromEdiString(string ediText) returns EdifactHeaders|Error {
    string trimmed = ediText.trim();

    // EDIFACT defaults per UN/EDIFACT when UNA is absent.
    string fieldDelim = "+";
    string componentDelim = ":";
    string segmentTerminator = "'";
    string releaseChar = "?";

    string remaining = trimmed;

    if trimmed.startsWith("UNA") {
        if trimmed.length() < 9 {
            return error Error("UNA service string is too short.");
        }
        // UNA layout: positions 3-8 carry component, field, decimal,
        // release, reserved, segment terminator (in that order).
        componentDelim = trimmed.substring(3, 4);
        fieldDelim = trimmed.substring(4, 5);
        releaseChar = trimmed.substring(6, 7);
        segmentTerminator = trimmed.substring(8, 9);
        remaining = trimmed.substring(9).trim();
    }

    if !remaining.startsWith("UNB") {
        return error Error("EDI text does not contain a UNB segment after UNA (or at the start).");
    }

    int unbEnd = indexOfUnescaped(remaining, segmentTerminator, releaseChar);
    string unbText = remaining.substring(0, unbEnd);
    string[] unbFields = splitByDelimiter(unbText, fieldDelim);

    // UNB requires S001 syntax id, S002 sender, S003 recipient,
    // S004 date/time, and 0020 interchange control reference (mandatory).
    // Total: tag + 5 composites = 6 entries minimum.
    if unbFields.length() < 6 {
        return error Error(string `UNB segment has fewer fields than expected. Found ${unbFields.length()} fields.`);
    }

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
        controlRef: unbFields[5].trim()
    };

    EdifactUNH? unh = ();
    string afterUNB = remaining.length() > unbEnd + 1 ? remaining.substring(unbEnd + 1) : "";
    string nextSeg = afterUNB.trim();
    if nextSeg.startsWith("UNH") {
        int unhEnd = indexOfUnescaped(nextSeg, segmentTerminator, releaseChar);
        string unhText = nextSeg.substring(0, unhEnd);
        string[] unhFields = splitByDelimiter(unhText, fieldDelim);
        if unhFields.length() >= 3 {
            string[] msgIdParts = splitByDelimiter(unhFields[2], componentDelim);
            unh = {
                messageRef: unhFields[1].trim(),
                messageIdentifier: {
                    messageType: msgIdParts.length() > 0 ? msgIdParts[0].trim() : "",
                    version: msgIdParts.length() > 1 ? msgIdParts[1].trim() : "",
                    release: msgIdParts.length() > 2 ? msgIdParts[2].trim() : "",
                    controlAgency: msgIdParts.length() > 3 ? msgIdParts[3].trim() : ""
                }
            };
        }
    }

    if unh is EdifactUNH {
        return {unb, unh};
    }
    return {unb};
}

# Reads EDIFACT interchange headers from a file without requiring a schema.
# Reads only the first 512 characters from the file, which is enough for any
# UNA + UNB + UNH combination.
#
# + filePath - path to the EDI file
# + return - parsed EdifactHeaders, or Error when the file cannot be read or parsed
public isolated function edifactHeadersFromEdiFile(string filePath) returns EdifactHeaders|Error {
    string text = check readFileChars(filePath, SCHEMA_FREE_READ_CHARS);
    return edifactHeadersFromEdiString(text);
}

// =============================================================================
// Schema-driven header-only
// =============================================================================

# Parses only the envelope header segments defined in the schema and stops.
# The remainder of the document is never processed.
#
# Returns an error if `schema.envelope` is `()` (old schema guard) directing
# the caller to regenerate the schema.
#
# + ediText - raw EDI text
# + schema - EDI schema with a non-nil `envelope`
# + return - parsed header sections as JSON (interchange / group? / transaction),
# or Error
public isolated function headersFromEdiString(string ediText, EdiSchema schema) returns json|Error {
    EdiEnvelopeSchema env = check getEnvelopeOrError(schema);
    string[] segments = check splitSegments(ediText, schema.delimiters.segment);
    return readEnvelopeHeaders(segments, schema, env);
}

# Reads only the envelope header segments from an EDI file. Reads only the first
# 4096 characters via a `ReadableCharacterChannel` and parses them. Returns an
# error if the headers exceed the read window.
#
# + filePath - path to the EDI file
# + schema - EDI schema with a non-nil `envelope`
# + return - parsed header sections as JSON, or Error
public isolated function headersFromEdiFile(string filePath, EdiSchema schema) returns json|Error {
    string text = check readFileChars(filePath, SCHEMA_DRIVEN_READ_CHARS);
    return headersFromEdiString(text, schema);
}

// =============================================================================
// Schema-driven hierarchical interchange (fail-safe per transaction body)
// =============================================================================

# Parses the full envelope hierarchy and returns an `EdiInterchange`. Envelope
# headers and trailers are fail-fast — a malformed envelope segment aborts the
# parse with an Error. The transaction body is fail-safe — when a body cannot
# be parsed, the resulting `EdiTransaction.body` holds the parse `error` and
# the rest of the interchange continues.
#
# Returns an error if `schema.envelope` is `()` (old schema guard).
#
# + ediText - raw EDI text
# + schema - EDI schema with a non-nil `envelope`
# + return - parsed `EdiInterchange`, or Error
public isolated function interchangeFromEdiString(string ediText, EdiSchema schema) returns EdiInterchange|Error {
    EdiEnvelopeSchema env = check getEnvelopeOrError(schema);
    string[] segments = check splitSegments(ediText, schema.delimiters.segment);

    // Parse interchange header.
    EdiContext ihCtx = {schema, ediText: segments, rawIndex: 0};
    EdiSegmentGroup ihGroup = check readSegmentGroup(env.interchange.header, ihCtx, false);
    int bodyStart = ihCtx.rawIndex;

    // Locate interchange trailer by its leading code(s), scanning from the end.
    string[] interchangeTrailerCodes = envelopeLevelCodes(env.interchange.trailer);
    int? trailerIdx = findFirstMatchingCode(segments, interchangeTrailerCodes,
            bodyStart, segments.length(), schema.delimiters.'field);
    if trailerIdx is () {
        return error Error("Interchange trailer segment not found.");
    }
    EdiContext itCtx = {schema, ediText: segments, rawIndex: trailerIdx};
    EdiSegmentGroup itGroup = check readSegmentGroup(env.interchange.trailer, itCtx, false);

    // Body slice between interchange header and trailer.
    string[] body = segments.slice(bodyStart, trailerIdx);

    EdiInterchange result;
    if env?.group is EdiEnvelopeLevel {
        EdiFunctionalGroup[] groups = check parseGroups(body, schema, env);
        result = {
            interchangeHeader: ihGroup.toJson(),
            groups,
            interchangeTrailer: itGroup.toJson()
        };
    } else {
        EdiTransaction[] transactions = check parseTransactions(body, schema, env);
        result = {
            interchangeHeader: ihGroup.toJson(),
            transactions,
            interchangeTrailer: itGroup.toJson()
        };
    }
    return result;
}

// =============================================================================
// Internal helpers
// =============================================================================

isolated function getEnvelopeOrError(EdiSchema schema) returns EdiEnvelopeSchema|Error {
    EdiEnvelopeSchema? env = schema.envelope;
    if env is () {
        return error Error(string `Schema '${schema.name}' has no envelope defined. ` +
                "Regenerate the schema with edi-tools 2.2.0 or later to use envelope-aware APIs.");
    }
    return env;
}

// Reads the envelope header sections (interchange, optional group, transaction)
// from a pre-split segment array and assembles them into a JSON map.
isolated function readEnvelopeHeaders(string[] segments, EdiSchema schema,
        EdiEnvelopeSchema env) returns json|Error {
    EdiContext ctx = {schema, ediText: segments, rawIndex: 0};

    EdiSegmentGroup interchange = check readSegmentGroup(env.interchange.header, ctx, false);
    map<json> result = {interchange: interchange.toJson()};

    EdiEnvelopeLevel? grpLevel = env?.group;
    if grpLevel is EdiEnvelopeLevel {
        EdiSegmentGroup grp = check readSegmentGroup(grpLevel.header, ctx, false);
        result["group"] = grp.toJson();
    }

    EdiSegmentGroup txn = check readSegmentGroup(env.'transaction.header, ctx, false);
    result["transaction"] = txn.toJson();

    return result;
}

// Iterates GS...GE pairs (or equivalent) in the interchange body, building one
// EdiFunctionalGroup per pair. Group headers and trailers fail-fast; nested
// transaction bodies remain fail-safe.
isolated function parseGroups(string[] body, EdiSchema schema, EdiEnvelopeSchema env)
        returns EdiFunctionalGroup[]|Error {
    EdiEnvelopeLevel grpLevel = <EdiEnvelopeLevel>env?.group;
    string[] groupHeaderCodes = envelopeLevelCodes(grpLevel.header);
    string[] groupTrailerCodes = envelopeLevelCodes(grpLevel.trailer);

    EdiFunctionalGroup[] groups = [];
    int i = 0;
    string fieldDelim = schema.delimiters.'field;
    while i < body.length() {
        string code = getSegmentCode(body[i].trim(), fieldDelim);
        if !codeIn(code, groupHeaderCodes) {
            return error Error(string `Expected functional group header (one of ${groupHeaderCodes.toString()}), found '${code}'.`);
        }

        // Parse group header
        EdiContext ghCtx = {schema, ediText: body, rawIndex: i};
        EdiSegmentGroup gh = check readSegmentGroup(grpLevel.header, ghCtx, false);
        int afterGh = ghCtx.rawIndex;

        // Locate group trailer
        int? gtIdx = findFirstMatchingCode(body, groupTrailerCodes, afterGh, body.length(), fieldDelim);
        if gtIdx is () {
            return error Error("Functional group trailer segment not found.");
        }
        EdiContext gtCtx = {schema, ediText: body, rawIndex: gtIdx};
        EdiSegmentGroup gt = check readSegmentGroup(grpLevel.trailer, gtCtx, false);
        int afterGt = gtCtx.rawIndex;

        string[] inner = body.slice(afterGh, gtIdx);
        EdiTransaction[] transactions = check parseTransactions(inner, schema, env);

        groups.push({
            groupHeader: gh.toJson(),
            transactions,
            groupTrailer: gt.toJson()
        });
        i = afterGt;
    }
    return groups;
}

// Iterates ST...SE pairs (or UNH...UNT) in the supplied segment slice. Each
// transaction's header and trailer are fail-fast; the body is fail-safe — when
// the body cannot be parsed, the resulting `error` is captured in the
// transaction's `body` field.
isolated function parseTransactions(string[] body, EdiSchema schema, EdiEnvelopeSchema env)
        returns EdiTransaction[]|Error {
    string[] txnHeaderCodes = envelopeLevelCodes(env.'transaction.header);
    string[] txnTrailerCodes = envelopeLevelCodes(env.'transaction.trailer);

    EdiTransaction[] transactions = [];
    int i = 0;
    string fieldDelim = schema.delimiters.'field;
    while i < body.length() {
        string code = getSegmentCode(body[i].trim(), fieldDelim);
        if !codeIn(code, txnHeaderCodes) {
            return error Error(string `Expected transaction header (one of ${txnHeaderCodes.toString()}), found '${code}'.`);
        }

        EdiContext thCtx = {schema, ediText: body, rawIndex: i};
        EdiSegmentGroup th = check readSegmentGroup(env.'transaction.header, thCtx, false);
        int afterTh = thCtx.rawIndex;

        int? ttIdx = findFirstMatchingCode(body, txnTrailerCodes, afterTh, body.length(), fieldDelim);
        if ttIdx is () {
            return error Error("Transaction trailer segment not found.");
        }
        EdiContext ttCtx = {schema, ediText: body, rawIndex: ttIdx};
        EdiSegmentGroup tt = check readSegmentGroup(env.'transaction.trailer, ttCtx, false);
        int afterTt = ttCtx.rawIndex;

        string[] bodySegs = body.slice(afterTh, ttIdx);
        json|error parsedBody = parseTransactionBody(bodySegs, schema);

        transactions.push({
            transactionHeader: th.toJson(),
            body: parsedBody,
            transactionTrailer: tt.toJson()
        });
        i = afterTt;
    }
    return transactions;
}

// Parses the segment slice of a single transaction's body using
// `schema.segments`. Errors are returned as values rather than thrown — this
// is what makes `interchangeFromEdiString` fail-safe at the body level.
isolated function parseTransactionBody(string[] bodySegs, EdiSchema schema) returns json|error {
    if bodySegs.length() == 0 {
        return {};
    }
    EdiContext ctx = {schema, ediText: bodySegs, rawIndex: 0};
    EdiSegmentGroup grp = check readSegmentGroup(schema.segments, ctx, true);
    return grp.toJson();
}

// Returns the segment codes appearing at this envelope level. Most levels have
// exactly one code; the helper handles the edge case of multiple (e.g. UNH plus
// auxiliary segments) and segment-group entries (matched by their first child).
isolated function envelopeLevelCodes(EdiUnitSchema[] units) returns string[] {
    string[] codes = [];
    foreach EdiUnitSchema u in units {
        if u is EdiSegSchema {
            if !codeIn(u.code, codes) {
                codes.push(u.code);
            }
        } else if u is EdiSegGroupSchema && u.segments.length() > 0 {
            EdiUnitSchema first = u.segments[0];
            if first is EdiSegSchema && !codeIn(first.code, codes) {
                codes.push(first.code);
            }
        }
    }
    return codes;
}

isolated function codeIn(string code, string[] codes) returns boolean {
    foreach string c in codes {
        if c == code {
            return true;
        }
    }
    return false;
}

// Returns the index in `segments[fromIdx..toIdx)` whose leading segment code
// matches one of `codes`, or `()` if none matches.
isolated function findFirstMatchingCode(string[] segments, string[] codes, int fromIdx, int toIdx,
        string fieldDelim) returns int? {
    int i = fromIdx;
    while i < toIdx {
        string code = getSegmentCode(segments[i].trim(), fieldDelim);
        if codeIn(code, codes) {
            return i;
        }
        i += 1;
    }
    return ();
}

// Returns `segments` with envelope-level segments (interchange, group?,
// transaction headers and trailers) removed. Used by `fromEdiString` so that
// body parsing sees only body segments when a schema declares an envelope.
isolated function stripEnvelopeSegments(string[] segments, EdiEnvelopeSchema env,
        string fieldDelim) returns string[] {
    string[] envCodes = [];
    foreach string c in envelopeLevelCodes(env.interchange.header) {
        if !codeIn(c, envCodes) {
            envCodes.push(c);
        }
    }
    foreach string c in envelopeLevelCodes(env.interchange.trailer) {
        if !codeIn(c, envCodes) {
            envCodes.push(c);
        }
    }
    EdiEnvelopeLevel? grp = env?.group;
    if grp is EdiEnvelopeLevel {
        foreach string c in envelopeLevelCodes(grp.header) {
            if !codeIn(c, envCodes) {
                envCodes.push(c);
            }
        }
        foreach string c in envelopeLevelCodes(grp.trailer) {
            if !codeIn(c, envCodes) {
                envCodes.push(c);
            }
        }
    }
    foreach string c in envelopeLevelCodes(env.'transaction.header) {
        if !codeIn(c, envCodes) {
            envCodes.push(c);
        }
    }
    foreach string c in envelopeLevelCodes(env.'transaction.trailer) {
        if !codeIn(c, envCodes) {
            envCodes.push(c);
        }
    }

    string[] result = [];
    foreach string seg in segments {
        string code = getSegmentCode(seg.trim(), fieldDelim);
        if !codeIn(code, envCodes) {
            result.push(seg);
        }
    }
    return result;
}

// Reads up to `maxChars` characters from a file using a ReadableCharacterChannel.
// Used by the file-based header APIs to avoid loading whole files.
isolated function readFileChars(string filePath, int maxChars) returns string|Error {
    do {
        io:ReadableByteChannel byteCh = check io:openReadableFile(filePath);
        io:ReadableCharacterChannel charCh = new io:ReadableCharacterChannel(byteCh, "UTF-8");
        string text = check charCh.read(maxChars);
        check charCh.close();
        return text;
    } on fail var e {
        return error Error(string `Failed to read EDI file '${filePath}': ${e.message()}`, e);
    }
}
