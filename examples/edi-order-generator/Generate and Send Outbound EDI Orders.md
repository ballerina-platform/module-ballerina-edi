# Generate and Send Outbound EDI Orders

This example builds an EDIFACT D03A `ORDERS` interchange from application data, serialises it to
conforming EDI text, and delivers it to a supplier's SFTP drop. It is the outbound counterpart to
[Parse EDI Documents and Publish to Kafka](../edi-parser-to-kafka).

## Overview

A buyer application produces purchase orders as Ballerina records. The `interchangeToEdiString`
function — the inverse of `interchangeFromEdiString` — writes the full envelope (UNB/UNH headers and
UNT/UNZ trailers) together with each transaction body.

On write, the module keeps the output conformant automatically:

- the envelope segments are emitted from the typed `ORDERSInterchange`, and
- the **UNT and UNZ trailer counts are recomputed** from the content being written, so you can add or
  remove transactions and line items freely without maintaining segment counts by hand.

A parse → serialise round-trip is structurally symmetric: the generated text re-parses cleanly
through `interchangeFromEdiString`. A transaction whose `body` is an `error` cannot be serialised and
raises `edi:SerializationError` — filter or replace such transactions before writing.

The typed `orders` module under `modules/orders` was generated from `schemas/ORDERS.json` with
`edi-tools`. See [Build a Custom EDI Schema and Parser](../custom-edi-schema) for how it is produced.

## Prerequisites

1. **Ballerina** — Swan Lake (2201.12.0 or later).
2. **SFTP server** *(optional)* — only needed for the delivery step:

   ```bash
   docker compose up -d
   ```

   Without it, generation, round-trip, and the serialization-error demo still run; delivery is
   skipped with a warning.

## Run the example

```bash
bal run
```

Expected output — note `UNT+11` is computed by the module, not supplied by the program:

```text
Generated EDI:
UNB+UNOA:3+BUYER123:14+ACME:14+260615:1200+REF1++++ORDERS'UNH+0001+ORDERS:D:03A:UN'BGM+220+PO20260615+9'...UNS+S'UNT+11+0001'UNZ+1+REF1'

Delivered EDI to supplier path=/edi/outbound/PO20260615.edi
Round-trip OK. Transactions: 1
Refused to serialise transaction with an error body: Cannot serialise transaction with error body: ...
```

## Configuration

Override defaults in a `Config.toml` if needed:

```toml
sftpHost = "localhost"
sftpPort = 2222
sftpUser = "wso2"
sftpPassword = "wso2123"
outboundPath = "/edi/outbound"
```
