# Build a Custom EDI Schema and Parser

This example shows how to start from a standard EDIFACT message, customise it for a trading
partner's deviations, and generate a typed Ballerina parser with `edi-tools`. The
[parser to Kafka](../edi-parser-to-kafka) and [order generator](../edi-order-generator) examples
reuse a typed module produced this way.

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
bal edi convertEdifactSchema -v d03a -t ORDERS -o resources/ORDERS.json
```

## Step 2 — Customise the schema

Edit `resources/ORDERS.json` for partner-specific deviations. In this example the partner appends a
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
bal edi codegen -i resources/ORDERS.json -o edi_parser/edi.bal
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

## Run the example

This example is a Ballerina **workspace**: the generated `edi_parser` package plus the
`custom_edi_schema` program that parses `resources/sample.edi` (it carries the partner extension in
its UNH segment, `...:UN:EXT1`). Run from the program package:

```bash
cd custom_edi_schema
bal run
```

Expected output — the custom `new_field` is parsed alongside the standard fields:

```text
Standard message type: ORDERS D03A UN
Partner extension (custom new_field): EXT1
Order id: PO77001
Line items: 2
```
