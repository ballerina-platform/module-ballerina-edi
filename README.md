# Ballerina EDI Module

[![Build](https://github.com/ballerina-platform/module-ballerina-edi/actions/workflows/build-timestamped-master.yml/badge.svg)](https://github.com/ballerina-platform/module-ballerina-edi/actions/workflows/build-timestamped-master.yml)
[![Trivy](https://github.com/ballerina-platform/module-ballerina-edi/actions/workflows/trivy-scan.yml/badge.svg)](https://github.com/ballerina-platform/module-ballerina-edi/actions/workflows/trivy-scan.yml)
[![codecov](https://codecov.io/gh/ballerina-platform/module-ballerina-edi/branch/main/graph/badge.svg)](https://codecov.io/gh/ballerina-platform/module-ballerina-edi)
[![GraalVM Check](https://github.com/ballerina-platform/module-ballerina-edi/actions/workflows/build-with-bal-test-graalvm.yml/badge.svg)](https://github.com/ballerina-platform/module-ballerina-edi/actions/workflows/build-with-bal-test-graalvm.yml)
[![GitHub Last Commit](https://img.shields.io/github/last-commit/ballerina-platform/module-ballerina-edi.svg)](https://github.com/ballerina-platform/module-ballerina-edi/commits/main)
[![GitHub Issues](https://img.shields.io/github/issues/ballerina-platform/ballerina-library/module/ballerina-edi.svg?label=Open%20Issues)](https://github.com/ballerina-platform/ballerina-library/labels/module%2Fballerina-edi)

## Overview

Electronic Data Interchange (EDI) is a standard for exchanging business documents — purchase orders, invoices, shipping notices — between trading partners in a structured, machine-readable format. The two most widely used standards are **X12** (North America) and **EDIFACT** (international).

The Ballerina `edi` module lets you:

- **Inspect envelope headers** without a schema — fastest path for routing and partner identification (X12 ISA/GS, EDIFACT UNB/UNH).
- **Parse the full envelope hierarchy** into typed `EdiInterchange` / `EdiFunctionalGroup` / `EdiTransaction` records, with fail-safe per-transaction body — process what you can and quarantine what you can't.
- **Parse a transaction body into JSON or typed Ballerina records** (X12, EDIFACT, or any custom format).
- **Serialize JSON / records back to EDI text** for outbound flows.
- **Drive parsing from a JSON schema** — either hand-written, [generated from an X12 / EDIFACT spec](#3-working-with-standard-edi-formats-x12--edifact), or [defined manually](#5-defining-a-custom-edi-schema) for partner-specific formats.

The companion [`edi-tools` CLI](https://github.com/ballerina-platform/edi-tools) generates Ballerina records and ready-to-use parser code from a schema, so most users never have to call the low-level functions in this module directly.

## 1. Quick start

The fastest path is to generate a typed parser from an EDIFACT or X12 spec using `edi-tools` and call the generated functions from your code.

### Install

The `edi` module is pulled in automatically when you import it. Install the CLI tool:

```bash
$ bal tool pull edi
```

### Generate a parser from an EDIFACT spec

```bash
# 1. Convert the EDIFACT D03A ORDERS spec into a Ballerina EDI schema
$ bal edi convertEdifactSchema -v d03a -t ORDERS -o resources/orders-schema.json

# 2. Generate Ballerina records and parser functions from the schema
$ bal edi codegen -i resources/orders-schema.json -o modules/orders/orders.bal
```

For X12 use `bal edi convertX12Schema` — see [Working with standard EDI formats](#3-working-with-standard-edi-formats-x12--edifact).

### Use the generated code

```ballerina
import ballerina/io;
import sample.orders;

public function main() returns error? {
    string ediText = check io:fileReadString("resources/order.edi");
    orders:OrdersInterchange interchange = check orders:interchangeFromEdiString(ediText);
    foreach var txn in interchange.transactions {
        if txn.body is error {
            io:println("Quarantined: ", (<error>txn.body).message());
            continue;
        }
        io:println(txn.body);
    }
}
```

That's it for typical usage. The rest of this README covers the operations available, when to drop down to the underlying module functions, and how to define a custom schema.

## 2. Processing EDI

The module exposes four families of operations spanning schema-free and schema-driven usage. Pick the one that matches your use case:

| # | Function | Schema needed? | Error behavior | Primary use case |
|---|----------|---------------|----------------|------------------|
| 1 | [`x12HeadersFromEdiString`](https://github.com/ballerina-platform/module-ballerina-edi/blob/main/docs/specs/ModuleSpecification.md#34-x12headersfromedistring-function) / [`x12HeadersFromEdiFile`](https://github.com/ballerina-platform/module-ballerina-edi/blob/main/docs/specs/ModuleSpecification.md#35-x12headersfromedifile-function) | No | Fail fast | Routing, filtering, schema selection (X12) |
| 2 | [`edifactHeadersFromEdiString`](https://github.com/ballerina-platform/module-ballerina-edi/blob/main/docs/specs/ModuleSpecification.md#36-edifactheadersfromedistring-function) / [`edifactHeadersFromEdiFile`](https://github.com/ballerina-platform/module-ballerina-edi/blob/main/docs/specs/ModuleSpecification.md#37-edifactheadersfromedifile-function) | No | Fail fast | Routing, filtering, schema selection (EDIFACT) |
| 3 | [`headersFromEdiString`](https://github.com/ballerina-platform/module-ballerina-edi/blob/main/docs/specs/ModuleSpecification.md#38-headersfromedistring-function) / [`headersFromEdiFile`](https://github.com/ballerina-platform/module-ballerina-edi/blob/main/docs/specs/ModuleSpecification.md#39-headersfromedifile-function) | Yes (`envelope`) | Fail fast | Header-only inspection inside generated libs |
| 4 | [`interchangeFromEdiString`](https://github.com/ballerina-platform/module-ballerina-edi/blob/main/docs/specs/ModuleSpecification.md#310-interchangefromedistring-function) | Yes (`envelope`) | **Fail safe** (body only) | Batch splitting, partial recovery, body forwarding |
| 5 | [`fromEdiString`](https://github.com/ballerina-platform/module-ballerina-edi/blob/main/docs/specs/ModuleSpecification.md#32-fromedistring-function) | Yes | Fail fast | Transaction body parsing into typed records |
| 6 | [`toEdiString`](https://github.com/ballerina-platform/module-ballerina-edi/blob/main/docs/specs/ModuleSpecification.md#33-toedistring-function) | Yes | Fail fast | Serialize JSON / records into EDI text |
| 7 | [`interchangeToEdiString`](https://github.com/ballerina-platform/module-ballerina-edi/blob/main/docs/specs/ModuleSpecification.md#311-interchangetoedistring-function) | Yes (`envelope`) | Fail fast | Serialize a full interchange; round-trips with `interchangeFromEdiString` |

### 2.1 Inspecting envelopes (no schema)

Cheapest — pulls just the interchange / message headers off the wire so you can route or audit before deciding whether to parse the body.

```ballerina
import ballerina/edi;
import ballerina/io;

public function main() returns error? {
    string ediText = check io:fileReadString("resources/sample.edi");

    // X12 — fixed-width parse of ISA (and GS if present)
    edi:X12Headers x12 = check edi:x12HeadersFromEdiString(ediText);
    io:println("Sender: ", x12.isa.senderId, " Control#: ", x12.isa.controlNumber);

    // EDIFACT — UNA + UNB (and UNH if present)
    edi:EdifactHeaders ed = check edi:edifactHeadersFromEdiString(ediText);
    io:println("Message type: ", ed.unh?.messageIdentifier?.messageType);
}
```

The file variants (`x12HeadersFromEdiFile`, `edifactHeadersFromEdiFile`) read only the first 512 characters from the file via a `ReadableCharacterChannel`, which is enough for any conforming ISA / UNB plus the next header.

### 2.2 Parsing the envelope hierarchy

When you have a schema with an `envelope` declaration, `interchangeFromEdiString` returns the full `EdiInterchange` — interchange header / trailer, optional functional groups (X12 only), and one `EdiTransaction` per ST or UNH. Each transaction's body is parsed independently: if one is malformed, only its `body` field becomes an `error` — sibling transactions and the surrounding envelope continue to parse.

```ballerina
edi:EdiSchema schema = check edi:getSchema(check io:fileReadJson("schema.json"));
edi:EdiInterchange ix = check edi:interchangeFromEdiString(ediText, schema);

foreach var grp in ix.groups ?: [] {
    foreach var txn in grp.transactions {
        if txn.body is error {
            log:printError("Quarantined", body = txn.body);
            continue;
        }
        // Forward the parsed body downstream.
    }
}
```

For EDIFACT messages without UNG/UNE, the schema omits the `group` level and `EdiInterchange.transactions` is set directly (no `groups` field).

A few semantics to be aware of:

- **Single interchange per call** — content after the interchange trailer (e.g. a second concatenated interchange) is rejected with `edi:InvalidEnvelopeError`. Split batched streams into individual interchanges first.
- **Counts are not validated on read** — trailer counts and control references (SE01, GE01, IEA01, UNT01, UNZ01, ...) are captured as-is; `interchangeToEdiString` recomputes them on write.
- **UNA handling** — a leading EDIFACT UNA service string advice is validated against the schema delimiters and skipped; conflicting delimiters produce `edi:InvalidEnvelopeError`. (The schema-free `edifactHeaders...` functions honour custom UNA delimiters fully, including the release character.)
- **Fixed-length schemas are unsupported** — envelope-aware APIs reject `"field": "FL"` schemas with `edi:SchemaCompatibilityError`.

If you only need the headers, `headersFromEdiString` stops as soon as the envelope header segments are consumed. The file variant reads only the first 4096 characters and returns an `edi:InvalidEnvelopeError` mentioning the window size when the headers cannot be parsed within it.

> See the [`envelope` field](https://github.com/ballerina-platform/module-ballerina-edi/blob/main/docs/specs/SchemaSpecification.md#7-envelope) in the schema spec for how to declare envelope segments.

### 2.3 Parsing a message body

Given an EDI text and a matching schema, `fromEdiString` returns a JSON tree shaped per the schema's segment / field tags. When the schema declares an `envelope`, envelope segments are skipped automatically (positionally — headers at the start, trailers at the end) and the output contains only the parsed transaction body. The input must contain a single transaction: multi-transaction interchanges are rejected with `edi:InvalidEnvelopeError` directing you to `interchangeFromEdiString`.

```ballerina
edi:EdiSchema schema = check edi:getSchema(check io:fileReadJson("resources/schema.json"));
string ediText = check io:fileReadString("resources/sample.edi");
json data = check edi:fromEdiString(ediText, schema);
io:println(data.toJsonString());
```

For most schemas you won't call this directly — the [code generated by `edi-tools`](#4-generating-ballerina-records-from-a-schema) wraps it and gives you a typed record.

### 2.4 Writing EDI text

`toEdiString` is the inverse — given a JSON value matching the schema, it produces conforming EDI text.

```ballerina
json order = {
    "header": {"code": "HDR", "orderId": "ORDER_1201", "organization": "ABC", "date": "2008-01-01"},
    "items": [
        {"code": "ITM", "item": "A-250", "quantity": 12},
        {"code": "ITM", "item": "B-250", "quantity": 10}
    ]
};
string ediText = check edi:toEdiString(order, schema);
io:println(ediText);
```

`toEdiString` writes only the message body — even when the schema declares an `envelope`, the surrounding interchange / group / transaction segments are not emitted. To serialize a full envelope, use `interchangeToEdiString`, the inverse of `interchangeFromEdiString`: it writes the interchange, group, and transaction headers/trailers from the `EdiInterchange` together with each transaction's body. A parse / serialize round-trip is structurally symmetric.

```ballerina
edi:EdiInterchange ix = check edi:interchangeFromEdiString(ediText, schema);
// ... inspect, filter, or transform ix ...
string ediOut = check edi:interchangeToEdiString(ix, schema);
```

A transaction whose `body` is an `error` (a fail-safe parse result) cannot be serialized (`edi:SerializationError`) — filter or replace such transactions before calling `interchangeToEdiString`.

On write, `interchangeToEdiString` keeps the output conformant automatically:

- the X12 ISA header is re-padded to its standard fixed widths (the emitted ISA is exactly 106 characters), and
- trailer counts (SE01 / GE01 / IEA01 / UNT01 / UNZ01) are **recomputed** from the content being written, with trailer control references mirrored from the corresponding headers (IEA02=ISA13, GE02=GS06, SE02=ST02, UNT02=UNH 0062, UNZ02=UNB 0020) — so you can add or remove transactions freely between parse and write.

### 2.5 Error handling

All module errors are subtypes of `edi:Error`, with three distinct subtypes for the envelope-aware paths:

| Error type | Meaning |
|------------|---------|
| `edi:InvalidEnvelopeError` | The input does not conform to the expected envelope structure (missing / non-matching mandatory envelope segment, malformed ISA, conflicting UNA, content after the interchange trailer, multi-transaction input to `fromEdiString`, header window overflow). |
| `edi:SchemaCompatibilityError` | The schema cannot support the operation (no `envelope` — regenerate with edi-tools 2.2.0+; fixed-length "FL" schemas with envelope APIs; unresolved `ref` entries at runtime). |
| `edi:SerializationError` | `interchangeToEdiString` refuses to serialize (a transaction `body` holds an `error`, or a body / envelope section is not a JSON object). |

```ballerina
json|edi:Error headers = edi:headersFromEdiString(ediText, schema);
if headers is edi:SchemaCompatibilityError {
    // wrong / outdated schema — pick or regenerate the right one
} else if headers is edi:InvalidEnvelopeError {
    // malformed input — reject the document
}
```

## 3. Working with standard EDI formats (X12 / EDIFACT)

You rarely write a schema for a standard EDI document by hand. The [`edi-tools`](https://github.com/ballerina-platform/edi-tools) CLI converts published X12 and EDIFACT specs into Ballerina EDI schemas:

```bash
# X12 (e.g. 850 Purchase Order, 810 Invoice)
$ bal edi convertX12Schema -i input/850.xsd -o resources/850-schema.json

# EDIFACT (version + message type, e.g. D03A ORDERS)
$ bal edi convertEdifactSchema -v d03a -t ORDERS -o resources/orders-schema.json
```

Generated schemas include a populated `envelope` field — three levels for X12 (interchange / group / transaction) and two for EDIFACT (interchange / transaction; no group). Trading-partner deviations (different field lengths, optional segments, custom code lists) are handled by editing the generated schema — see [Defining a custom EDI schema](#5-defining-a-custom-edi-schema) for the schema fields you can tweak.

## 4. Generating Ballerina records from a schema

Once you have a schema (generated or hand-written), `edi-tools` produces typed Ballerina records and parser / serializer functions for it.

### Single schema — `codegen`

```bash
$ bal edi codegen -i resources/schema.json -o modules/orders/orders.bal
```

When the schema includes an `envelope`, the generated module emits typed wrappers — no `json` fields visible to the user:

```ballerina
public type OrdersInterchange record {|
    InterchangeHeader interchangeHeader;
    OrdersTransaction[] transactions;
    InterchangeTrailer interchangeTrailer;
|};

public type OrdersTransaction record {|
    MessageHeader transactionHeader;
    Orders|error body;     // fail-safe: per-transaction body
    MessageTrailer transactionTrailer;
|};

public function interchangeFromEdiString(string ediText) returns OrdersInterchange|edi:Error;
public function headersFromEdiString(string ediText) returns json|edi:Error;
public function fromEdiString(string ediText) returns Orders|edi:Error;
public function toEdiString(Orders msg) returns string|edi:Error;
```

In your code:

```ballerina
import ballerina/io;
import sample.orders;

public function main() returns error? {
    string ediText = check io:fileReadString("resources/sample.edi");
    orders:OrdersInterchange ix = check orders:interchangeFromEdiString(ediText);
    foreach var txn in ix.transactions {
        if txn.body is error {
            continue;
        }
        io:println(txn.body.bgm.documentNumber);
    }
}
```

### Multiple schemas as a package — `libgen`

When you support a family of EDI documents (e.g. X12 850, 810, 820, 855), pack them into a single Ballerina library:

```bash
$ bal edi libgen -p citymart/porder -i CityMart/schemas -o CityMart/lib
```

This produces an importable package with one module per schema, plus a REST connector for service-style deployment. See the [edi-tools README](https://github.com/ballerina-platform/edi-tools#package-generation) for the full workflow.

## 5. Defining a custom EDI schema

For partner-specific formats — or when you want to hand-tune a generated schema — define the EDI structure as JSON. The full grammar is documented in the [Schema Specification](https://github.com/ballerina-platform/module-ballerina-edi/blob/main/docs/specs/SchemaSpecification.md).

### Minimal example

```json
{
    "name": "SimpleOrder",
    "delimiters": {"segment": "~", "field": "*", "component": ":", "repetition": "^"},
    "segments": [
        {
            "code": "HDR",
            "tag": "header",
            "minOccurances": 1,
            "fields": [
                {"tag": "code"},
                {"tag": "orderId"},
                {"tag": "organization"},
                {"tag": "date"}
            ]
        },
        {
            "code": "ITM",
            "tag": "items",
            "maxOccurances": -1,
            "fields": [
                {"tag": "code"},
                {"tag": "item"},
                {"tag": "quantity", "dataType": "int"}
            ]
        }
    ]
}
```

Parses EDI text like:

```text
HDR*ORDER_1201*ABC_Store*2008-01-01~
ITM*A-250*12~
ITM*A-45*100~
```

### What the schema controls

- [Delimiters](https://github.com/ballerina-platform/module-ballerina-edi/blob/main/docs/specs/SchemaSpecification.md#2-delimiters) — segment / field / component / sub-component / repetition / decimal separators.
- [Segments and segment groups](https://github.com/ballerina-platform/module-ballerina-edi/blob/main/docs/specs/SchemaSpecification.md#3-segments) — including occurrence cardinality and `truncatable` behaviour.
- [Fields, components, sub-components](https://github.com/ballerina-platform/module-ballerina-edi/blob/main/docs/specs/SchemaSpecification.md#4-definition-for-fields) — types (`string` / `int` / `float` / `composite`), required flag, length constraints.
- [Envelope](https://github.com/ballerina-platform/module-ballerina-edi/blob/main/docs/specs/SchemaSpecification.md#7-envelope) — hierarchical interchange / group? / transaction headers and trailers used by the envelope-aware APIs.
- [Other configuration](https://github.com/ballerina-platform/module-ballerina-edi/blob/main/docs/specs/SchemaSpecification.md#8-additional-configuration-optional) — `ignoreSegments`, `preserveEmptyFields`, `includeSegmentCode`, `segmentDefinitions` (for ref-based reuse).

For the full record-level API, see the [Module Specification](https://github.com/ballerina-platform/module-ballerina-edi/blob/main/docs/specs/ModuleSpecification.md).

## Issues and projects

The **Issues** and **Projects** tabs are disabled for this repository as this is part of the Ballerina library. To report bugs, request new features, start new discussions, view project boards, etc., visit the Ballerina library [parent repository](https://github.com/ballerina-platform/ballerina-library).

This repository only contains the source code for the package.

## Build from the source

### Prerequisites

1. Download and install Java SE Development Kit (JDK) version 21. You can download it from either of the following sources:

   * [Oracle JDK](https://www.oracle.com/java/technologies/downloads/)
   * [OpenJDK](https://adoptium.net/)

    > **Note:** After installation, remember to set the `JAVA_HOME` environment variable to the directory where JDK was installed.

2. Download and install [Ballerina Swan Lake](https://ballerina.io/).

3. Download and install [Docker](https://www.docker.com/get-started).

    > **Note**: Ensure that the Docker daemon is running before executing any tests.

4. Export your GitHub personal access token with the read package permissions as follows.

        export packageUser=<Username>
        export packagePAT=<Personal access token>

### Building the source

Execute the commands below to build from the source.

1. To build the package:

   ```bash
   ./gradlew clean build
   ```

2. To run the tests:

   ```bash
   ./gradlew clean test
   ```

3. To build the without the tests:

   ```bash
   ./gradlew clean build -x test
   ```

4. To debug package with a remote debugger:

   ```bash
   ./gradlew clean build -Pdebug=<port>
   ```

5. To debug with the Ballerina language:

   ```bash
   ./gradlew clean build -PbalJavaDebug=<port>
   ```

6. Publish the generated artifacts to the local Ballerina Central repository:

    ```bash
    ./gradlew clean build -PpublishToLocalCentral=true
    ```

7. Publish the generated artifacts to the Ballerina Central repository:

   ```bash
   ./gradlew clean build -PpublishToCentral=true
   ```

## Contribute to Ballerina

As an open-source project, Ballerina welcomes contributions from the community.

For more information, go to the [contribution guidelines](https://github.com/ballerina-platform/ballerina-lang/blob/master/CONTRIBUTING.md).

## Code of conduct

All the contributors are encouraged to read the [Ballerina Code of Conduct](https://ballerina.io/code-of-conduct).

## Useful links

* For more information go to the [EDI package](https://central.ballerina.io/ballerina/edi/latest).
* For example demonstrations of the usage, go to [Ballerina By Examples](https://ballerina.io/learn/by-example/).
* Chat live with us via our [Discord server](https://discord.gg/ballerinalang).
* Post all technical questions on Stack Overflow with the [#ballerina](https://stackoverflow.com/questions/tagged/ballerina) tag.
