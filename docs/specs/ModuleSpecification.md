# Specification: Ballerina EDI Module

_Owners_: @chathurace @RDPerera
_Reviewers_: @niveathika @chathurace
_Created_: 2024/01/19
_Updated_: 2026/04/29
_Edition_: Swan Lake

## Introduction

This is the specification for the `edi` module of the [Ballerina language](https://ballerina.io). The `edi` module provides functionality to convert EDI text to JSON and JSON to EDI text. It additionally exposes a tiered envelope-aware API — schema-free header inspection, schema-driven header-only parses, and full hierarchical interchange parses with fail-safe per-transaction body — so callers can pay only for the depth of parsing they actually need. Schemas are defined in JSON.

If you have any feedback or suggestions about the module, start a discussion via a [GitHub issue](https://github.com/ballerina-platform/ballerina-library/issues) or in the [Discord server](https://discord.gg/ballerinalang). Based on the outcome of the discussion, the specification and implementation can be updated. Community feedback is always welcome. Any accepted proposal, which affects the specification, is stored under `/docs/proposals`. Proposals under discussion can be found with the label `type/proposal` on GitHub.

## Contents

1. [Overview](#1-overview)
2. [`EdiSchema` Record](#2-edischema-record)
3. [Functions](#3-functions)
    * 3.1 [`getSchema` function](#31-getschema-function)
    * 3.2 [`fromEdiString` function](#32-fromedistring-function)
    * 3.3 [`toEdiString` function](#33-toedistring-function)
    * 3.4 [`x12HeadersFromEdiString` function](#34-x12headersfromedistring-function)
    * 3.5 [`x12HeadersFromEdiFile` function](#35-x12headersfromedifile-function)
    * 3.6 [`edifactHeadersFromEdiString` function](#36-edifactheadersfromedistring-function)
    * 3.7 [`edifactHeadersFromEdiFile` function](#37-edifactheadersfromedifile-function)
    * 3.8 [`headersFromEdiString` function](#38-headersfromedistring-function)
    * 3.9 [`headersFromEdiFile` function](#39-headersfromedifile-function)
    * 3.10 [`interchangeFromEdiString` function](#310-interchangefromedistring-function)
    * 3.11 [`interchangeToEdiString` function](#311-interchangetoedistring-function)
4. [Types](#4-types)
    * 4.1 [X12 envelope types](#41-x12-envelope-types)
    * 4.2 [EDIFACT envelope types](#42-edifact-envelope-types)
    * 4.3 [Hierarchical interchange types](#43-hierarchical-interchange-types)
5. [Error types](#5-error-types)
6. [Envelope processing semantics](#6-envelope-processing-semantics)


## 1. Overview

The Ballerina language offers first-class support for handling network-structured data, and the `edi` module leverages these features to facilitate the conversion between EDI text and JSON, with the ability to define the EDI schema in JSON format. The module exposes eight public parsing functions and the envelope-aware writer `interchangeToEdiString`, plus `getSchema` and `toEdiString`. All but the four schema-free header functions require a schema; those four know the X12 / EDIFACT envelope structure intrinsically.

The function families span schema-free and schema-driven usage. Pick the one that matches your use case:

| Function | Schema needed? | Error behavior | Primary use case |
|----------|---------------|----------------|------------------|
| [`x12HeadersFromEdiString`](#34-x12headersfromedistring-function) / [`x12HeadersFromEdiFile`](#35-x12headersfromedifile-function) | No | Fail fast | Routing, filtering, schema selection (X12) |
| [`edifactHeadersFromEdiString`](#36-edifactheadersfromedistring-function) / [`edifactHeadersFromEdiFile`](#37-edifactheadersfromedifile-function) | No | Fail fast | Routing, filtering, schema selection (EDIFACT) |
| [`headersFromEdiString`](#38-headersfromedistring-function) / [`headersFromEdiFile`](#39-headersfromedifile-function) | Yes (`envelope`) | Fail fast | Header-only inspection inside generated libraries |
| [`interchangeFromEdiString`](#310-interchangefromedistring-function) | Yes (`envelope`) | **Fail safe** (body only) | Batch splitting, partial recovery, body forwarding |
| [`fromEdiString`](#32-fromedistring-function) | Yes | Fail fast | Transaction body parsing into typed records |
| [`toEdiString`](#33-toedistring-function) | Yes | Fail fast | Serialize JSON / records into EDI text |
| [`interchangeToEdiString`](#311-interchangetoedistring-function) | Yes (`envelope`) | Fail fast | Serialize a full interchange; round-trips with `interchangeFromEdiString` |

## 2. `EdiSchema` Record

The `EdiSchema` record represents the schema of the EDI text. To define the structure of EDI data, developers can utilize the [Ballerina EDI Schema Specification](https://github.com/ballerina-platform/module-ballerina-edi/blob/main/docs/specs/SchemaSpecification.md). When a schema declares an `envelope` field, the schema-driven envelope-aware functions (`headersFromEdiString`, `headersFromEdiFile`, `interchangeFromEdiString`) become available, and `fromEdiString` skips envelope segments automatically.

## 3. Functions

This section outlines the functions provided by the Ballerina `edi` module.

### 3.1 `getSchema` function

Creates an EDI schema from a string or a JSON.

```ballerina
function getSchema(string|json schema) returns EdiSchema|error
```

#### Parameters
- `schema` string|json - Schema of the EDI type.

#### Return Type
- `EdiSchema|error` - Error is returned if the given schema is not valid.

#### Example
The following is a basic EDI schema, assuming it is stored in the `edi-schema.json` file:

```json
{
    "name": "SimpleOrder",
    "delimiters" : {"segment" : "~", "field" : "*", "component": ":", "repetition": "^"},
    "segments" : [
        {
            "code": "HDR",
            "tag" : "header",
            "fields" : [{"tag": "code"}, {"tag" : "orderId"}, {"tag" : "organization"}, {"tag" : "date"}]
        },
        {
            "code": "ITM",
            "tag" : "items",
            "maxOccurances" : -1,
            "fields" : [{"tag": "code"}, {"tag" : "item"}, {"tag" : "quantity", "dataType" : "int"}]
        }
    ]
}
```

Below code reads the edi-schema.json file and assigns to an `edi:EdiSchema` variable.

```ballerina
import ballerina/io;
import ballerina/edi;

public function main() returns error? {
    edi:EdiSchema schema = check edi:getSchema(check io:fileReadJson("resources/edi-schema.json"));
    io:println(schema.toString());
}
```

### 3.2 `fromEdiString` function

Reads the given EDI text according to the provided schema. Fail-fast — any malformed segment aborts the parse with an `Error`. When the schema declares an `envelope`, envelope segments are skipped **positionally**: header segments (interchange / group / transaction) at the start of the input and trailer segments at the end. Envelope-coded segments in the middle of the input are not removed and surface as body parse errors. The input must contain at most one transaction — an input with more than one transaction header segment is rejected with `InvalidEnvelopeError` directing the caller to [`interchangeFromEdiString`](#310-interchangefromedistring-function). A leading BOM is stripped, an EDIFACT UNA service string advice is validated against the schema delimiters and skipped (see [UNA semantics](#63-una-service-string-advice)), and fixed-length ("FL") schemas with an `envelope` are rejected with `SchemaCompatibilityError`. For schemas without `envelope`, behaviour is unchanged.

```ballerina
function fromEdiString(string ediText, EdiSchema schema) returns json|Error
```

#### Parameters
- `ediText` string - EDI text to be read.
- `schema` EdiSchema - Schema of the EDI text.

#### Return Type
- `json|Error` - JSON variable containing the parsed transaction body. Error if the reading fails.

#### Example

```ballerina
import ballerina/io;
import ballerina/edi;

public function main() returns error? {
    edi:EdiSchema schema = check edi:getSchema(check io:fileReadJson("resources/edi-schema.json"));
    string ediText = check io:fileReadString("resources/edi-sample.edi");
    json orderData = check edi:fromEdiString(ediText, schema);
    io:println(orderData.toJsonString());
}
```

### 3.3 `toEdiString` function

Writes the given JSON variable into EDI text according to the provided schema.

```ballerina
function toEdiString(json msg, EdiSchema schema) returns string|Error
```

#### Parameters
- `msg` json - JSON value to be written into EDI.
- `schema` EdiSchema - Schema of the EDI text.

#### Return Type
- `string|Error` - EDI text containing the data provided in the JSON variable. Error if the writing fails.

### 3.4 `x12HeadersFromEdiString` function

Schema-free. Parses the X12 ISA segment (fixed-width, 106 characters) and optionally the GS segment that follows. Useful for routing, partner identification, and schema selection without loading a schema. The ISA is validated strictly against the standard fixed element widths (ISA01..ISA16) — a non-conformant (e.g. unpadded) ISA is rejected with `InvalidEnvelopeError` instead of being part-parsed. A leading BOM is stripped.

```ballerina
isolated function x12HeadersFromEdiString(string ediText) returns X12Headers|Error
```

#### Parameters
- `ediText` string - Raw X12 EDI text.

#### Return Type
- `X12Headers|Error` - Parsed `X12Headers` (`isa` always present, `gs?` when a GS follows ISA). `InvalidEnvelopeError` when the ISA cannot be located, is truncated, or is not a conformant fixed-width ISA.

### 3.5 `x12HeadersFromEdiFile` function

File variant of [`x12HeadersFromEdiString`](#34-x12headersfromedistring-function). Reads only the first 512 characters from the file via a `ReadableCharacterChannel` — enough for any conforming ISA + GS combination — and parses them.

```ballerina
isolated function x12HeadersFromEdiFile(string filePath) returns X12Headers|Error
```

#### Parameters
- `filePath` string - Path to the X12 EDI file.

#### Return Type
- `X12Headers|Error` - Parsed `X12Headers`, or `Error` when the file cannot be read or the ISA cannot be parsed.

### 3.6 `edifactHeadersFromEdiString` function

Schema-free. Parses the EDIFACT UNB segment and optionally the UNH that follows. Honours the optional UNA service string advice when present, picking up custom delimiters and the release character from UNA positions 3–8. Field and component splitting is release-character aware: delimiters escaped by the release character are treated as data, and release sequences are un-escaped in the returned values (`?+` → `+`, `?:` → `:`, `?'` → `'`, `??` → `?`). A leading BOM is stripped.

```ballerina
isolated function edifactHeadersFromEdiString(string ediText) returns EdifactHeaders|Error
```

#### Parameters
- `ediText` string - Raw EDIFACT EDI text (with or without UNA).

#### Return Type
- `EdifactHeaders|Error` - Parsed `EdifactHeaders` (`unb` always present, `unh?` when a UNH follows). `InvalidEnvelopeError` when the UNB cannot be located.

### 3.7 `edifactHeadersFromEdiFile` function

File variant of [`edifactHeadersFromEdiString`](#36-edifactheadersfromedistring-function). Reads only the first 512 characters from the file via a `ReadableCharacterChannel` and parses them.

```ballerina
isolated function edifactHeadersFromEdiFile(string filePath) returns EdifactHeaders|Error
```

#### Parameters
- `filePath` string - Path to the EDIFACT EDI file.

#### Return Type
- `EdifactHeaders|Error` - Parsed `EdifactHeaders`, or `Error`.

### 3.8 `headersFromEdiString` function

Schema-driven. Parses only the envelope header segments declared by `schema.envelope` (interchange, optional group, transaction) and stops — the rest of the document is never processed. Returns a JSON map with `interchange`, `group?`, and `transaction` entries. The envelope header segments are treated as mandatory regardless of their declared `minOccurances` — non-matching input fails fast with `InvalidEnvelopeError` instead of producing empty header sections. A leading UNA service string advice is validated against the schema delimiters and skipped (see [UNA semantics](#63-una-service-string-advice)); a leading BOM is stripped.

```ballerina
isolated function headersFromEdiString(string ediText, EdiSchema schema) returns json|Error
```

#### Parameters
- `ediText` string - Raw EDI text.
- `schema` EdiSchema - Schema with a non-nil `envelope`.

#### Return Type
- `json|Error` - Parsed header sections. `SchemaCompatibilityError` (with a *Regenerate the schema…* message) when `schema.envelope` is `()` (older schema) or when the schema uses fixed-length ("FL") field delimiting; `InvalidEnvelopeError` when the input does not match the envelope headers.

### 3.9 `headersFromEdiFile` function

File variant of [`headersFromEdiString`](#38-headersfromedistring-function). Reads only the first 4096 characters from the file via a `ReadableCharacterChannel`, which covers any reasonable envelope header section. When the headers cannot be parsed and the read consumed the entire 4096-character window, an `InvalidEnvelopeError` mentioning the window size is returned — the envelope header section may exceed the read window.

```ballerina
isolated function headersFromEdiFile(string filePath, EdiSchema schema) returns json|Error
```

#### Parameters
- `filePath` string - Path to the EDI file.
- `schema` EdiSchema - Schema with a non-nil `envelope`.

#### Return Type
- `json|Error` - Parsed header sections, or `Error`.

### 3.10 `interchangeFromEdiString` function

Schema-driven. Parses the full envelope hierarchy and returns an `EdiInterchange`. Envelope segments (interchange / group / transaction headers and trailers) are fail-fast — a malformed envelope segment aborts the parse with `InvalidEnvelopeError`, and they are treated as mandatory regardless of the schema's declared `minOccurances`. The transaction body is **fail-safe** — when a body cannot be parsed against `schema.segments`, the resulting `EdiTransaction.body` field holds the parse `error` and the rest of the interchange continues. Envelope trailers are located by scanning backward (see [Trailer location](#64-trailer-location-fail-safe-guarantee)), so trailer-coded junk in a corrupted body cannot hijack the envelope.

Trailer counts and control references are captured as-is and are **not validated** against the actual content; they are recomputed on write by [`interchangeToEdiString`](#311-interchangetoedistring-function) (see [Counts and control numbers](#61-counts-and-control-numbers)). Only a **single interchange per call** is supported — content after the interchange trailer or a second interchange header in the body produces `InvalidEnvelopeError` (see [Single interchange per call](#62-single-interchange-per-call)). A leading UNA service string advice is validated against the schema delimiters and skipped; a leading BOM is stripped.

When `schema.envelope.group` is set (X12), transactions are nested inside `EdiFunctionalGroup` entries on the `groups` field. When it is absent (EDIFACT without UNG/UNE), transactions appear directly on the `transactions` field of `EdiInterchange`.

```ballerina
isolated function interchangeFromEdiString(string ediText, EdiSchema schema) returns EdiInterchange|Error
```

#### Parameters
- `ediText` string - Raw EDI text.
- `schema` EdiSchema - Schema with a non-nil `envelope`.

#### Return Type
- `EdiInterchange|Error` - Parsed interchange tree. `InvalidEnvelopeError` when an envelope segment is malformed or missing, when an envelope trailer cannot be located, or when the input carries more than one interchange; `SchemaCompatibilityError` when `schema.envelope` is `()` or the schema uses fixed-length ("FL") field delimiting.

#### Example

```ballerina
edi:EdiInterchange ix = check edi:interchangeFromEdiString(ediText, schema);
foreach var grp in ix.groups ?: [] {
    foreach var txn in grp.transactions {
        if txn.body is error {
            log:printError("Quarantined", body = txn.body);
            continue;
        }
        // forward parsed body downstream
    }
}
```

### 3.11 `interchangeToEdiString` function

Schema-driven. The inverse of `interchangeFromEdiString` — serialises a fully populated `EdiInterchange` back into EDI text using the schema's `envelope` definition. The interchange / group / transaction headers and trailers are written from the corresponding `EdiInterchange` fields, and each transaction's body is written using `schema.segments` (the same fragment `fromEdiString` parses against), so a parse / serialise round-trip is structurally symmetric.

Two conformance adjustments are applied on write (see [Counts and control numbers](#61-counts-and-control-numbers)):

- The X12 ISA interchange header is re-padded to its standard fixed element widths so the emitted ISA is exactly 106 characters (parsing trims the padding; receivers read the ISA positionally).
- Trailer counts (SE01 / GE01 / IEA01 / UNT01 / UNZ01) are **recomputed** from the content being written, and trailer control references (SE02 / GE02 / IEA02 / UNT02 / UNZ02) are mirrored from the corresponding headers — stale values captured at parse time (e.g. after the caller mutates the transaction list) are ignored.

Unlike `toEdiString`, which is body-only and writes just `schema.segments` even when the schema declares an `envelope`, `interchangeToEdiString` emits the envelope segments alongside the body without the caller having to hand-build them.

```ballerina
isolated function interchangeToEdiString(EdiInterchange msg, EdiSchema schema) returns string|Error
```

#### Parameters
- `msg` EdiInterchange - The interchange to serialise.
- `schema` EdiSchema - Schema with a non-nil `envelope`.

#### Return Type
- `string|Error` - EDI text for the interchange. `SchemaCompatibilityError` when `schema.envelope` is `()` or the schema uses fixed-length ("FL") field delimiting; `SerializationError` when `groups` is unset for a group-bearing (X12) schema (or `transactions` is unset for a group-less EDIFACT schema), or when any transaction's `body` field holds an `error` (malformed bodies cannot be serialised — callers must filter or replace them first).

#### Example

```ballerina
edi:EdiInterchange ix = check edi:interchangeFromEdiString(ediText, schema);
// ... inspect or transform ix ...
string ediOut = check edi:interchangeToEdiString(ix, schema);
```

## 4. Types

### 4.1 X12 envelope types

```ballerina
public type X12ISA record {|
    string authInfoQualifier; string authInfo;
    string securityQualifier; string securityInfo;
    string senderQualifier; string senderId;
    string receiverQualifier; string receiverId;
    string date; string time;
    string version; string controlNumber; string usageIndicator;
|};

public type X12GS record {|
    string functionalIdentifier;
    string senderId; string receiverId;
    string date; string time;
    string controlNumber; string version;
|};

public type X12Headers record {|
    X12ISA isa;
    X12GS gs?;
|};
```

### 4.2 EDIFACT envelope types

EDIFACT composites within UNB and UNH are exposed as separate named records for reuse and clarity.

```ballerina
public type EdifactSyntaxIdentifier record {|
    string syntaxId;
    string syntaxVersion;
|};

public type EdifactInterchangeParty record {|
    string id;
    string qualifier;
|};

public type EdifactDateTime record {|
    string date;
    string time;
|};

public type EdifactUNB record {|
    EdifactSyntaxIdentifier syntaxIdentifier;
    EdifactInterchangeParty sender;
    EdifactInterchangeParty recipient;
    EdifactDateTime dateAndTime;
    string controlRef;
|};

public type EdifactMessageIdentifier record {|
    string messageType;
    string version;
    string release;
    string controlAgency;
|};

public type EdifactUNH record {|
    string messageRef;
    EdifactMessageIdentifier messageIdentifier;
|};

public type EdifactHeaders record {|
    EdifactUNB unb;
    EdifactUNH unh?;
|};
```

### 4.3 Hierarchical interchange types

```ballerina
public type EdiInterchange record {|
    json interchangeHeader;
    EdiFunctionalGroup[] groups?;       // set when envelope.group is defined
    EdiTransaction[] transactions?;     // set when envelope.group is absent
    json interchangeTrailer;
|};

public type EdiFunctionalGroup record {|
    json groupHeader;
    EdiTransaction[] transactions;
    json groupTrailer;
|};

public type EdiTransaction record {|
    json transactionHeader;
    json|error body;                    // fail-safe per-transaction body
    json transactionTrailer;
|};
```

The `body` field of `EdiTransaction` uses a `json|error` union so callers can inspect *why* a transaction failed (`error.message()`), log it, or route it to a dead-letter queue without aborting the rest of the interchange.

## 5. Error types

All module errors are subtypes of `edi:Error`, so every existing `returns ...|edi:Error` signature remains valid. The envelope-aware code paths additionally distinguish three failure classes:

```ballerina
# Parent of all EDI module errors.
public type Error distinct error;

# The input EDI text does not conform to the expected envelope structure.
public type InvalidEnvelopeError distinct Error;

# The schema cannot support the requested operation.
public type SchemaCompatibilityError distinct Error;

# interchangeToEdiString refuses to serialise the given EdiInterchange.
public type SerializationError distinct Error;
```

- `InvalidEnvelopeError` — returned when a mandatory envelope segment is missing or does not match (envelope header / trailer segments are always treated as mandatory by envelope-aware APIs, regardless of the schema's declared `minOccurances`); when content remains after the interchange trailer or a second interchange header appears in the body (only a single interchange per call is supported); when the X12 ISA segment is malformed, truncated, or not the standard fixed width; when a UNA service string advice declares delimiters conflicting with the schema; when `fromEdiString` receives a multi-transaction interchange; or when the envelope headers exceed the file read window of `headersFromEdiFile`.
- `SchemaCompatibilityError` — returned when a schema without `envelope` is passed to an envelope-aware API (regenerate the schema with edi-tools 2.2.0 or later); when a fixed-length (`"field": "FL"`) schema is used with any envelope-aware API (`headersFromEdiString`, `headersFromEdiFile`, `interchangeFromEdiString`, `interchangeToEdiString`, and the envelope path of `fromEdiString`); or when unresolved segment references (`ref`) surface at runtime in an envelope section.
- `SerializationError` — returned when `interchangeToEdiString` refuses to serialise: a transaction `body` holds an `error` (the fail-safe result of a previous parse), a body or envelope section is not a JSON object, or the `groups` / `transactions` field required by the schema's envelope shape is unset.

Legacy body-parsing internals (used by `fromEdiString` for schemas without `envelope`) continue to return the generic `edi:Error`.

## 6. Envelope processing semantics

### 6.1 Counts and control numbers

Envelope trailer counts and control references (SE01 / GE01 / IEA01 / UNT01 / UNZ01 and SE02 / GE02 / IEA02 / UNT02 / UNZ02) are **not validated on read**: `interchangeFromEdiString` captures whatever values appear in the input. They are **recomputed on write** by `interchangeToEdiString`:

- transaction trailer count (SE01 / UNT01) = number of segments in the transaction, inclusive of the transaction header and trailer segments;
- group trailer count (GE01) = number of transaction sets in the group;
- interchange trailer count (IEA01 / UNZ01) = number of functional groups (or number of messages when the schema has no group level);
- trailer control references are mirrored from the corresponding headers: IEA02=ISA13, GE02=GS06, SE02=ST02, UNT02=UNH 0062, UNZ02=UNB 0020. The elements are identified positionally per the standard segment layouts (the count is the first element after the segment code; the control reference is the element after the count). When the schema-declared trailer has fewer fields, only what fits is written.

The X12 ISA interchange header is re-padded on write to its standard fixed element widths (ISA01..ISA16 = 2, 10, 2, 10, 2, 15, 2, 15, 6, 4, 1, 5, 9, 1, 1, 1), producing the mandatory 106-character ISA. Schema-declared fixed field lengths take precedence over the standard widths.

### 6.2 Single interchange per call

`interchangeFromEdiString` processes exactly one interchange. Content after the interchange trailer, or a second interchange header segment inside the body, is rejected with `InvalidEnvelopeError`. Callers processing batched streams must split the input into individual interchanges first. Similarly, `fromEdiString` with an envelope schema parses a single transaction body — multi-transaction interchanges must use `interchangeFromEdiString`.

### 6.3 UNA service string advice

- **Schema-free functions** (`edifactHeadersFromEdiString` / `edifactHeadersFromEdiFile`) honour the UNA fully: all six service characters (component, field, decimal, release, reserved, segment terminator) are taken from the UNA, including custom delimiter sets. Field and component splitting is release-character aware and release sequences are un-escaped in the returned values (`?+` → `+`, `?:` → `:`, `?'` → `'`, `??` → `?`).
- **Schema-driven functions** (`headersFromEdiString`, `headersFromEdiFile`, `interchangeFromEdiString`, and `fromEdiString` with an envelope schema) validate a leading UNA against the schema delimiters (component, field, decimal separator when the schema declares one, and segment terminator). A matching UNA is skipped; a conflicting UNA produces `InvalidEnvelopeError` — the schema-driven parser cannot honour delimiters other than the schema's.

### 6.4 Trailer location (fail-safe guarantee)

`interchangeFromEdiString` locates the interchange trailer by scanning **backward** from the end of the input, and group / transaction trailers by scanning backward from the next same-level header. Trailer-coded junk inside a corrupted transaction body therefore stays inside that body (captured as the per-transaction `error`) instead of hijacking the envelope.

### 6.5 Fixed-length schemas

Envelope-aware APIs rely on delimiter-based segment-code extraction and do not support fixed-length (`"field": "FL"`) schemas; they return `SchemaCompatibilityError`. `fromEdiString` / `toEdiString` with FL schemas that have no `envelope` are unaffected.

### 6.6 Byte-order marks

A single leading U+FEFF (BOM) is stripped by the string and file entry points of the envelope-aware APIs before envelope detection.
