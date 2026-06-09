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

### Changed
- `fromEdiString` is now envelope-aware: when `schema.envelope` is set, envelope
  segments are skipped and only `schema.segments` is parsed. Old schemas (no
  `envelope`) keep their existing behaviour.
- `schema_denormalizer` now resolves `ref` entries inside every envelope level
  in addition to `schema.segments`.
- [Fix `convertToType` corrupting numeric values when `decimalSeparator` is a
  regex metacharacter (e.g. `.`)](https://github.com/ballerina-platform/ballerina-library/issues/8771).
  The replacement now uses a literal character scan (`replaceLiteral`) instead
  of `regexp:fromString`.

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