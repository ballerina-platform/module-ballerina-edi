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

# Serializes an `EdiInterchange` into EDI text; the inverse of `interchangeFromEdiString`.
# The X12 ISA header is re-padded to its standard fixed widths, and trailer counts and
# control references are recomputed from the content being written. A transaction whose
# `body` is an `error` is refused with a `SerializationError`.
#
# + msg - Interchange to serialize
# + schema - EDI schema with an `envelope` declaration
# + return - EDI text, or an `Error`
public isolated function interchangeToEdiString(EdiInterchange msg, EdiSchema schema) returns string|Error {
    EdiEnvelopeSchema env = check getEnvelopeOrError(schema);
    check checkEnvelopeFixedLengthSupport(schema);

    EdiSchema|error clonedSchema = schema.cloneWithType();
    if clonedSchema is error {
        return <Error>clonedSchema;
    }
    EdiContext context = {schema: clonedSchema};

    json ihJson = padX12InterchangeHeader(msg.interchangeHeader, env.interchange.header, clonedSchema);
    check writeEnvelopeLevel(ihJson, env.interchange.header, clonedSchema, context, "interchange header");

    int interchangeUnitCount;
    EdiEnvelopeLevel? grpLevel = env?.group;
    if grpLevel is EdiEnvelopeLevel {
        EdiFunctionalGroup[]? groups = msg?.groups;
        if groups is () {
            return error SerializationError("Schema declares envelope.group, but EdiInterchange.groups is not set.");
        }
        foreach EdiFunctionalGroup grp in groups {
            check writeEnvelopeLevel(grp.groupHeader, grpLevel.header, clonedSchema, context,
                    "functional group header");
            foreach EdiTransaction t in grp.transactions {
                check writeOneTransaction(t, env, clonedSchema, context);
            }
            // GE01 (number of transaction sets) and GE02 (group control
            // number, mirrored from GS06) are recomputed before writing.
            json gtJson = patchTrailerCounts(grp.groupTrailer, grpLevel.trailer, clonedSchema,
                    grp.transactions.length(),
                    getHeaderControlValue(grp.groupHeader, grpLevel.header, clonedSchema));
            check writeEnvelopeLevel(gtJson, grpLevel.trailer, clonedSchema, context,
                    "functional group trailer");
        }
        interchangeUnitCount = groups.length();
    } else {
        EdiTransaction[]? transactions = msg?.transactions;
        if transactions is () {
            return error SerializationError("Schema does not declare envelope.group, but EdiInterchange.transactions is not set.");
        }
        foreach EdiTransaction t in transactions {
            check writeOneTransaction(t, env, clonedSchema, context);
        }
        interchangeUnitCount = transactions.length();
    }

    // IEA01 / UNZ01 (number of groups, or messages when no group level) and
    // IEA02 / UNZ02 (interchange control reference, mirrored from
    // ISA13 / UNB-0020) are recomputed before writing.
    json itJson = patchTrailerCounts(msg.interchangeTrailer, env.interchange.trailer, clonedSchema,
            interchangeUnitCount,
            getHeaderControlValue(msg.interchangeHeader, env.interchange.header, clonedSchema));
    check writeEnvelopeLevel(itJson, env.interchange.trailer, clonedSchema, context, "interchange trailer");

    // Each entry in `context.ediText` already includes the segment terminator
    // (appended by `writeSegment`); join them with newlines for readability,
    // matching the existing `toEdiString` convention.
    string segDelim = clonedSchema.delimiters.segment;
    string[] ediText = context.ediText;
    if ediText.length() == 0 {
        return "";
    }
    // Append a readability newline after every entry (unless the segment
    // delimiter is already a newline). A single join avoids the quadratic cost
    // of repeated `+=` concatenation when serialising large interchanges.
    string suffix = segDelim == "\n" ? "" : "\n";
    return string:'join(suffix, ...ediText) + suffix;
}

