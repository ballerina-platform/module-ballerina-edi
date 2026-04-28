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

- **Parse EDI text into JSON or typed Ballerina records** (X12, EDIFACT, or any custom format).
- **Inspect envelope headers** without parsing the full message — useful for routing.
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
    orders:ORDERS_Type order = check orders:fromEdiString(ediText);
    io:println(order.BeginningOfMessage.documentNumber);
}
```

That's it for typical usage. The rest of this README covers the operations available, when to drop down to the underlying module functions, and how to define a custom schema.

## 2. Processing EDI

The module exposes four families of operations. Pick the one that matches your use case:

| Operation | Function | Use when |
|-----------|----------|----------|
| **Peek headers (no schema)** | [`peekX12Headers`](./docs/specs/ModuleSpecification.md#34-peekx12headers-function) / [`peekEdifactHeaders`](./docs/specs/ModuleSpecification.md#35-peekedifactheaders-function) | You only need ISA/UNB info for routing or partner identification — fastest path. |
| **Parse envelope** | [`headersFromEdiString`](./docs/specs/ModuleSpecification.md#36-headersfromedistring-function) / [`envelopeFromEdiString`](./docs/specs/ModuleSpecification.md#37-envelopefromedistring-function) | You need parsed envelope headers + raw body segments — typical for routing then conditional deep-parse. |
| **Parse body / full message** | [`fromEdiString`](./docs/specs/ModuleSpecification.md#32-fromedistring-function) | You have a schema covering the segments you care about and want JSON / records back. |
| **Write EDI text** | [`toEdiString`](./docs/specs/ModuleSpecification.md#33-toedistring-function) | You need to serialize JSON / records into EDI text for an outbound flow. |

### 2.1 Inspecting envelopes (no schema)

Cheapest — pulls just the interchange / message headers off the wire so you can route or audit before deciding whether to parse the body.

```ballerina
import ballerina/edi;
import ballerina/io;

public function main() returns error? {
    string ediText = check io:fileReadString("resources/sample.edi");

    // X12 — fixed-width parse of ISA (and GS if present)
    edi:X12Headers x12 = check edi:peekX12Headers(ediText);
    io:println("Sender: ", x12.isa.senderId, " Control#: ", x12.isa.controlNumber);

    // EDIFACT — UNA + UNB (and UNH if present)
    edi:EdifactHeaders ed = check edi:peekEdifactHeaders(ediText);
    io:println("Message type: ", ed.unh?.messageIdentifier?.messageType);
}
```

No schema is required — these functions know the X12 / EDIFACT envelope structure.

### 2.2 Parsing the envelope and splitting the body

When you do have a schema with `headerSegments` and `trailerSegments` declared, `envelopeFromEdiString` returns the parsed envelope plus the body as raw segment strings — you can route on the headers and feed the body into `fromEdiString` against a body-only schema for deeper parsing.

```ballerina
edi:EdiSchema schema = check edi:getSchema(check io:fileReadJson("envelope-schema.json"));
edi:EdiEnvelope env = check edi:envelopeFromEdiString(ediText, schema);

io:println("Headers: ", env.headers);
io:println("Body segments: ", env.body.length());
io:println("Trailers: ", env.trailers);
```

If you only need the headers, use `headersFromEdiString` — it stops as soon as the header segments are consumed.

> See [`headerSegments` / `trailerSegments`](./docs/specs/SchemaSpecification.md#7-additional-configuration-optional) in the schema spec for how to declare envelope segments.

### 2.3 Parsing a message body

Given an EDI text and a matching schema, `fromEdiString` returns a JSON tree shaped per the schema's segment / field tags.

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

## 3. Working with standard EDI formats (X12 / EDIFACT)

You rarely write a schema for a standard EDI document by hand. The [`edi-tools`](https://github.com/ballerina-platform/edi-tools) CLI converts published X12 and EDIFACT specs into Ballerina EDI schemas:

```bash
# X12 (e.g. 850 Purchase Order, 810 Invoice)
$ bal edi convertX12Schema -i input/850.xsd -o resources/850-schema.json

# EDIFACT (version + message type, e.g. D03A ORDERS)
$ bal edi convertEdifactSchema -v d03a -t ORDERS -o resources/orders-schema.json
```

Trading-partner deviations (different field lengths, optional segments, custom code lists) are handled by editing the generated schema — see [Defining a custom EDI schema](#5-defining-a-custom-edi-schema) for the schema fields you can tweak.

## 4. Generating Ballerina records from a schema

Once you have a schema (generated or hand-written), `edi-tools` produces typed Ballerina records and parser / serializer functions for it.

### Single schema — `codegen`

```bash
$ bal edi codegen -i resources/schema.json -o modules/orders/orders.bal
```

This emits records for every segment plus a top-level record for the message, along with `fromEdiString` and `toEdiString` functions wired to the schema:

```ballerina
public type Header_Type record {|
    string code = "HDR";
    string orderId?;
    string organization?;
    string date?;
|};

public type Items_Type record {|
    string code = "ITM";
    string item?;
    int? quantity?;
|};

public type SimpleOrder record {|
    Header_Type header;
    Items_Type[] items = [];
|};
```

In your code:

```ballerina
import ballerina/io;
import sample.orders;

public function main() returns error? {
    string ediText = check io:fileReadString("resources/sample.edi");
    orders:SimpleOrder data = check orders:fromEdiString(ediText);
    io:println(data.header.orderId);
}
```

### Multiple schemas as a package — `libgen`

When you support a family of EDI documents (e.g. X12 850, 810, 820, 855), pack them into a single Ballerina library:

```bash
$ bal edi libgen -p citymart/porder -i CityMart/schemas -o CityMart/lib
```

This produces an importable package with one module per schema, plus a REST connector for service-style deployment. See the [edi-tools README](https://github.com/ballerina-platform/edi-tools#package-generation) for the full workflow.

## 5. Defining a custom EDI schema

For partner-specific formats — or when you want to hand-tune a generated schema — define the EDI structure as JSON. The full grammar is documented in the [Schema Specification](./docs/specs/SchemaSpecification.md).

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

```
HDR*ORDER_1201*ABC_Store*2008-01-01~
ITM*A-250*12~
ITM*A-45*100~
```

### What the schema controls

- [Delimiters](./docs/specs/SchemaSpecification.md#2-delimiters) — segment / field / component / sub-component / repetition / decimal separators.
- [Segments and segment groups](./docs/specs/SchemaSpecification.md#3-segments) — including occurrence cardinality and `truncatable` behaviour.
- [Fields, components, sub-components](./docs/specs/SchemaSpecification.md#4-definition-for-fields) — types (`string` / `int` / `float` / `composite`), required flag, length constraints.
- [Envelope header / trailer segments](./docs/specs/SchemaSpecification.md#7-additional-configuration-optional) — used by `headersFromEdiString` / `envelopeFromEdiString`.
- [Other configuration](./docs/specs/SchemaSpecification.md#7-additional-configuration-optional) — `ignoreSegments`, `preserveEmptyFields`, `includeSegmentCode`, `segmentDefinitions` (for ref-based reuse).

For the full record-level API, see the [Module Specification](./docs/specs/ModuleSpecification.md).

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
