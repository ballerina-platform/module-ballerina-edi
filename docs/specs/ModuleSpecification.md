# Specification: Ballerina EDI Module

_Owners_: @chathurace @RDPerera
_Reviewers_: @niveathika @chathurace
_Created_: 2024/01/19
_Updated_: 2024/01/19
_Edition_: Swan Lake

## Introduction

This is the specification for the `edi` module of the [Ballerina language](https://ballerina.io). The `edi` module provides functionality to convert EDI text to JSON and JSON to EDI text. Additionally, it supports defining the schema of EDI files in JSON format. The module includes three functions: `fromEdiString`, `toEdiString` and `getSchema`.

If you have any feedback or suggestions about the module, start a discussion via a [GitHub issue](https://github.com/ballerina-platform/ballerina-library/issues) or in the [Discord server](https://discord.gg/ballerinalang). Based on the outcome of the discussion, the specification and implementation can be updated. Community feedback is always welcome. Any accepted proposal, which affects the specification, is stored under `/docs/proposals`. Proposals under discussion can be found with the label `type/proposal` on GitHub.

## Contents

1. [Overview](#1-overview)
2. [`EdiSchema` Record](#2-edischema-record)
3. [Functions](#3-functions)
    * 3.1 [`getSchema` function](#31-getschema-function)
    * 3.2 [`fromEdiString` function](#32-fromedistring-function)
    * 3.3 [`toEdiString` function](#33-toedistring-function)
    * 3.4 [`peekX12Headers` function](#34-peekx12headers-function)
    * 3.5 [`peekEdifactHeaders` function](#35-peekedifactheaders-function)
    * 3.6 [`headersFromEdiString` function](#36-headersfromedistring-function)
    * 3.7 [`envelopeFromEdiString` function](#37-envelopefromedistring-function)


## 1. Overview

The Ballerina language offers first-class support for handling network-structured data, and the `edi` module leverages these features to facilitate the conversion between EDI text and JSON, with the ability to define the EDI schema in JSON format.

## 2. `EdiSchema` Record

The `EdiSchema` record represents the schema of the EDI text. To define the structure of EDI data, developers can utilize the [Ballerina EDI Schema Specification](./SchemaSpecification.md). 

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

Below code reads the edi-schema.json file and assign to a edi:EdiSchema variable which holds Ballerina EDI Schema.

```ballerina
import ballerina/io;
import balarina/edi;

public function main() returns error? {
    edi:EdiSchema schema = check edi:getSchema(check io:fileReadJson("resources/edi-schema.json"));
    io:println(schema.toString());
}
```

### 3.2 `fromEdiString` function

Reads the given EDI text according to the provided schema.

```ballerina
function fromEdiString(string ediText, EdiSchema schema) returns json|Error
```

#### Parameters
- `ediText` string - EDI text to be read.
- `schema` EdiSchema - Schema of the EDI text.

#### Return Type
- `json|Error` - JSON variable containing EDI data. Error if the reading fails.


#### Example

Below code reads the `edi-sample.edi` into a json variable named "orderData".
_(given schema is based on the schema used in the above example)_

```ballerina
import ballerina/io;
import balarina/edi;

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

#### Example

Below code converts of a json data to EDI text :

```ballerina
import ballerina/io;
import balarinax/edi;

public function main() returns error? {
    json order2 = {...};
    edi:EdiSchema schema = check edi:getSchema(check io:fileReadJson("resources/edi-schema.json"));
    string orderEDI = check edi:toEdiString(order2, schema);
    io:println(orderEDI);
}
```

### 3.4 `peekX12Headers` function

Extracts X12 envelope headers (ISA and optional GS) directly from raw EDI text without requiring a schema. The ISA segment is parsed using fixed-width offsets per the X12 standard.

```ballerina
function peekX12Headers(string ediText) returns X12Headers|Error
```

#### Parameters
- `ediText` string - Raw X12 EDI text starting with the `ISA` segment.

#### Return Type
- `X12Headers|Error` - Parsed `X12Headers` record (`{ isa, gs? }`). `Error` if the text does not start with `ISA` or the segment cannot be parsed.

#### Example

```ballerina
import ballerina/io;
import ballerina/edi;

public function main() returns error? {
    string ediText = check io:fileReadString("resources/x12-message.edi");
    edi:X12Headers headers = check edi:peekX12Headers(ediText);
    io:println(headers.isa.controlNumber);
}
```

### 3.5 `peekEdifactHeaders` function

Extracts EDIFACT envelope headers (UNA service-string advice, UNB interchange header, optional UNH message header) without requiring a schema.

```ballerina
function peekEdifactHeaders(string ediText) returns EdifactHeaders|Error
```

#### Parameters
- `ediText` string - Raw EDIFACT EDI text starting with the optional `UNA` advice or with `UNB`.

#### Return Type
- `EdifactHeaders|Error` - Parsed `EdifactHeaders` record (`{ unb, unh? }`). `Error` if the text is not a valid EDIFACT interchange.

#### Example

```ballerina
import ballerina/io;
import ballerina/edi;

public function main() returns error? {
    string ediText = check io:fileReadString("resources/edifact-message.edi");
    edi:EdifactHeaders headers = check edi:peekEdifactHeaders(ediText);
    io:println(headers.unh?.messageIdentifier?.messageType);
}
```

### 3.6 `headersFromEdiString` function

Schema-driven envelope header parse. Reads only the segments declared in `schema.headerSegments` and returns immediately, skipping the body and trailer. Useful when only routing/identifying envelope information is needed.

```ballerina
function headersFromEdiString(string ediText, EdiSchema schema) returns json|Error
```

#### Parameters
- `ediText` string - EDI text to be read.
- `schema` EdiSchema - Schema with `headerSegments` populated.

#### Return Type
- `json|Error` - JSON containing the parsed header segments. `Error` if the schema does not declare `headerSegments` or if header parsing fails.

### 3.7 `envelopeFromEdiString` function

Single-pass envelope split. Parses the segments declared in `schema.headerSegments` and `schema.trailerSegments` against the given EDI text and returns the headers, the raw unparsed body segment strings, and the trailers as an `EdiEnvelope` record. The raw body strings can later be passed to `fromEdiString` against a body-only schema for deeper parsing.

```ballerina
function envelopeFromEdiString(string ediText, EdiSchema schema) returns EdiEnvelope|Error
```

#### Parameters
- `ediText` string - EDI text to be read.
- `schema` EdiSchema - Schema with both `headerSegments` and `trailerSegments` populated.

#### Return Type
- `EdiEnvelope|Error` - Record `{ headers: json, body: string[], trailers: json }`. `Error` if the schema is missing envelope fields or if parsing fails.

#### Example

```ballerina
import ballerina/io;
import ballerina/edi;

public function main() returns error? {
    edi:EdiSchema schema = check edi:getSchema(check io:fileReadJson("resources/envelope-schema.json"));
    string ediText = check io:fileReadString("resources/message.edi");
    edi:EdiEnvelope env = check edi:envelopeFromEdiString(ediText, schema);
    io:println("Header segments: ", env.headers);
    io:println("Body segment count: ", env.body.length());
    io:println("Trailer segments: ", env.trailers);
}
```
