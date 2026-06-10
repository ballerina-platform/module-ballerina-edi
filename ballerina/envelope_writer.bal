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

# Serializes an `EdiInterchange` into EDI text using the schema's `envelope`
# definition. The inverse of `interchangeFromEdiString`.
#
# Envelope segments (interchange / group? / transaction headers and trailers)
# are written from `EdiInterchange.interchangeHeader`, `groups[*].groupHeader`,
# `transactions[*].transactionHeader`, etc. Transaction bodies are written
# using `schema.segments` — the same schema fragment that `fromEdiString`
# parses against — so a parse / serialize round-trip is structurally
# symmetric.
#
# A transaction whose `body` is an `error` cannot be serialized; the function
# returns an error in that case. Callers should filter out errored
# transactions (or replace them with valid bodies) before serialising.
#
# Returns an error if `schema.envelope` is `()` (old schema guard), if
# `EdiInterchange.groups` is unset for an X12-style schema (or `transactions`
# is unset for an EDIFACT-style schema), or if any envelope segment fails
# to write.
#
# + msg - The interchange to serialise
# + schema - EDI schema with a non-nil `envelope`
# + return - EDI text, or Error
public isolated function interchangeToEdiString(EdiInterchange msg, EdiSchema schema) returns string|Error {
    EdiEnvelopeSchema env = check getEnvelopeOrError(schema);

    EdiSchema|error clonedSchema = schema.cloneWithType();
    if clonedSchema is error {
        return <Error>clonedSchema;
    }
    EdiContext context = {schema: clonedSchema};

    check writeEnvelopeLevel(msg.interchangeHeader, env.interchange.header,
            clonedSchema, context, "interchange header");

    EdiEnvelopeLevel? grpLevel = env?.group;
    if grpLevel is EdiEnvelopeLevel {
        EdiFunctionalGroup[]? groups = msg?.groups;
        if groups is () {
            return error Error("Schema declares envelope.group, but EdiInterchange.groups is not set.");
        }
        foreach EdiFunctionalGroup grp in groups {
            check writeEnvelopeLevel(grp.groupHeader, grpLevel.header, clonedSchema, context,
                    "functional group header");
            foreach EdiTransaction t in grp.transactions {
                check writeOneTransaction(t, env, clonedSchema, context);
            }
            check writeEnvelopeLevel(grp.groupTrailer, grpLevel.trailer, clonedSchema, context,
                    "functional group trailer");
        }
    } else {
        EdiTransaction[]? transactions = msg?.transactions;
        if transactions is () {
            return error Error("Schema does not declare envelope.group, but EdiInterchange.transactions is not set.");
        }
        foreach EdiTransaction t in transactions {
            check writeOneTransaction(t, env, clonedSchema, context);
        }
    }

    check writeEnvelopeLevel(msg.interchangeTrailer, env.interchange.trailer,
            clonedSchema, context, "interchange trailer");

    // Each entry in `context.ediText` already includes the segment terminator
    // (appended by `writeSegment`); join them with newlines for readability,
    // matching the existing `toEdiString` convention.
    string segDelim = clonedSchema.delimiters.segment;
    string ediOutput = "";
    foreach string s in context.ediText {
        ediOutput += s + (segDelim == "\n" ? "" : "\n");
    }
    return ediOutput;
}

// Writes the body of one transaction sandwiched between its header and trailer.
isolated function writeOneTransaction(EdiTransaction t, EdiEnvelopeSchema env,
        EdiSchema clonedSchema, EdiContext context) returns Error? {
    check writeEnvelopeLevel(t.transactionHeader, env.'transaction.header,
            clonedSchema, context, "transaction header");

    json|error rawBody = t.body;
    if rawBody is error {
        return error Error(string `Cannot serialise transaction with error body: ${rawBody.message()}`);
    }
    if !(rawBody is map<json>) {
        return error Error(string `Transaction body must be a JSON object. Found: ${rawBody.toString()}`);
    }
    EdiSchema bodyScratch = makeScratchSchema(clonedSchema, clonedSchema.segments);
    EdiContext bodyContext = {schema: bodyScratch, ediText: context.ediText};
    check writeSegmentGroup(rawBody, bodyScratch, bodyContext);
    // bodyContext.ediText is the same array reference as context.ediText, so
    // segments appended inside writeSegmentGroup are visible to the caller.

    check writeEnvelopeLevel(t.transactionTrailer, env.'transaction.trailer,
            clonedSchema, context, "transaction trailer");
}

// Writes one envelope level's worth of segments (e.g. just UNB, or UNH+DTM)
// using a scratch schema that exposes only that level's segments.
isolated function writeEnvelopeLevel(json levelJson, EdiUnitSchema[] segments,
        EdiSchema clonedSchema, EdiContext context, string label) returns Error? {
    if !(levelJson is map<json>) {
        return error Error(string `Envelope ${label} must be a JSON object. Found: ${levelJson.toString()}`);
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
