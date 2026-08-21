# Acknowledge EDI Orders with an APERAK

This example reads an inbound EDIFACT D03A `ORDERS` interchange, and replies with a D03A `APERAK`
that lists every order it could read and every message it could not. It closes the loop that
[Parse EDI Documents and Publish to Kafka](../edi-parser-to-kafka) leaves open.

## Overview

A trading partner sends a batch of purchase orders. The receiver is expected to answer with an
acknowledgement saying what was accepted and what was rejected — in EDIFACT, that answer is an
`APERAK` (application error and acknowledgement) message.

The integration reads the interchange with `interchangeFromEdiString`, which is **fail-safe per
transaction**: a message the schema cannot read leaves its parse error on that transaction instead
of failing the batch. Both outcomes then map onto the APERAK:

- every order that was read becomes a `DOC` segment group naming the order number;
- every message that was not becomes an `ERC` segment group carrying an error code, the parse error
  as free text, and an `RFF` pointing at the failed message reference.

```text
order-batch.edi ──▶ interchangeFromEdiString ──┬── read ────▶ DOC+220+<order>
                                               └── failed ──▶ ERC + FTX + RFF+ACW:<message ref>
                                                                      │
                                              interchangeToEdiString ─┴──▶ acknowledgement.edi
```

The reply is written with `interchangeToEdiString`, which emits the envelope from the typed
`EDI_APERAK_APERAKInterchange` and recomputes the `UNT` segment count and the `UNZ` interchange count, so
neither has to be tracked by hand as errors are added.

## Project layout

Nothing is generated here. Both message types come from the prebuilt
[`ballerinax/edifact.d03a.supplychain`](https://central.ballerina.io/ballerinax/edifact.d03a.supplychain)
package, so the example is a single Ballerina package with two imports:

```ballerina
import ballerinax/edifact.d03a.supplychain.mAPERAK;
import ballerinax/edifact.d03a.supplychain.mORDERS;
```

```text
edi-acknowledgement/
├── main.bal                # integration (orders in → APERAK out)
└── resources/              # sample-data/, outbound/
```

Each submodule exposes the full envelope-aware API — `interchangeFromEdiString`,
`interchangeToEdiString`, `headersFromEdiString`, `fromEdiString`, `toEdiString` — over typed
records, so `mORDERS:EDI_ORDERS_ORDERSInterchange` and `mAPERAK:EDI_APERAK_APERAKInterchange` are
the same shapes `bal edi codegen` would have produced from the D03A schemas.

Reach for code generation when a trading partner deviates from the published specification, since the
prebuilt packages track the standard exactly — see
[Build a Custom EDI Schema and Parser](../custom-edi-schema) for that path.

## Prerequisites

**Ballerina** — Swan Lake (2201.12.0 or later). The prebuilt EDIFACT package is resolved from
Ballerina Central on the first build; nothing else is needed, since the example reads and writes
local files.

## Run the example

```bash
bal run
```

```text
level=INFO message="Acknowledgement written" file="resources/outbound/acknowledgement.edi" accepted=2 rejected=1
```

The inbound sample `resources/sample-data/order-batch.edi` holds three messages: `0001` and `0002`
are well-formed orders, and `0003` is missing its mandatory `BGM` segment.

## The acknowledgement

`resources/outbound/acknowledgement.edi`, split a segment per line:

```text
UNB+UNOA:3+SUPPLIER456:14+SUPERMART:14+260820:1601+ACKREF2++APERAK'
UNH+0001+APERAK:D:03A:UN'
BGM+305+ACKREF2+9'                 application error and acknowledgement
DTM+137:20260820:102'             the date and time of the run
DOC+220+PO20001'                   order 0001 accepted
DOC+220+PO20002'                   order 0002 accepted
RFF+ACW:REF2'                      the interchange being acknowledged
NAD+MS+SUPPLIER456'                acknowledgement issuer
NAD+MR+SUPERMART'                  acknowledgement recipient
ERC+13::ZZZ'                       order 0003 rejected
FTX+AAO+++Mandatory unit is missing in the EDI. Unit Segment BGM | Min 1 | Max 1'
RFF+ACW:0003'                      the message the error belongs to
UNT+12+0001'
UNZ+1+ACKREF2'
```

The interchange sender and recipient are swapped from the inbound `UNB`: the receiver of the orders
is the issuer of the acknowledgement.

## Notes on the error codes

EDIFACT does not publish a code list for `ERC` application error codes — they are agreed between the
trading partners. The example therefore sends the code with `ZZZ` (mutually defined) as the code list
responsible agency, and puts the reason in the following `FTX`. Replace the code with whatever the
partner agreement specifies.

The parse error is written as free text, so the integration collapses its line breaks, drops the
characters EDIFACT reserves as delimiters, and truncates it to the component length before sending.
