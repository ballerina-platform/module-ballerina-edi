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
4. [Types](#4-types)
    * 4.1 [X12 envelope types](#41-x12-envelope-types)
    * 4.2 [EDIFACT envelope types](#42-edifact-envelope-types)
    * 4.3 [Hierarchical interchange types](#43-hierarchical-interchange-types)


## 1. Overview

The Ballerina language offers first-class support for handling network-structured data, and the `edi` module leverages these features to facilitate the conversion between EDI text and JSON, with the ability to define the EDI schema in JSON format. The module exposes eight public parsing functions plus `getSchema` and `toEdiString`. Five of the eight require a schema; the four schema-free header functions know the X12 / EDIFACT envelope structure intrinsically. See the [API summary table](https://github.com/ballerina-platform/module-ballerina-edi/blob/main/README.md#2-processing-edi) in the README for a use-case-driven decision tree.

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

Reads the given EDI text according to the provided schema. Fail-fast — any malformed segment aborts the parse with an `Error`. When the schema declares an `envelope`, envelope segments (interchange / group / transaction headers and trailers) are skipped automatically and only `schema.segments` is parsed; the output is identical to what callers received under the previous `ignoreSegments`-based workaround. For schemas without `envelope`, behaviour is unchanged.

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

Schema-free. Parses the X12 ISA segment (fixed-width, 106 characters) and optionally the GS segment that follows. Useful for routing, partner identification, and schema selection without loading a schema.

```ballerina
isolated function x12HeadersFromEdiString(string ediText) returns X12Headers|Error
```

#### Parameters
- `ediText` string - Raw X12 EDI text.

#### Return Type
- `X12Headers|Error` - Parsed `X12Headers` (`isa` always present, `gs?` when a GS follows ISA). `Error` when the ISA cannot be located or is truncated.

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

Schema-free. Parses the EDIFACT UNB segment and optionally the UNH that follows. Honours the optional UNA service string advice when present, picking up custom delimiters and the release character from UNA positions 3–8.

```ballerina
isolated function edifactHeadersFromEdiString(string ediText) returns EdifactHeaders|Error
```

#### Parameters
- `ediText` string - Raw EDIFACT EDI text (with or without UNA).

#### Return Type
- `EdifactHeaders|Error` - Parsed `EdifactHeaders` (`unb` always present, `unh?` when a UNH follows). `Error` when the UNB cannot be located.

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

Schema-driven. Parses only the envelope header segments declared by `schema.envelope` (interchange, optional group, transaction) and stops — the rest of the document is never processed. Returns a JSON map with `interchange`, `group?`, and `transaction` entries.

```ballerina
isolated function headersFromEdiString(string ediText, EdiSchema schema) returns json|Error
```

#### Parameters
- `ediText` string - Raw EDI text.
- `schema` EdiSchema - Schema with a non-nil `envelope`.

#### Return Type
- `json|Error` - Parsed header sections. `Error` (with a *Regenerate the schema…* message) when `schema.envelope` is `()` (older schema).

### 3.9 `headersFromEdiFile` function

File variant of [`headersFromEdiString`](#38-headersfromedistring-function). Reads only the first 4096 characters from the file via a `ReadableCharacterChannel`, which covers any reasonable envelope header section. Returns an `Error` if the headers exceed the read window.

```ballerina
isolated function headersFromEdiFile(string filePath, EdiSchema schema) returns json|Error
```

#### Parameters
- `filePath` string - Path to the EDI file.
- `schema` EdiSchema - Schema with a non-nil `envelope`.

#### Return Type
- `json|Error` - Parsed header sections, or `Error`.

### 3.10 `interchangeFromEdiString` function

Schema-driven. Parses the full envelope hierarchy and returns an `EdiInterchange`. Envelope segments (interchange / group / transaction headers and trailers) are fail-fast — a malformed envelope segment aborts the parse. The transaction body is **fail-safe** — when a body cannot be parsed against `schema.segments`, the resulting `EdiTransaction.body` field holds the parse `error` and the rest of the interchange continues.

When `schema.envelope.group` is set (X12), transactions are nested inside `EdiFunctionalGroup` entries on the `groups` field. When it is absent (EDIFACT without UNG/UNE), transactions appear directly on the `transactions` field of `EdiInterchange`.

```ballerina
isolated function interchangeFromEdiString(string ediText, EdiSchema schema) returns EdiInterchange|Error
```

#### Parameters
- `ediText` string - Raw EDI text.
- `schema` EdiSchema - Schema with a non-nil `envelope`.

#### Return Type
- `EdiInterchange|Error` - Parsed interchange tree. `Error` when an envelope segment is malformed, when `schema.envelope` is `()`, or when the envelope trailer cannot be located.

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
