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
- **Drive parsing from a JSON schema** — either [generated from an X12 / EDIFACT spec](https://github.com/ballerina-platform/edi-tools) or [defined manually](https://github.com/ballerina-platform/module-ballerina-edi/blob/main/docs/specs/SchemaSpecification.md) for partner-specific formats.

The companion [`edi-tools` CLI](https://github.com/ballerina-platform/edi-tools) generates Ballerina records and ready-to-use parser code from a schema, so most users never have to call the low-level functions in this module directly.

## Quickstart

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

For X12 use `bal edi convertX12Schema` — see the [edi-tools documentation](https://github.com/ballerina-platform/edi-tools).

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

## Documentation

- [Module Specification](https://github.com/ballerina-platform/module-ballerina-edi/blob/main/docs/specs/ModuleSpecification.md) — the full API: the schema-free and schema-driven function families (with an API summary table), envelope and interchange types, error types (`InvalidEnvelopeError`, `SchemaCompatibilityError`, `SerializationError`), and envelope processing semantics (count recomputation on write, UNA handling, single interchange per call).
- [Schema Specification](https://github.com/ballerina-platform/module-ballerina-edi/blob/main/docs/specs/SchemaSpecification.md) — the JSON grammar for EDI schemas: delimiters, segments and segment groups, fields / components / sub-components, the `envelope` declaration, and additional configuration.
- [edi-tools](https://github.com/ballerina-platform/edi-tools) — converting published X12 / EDIFACT specs into schemas, generating typed records and parser functions (`codegen`), and packaging schema families as libraries (`libgen`).

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
