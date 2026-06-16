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

The typed `orders` module under `modules/orders` was generated from `schemas/ORDERS.json` with
`edi-tools`. See the [Build a Custom EDI Schema and Parser](../custom-edi-schema) example for how
that schema and module are produced.

## Prerequisites

1. **Ballerina** — Swan Lake (2201.12.0 or later).
2. **Kafka broker** — start a local single-node broker with the bundled compose file:

   ```bash
   docker compose up -d
   ```

## Run the example

```bash
bal run
```

The service starts watching `./sample-data`. Two sample files are provided:

- `order1.edi` — a single, well-formed purchase order.
- `order-batch.edi` — two messages where the second is missing its mandatory `BGM` segment.

## Testing

With the service running, (re-)drop a file into the inbox to trigger processing:

```bash
cp sample-data/order-batch.edi "sample-data/incoming-$(date +%s).edi"
```

Expected logs — the valid order is published, the malformed one is quarantined, and the batch is not
aborted:

```text
Parsed interchange file=./sample-data/incoming.edi partner=SUPERMART transactions=2
Published order orderId=PO20001 partner=SUPERMART topic=edi.orders
Quarantining malformed transaction error=...
```

Consume the published orders to verify the payloads:

```bash
docker exec edi-kafka /opt/kafka/bin/kafka-console-consumer.sh \
    --bootstrap-server localhost:9092 --topic edi.orders --from-beginning
```

## Configuration

Override defaults in a `Config.toml` if needed:

```toml
inboxPath = "./sample-data"
kafkaBootstrap = "localhost:9092"
ordersTopic = "edi.orders"
quarantineTopic = "edi.orders.quarantine"
```
