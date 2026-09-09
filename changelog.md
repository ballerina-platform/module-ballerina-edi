# Changelog
This file contains all the notable changes done to the Ballerina EDI Module through the releases.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- [Match consecutive same-code sibling definitions that all declare discriminators as an unordered set, so discriminated segments may arrive in any order and interleave (e.g. HIPAA "any order" sub-loops, EANCOM interleaved `ALC` occurrences)](https://github.com/ballerina-platform/ballerina-library/issues/9100)
- [Add `values` and `discriminator` attributes to fields, components, and sub-components, enabling qualifier-based discrimination of segment definitions sharing a segment code (e.g. X12 834 `REF` definitions, EDIFACT `RFF`/`C506`). `values` lists the element's legal codes and is validated when writing; `discriminator` lists the codes that identify a definition and drives segment matching](https://github.com/ballerina-platform/ballerina-library/issues/9100)

### Fixed

## [1.6.0] - 2026-08-03

### Added

### Fixed

## [1.6.0]

### Added
- [Add tiered EDI envelope parsing and serialization API, with typed envelope records and a typed error hierarchy (BEP-1441)](https://github.com/ballerina-platform/ballerina-spec/issues/1441)

### Fixed
- [Fix `convertToType` corrupting numeric values when `decimalSeparator` is a regex metacharacter](https://github.com/ballerina-platform/ballerina-library/issues/8771)
- [Fix ISA02/ISA04 space-padded values incorrectly failing required field validation](https://github.com/ballerina-platform/ballerina-library/issues/8834)
- [Fix EDI parser incorrectly matches repeatable segment groups](https://github.com/ballerina-platform/ballerina-library/issues/8862)
- [Fix parsing of multiple ST/SE transaction sets within a single GS/GE functional group](https://github.com/ballerina-platform/ballerina-library/issues/8860)

## [1.5.5] - 2026-07-02

### Fixed
- [Fix EDI parser incorrectly matches repeatable segment groups](https://github.com/ballerina-platform/ballerina-library/issues/8862)
- [Fix parsing of multiple ST/SE transaction sets within a single GS/GE functional group](https://github.com/ballerina-platform/ballerina-library/issues/8860)

## [1.5.4] - 2026-06-23

### Fixed

- [Fix ISA02/ISA04 space-padded values incorrectly failing required field validation](https://github.com/ballerina-platform/ballerina-library/issues/8834)

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
