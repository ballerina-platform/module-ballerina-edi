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

type EdiContext record {|
    EdiSchema schema;
    string[] ediText = [];
    int rawIndex = 0;
|};

# Reads the given EDI text according to the provided schema.
# When `schema.envelope` is set (new envelope-aware schemas), envelope segments
# are skipped positionally — header segments at the start of the input and
# trailer segments at the end — and only `schema.segments` is parsed. The input
# must contain at most a single transaction; when more than one transaction
# header segment is present, an `InvalidEnvelopeError` is returned directing
# the caller to `interchangeFromEdiString`. A leading BOM is stripped and an
# EDIFACT UNA service string advice is validated against the schema delimiters
# and skipped. Envelope-aware processing does not support fixed-length ("FL")
# schemas. When `schema.envelope` is nil (older schemas), behaviour is
# unchanged.
#
# + ediText - EDI text to be read
# + schema - Schema of the EDI text
# + return - JSON variable containing EDI data. Error if the reading fails.
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
    }

    EdiSegmentGroup rootGroup = check readSegmentGroup(currentMapping, context, true);
    return rootGroup;
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

# Represents failures where the input EDI text does not conform to the expected
# envelope structure. Examples: a mandatory envelope segment (ISA / GS / ST /
# UNB / UNH or the corresponding trailers) is missing or does not match,
# content remains after the interchange trailer (multiple interchanges per
# call are not supported), the X12 ISA segment is malformed or truncated,
# a UNA service string advice declares delimiters conflicting with the schema,
# or the envelope headers exceed the file read window.
public type InvalidEnvelopeError distinct Error;

# Represents failures where the provided schema cannot support the requested
# operation. Examples: a schema without an `envelope` declaration is passed to
# an envelope-aware API (regenerate the schema with edi-tools 2.2.0 or later),
# a fixed-length ("FL" field delimiter) schema is used with envelope-aware
# APIs, or unresolved segment references (`ref`) surface at runtime.
public type SchemaCompatibilityError distinct Error;

# Represents refusals of `interchangeToEdiString` to serialize an
# `EdiInterchange`. Examples: a transaction `body` holds an `error` (the
# fail-safe result of a previous parse), or a body / envelope section is not
# a JSON object.
public type SerializationError distinct Error;
