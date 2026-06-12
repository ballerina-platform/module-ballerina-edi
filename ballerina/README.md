## Overview

Electronic Data Interchange (EDI) is a standard for exchanging business documents — purchase orders, invoices, shipping notices — between trading partners in a structured, machine-readable format. The two most widely used standards are **X12** (North America) and **EDIFACT** (international).

The Ballerina `edi` module lets you:

- **Inspect envelope headers** without a schema — fastest path for routing and partner identification (X12 ISA/GS, EDIFACT UNB/UNH).
- **Parse the full envelope hierarchy** into typed `EdiInterchange` / `EdiFunctionalGroup` / `EdiTransaction` records, with fail-safe per-transaction body — process what you can and quarantine what you can't.
- **Parse a transaction body into JSON or typed Ballerina records** (X12, EDIFACT, or any custom format).
- **Serialize JSON / records back to EDI text** for outbound flows.
- **Drive parsing from a JSON schema** — either [generated from an X12 / EDIFACT spec](https://github.com/ballerina-platform/edi-tools) or [defined manually](https://github.com/ballerina-platform/module-ballerina-edi/blob/main/docs/specs/SchemaSpecification.md) for partner-specific formats.

The companion [`edi-tools` CLI](https://github.com/ballerina-platform/edi-tools) generates Ballerina records and ready-to-use parser code from a schema, so most users never have to call the low-level functions in this module directly.

## Quick start

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
