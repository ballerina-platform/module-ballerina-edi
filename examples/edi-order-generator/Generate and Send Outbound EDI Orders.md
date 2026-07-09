# Generate and Send Outbound EDI Orders

This example reads a purchase order from a database, builds an EDIFACT D03A `ORDERS` interchange from
it, serialises it to conforming EDI text, and delivers it to a supplier's SFTP drop. It is the
outbound counterpart to [Parse EDI Documents and Publish to Kafka](../edi-parser-to-kafka).

## Overview

A buyer application stores purchase orders in a relational database. For a given order, the program
queries its header and line items, maps them onto the typed `ORDERSInterchange`, and serialises with
`interchangeToEdiString` — the inverse of `interchangeFromEdiString` — which writes the full envelope
(UNB/UNH headers and UNT/UNZ trailers) together with the transaction body.

```text
postgres (orders + order_items) ──▶ buildOrder ──▶ interchangeToEdiString ──▶ sftp:/edi/outbound/<order>.edi
```

On write, the module keeps the output conformant automatically: the envelope segments are emitted
from the typed `ORDERSInterchange`, and the **UNT and UNZ trailer counts are recomputed** from the
content being written, so line items can be added or removed without maintaining segment counts by
hand.

## Project layout

This example is a Ballerina **workspace** with two packages:

- `edi_parser` — the typed `ORDERS` module (records plus `interchangeToEdiString`), generated from an
  `ORDERS` EDI schema and exposed at the package root. See
  [Build a Custom EDI Schema and Parser](../custom-edi-schema) for how it is produced.
- `edi_order_generator` — the program that queries the database, builds the interchange, and delivers
  the EDI.

```text
edi-order-generator/
├── edi_order_generator/   # the generator program
├── edi_parser/            # generated typed ORDERS module
└── resources/             # docker-compose.yml (Postgres + SFTP) + init.sql
```

## Prerequisites

1. **Ballerina** — Swan Lake (2201.12.0 or later).
2. **Postgres + SFTP** — start both with the bundled compose file. Postgres is seeded from `init.sql`
   with one order (`PO20260615`) and two line items:

   ```bash
   docker compose -f resources/docker-compose.yml up -d
   ```

## Run the example

```bash
cd edi_order_generator
bal run
```

The program reads the order configured by `orderId` (default `PO20260615`) and delivers it. Expected
output:

```text
Delivered EDI to supplier file=PO20260615.edi items=2
```

The delivered `/edi/outbound/PO20260615.edi` — note `UNT+11` is computed by the module, not supplied
by the program:

```text
UNB+UNOA:3+BUYER123:14+ACME:14+260615:1200+REF1'
UNH+0001+ORDERS:D:03A:UN'
BGM+220+PO20260615+9'
...
UNS+S'UNT+11+0001'UNZ+1+REF1'
```

## Configuration

`sftpUser` and `sftpPassword` are required, so create an `edi_order_generator/Config.toml`. Other
values default to the compose setup:

```toml
sftpHost = "localhost"
sftpPort = 2222
sftpUser = "wso2"
sftpPassword = "wso2123"
outboundPath = "/edi/outbound"

dbHost = "localhost"
dbPort = 5432
dbUser = "wso2"
dbPassword = "wso2123"
dbName = "edi"

orderId = "PO20260615"   # which order to pick and send
```