// Writes the body of one transaction sandwiched between its header and trailer.
// The trailer's segment count (SE01 / UNT01) is recomputed as the number of
// segments from the transaction header through the trailer inclusive, and its
// control reference (SE02 / UNT02) is mirrored from the transaction header.
isolated function writeOneTransaction(EdiTransaction t, EdiEnvelopeSchema env,
        EdiSchema clonedSchema, EdiContext context) returns Error? {
    int startIdx = context.ediText.length();
    check writeEnvelopeLevel(t.transactionHeader, env.'transaction.header,
            clonedSchema, context, "transaction header");

    json|error rawBody = t.body;
    if rawBody is error {
        return error SerializationError(string `Cannot serialise transaction with error body: ${rawBody.message()}`);
    }
    if !(rawBody is map<json>) {
        return error SerializationError(string `Transaction body must be a JSON object. Found: ${rawBody.toString()}`);
    }
    EdiSchema bodyScratch = makeScratchSchema(clonedSchema, clonedSchema.segments);
    EdiContext bodyContext = {schema: bodyScratch, ediText: context.ediText};
    check writeSegmentGroup(rawBody, bodyScratch, bodyContext);
    // bodyContext.ediText is the same array reference as context.ediText, so
    // segments appended inside writeSegmentGroup are visible to the caller.

    // Determine how many segments the trailer itself will emit (normally 1)
    // by writing it to a scratch context, then recompute the inclusive
    // segment count and write the patched trailer for real.
    EdiContext trailerScratch = {schema: clonedSchema};
    check writeEnvelopeLevel(t.transactionTrailer, env.'transaction.trailer,
            clonedSchema, trailerScratch, "transaction trailer");
    int segmentCount = (context.ediText.length() - startIdx) + trailerScratch.ediText.length();

    json ttJson = patchTrailerCounts(t.transactionTrailer, env.'transaction.trailer, clonedSchema,
            segmentCount,
            getHeaderControlValue(t.transactionHeader, env.'transaction.header, clonedSchema));
    check writeEnvelopeLevel(ttJson, env.'transaction.trailer,
            clonedSchema, context, "transaction trailer");
}

// Writes one envelope level's worth of segments (e.g. just UNB, or UNH+DTM)
// using a scratch schema that exposes only that level's segments.
isolated function writeEnvelopeLevel(json levelJson, EdiUnitSchema[] segments,
        EdiSchema clonedSchema, EdiContext context, string label) returns Error? {
    if !(levelJson is map<json>) {
        return error SerializationError(string `Envelope ${label} must be a JSON object. Found: ${levelJson.toString()}`);
    }
    EdiSchema scratch = makeScratchSchema(clonedSchema, segments);
    EdiContext scratchContext = {schema: scratch, ediText: context.ediText};
    check writeSegmentGroup(levelJson, scratch, scratchContext);
}

// Builds a scratch EdiSchema that shares delimiters and other top-level
// settings with the base schema but exposes only the supplied segments. Used
// to drive `writeSegmentGroup` for one envelope level (or for the body) at a
// time.
isolated function makeScratchSchema(EdiSchema base, EdiUnitSchema[] segments) returns EdiSchema {
    return {
        name: base.name,
        tag: base.tag,
        delimiters: base.delimiters,
        ignoreSegments: base.ignoreSegments,
        preserveEmptyFields: base.preserveEmptyFields,
        includeSegmentCode: base.includeSegmentCode,
        segments: segments,
        segmentDefinitions: {}
    };
}

// Re-pads the X12 ISA interchange header values to their standard fixed
// widths (ISA01..ISA16) so the emitted ISA segment is exactly 106 characters.
// Parsing trims the fixed-width padding (values are stored trimmed), so the
// writer must restore it — receivers (including this module's own
// `x12HeadersFromEdiString`) read the ISA positionally. A schema-declared
// fixed field length takes precedence over the standard width. Values longer
// than the target width are left untouched. Returns the level JSON unchanged
// when it carries no ISA segment (e.g. EDIFACT).
isolated function padX12InterchangeHeader(json levelJson, EdiUnitSchema[] units,
        EdiSchema schema) returns json {
    if !(levelJson is map<json>) {
        return levelJson;
    }
    EdiSegSchema? isaSchema = ();
    foreach EdiUnitSchema u in units {
        if u is EdiSegSchema && u.code == "ISA" {
            isaSchema = u;
            break;
        }
    }
    if isaSchema is () {
        return levelJson;
    }
    map<json>|error cloned = levelJson.cloneWithType();
    if cloned is error {
        return levelJson;
    }
    json segJson = cloned[isaSchema.tag];
    if !(segJson is map<json>) {
        return levelJson;
    }
    map<json> segMap = segJson;
    int offset = schema.includeSegmentCode ? 1 : 0;
    foreach int isaIdx in 1 ... 16 {
        int schemaIdx = offset + isaIdx - 1;
        if schemaIdx >= isaSchema.fields.length() {
            break;
        }
        EdiFieldSchema fieldSchema = isaSchema.fields[schemaIdx];
        int width = X12_ISA_ELEMENT_WIDTHS[isaIdx - 1];
        Range|int declaredLength = fieldSchema.length;
        if declaredLength is int && declaredLength > 0 {
            width = declaredLength;
        }
        json currentVal = segMap[fieldSchema.tag];
        string sv = currentVal is () ? "" : (currentVal is string ? currentVal : currentVal.toString());
        segMap[fieldSchema.tag] = sv.length() < width ? addPadding(sv, width) : sv;
    }
    return cloned;
}

// Returns a copy of the trailer level JSON in which the count element (the
// first element after the segment code: SE01 / GE01 / IEA01 / UNT01 / UNZ01)
// is replaced by `count` and the control-reference element (the element after
// the count: SE02 / GE02 / IEA02 / UNT02 / UNZ02) is replaced by
// `controlRef`. Elements are identified positionally per the standard
// trailer layouts. When the schema-declared trailer has fewer fields, only
// what fits is written. Non-object trailer JSON is returned unchanged (the
// writer reports it as a SerializationError downstream).
isolated function patchTrailerCounts(json trailerJson, EdiUnitSchema[] trailerUnits,
        EdiSchema schema, int count, json controlRef) returns json {
    if !(trailerJson is map<json>) {
        return trailerJson;
    }
    EdiSegSchema? segSchema = ();
    foreach EdiUnitSchema u in trailerUnits {
        if u is EdiSegSchema {
            segSchema = u;
            break;
        }
    }
    if segSchema is () {
        return trailerJson;
    }
    map<json>|error cloned = trailerJson.cloneWithType();
    if cloned is error {
        return trailerJson;
    }
    json segJson = cloned[segSchema.tag];
    map<json> segMap;
    if segJson is map<json> {
        segMap = segJson;
    } else {
        segMap = {};
        cloned[segSchema.tag] = segMap;
    }
    int offset = schema.includeSegmentCode ? 1 : 0;
    EdiFieldSchema[] fields = segSchema.fields;
    if fields.length() > offset {
        EdiFieldSchema countField = fields[offset];
        segMap[countField.tag] = countField.dataType == INT ? count : count.toString();
    }
    if fields.length() > offset + 1 && controlRef != () {
        segMap[fields[offset + 1].tag] = controlRef;
    }
    return cloned;
}

// Extracts the control value of an envelope header segment, identified
// positionally per the standard layouts: ISA13 (interchange control number),
// UNB 0020 (interchange control reference), GS06 (group control number),
// UNG 0048 (group reference number), ST02 (transaction set control number),
// UNH 0062 (message reference number). Returns `()` for unrecognised header
// codes or when the element is not present.
isolated function getHeaderControlValue(json headerJson, EdiUnitSchema[] headerUnits,
        EdiSchema schema) returns json {
    if !(headerJson is map<json>) {
        return ();
    }
    EdiSegSchema? segSchema = ();
    foreach EdiUnitSchema u in headerUnits {
        if u is EdiSegSchema {
            segSchema = u;
            break;
        }
    }
    if segSchema is () {
        return ();
    }
    int afterCodeIdx = headerControlElementIndex(segSchema.code);
    if afterCodeIdx < 0 {
        return ();
    }
    int idx = (schema.includeSegmentCode ? 1 : 0) + afterCodeIdx;
    if segSchema.fields.length() <= idx {
        return ();
    }
    json segJson = headerJson[segSchema.tag];
    if !(segJson is map<json>) {
        return ();
    }
    return segJson[segSchema.fields[idx].tag];
}

// Zero-based element index (after the segment code) of the control value in a
// standard envelope header segment, or -1 for unrecognised codes.
isolated function headerControlElementIndex(string code) returns int {
    match code {
        "ISA" => {
            return 12; // ISA13 Interchange Control Number
        }
        "UNB" => {
            return 4; // UNB 0020 Interchange Control Reference
        }
        "GS" => {
            return 5; // GS06 Group Control Number
        }
        "UNG" => {
            return 4; // UNG 0048 Group Reference Number
        }
        "ST" => {
            return 1; // ST02 Transaction Set Control Number
        }
        "UNH" => {
            return 0; // UNH 0062 Message Reference Number
        }
    }
    return -1;
}
