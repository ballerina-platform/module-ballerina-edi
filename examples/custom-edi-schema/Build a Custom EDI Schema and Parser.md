# Build a Custom EDI Schema and Parser

This example shows how to start from a standard EDIFACT message, customise it for a trading
partner's deviations, and generate a typed Ballerina parser with `edi-tools`. The other EDI examples
([parser to Kafka](../edi-parser-to-kafka), [vendor router](../edi-vendor-router),
[order generator](../edi-order-generator)) all rely on a module produced this way.

## Overview

Real trading partners rarely use a published EDI specification verbatim — they add extra elements,
tighten field lengths, or restrict code lists. The workflow is:

1. **Generate the base schema** from the standard message version and type.
2. **Customise the schema JSON** for the partner's deviations.
3. **Generate the typed module** (records + envelope-aware parser/serializer functions).

The result is a Ballerina module whose `interchangeFromEdiString`, `headersFromEdiString`,
`fromEdiString`, `toEdiString`, and `interchangeToEdiString` functions expose only typed records — no
`json` on the surface.

## Step 1 — Generate the base schema

`edi-tools` converts a published EDIFACT version + message type into a Ballerina EDI schema with a
populated `envelope` (interchange + transaction levels for EDIFACT; no functional group):

```bash
bal edi convertEdifactSchema -v d03a -t ORDERS -o schemas/ORDERS.json
```

## Step 2 — Customise the schema

Edit `schemas/ORDERS.json` for partner-specific deviations. In this example the partner appends a
fifth sub-element to the UNH message identifier, so a `new_field` component was added to the `UNH`
segment definition:

```json
"message_information": {
    "components": [
        {"tag": "name"}, {"tag": "catagory"}, {"tag": "version"},
        {"tag": "status"}, {"tag": "new_field"}
    ]
}
```

Other common customisations: change a field `length`, mark a segment `required`, add code values, or
add/remove segments. See the [Schema Specification](https://github.com/ballerina-platform/module-ballerina-edi/blob/main/docs/specs/SchemaSpecification.md)
for the full grammar.

## Step 3 — Generate the typed module

```bash
bal edi codegen -i schemas/ORDERS.json -o modules/orders/orders.bal
```

The customised element appears on the generated record, so `messageInfo.new_field` is fully typed:

```ballerina
public type Message_information_GType record {|
    string name?;
    string catagory?;
    string version?;
    string status?;
    string new_field?;   // partner extension
|};
```

> The `edi-tools` 2.2.0 commands above and the `ballerina/edi` 1.6.0 envelope APIs are part of an
> unreleased version; the generated module under `modules/orders` and the schema under `schemas/` are
> committed so this example runs against the local `ballerina/edi` build today.

## Run the example

`sample.edi` carries the partner extension in its UNH segment (`...:UN:EXT1`):

```bash
bal run
```

Expected output — the custom `new_field` is parsed alongside the standard fields:

```
Standard message type: ORDERS D03A UN
Partner extension (custom new_field): EXT1
Order id: PO77001
Line items: 2
```
