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

## Prerequisites

1. **Ballerina** — Swan Lake (2201.12.0 or later).
2. **SFTP server** — start one with the inbox and vendor folders pre-created:

   ```bash
   docker compose up -d
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
sftp> put sample-data/edifact-acme.edi /edi/inbox/
sftp> put sample-data/x12-sender.edi   /edi/inbox/
```

Expected logs — the EDIFACT file is routed by its UNB sender, the X12 file by its ISA06 sender:

```text
Routed EDI file sender=ACME file=edifact-acme.edi destination=/edi/vendors/acme
Routed EDI file sender=SENDER file=x12-sender.edi destination=/edi/vendors/globex
```

Confirm the files moved out of the inbox and into the vendor folders over SFTP.

## Configuration

Override defaults in a `Config.toml` if needed:

```toml
sftpHost = "localhost"
sftpPort = 2222
sftpUser = "wso2"
sftpPassword = "wso2123"
inboxPath = "/edi/inbox"
fallbackPath = "/edi/vendors/unknown"
```
