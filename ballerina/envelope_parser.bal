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

// Standard fixed widths of the X12 ISA elements ISA01..ISA16. The ISA segment
// is 106 characters: "ISA" (3) + 16 field delimiters + these 86 element
// characters + the segment terminator at position 105. ISA16 (width 1) is the
// component element separator.
final int[] & readonly X12_ISA_ELEMENT_WIDTHS = [2, 10, 2, 10, 2, 15, 2, 15, 6, 4, 1, 5, 9, 1, 1, 1];

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
# and the field delimiter is determined from position 3 of the input. The ISA
# is validated strictly against the standard fixed element widths — a
# non-conformant (e.g. unpadded) ISA is rejected with `InvalidEnvelopeError`
# instead of being part-parsed.
#
# + ediText - raw X12 EDI text
# + return - parsed X12Headers, or `InvalidEnvelopeError` when the ISA segment
# is missing, truncated, or not a conformant fixed-width ISA
public isolated function x12HeadersFromEdiString(string ediText) returns X12Headers|Error {
    string trimmed = stripBom(ediText).trim();
    if !trimmed.startsWith("ISA") {
        return error InvalidEnvelopeError("EDI text does not start with an ISA segment.");
    }
    if trimmed.length() < ISA_SEGMENT_LENGTH {
        return error InvalidEnvelopeError(string `ISA segment is too short. Expected ${ISA_SEGMENT_LENGTH} characters, found ${trimmed.length()}.`);
    }

    string fieldDelimiter = trimmed.substring(3, 4);
    string[] parts = splitByDelimiter(trimmed.substring(0, ISA_SEGMENT_LENGTH), fieldDelimiter);
    // Strict fixed-width validation: "ISA" + 16 elements. parts[16] carries
    // ISA16 (the component element separator, position 104) immediately
    // followed by the segment terminator (position 105) — exactly 2 chars.
    if parts.length() != 17 || parts[16].length() != 2 {
        return error InvalidEnvelopeError(string `ISA segment is not a conformant fixed-width (${ISA_SEGMENT_LENGTH}-character) X12 interchange header. ` +
                string `Expected 17 elements with the component separator (ISA16) and segment terminator at positions 104-105. Found ${parts.length()} elements.`);
    }
    foreach int i in 1 ... 15 {
        if parts[i].length() != X12_ISA_ELEMENT_WIDTHS[i - 1] {
            return error InvalidEnvelopeError(string `ISA segment is not a conformant fixed-width X12 interchange header. ` +
                    string `Element ISA${i < 10 ? "0" : ""}${i} must be ${X12_ISA_ELEMENT_WIDTHS[i - 1]} character(s) wide, found ${parts[i].length()} ('${parts[i]}').`);
        }
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
        // The text clearly begins with a GS segment, so a missing terminator or
        // a short field count means the GS is broken/truncated. Fail fast rather
        // than silently returning only the ISA, which callers cannot distinguish
        // from genuinely GS-less input.
        int? segEnd = remaining.indexOf(segmentTerminator);
        if segEnd is () {
            return error InvalidEnvelopeError("GS segment is present but its segment terminator was not found.");
        }
        string gsSegText = remaining.substring(0, segEnd);
        string[] gsFields = splitByDelimiter(gsSegText, fieldDelimiter);
        if gsFields.length() < 9 {
            return error InvalidEnvelopeError(string `GS segment has fewer fields than expected. Found ${gsFields.length()} fields.`);
        }
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
# segment to discover delimiters (including custom ones). Field and component
# splitting is release-character aware: delimiters escaped by the release
# character (default `?`) are kept as data and release sequences are
# un-escaped in the returned values (`?+` -> `+`, `??` -> `?`, ...).
#
# + ediText - raw EDIFACT EDI text
# + return - parsed EdifactHeaders, or `InvalidEnvelopeError` when UNB cannot be parsed
public isolated function edifactHeadersFromEdiString(string ediText) returns EdifactHeaders|Error {
    string trimmed = stripBom(ediText).trim();

    // EDIFACT defaults per UN/EDIFACT when UNA is absent.
    string fieldDelim = "+";
    string componentDelim = ":";
    string segmentTerminator = "'";
    string releaseChar = "?";

    string remaining = trimmed;

    if trimmed.startsWith("UNA") {
        if trimmed.length() < 9 {
            return error InvalidEnvelopeError("UNA service string is too short. Expected 9 characters (UNA followed by 6 service characters).");
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
        return error InvalidEnvelopeError("EDI text does not contain a UNB segment after UNA (or at the start).");
    }

    int unbEnd = indexOfUnescaped(remaining, segmentTerminator, releaseChar);
    // `indexOfUnescaped` returns the text length when the terminator is absent.
    // Without a terminator the UNB cannot be bounded, so the remainder (possibly
    // including UNH/body) would be parsed as a single garbage UNB. Error instead.
    if unbEnd == remaining.length() {
        return error InvalidEnvelopeError("UNB segment terminator was not found in the available EDI text.");
    }
    string unbText = remaining.substring(0, unbEnd);
    string[] unbFields = splitUnescaped(unbText, fieldDelim, releaseChar);

    // UNB requires S001 syntax id, S002 sender, S003 recipient,
    // S004 date/time, and 0020 interchange control reference (mandatory).
    // Total: tag + 5 composites = 6 entries minimum.
    if unbFields.length() < 6 {
        return error InvalidEnvelopeError(string `UNB segment has fewer fields than expected. Found ${unbFields.length()} fields.`);
    }

    string[] syntaxParts = splitUnescaped(unbFields[1], componentDelim, releaseChar);
    string[] senderParts = splitUnescaped(unbFields[2], componentDelim, releaseChar);
    string[] recipientParts = splitUnescaped(unbFields[3], componentDelim, releaseChar);
    string[] dateTimeParts = splitUnescaped(unbFields[4], componentDelim, releaseChar);

    EdifactUNB unb = {
        syntaxIdentifier: {
            syntaxId: componentAt(syntaxParts, 0, releaseChar),
            syntaxVersion: componentAt(syntaxParts, 1, releaseChar)
        },
        sender: {
            id: componentAt(senderParts, 0, releaseChar),
            qualifier: componentAt(senderParts, 1, releaseChar)
        },
        recipient: {
            id: componentAt(recipientParts, 0, releaseChar),
            qualifier: componentAt(recipientParts, 1, releaseChar)
        },
        dateAndTime: {
            date: componentAt(dateTimeParts, 0, releaseChar),
            time: componentAt(dateTimeParts, 1, releaseChar)
        },
        controlRef: unescapeReleased(unbFields[5], releaseChar).trim()
    };

    EdifactUNH? unh = ();
    string afterUNB = remaining.length() > unbEnd + 1 ? remaining.substring(unbEnd + 1) : "";
    string nextSeg = afterUNB.trim();
    if nextSeg.startsWith("UNH") {
        // As with GS above: a UNH that is present but truncated/malformed must
        // fail fast, so callers can distinguish it from a genuinely UNH-less
        // interchange rather than silently receiving only the UNB.
        int unhEnd = indexOfUnescaped(nextSeg, segmentTerminator, releaseChar);
        if unhEnd == nextSeg.length() {
            return error InvalidEnvelopeError("UNH segment is present but its segment terminator was not found.");
        }
        string unhText = nextSeg.substring(0, unhEnd);
        string[] unhFields = splitUnescaped(unhText, fieldDelim, releaseChar);
        if unhFields.length() < 3 {
            return error InvalidEnvelopeError(string `UNH segment has fewer fields than expected. Found ${unhFields.length()} fields.`);
        }
        string[] msgIdParts = splitUnescaped(unhFields[2], componentDelim, releaseChar);
        unh = {
            messageRef: unescapeReleased(unhFields[1], releaseChar).trim(),
            messageIdentifier: {
                messageType: componentAt(msgIdParts, 0, releaseChar),
                version: componentAt(msgIdParts, 1, releaseChar),
                release: componentAt(msgIdParts, 2, releaseChar),
                controlAgency: componentAt(msgIdParts, 3, releaseChar)
            }
        };
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
# The remainder of the document is never processed. The envelope header
# segments are treated as mandatory regardless of their declared
# `minOccurances` — input that does not match them fails fast with
# `InvalidEnvelopeError` instead of returning empty header sections. An
# EDIFACT UNA service string advice at the start of the input is validated
# against the schema delimiters and skipped (conflicting delimiters produce
# an `InvalidEnvelopeError`).
#
# Returns `SchemaCompatibilityError` if `schema.envelope` is `()` (old schema
# guard, directing the caller to regenerate the schema) or if the schema uses
# fixed-length ("FL") field delimiting, which envelope-aware APIs do not
# support.
#
# + ediText - raw EDI text
# + schema - EDI schema with a non-nil `envelope`
# + return - parsed header sections as JSON (interchange / group? / transaction),
# or Error
public isolated function headersFromEdiString(string ediText, EdiSchema schema) returns json|Error {
    EdiEnvelopeSchema env = check getEnvelopeOrError(schema);
    check checkEnvelopeFixedLengthSupport(schema);
    string text = check stripUnaIfPresent(stripBom(ediText), schema);
    string[] segments = check splitSegments(text, schema.delimiters.segment);
    return readEnvelopeHeaders(segments, schema, env);
}

# Reads only the envelope header segments from an EDI file. Reads only the first
# 4096 characters via a `ReadableCharacterChannel` and parses them. When the
# headers cannot be parsed and the read consumed the entire 4096-character
# window, an `InvalidEnvelopeError` mentioning the window size is returned —
# the envelope header section may exceed the read window.
#
# + filePath - path to the EDI file
# + schema - EDI schema with a non-nil `envelope`
# + return - parsed header sections as JSON, or Error
public isolated function headersFromEdiFile(string filePath, EdiSchema schema) returns json|Error {
    string text = check readFileChars(filePath, SCHEMA_DRIVEN_READ_CHARS);
    json|Error result = headersFromEdiString(text, schema);
    if result is Error && !(result is SchemaCompatibilityError) && text.length() == SCHEMA_DRIVEN_READ_CHARS {
        return error InvalidEnvelopeError(string `Envelope headers could not be parsed within the ${SCHEMA_DRIVEN_READ_CHARS}-character read window of file '${filePath}'. ` +
                string `The envelope header section may exceed the window. Cause: ${result.message()}`, result);
    }
    return result;
}

// =============================================================================
// Schema-driven hierarchical interchange (fail-safe per transaction body)
// =============================================================================

# Parses the full envelope hierarchy and returns an `EdiInterchange`. Envelope
# headers and trailers are fail-fast — a malformed envelope segment aborts the
# parse with an `InvalidEnvelopeError`. The transaction body is fail-safe —
# when a body cannot be parsed, the resulting `EdiTransaction.body` holds the
# parse `error` and the rest of the interchange continues. Envelope trailers
# are located by scanning backward, so trailer-coded junk inside a corrupted
# body does not hijack the envelope. Count and control-number values in the
# trailers (SE01/GE01/IEA01/UNT01/UNZ01 etc.) are captured as-is and are NOT
# validated against the actual content; they are recomputed on write by
# `interchangeToEdiString`.
#
# Only a single interchange per call is supported: content after the
# interchange trailer, or a second interchange header inside the body, is
# rejected with `InvalidEnvelopeError`.
#
# Returns `SchemaCompatibilityError` if `schema.envelope` is `()` (old schema
# guard) or if the schema uses fixed-length ("FL") field delimiting.
#
# + ediText - raw EDI text
# + schema - EDI schema with a non-nil `envelope`
# + return - parsed `EdiInterchange`, or Error
public isolated function interchangeFromEdiString(string ediText, EdiSchema schema) returns EdiInterchange|Error {
    EdiEnvelopeSchema env = check getEnvelopeOrError(schema);
    check checkEnvelopeFixedLengthSupport(schema);
    string text = check stripUnaIfPresent(stripBom(ediText), schema);
    string[] segments = check splitSegments(text, schema.delimiters.segment);
    string fieldDelim = schema.delimiters.'field;

    // Parse interchange header (fail-fast, leading segment mandatory).
    EdiContext ihCtx = {schema, ediText: segments, rawIndex: 0};
    EdiSegmentGroup ihGroup = check readEnvelopeSection(env.interchange.header, ihCtx, "interchange header");
    int bodyStart = ihCtx.rawIndex;

    // Locate the interchange trailer by scanning BACKWARD from the end so that
    // trailer-coded junk inside a corrupted transaction body cannot hijack the
    // envelope (preserving the fail-safe per-transaction body guarantee).
    string[] interchangeTrailerCodes = envelopeLevelCodes(env.interchange.trailer);
    int? trailerIdx = findLastMatchingCode(segments, interchangeTrailerCodes,
            bodyStart, segments.length(), fieldDelim);
    if trailerIdx is () {
        return error InvalidEnvelopeError("Interchange trailer segment not found.");
    }
    EdiContext itCtx = {schema, ediText: segments, rawIndex: trailerIdx};
    EdiSegmentGroup itGroup = check readEnvelopeSection(env.interchange.trailer, itCtx, "interchange trailer");

    // Only a single interchange per call is supported: nothing but whitespace
    // may remain after the interchange trailer ...
    foreach int i in itCtx.rawIndex ..< segments.length() {
        if segments[i].trim().length() > 0 {
            return error InvalidEnvelopeError(string `Content found after the interchange trailer (starting with segment '${segments[i].trim()}'). ` +
                    "Only a single interchange per call is supported. Split the input into individual interchanges and call interchangeFromEdiString once per interchange.");
        }
    }

    // Body slice between interchange header and trailer.
    string[] body = segments.slice(bodyStart, trailerIdx);

    // ... and no second interchange header may appear within the body.
    string[] interchangeHeaderCodes = envelopeLevelCodes(env.interchange.header);
    int? extraHeaderIdx = findFirstMatchingCode(body, interchangeHeaderCodes, 0, body.length(), fieldDelim);
    if extraHeaderIdx is int {
        return error InvalidEnvelopeError("EDI text contains more than one interchange. " +
                "Only a single interchange per call is supported. Split the input into individual interchanges and call interchangeFromEdiString once per interchange.");
    }

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
        return error SchemaCompatibilityError(string `Schema '${schema.name}' has no envelope defined. ` +
                "Regenerate the schema with edi-tools 2.2.0 or later to use envelope-aware APIs.");
    }
    return env;
}

// Envelope-aware APIs rely on delimiter-based segment-code extraction, which is
// meaningless for fixed-length ("FL") schemas. Reject them up front.
isolated function checkEnvelopeFixedLengthSupport(EdiSchema schema) returns Error? {
    if schema.delimiters.'field == "FL" {
        return error SchemaCompatibilityError(string `Envelope-aware APIs do not support fixed-length ("FL") schemas. Schema: '${schema.name}'.`);
    }
    return ();
}

// If the input starts with an EDIFACT UNA service string advice, validates its
// declared delimiters against the schema (component, field, decimal separator
// when the schema declares one, and segment terminator per the UNA layout) and
// strips it. Conflicting delimiters produce an InvalidEnvelopeError — the
// schema-driven parser cannot honour delimiters other than the schema's.
isolated function stripUnaIfPresent(string ediText, EdiSchema schema) returns string|Error {
    if !ediText.startsWith("UNA") {
        return ediText;
    }
    if ediText.length() < 9 {
        return error InvalidEnvelopeError("UNA service string is too short. Expected 9 characters (UNA followed by 6 service characters).");
    }
    // UNA layout: positions 3-8 carry component, field, decimal, release,
    // reserved, segment terminator (in that order).
    string component = ediText.substring(3, 4);
    string fieldDelim = ediText.substring(4, 5);
    string decimalSep = ediText.substring(5, 6);
    string segment = ediText.substring(8, 9);
    string? schemaDecimal = schema.delimiters.decimalSeparator;
    if component != schema.delimiters.component || fieldDelim != schema.delimiters.'field
            || segment != schema.delimiters.segment
            || (schemaDecimal is string && decimalSep != schemaDecimal) {
        return error InvalidEnvelopeError(string `The UNA-declared delimiters differ from the schema delimiters. ` +
                string `UNA: component '${component}', field '${fieldDelim}', decimal '${decimalSep}', segment terminator '${segment}'. ` +
                string `Schema: component '${schema.delimiters.component}', field '${schema.delimiters.'field}'` +
                (schemaDecimal is string ? string `, decimal '${schemaDecimal}'` : "") +
                string `, segment terminator '${schema.delimiters.segment}'.`);
    }
    return ediText.substring(9);
}

// Returns the (idx)th component of a split composite, un-escaped and trimmed,
// or "" when the component is absent.
isolated function componentAt(string[] parts, int idx, string release) returns string {
    return parts.length() > idx ? unescapeReleased(parts[idx], release).trim() : "";
}

// Reads one envelope section (e.g. interchange header) fail-fast: the leading
// (level-identifying) segment of the section is treated as mandatory
// regardless of its declared minOccurances, so non-matching input fails with
// InvalidEnvelopeError instead of silently producing an empty section.
// Unresolved-segment-reference errors are surfaced as SchemaCompatibilityError.
isolated function readEnvelopeSection(EdiUnitSchema[] units, EdiContext ctx, string label)
        returns EdiSegmentGroup|Error {
    EdiSegmentGroup|Error result = readSegmentGroup(forceLeadingUnitMandatory(units), ctx, false);
    if result is Error {
        if result.message().includes("not supported at runtime") {
            return error SchemaCompatibilityError(string `Failed to parse ${label}: ${result.message()}`, result);
        }
        return error InvalidEnvelopeError(string `Failed to parse ${label}: ${result.message()}`, result);
    }
    // readSegmentGroup returns an empty group (without an error) when the
    // input runs out before the section starts. The leading envelope segment
    // is mandatory, so its absence is an envelope error.
    string? leadTag = leadingUnitTag(units);
    if leadTag is string && !result.hasKey(leadTag) {
        return error InvalidEnvelopeError(string `Mandatory envelope segment for the ${label} ('${leadTag}') was not found in the input.`);
    }
    return result;
}

// Returns the tag of the first (level-identifying) unit of an envelope level,
// or `()` when the level is empty.
isolated function leadingUnitTag(EdiUnitSchema[] units) returns string? {
    if units.length() == 0 {
        return ();
    }
    EdiUnitSchema first = units[0];
    if first is EdiSegSchema {
        return first.tag;
    }
    if first is EdiSegGroupSchema {
        return first.tag;
    }
    return first?.tag;
}

// Returns a copy of the units in which the first (level-identifying) unit is
// mandatory (minOccurances >= 1). Auxiliary segments keep their declared
// cardinality. The original schema units are never mutated.
isolated function forceLeadingUnitMandatory(EdiUnitSchema[] units) returns EdiUnitSchema[] {
    if units.length() == 0 {
        return units;
    }
    EdiUnitSchema first = units[0];
    if first is EdiSegSchema && first.minOccurances < 1 {
        first = {
            code: first.code,
            tag: first.tag,
            truncatable: first.truncatable,
            minOccurances: 1,
            maxOccurances: first.maxOccurances,
            fields: first.fields
        };
    } else if first is EdiSegGroupSchema && first.minOccurances < 1 {
        first = {
            tag: first.tag,
            minOccurances: 1,
            maxOccurances: first.maxOccurances,
            segments: first.segments
        };
    } else if first is EdiUnitRef && first.minOccurances < 1 {
        EdiUnitRef firstRef = {ref: first.ref, minOccurances: 1, maxOccurances: first.maxOccurances};
        string? refTag = first?.tag;
        if refTag is string {
            firstRef.tag = refTag;
        }
        first = firstRef;
    } else {
        return units;
    }
    EdiUnitSchema[] result = [first];
    foreach int i in 1 ..< units.length() {
        result.push(units[i]);
    }
    return result;
}

// Reads the envelope header sections (interchange, optional group, transaction)
// from a pre-split segment array and assembles them into a JSON map. Each
// section is fail-fast: its leading segment is mandatory.
isolated function readEnvelopeHeaders(string[] segments, EdiSchema schema,
        EdiEnvelopeSchema env) returns json|Error {
    EdiContext ctx = {schema, ediText: segments, rawIndex: 0};

    EdiSegmentGroup interchange = check readEnvelopeSection(env.interchange.header, ctx, "interchange header");
    map<json> result = {interchange: interchange.toJson()};

    EdiEnvelopeLevel? grpLevel = env?.group;
    if grpLevel is EdiEnvelopeLevel {
        EdiSegmentGroup grp = check readEnvelopeSection(grpLevel.header, ctx, "functional group header");
        result["group"] = grp.toJson();
    }

    EdiSegmentGroup txn = check readEnvelopeSection(env.'transaction.header, ctx, "transaction header");
    result["transaction"] = txn.toJson();

    return result;
}

// Iterates GS...GE pairs (or equivalent) in the interchange body, building one
// EdiFunctionalGroup per pair. Group headers and trailers fail-fast; nested
// transaction bodies remain fail-safe. The group trailer is located by
// scanning backward from the next group header (or the end of the body), so
// trailer-coded junk inside a corrupted transaction body is skipped over.
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
            return error InvalidEnvelopeError(string `Expected functional group header (one of ${groupHeaderCodes.toString()}), found '${code}'.`);
        }

        // Parse group header
        EdiContext ghCtx = {schema, ediText: body, rawIndex: i};
        EdiSegmentGroup gh = check readEnvelopeSection(grpLevel.header, ghCtx, "functional group header");
        int afterGh = ghCtx.rawIndex;

        // Locate group trailer: the LAST trailer-coded segment before the next
        // group header (or the end of the interchange body).
        int groupEnd = findFirstMatchingCode(body, groupHeaderCodes, afterGh, body.length(), fieldDelim) ?: body.length();
        int? gtIdx = findLastMatchingCode(body, groupTrailerCodes, afterGh, groupEnd, fieldDelim);
        if gtIdx is () {
            return error InvalidEnvelopeError("Functional group trailer segment not found.");
        }
        EdiContext gtCtx = {schema, ediText: body, rawIndex: gtIdx};
        EdiSegmentGroup gt = check readEnvelopeSection(grpLevel.trailer, gtCtx, "functional group trailer");
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
// transaction's `body` field. The transaction trailer is located by scanning
// backward from the next transaction header (or the end of the slice), so
// trailer-coded junk inside a corrupted body stays inside that body.
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
            return error InvalidEnvelopeError(string `Expected transaction header (one of ${txnHeaderCodes.toString()}), found '${code}'.`);
        }

        EdiContext thCtx = {schema, ediText: body, rawIndex: i};
        EdiSegmentGroup th = check readEnvelopeSection(env.'transaction.header, thCtx, "transaction header");
        int afterTh = thCtx.rawIndex;

        // Locate transaction trailer: the LAST trailer-coded segment before
        // the next transaction header (or the end of the slice).
        int txnEnd = findFirstMatchingCode(body, txnHeaderCodes, afterTh, body.length(), fieldDelim) ?: body.length();
        int? ttIdx = findLastMatchingCode(body, txnTrailerCodes, afterTh, txnEnd, fieldDelim);
        if ttIdx is () {
            return error InvalidEnvelopeError("Transaction trailer segment not found.");
        }
        EdiContext ttCtx = {schema, ediText: body, rawIndex: ttIdx};
        EdiSegmentGroup tt = check readEnvelopeSection(env.'transaction.trailer, ttCtx, "transaction trailer");
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

// Returns the LAST index in `segments[fromIdx..toIdx)` whose leading segment
// code matches one of `codes`, or `()` if none matches. Used to locate
// envelope trailers by scanning backward, so trailer-coded junk inside a
// corrupted transaction body cannot hijack the envelope.
isolated function findLastMatchingCode(string[] segments, string[] codes, int fromIdx, int toIdx,
        string fieldDelim) returns int? {
    int i = toIdx - 1;
    while i >= fromIdx {
        string code = getSegmentCode(segments[i].trim(), fieldDelim);
        if codeIn(code, codes) {
            return i;
        }
        i -= 1;
    }
    return ();
}

// Positionally strips envelope segments for `fromEdiString`: envelope header
// segments are skipped at the START of the input and trailer segments at the
// END (per BEP-1441). Envelope-coded segments in the middle of the input are
// never removed, so they surface as body parse errors instead of being
// silently dropped. The input must contain at most one transaction; an input
// with more than one transaction header is rejected.
isolated function stripEnvelopeSegmentsPositional(string[] segments, EdiEnvelopeSchema env,
        string fieldDelim) returns string[]|Error {
    string[] txnHeaderCodes = envelopeLevelCodes(env.'transaction.header);

    int txnHeaderCount = 0;
    foreach string seg in segments {
        if codeIn(getSegmentCode(seg.trim(), fieldDelim), txnHeaderCodes) {
            txnHeaderCount += 1;
        }
    }
    if txnHeaderCount > 1 {
        return error InvalidEnvelopeError(string `EDI text contains ${txnHeaderCount} transactions, but fromEdiString parses a single transaction body. ` +
                "Use interchangeFromEdiString to parse a multi-transaction interchange.");
    }

    string[] headerCodes = [];
    string[] trailerCodes = [];
    foreach string c in envelopeLevelCodes(env.interchange.header) {
        headerCodes.push(c);
    }
    foreach string c in envelopeLevelCodes(env.interchange.trailer) {
        trailerCodes.push(c);
    }
    EdiEnvelopeLevel? grp = env?.group;
    if grp is EdiEnvelopeLevel {
        foreach string c in envelopeLevelCodes(grp.header) {
            if !codeIn(c, headerCodes) {
                headerCodes.push(c);
            }
        }
        foreach string c in envelopeLevelCodes(grp.trailer) {
            if !codeIn(c, trailerCodes) {
                trailerCodes.push(c);
            }
        }
    }
    foreach string c in txnHeaderCodes {
        if !codeIn(c, headerCodes) {
            headerCodes.push(c);
        }
    }
    foreach string c in envelopeLevelCodes(env.'transaction.trailer) {
        if !codeIn(c, trailerCodes) {
            trailerCodes.push(c);
        }
    }

    int startIdx = 0;
    while startIdx < segments.length()
            && codeIn(getSegmentCode(segments[startIdx].trim(), fieldDelim), headerCodes) {
        startIdx += 1;
    }
    int endIdx = segments.length();
    while endIdx > startIdx
            && codeIn(getSegmentCode(segments[endIdx - 1].trim(), fieldDelim), trailerCodes) {
        endIdx -= 1;
    }
    return segments.slice(startIdx, endIdx);
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
