# Changelog
This file contains all the notable changes done to the Ballerina EDI Module through the releases.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- [Add tiered EDI envelope parsing and serialization API, with typed envelope records and a typed error hierarchy (BEP-1441)](https://github.com/ballerina-platform/ballerina-spec/issues/1441)

### Fixed
- [Fix `convertToType` corrupting numeric values when `decimalSeparator` is a regex metacharacter](https://github.com/ballerina-platform/ballerina-library/issues/8771)
- [Fix ISA02/ISA04 space-padded values incorrectly failing required field validation](https://github.com/ballerina-platform/ballerina-library/issues/8834)

## [1.5.4]

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
