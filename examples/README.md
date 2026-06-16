# Examples

The `ballerina/edi` module provides practical examples illustrating end-to-end EDI integration
scenarios built on the envelope-aware API — schema-free header inspection, fail-safe interchange
parsing, and conformant serialization.

1. [Build a Custom EDI Schema and Parser](custom-edi-schema) — Start from a standard EDIFACT message,
   customise the schema for a trading partner's deviations, and generate a typed Ballerina parser with
   `edi-tools`. The other examples reuse a module produced this way.

2. [Parse EDI Documents and Publish to Kafka](edi-parser-to-kafka) — Watch an inbox for incoming EDI
   files, parse each interchange with `interchangeFromEdiString`, and publish every order to a Kafka
   topic. Parsing is fail-safe per transaction: malformed messages are quarantined while the rest of
   the batch is published.

3. [Route EDI Files by Trading Partner](edi-vendor-router) — Move incoming EDI files from an SFTP inbox
   to partner-specific folders using only the envelope headers (`x12HeadersFromEdiString` /
   `edifactHeadersFromEdiString`) — no schema and no body parse required.

4. [Generate and Send Outbound EDI Orders](edi-order-generator) — Build an interchange from application
   data, serialise it with `interchangeToEdiString` (envelope and trailer counts recomputed
   automatically), and deliver it to a supplier's SFTP drop.

## Prerequisites

Each example includes detailed steps in its own page. Some examples use Kafka or SFTP; a
`docker-compose.yml` is provided to start the required service locally.

> These examples target `ballerina/edi` 1.6.0 and `edi-tools` 2.2.0. Until that release is published to
> Ballerina Central, the dependency is resolved from the local repository (`repository = "local"` in
> each `Ballerina.toml`); `build.sh` packs and pushes the in-repo module before building the examples.

## Running an Example

* To build an example:

    ```bash
    bal build
    ```

* To run an example:

    ```bash
    bal run
    ```

## Building all the Examples with the Local Module

Execute the following commands to build (or run) every example against the local `ballerina/edi`
build:

* To build all the examples:

    ```bash
    ./build.sh build
    ```

* To run all the examples:

    ```bash
    ./build.sh run
    ```
