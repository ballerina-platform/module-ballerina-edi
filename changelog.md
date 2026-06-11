# Changelog
This file contains all the notable changes done to the Ballerina EDI Module through the releases.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- [Add tiered EDI envelope parsing API per BEP-1441](https://github.com/ballerina-platform/ballerina-spec/issues/1441):
  schema-free `x12HeadersFromEdiString`, `x12HeadersFromEdiFile`,
  `edifactHeadersFromEdiString`, `edifactHeadersFromEdiFile`; schema-driven
  `headersFromEdiString`, `headersFromEdiFile`, and the fail-safe
  `interchangeFromEdiString`; and the symmetric, envelope-aware writer
  `interchangeToEdiString` that serialises an `EdiInterchange` back into EDI text
  (round-trips with `interchangeFromEdiString`).
- Added X12 (`X12ISA`, `X12GS`, `X12Headers`), EDIFACT (`EdifactSyntaxIdentifier`,
  `EdifactInterchangeParty`, `EdifactDateTime`, `EdifactMessageIdentifier`,
  `EdifactUNB`, `EdifactUNH`, `EdifactHeaders`), and hierarchical
  (`EdiInterchange`, `EdiFunctionalGroup`, `EdiTransaction`) types.
- Added a structured `envelope` field to `EdiSchema` (`EdiEnvelopeSchema`)
  with separate interchange / group? / transaction levels.
- Added a typed error hierarchy under the existing `Error`:
  `InvalidEnvelopeError` (input does not conform to the expected envelope
  structure), `SchemaCompatibilityError` (schema cannot support the requested
  operation — no `envelope`, fixed-length "FL" schemas with envelope APIs,
  unresolved refs at runtime), and `SerializationError`
  (`interchangeToEdiString` refusals). All existing `returns ...|Error`
  signatures remain valid.

### Changed
- `fromEdiString` is now envelope-aware: when `schema.envelope` is set, envelope
  segments are skipped positionally (headers at the start, trailers at the end)
  and only `schema.segments` is parsed. Inputs with more than one transaction
  are rejected with `InvalidEnvelopeError` directing the caller to
  `interchangeFromEdiString`. Old schemas (no `envelope`) keep their existing
  behaviour.
- `schema_denormalizer` now resolves `ref` entries inside every envelope level
  in addition to `schema.segments`.
- `interchangeToEdiString` now recomputes envelope trailer counts
  (SE01 / GE01 / IEA01 / UNT01 / UNZ01) from the content being written and
  mirrors trailer control references from the corresponding headers
  (IEA02=ISA13, GE02=GS06, SE02=ST02, UNT02=UNH 0062, UNZ02=UNB 0020), so
  mutated interchanges serialise with correct counts.
- Envelope-aware APIs treat envelope header/trailer segments as mandatory
  regardless of the schema's declared `minOccurances` — garbage input fails
  fast with `InvalidEnvelopeError` instead of returning empty header sections.
- Envelope-aware APIs reject fixed-length (`"field": "FL"`) schemas with
  `SchemaCompatibilityError`.
- Schema-driven envelope APIs validate a leading EDIFACT UNA service string
  advice against the schema delimiters: a matching UNA is skipped; a
  conflicting one produces `InvalidEnvelopeError`.
- Only a single interchange per call is supported by
  `interchangeFromEdiString`: trailing content after the interchange trailer
  or a second interchange header is rejected with `InvalidEnvelopeError`.

### Fixed
- [Fix `convertToType` corrupting numeric values when `decimalSeparator` is a
  regex metacharacter (e.g. `.`)](https://github.com/ballerina-platform/ballerina-library/issues/8771).
  The replacement now uses a literal character scan (`replaceLiteral`) instead
  of `regexp:fromString`.
- `interchangeToEdiString` re-pads the X12 ISA interchange header to its
  standard fixed element widths so the emitted ISA segment is the mandatory
  106 characters (previously a trimmed, variable-width — and therefore
  non-conformant — ISA was emitted).
- `interchangeFromEdiString` locates envelope trailers by scanning backward
  (interchange trailer from the end of the input; group / transaction trailers
  from the next same-level header), so stray trailer-coded junk inside a
  corrupted transaction body no longer aborts the parse — it stays inside that
  body and is captured as the per-transaction error.
- Schema-free EDIFACT header parsing is now release-character aware: escaped
  delimiters (`?+`, `?:`, `?'`, `??`) inside UNB/UNH values are treated as data
  and un-escaped in the returned values.
- `x12HeadersFromEdiString` validates the ISA strictly against the standard
  fixed element widths and rejects non-conformant (e.g. unpadded) ISA segments
  instead of part-parsing them and silently missing the GS.
- Component (and subcomponent) parsing no longer panics with IndexOutOfRange
  when the input carries more components than the schema declares — a proper
  `Error` describing the overflow is returned.
- `headersFromEdiFile` now actually detects header sections exceeding the
  4096-character read window and returns an `InvalidEnvelopeError` mentioning
  the window size, matching its documentation.
- A leading byte-order mark (U+FEFF) is stripped by the envelope-aware string
  and file entry points instead of failing with a misleading
  "does not start with ..." error.

## [1.5.3] 

### Changed
- [Fix InvalidUpdate Error for processing schemas with refs](https://github.com/ballerina-platform/ballerina-library/issues/7931)

## [1.5.2]

### Changed
- [Fix InvalidUpdate Error for processing schemas with refs](https://github.com/ballerina-platform/ballerina-library/issues/8096)

##

### Added
- [Add support for field length constraints (min/max)](https://github.com/ballerina-platform/ballerina-library/issues/5896).
- [Updated dependencies to use lang.regex instead of ballerina/regex](https://github.com/ballerina-platform/ballerina-library/issues/5941)