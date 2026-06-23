## Overview

Electronic Data Interchange (EDI) is a standard for exchanging business documents — purchase orders, invoices, shipping notices — between trading partners in a structured, machine-readable format. The two most widely used standards are **X12** (North America) and **EDIFACT** (international).

The Ballerina `edi` module provides schema-driven, envelope-aware conversion between EDI text and JSON or typed Ballerina records, in both directions. The companion [`edi-tools` CLI](https://github.com/ballerina-platform/edi-tools) generates Ballerina records and ready-to-use parser code from a schema, so most users never have to call the low-level functions in this module directly.

### Key features

- **Schema-free envelope header inspection** — the fastest path for routing and partner identification (X12 ISA/GS, EDIFACT UNB/UNH), with no schema required.
- **Full envelope hierarchy parsing** into typed `EdiInterchange` / `EdiFunctionalGroup` / `EdiTransaction` records, with a fail-safe per-transaction body — process what you can and quarantine what you can't.
- **Transaction body parsing** into JSON or typed Ballerina records (X12, EDIFACT, or any custom format).
- **Serialization** of JSON / records back to EDI text for outbound flows.
- **Schema-driven** parsing from a JSON schema — either [generated from an X12 / EDIFACT spec](https://github.com/ballerina-platform/edi-tools) or [defined manually](https://github.com/ballerina-platform/module-ballerina-edi/blob/main/docs/specs/SchemaSpecification.md) for partner-specific formats.

## Setup

The `edi` module is pulled in automatically when you import it. To generate typed parsers from EDI schemas, install the companion CLI tool:

```bash
$ bal tool pull edi
```

## Quickstart

The fastest path is to generate a typed parser from an EDIFACT or X12 spec using `edi-tools` and call the generated functions from your code.

### Step 1: Generate a parser from a spec

Run the following from your Ballerina package to generate the records and parser functions into its default module:

```bash
# 1. Convert the EDIFACT D03A ORDERS spec into a Ballerina EDI schema.
#    -o is a directory; the schema is written to resources/ORDERS.json (named after the message type).
$ bal edi convertEdifactSchema -v d03a -t ORDERS -o resources

# 2. Generate Ballerina records and parser functions into the default module
$ bal edi codegen -i resources/ORDERS.json -o orders.bal
```

For X12 use `bal edi convertX12Schema` — see the [edi-tools documentation](https://github.com/ballerina-platform/edi-tools). For larger projects, the generated EDI code can live in its own package within a Ballerina workspace alongside your integration.

### Step 2: Use the generated code

The generated code defines typed records and parser functions in the same default module, named after the schema (an `ORDERS` schema produces `ORDERSInterchange`):

```ballerina
import ballerina/io;

public function main() returns error? {
    string ediText = check io:fileReadString("resources/order.edi");
    ORDERSInterchange interchange = check interchangeFromEdiString(ediText);
    foreach var txn in interchange.transactions {
        if txn.body is error {
            io:println("Quarantined: ", (<error>txn.body).message());
            continue;
        }
        io:println(txn.body);
    }
}
```

## Working with standard EDI formats

### EDIFACT — prebuilt packages

For common UN/EDIFACT D03A message types you do not need to generate anything: import a ready-made
package from the `ballerinax` organization and call its `fromEdiString` / `toEdiString` functions
directly. Each package groups related message types by business domain.

| Package | Domain |
|---------|--------|
| [`ballerinax/edifact.d03a.finance`](https://central.ballerina.io/ballerinax/edifact.d03a.finance) | Credit/debit advices, payment orders, invoices, ledger and tax messages. |
| [`ballerinax/edifact.d03a.logistics`](https://central.ballerina.io/ballerinax/edifact.d03a.logistics) | Cargo summaries, transport instructions, booking confirmations, dangerous goods. |
| [`ballerinax/edifact.d03a.manufacturing`](https://central.ballerina.io/ballerinax/edifact.d03a.manufacturing) | Metered consumption, quality data, safety hazards, waste disposal. |
| [`ballerinax/edifact.d03a.retail`](https://central.ballerina.io/ballerinax/edifact.d03a.retail) | Product and price data, rebate orders, retail settlements, product inquiries. |
| [`ballerinax/edifact.d03a.services`](https://central.ballerina.io/ballerinax/edifact.d03a.services) | Insurance, healthcare, job applications, berth management, claims. |
| [`ballerinax/edifact.d03a.shipping`](https://central.ballerina.io/ballerinax/edifact.d03a.shipping) | Container operations, customs declarations, vessel departures, cargo reports. |
| [`ballerinax/edifact.d03a.supplychain`](https://central.ballerina.io/ballerinax/edifact.d03a.supplychain) | Purchase orders, order responses, delivery forecasts, inventory, despatch advices. |

Each message type is available as a submodule (e.g. `finance.mINVOIC`, `supplychain.mORDERS`)
exposing `fromEdiString` / `toEdiString`; each package's default module also provides
`getEDINames()` to list its supported message types:

```ballerina
import ballerina/io;
import ballerinax/edifact.d03a.finance.mINVOIC;

public function main() returns error? {
    string ediText = check io:fileReadString("resources/invoice.edi");
    mINVOIC:EDI_INVOIC_Invoice_message invoice = check mINVOIC:fromEdiString(ediText);
    io:println(invoice);
}
```

### X12 — generate from your own spec

X12 message specifications are proprietary (licensed from ASC X12), so no prebuilt X12 packages are
published. Instead, convert the X12 schema you are licensed to use into a Ballerina EDI schema and
generate a typed parser from it, exactly like the EDIFACT quickstart above:

```bash
$ bal edi convertX12Schema -i schema.xsd -o resources/850-schema.json
$ bal edi codegen -i resources/850-schema.json -o modules/po/po.bal
```

## Exposed APIs

Most users call the generated functions rather than this module directly, but the module's public
functions are available for advanced use. The table below is a cursory overview; see the
[Module Specification](https://github.com/ballerina-platform/module-ballerina-edi/blob/main/docs/specs/ModuleSpecification.md)
for full signatures, parameters, error types, and envelope semantics.

| Function | Purpose |
|----------|---------|
| `fromEdiString` / `toEdiString` | Parse a transaction body to JSON / serialize JSON back to EDI text. |
| `x12HeadersFromEdiString` / `x12HeadersFromEdiFile` | Schema-free peek at X12 ISA/GS headers — routing and partner identification. |
| `edifactHeadersFromEdiString` / `edifactHeadersFromEdiFile` | Schema-free peek at EDIFACT UNB/UNH headers. |
| `headersFromEdiString` / `headersFromEdiFile` | Schema-driven header-only parse. |
| `interchangeFromEdiString` | Parse the full envelope hierarchy into typed records, with fail-safe per-transaction bodies. |
| `interchangeToEdiString` | Serialize a full interchange back to EDI text (recomputes envelope counts). |
| `getSchema` | Load and validate a JSON EDI schema into an `EdiSchema`. |

## Customizing the generated schema

`edi-tools` emits the schema as a JSON file before generating code. Trading partners routinely use
variations of a standard format, so you can edit this schema to match a partner-specific layout —
adjust delimiters, segment occurrences (`minOccurances` / `maxOccurances`), field data types, or
list segments to skip in `ignoreSegments` — then re-run `bal edi codegen` to regenerate the typed
parser. A minimal schema looks like:

```json
{
    "name": "SimpleOrder",
    "delimiters": {"segment": "~", "field": "*", "component": ":", "repetition": "^"},
    "segments": [
        {"code": "HDR", "tag": "header", "minOccurances": 1,
         "fields": [{"tag": "code"}, {"tag": "orderId"}, {"tag": "organization"}, {"tag": "date"}]},
        {"code": "ITM", "tag": "items", "maxOccurances": -1,
         "fields": [{"tag": "code"}, {"tag": "item"}, {"tag": "quantity", "dataType": "int"}]}
    ]
}
```

The [Schema Specification](https://github.com/ballerina-platform/module-ballerina-edi/blob/main/docs/specs/SchemaSpecification.md)
documents the full grammar — delimiters, segments and segment groups, fields / components /
sub-components, the `envelope` declaration, and the additional configuration options.

## Examples

The [`examples`](https://github.com/ballerina-platform/module-ballerina-edi/tree/main/examples) directory contains runnable end-to-end samples:

- [Custom EDI schema](https://github.com/ballerina-platform/module-ballerina-edi/tree/main/examples/custom-edi-schema) — define a custom EDI schema and generate a typed parser from it (the codegen workflow foundation).
- [Vendor router](https://github.com/ballerina-platform/module-ballerina-edi/tree/main/examples/edi-vendor-router) — schema-free header inspection to route inbound messages by trading partner.
- [Parser to Kafka](https://github.com/ballerina-platform/module-ballerina-edi/tree/main/examples/edi-parser-to-kafka) — parse an interchange with fail-safe per-transaction bodies, forward good transactions to Kafka, and quarantine the rest.
- [Order generator](https://github.com/ballerina-platform/module-ballerina-edi/tree/main/examples/edi-order-generator) — build and serialize a full interchange with `interchangeToEdiString`, including a parse/serialize round-trip.

## Documentation

- [Module Specification](https://github.com/ballerina-platform/module-ballerina-edi/blob/main/docs/specs/ModuleSpecification.md) — the full API reference and envelope processing semantics.
- [Schema Specification](https://github.com/ballerina-platform/module-ballerina-edi/blob/main/docs/specs/SchemaSpecification.md) — the JSON grammar for EDI schemas.
- [edi-tools](https://github.com/ballerina-platform/edi-tools) — converting X12 / EDIFACT specs into schemas (`convertX12Schema` / `convertEdifactSchema`), generating typed parsers (`codegen`), and packaging schema families as libraries (`libgen`).

