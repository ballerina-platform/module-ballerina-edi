# Route EDI Files by Trading Partner

This example watches an SFTP inbox for incoming EDI files and moves each one to a
trading-partner-specific folder — **without parsing the document body or needing a schema**.

## Overview

A single inbox receives EDI files from many trading partners in both X12 and EDIFACT formats.
Routing only needs the sender id from the interchange envelope, so the integration reads just the
header segments with the schema-free `x12HeadersFromEdiString` / `edifactHeadersFromEdiString`
functions and moves the untouched file to the folder mapped to that sender.

```text
/edi/inbox/*.edi ──▶ read envelope header (no schema) ──▶ /edi/vendors/<partner>/
```

This is the cheapest way to inspect an EDI document: you decide where a file goes before committing
to a full, schema-driven parse. For purely local files, `x12HeadersFromEdiFile` /
`edifactHeadersFromEdiFile` read only the first ~512 characters off disk.

## Project layout

```text
edi-vendor-router/
├── main.bal        # the routing service
└── resources/      # docker-compose.yml (SFTP) + sample-data/
```

## Prerequisites

1. **Ballerina** — Swan Lake (2201.13.4 or later).
2. **SFTP server** — start one with the inbox and vendor folders pre-created:

   ```bash
   docker compose -f resources/docker-compose.yml up -d
   ```

## Run the example

```bash
bal run
```

The service polls `/edi/inbox` every 5 seconds. Sender ids are mapped to folders in `vendorRoutes`;
unmatched senders fall back to `/edi/vendors/unknown`:

| Sender id (ISA06 / UNB sender) | Destination |
|--------------------------------|-------------|
| `ACME`                         | `/edi/vendors/acme`    |
| `SENDER`                       | `/edi/vendors/globex`  |
| *(anything else)*              | `/edi/vendors/unknown` |

## Testing

Upload the two sample files to the inbox:

```bash
sftp -P 2222 wso2@localhost   # password: wso2123
sftp> put resources/sample-data/edifact-acme.edi /edi/inbox/
sftp> put resources/sample-data/x12-sender.edi   /edi/inbox/
```

Expected logs — the EDIFACT file is routed by its UNB sender, the X12 file by its ISA06 sender:

```text
Routed EDI file sender=ACME file=edifact-acme.edi destination=/edi/vendors/acme
Routed EDI file sender=SENDER file=x12-sender.edi destination=/edi/vendors/globex
```

Confirm the files moved out of the inbox and into the vendor folders over SFTP.

## Configuration

`sftpUser` and `sftpPassword` are required, so create a `Config.toml` to run.
`sftpHost`/`sftpPort` default to `localhost:2222`:

```toml
sftpHost = "localhost"
sftpPort = 2222
sftpUser = "wso2"
sftpPassword = "wso2123"
```

The inbox path (`/edi/inbox`), the per-vendor routes, and the `/edi/vendors/unknown` fallback are
defined in `main.bal`.
