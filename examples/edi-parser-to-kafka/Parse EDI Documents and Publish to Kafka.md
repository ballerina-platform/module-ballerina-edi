# Parse EDI Documents and Publish to Kafka

This example watches a directory for incoming EDIFACT D03A `ORDERS` files, parses each
interchange into typed Ballerina records, and publishes every purchase order onto a Kafka
topic for downstream systems to consume.

## Overview

A trading partner drops EDI purchase orders into an inbox folder. For each file, the integration
parses the full interchange with the envelope-aware `interchangeFromEdiString` function and fans the
individual orders out to a Kafka topic, keyed by order number.

Parsing is **fail-safe per transaction**: when one message in a multi-message interchange is
malformed, only that transaction's `body` becomes an `error`. The good orders are still published,
and the bad one is routed to a quarantine topic instead of aborting the whole batch.

```text
inbox (*.edi) ──▶ interchangeFromEdiString ──┬──▶ edi.orders            (parsed order bodies)
                                             └──▶ edi.orders.quarantine (malformed transactions)
```

## Project layout

This example is a Ballerina **workspace** with two packages:

- `edi_parser` — the typed `ORDERS` module (records plus `interchangeFromEdiString` and friends),
  generated from an `ORDERS` EDI schema with the `edi` CLI and exposed at the package root so it can
  be called from the integration. See the [Build a Custom EDI Schema and Parser](../custom-edi-schema)
  example for how that module is produced.
- `edi_kafka` — the file listener + Kafka producer integration that consumes the typed module.

```text
edi-parser-to-kafka/
├── edi_kafka/          # integration (file listener → Kafka)
├── edi_parser/         # generated typed ORDERS module
└── resources/          # docker-compose.yml + sample-data/
```

## Prerequisites

1. **Ballerina** — Swan Lake (2201.13.4 or later).
2. **Kafka broker** — start a local single-node broker with the bundled compose file:

   ```bash
   docker compose -f resources/docker-compose.yml up -d
   ```

## Configuration

Create an `edi_kafka/Config.toml` with the two configurable values used by the integration:

```toml
MONITOR_PATH = "../resources/sample-data"   # directory to watch for *.edi files
BOOTSTRAP_SERVERS = "localhost:9092"        # Kafka broker
```

`BOOTSTRAP_SERVERS` is required — the integration will not start without it. The output topics
(`edi.orders` and `edi.orders.quarantine`) are fixed in the code.

## Run the example

Run from inside the `edi_kafka` package so `Config.toml` and the relative `MONITOR_PATH` resolve:

```bash
cd edi_kafka
bal run
```

The service starts watching `../resources/sample-data`. Two sample files are provided:

- `order1.edi` — a single, well-formed purchase order.
- `order-batch.edi` — two messages where the second is missing its mandatory `BGM` segment.

## Testing

The file listener fires only on files **created after** it starts, so (re-)drop a file into the inbox
to trigger processing:

```bash
cp ../resources/sample-data/order-batch.edi "../resources/sample-data/incoming-$(date +%s).edi"
```

Expected logs — the interchange is parsed, the valid order is published, and the malformed one is
quarantined without aborting the batch:

```text
level=INFO message="EDI file parsed" file=".../incoming.edi" partner="SUPERMART" trx=2
level=ERROR message="Quarantining malformed transaction" ...
```

Consume the published orders to verify the payloads:

```bash
docker exec edi-kafka /opt/kafka/bin/kafka-console-consumer.sh \
    --bootstrap-server localhost:9092 --topic edi.orders --from-beginning
```
