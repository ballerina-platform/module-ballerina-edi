# Ballerina EDI Schema Specification

## Introduction
Ballerina facilitates seamless handling of EDI (Electronic Data Interchange) data by converting it into Ballerina records. To define the structure of EDI data, developers can utilize the Ballerina EDI Schema Specification. This specification outlines the essential elements needed to describe an EDI schema, including the name, delimiters, segments, field definitions, components, sub-components, the envelope hierarchy, and additional configuration options.

## Understanding Structure of EDI

Electronic Data Interchange (EDI) is a standardized format for exchanging business data between different computer systems. An EDI file is organized into `segments`, where each `segment` represents a logical grouping of related data elements that convey specific information. Each segment is identified by a unique `code`, and it contains `fields` that hold the actual data. For example, in a _purchase order_, you might have segments for the _header_, _items_, and _summary_. Further, fields may contain `components`, and components may have `sub-components`, forming a hierarchical structure.

```text
EDI File
├── Interchange envelope (e.g. ISA / IEA, UNB / UNZ)
│   ├── Functional group (X12 only — GS / GE)
│   │   ├── Transaction (e.g. ST / SE, UNH / UNT)
│   │   │   ├── Body segment (header, items, summary…)
│   │   │   │   ├── Field
│   │   │   │   │   ├── Component
│   │   │   │   │   │   └── Sub-component
```

The body segment level (HDR / ITM / SUM in the simple example below) is what `schema.segments` describes; the surrounding interchange / group / transaction levels are described separately by `schema.envelope` (see [§7 Envelope](#7-envelope)).

## Specification

### 1. Name and root tag

- **`name`** — name of the EDI schema. Used by code generation to name the top-level Ballerina record.
- **`tag`** *(optional, default `"Root_mapping"`)* — tag for the root JSON element produced when the schema is parsed.

### 2. Delimiters

The `delimiters` field defines the delimiters used in the EDI data. It includes the following sub-fields:

- **`segment`** — separates segments (e.g. `~`, `'`, or a newline).
- **`field`** — separates fields within a segment (e.g. `*`, `+`).
- **`component`** — separates components within a field (e.g. `:`).
- **`subcomponent`** *(optional, default `"NOT_USED"`)* — separates sub-components. The sentinel `"NOT_USED"` indicates that the format does not use sub-components.
- **`repetition`** *(optional, default `"NOT_USED"`)* — separates repetitions of a field. The sentinel `"NOT_USED"` indicates that the format does not use field repetition.
- **`decimalSeparator`** *(optional, default `.`)* — character used as the decimal separator in numeric fields. EDIFACT default is `.`; some regional X12 flavours use `,`.

**Example:**
```json
"delimiters": {
    "segment": "~",
    "field": "*",
    "component": ":",
    "subcomponent": "NOT_USED",
    "repetition": "^",
    "decimalSeparator": "."
}
```

### 3. Segments

The `segments` field is an array of segment / segment-group / segment-reference entries describing the **transaction body**. Envelope segments live separately in [`envelope`](#7-envelope) and do not belong here.

#### 3.1 Segment

Each segment entry includes:

- **`code`** — segment code as it appears in the EDI text (e.g. `HDR`, `BGM`).
- **`tag`** — user-friendly tag for the segment. Becomes the JSON / record field name.
- **`minOccurances`** *(default `0`)* — minimum required occurrences.
- **`maxOccurances`** *(default `1`, `-1` = unlimited)* — maximum occurrences.
- **`truncatable`** *(default `true`)* — when `true`, trailing fields may be omitted in the input as long as all required fields up to that point are present.
- **`fields`** — array of field definitions within the segment.

**Example:**
```json
{
    "code": "HDR",
    "tag": "header",
    "minOccurances": 1,
    "maxOccurances": 1,
    "truncatable": true,
    "fields": [
        {"tag": "code", "required": true},
        {"tag": "orderId", "required": true},
        {"tag": "organization"},
        {"tag": "date"}
    ]
}
```

#### 3.2 Segment group

Segment groups bundle a header segment with subordinate segments that always appear together (a common pattern in X12 loops and EDIFACT message branches). A group is recognised by the presence of `segments` instead of `fields`:

- **`tag`** — tag for the group in the parsed output.
- **`minOccurances` / `maxOccurances`** — as for segments.
- **`segments`** — array of nested segments / segment groups / refs. The first child must be an `EdiSegSchema` (the trigger segment).

**Example (X12 dependent loop):**
```json
{
    "tag": "Loop_2000A",
    "minOccurances": 1,
    "maxOccurances": -1,
    "segments": [
        {"code": "HL", "tag": "hierarchicalLevel", "fields": [...]},
        {"code": "PRV", "tag": "providerCharacteristics", "minOccurances": 0, "fields": [...]}
    ]
}
```

#### 3.3 Segment reference

When the same segment definition is reused at multiple points in the schema, declare it once under [`segmentDefinitions`](#8-additional-configuration-optional) and refer to it by name from `segments` (or from any `envelope` level):

- **`ref`** — key into `segmentDefinitions`.
- **`tag`** *(optional)* — overrides the tag of the referenced segment when emitted into the parent.
- **`minOccurances` / `maxOccurances`** *(optional)* — override the cardinality at this site.

References are resolved by `getSchema` / `denormalizeSchema` before parsing — the runtime never sees an unresolved `ref`.

**Example:**
```json
"segmentDefinitions": {
    "DTM": {
        "code": "DTM",
        "tag": "dateTimeReference",
        "fields": [{"tag": "code"}, {"tag": "dateTime"}]
    }
},
"segments": [
    {"ref": "DTM", "minOccurances": 1, "maxOccurances": 5}
]
```

### 4. Definition for Fields

Within the `fields` sub-definition, the `length` attribute is used to specify the length constraints for a field. This object includes parameters for fixed length, minimum length, and maximum length, offering comprehensive control over the size of the field.

- **`tag`** — user-friendly tag or name for the field.
- **`repeat`** *(default `false`)* — whether the field can be repeated (uses `delimiters.repetition`).
- **`required`** *(default `false`)* — whether the field is required.
- **`truncatable`** *(default `true`)* — whether trailing components within the field may be omitted.
- **`dataType`** *(default `"string"`)* — data type of the field (`string` / `int` / `float` / `composite`).
- **`startIndex`** *(default `-1`)* — starting index of the field within the segment (fixed-width formats only).
- **`length`** *(default `-1`)* — fixed length, or a `{"min": N, "max": M}` range.
- **`components`** — array of component definitions when `dataType` is `composite`.

#### 4.1 Type constraints

The `dataType` parameter accepts the following types:

- **`string`** — textual data.
- **`int`** — integer numeric data.
- **`float`** — floating-point numeric data. Honours `delimiters.decimalSeparator`.
- **`composite`** — a component group within the field. A composite field may contain multiple sub-components.

If `dataType` is omitted, the field is assumed to be `"string"`.

**Example:**
```json
"fields": [
    {"tag": "CustomerName", "dataType": "string", "length": 50},
    {"tag": "Quantity", "dataType": "int", "length": {"min": 1}},
    {"tag": "Price", "dataType": "float", "length": {"max": 10}},
    {"tag": "Address", "dataType": "composite", "components": [
        {"tag": "No", "required": false, "dataType": "string"},
        {"tag": "Street", "required": false, "dataType": "string"},
        {"tag": "City", "required": false, "dataType": "string"}
    ]}
]
```

#### 4.2 Length Constraints

The `length` value provides the following constraints:

- **Fixed-Length** — when `length` is an integer `N`:
  - Actual length equal to `N`: kept as is.
  - Actual length less than `N`: padded with spaces.
  - Actual length greater than `N`: error.

- **Length within a Range** — when `length` is a `{"min": …, "max": …}` object:
  - Below `min` → error.
  - Above `max` → error.

**Example:**
```json
"fields": [
    {"tag": "DocumentNameCode", "length": 10},
    {"tag": "DocumentNumber", "length": {"min": 1}},
    {"tag": "MessageFunction", "length": {"max": 3}},
    {"tag": "ResponseType", "length": {"min": 1, "max": 3}}
]
```

### 5. Definition for Components

For each component within a field:

- **`tag`** — user-friendly tag for the component.
- **`required`** *(default `false`)* — whether the component is required.
- **`truncatable`** *(default `true`)* — whether trailing sub-components may be omitted.
- **`dataType`** *(default `"string"`)* — data type of the component.
- **`subcomponents`** — array of sub-component definitions.

**Example:**
```json
"code": "ORG",
"tag": "organization",
"fields": [{"tag": "code"},{"tag": "partnerCode"},{"tag": "name"},
    {
        "tag": "address",
        "components": [
            {"tag": "streetAddress"},
            {"tag": "city"},
            {"tag": "country"}
        ]
    },
    {"tag": "contact", "repeat": true}
]
```

### 6. Definition for Sub-components

For each sub-component within a component:

- **`tag`** — user-friendly tag for the sub-component.
- **`required`** *(default `false`)* — whether the sub-component is required.
- **`dataType`** *(default `"string"`)* — data type of the sub-component.

**Example:**
```json
"code": "ORG",
"tag": "organization",
"fields": [
    {"tag": "code"},{"tag": "partnerCode"},{"tag": "name"},
    {
        "tag": "contact",
        "components": [
            {"tag": "mobile", "required": true},
            {"tag": "fixedLine"},
            {"tag": "address",
                "subcomponents": [
                    {"tag": "streetAddress"},
                    {"tag": "city"},
                    {"tag": "country"}
                ]
            }
        ]
    }
]
```

### 7. Envelope

The optional `envelope` field captures the interchange / group / transaction hierarchy of the EDI document, separate from the body `segments`. When set, the envelope-aware APIs (`headersFromEdiString`, `headersFromEdiFile`, `interchangeFromEdiString`) become available, and `fromEdiString` automatically skips envelope segments and parses only the body. When omitted (older schemas), `fromEdiString` parses all `segments` as before and the envelope-aware APIs return an error directing the user to regenerate the schema.

`envelope` has three levels:

- **`interchange`** *(required)* — interchange-level segments (e.g. ISA / IEA for X12, UNB / UNZ for EDIFACT).
- **`group`** *(optional — present for X12, omitted for EDIFACT-without-UNG)* — functional group segments (GS / GE).
- **`transaction`** *(required)* — transaction- or message-level segments (ST / SE for X12, UNH / UNT for EDIFACT).

Each level has a `header` and a `trailer` array, each populated with the same kind of entries used in `segments` (segments, groups, refs).

**Example (X12 — three levels):**

```json
"envelope": {
    "interchange": {
        "header": [{"code": "ISA", "tag": "InterchangeControlHeader", "fields": [...]}],
        "trailer": [{"code": "IEA", "tag": "InterchangeControlTrailer", "fields": [...]}]
    },
    "group": {
        "header": [{"code": "GS", "tag": "FunctionalGroupHeader", "fields": [...]}],
        "trailer": [{"code": "GE", "tag": "FunctionalGroupTrailer", "fields": [...]}]
    },
    "transaction": {
        "header": [{"code": "ST", "tag": "TransactionSetHeader", "fields": [...]}],
        "trailer": [{"code": "SE", "tag": "TransactionSetTrailer", "fields": [...]}]
    }
}
```

**Example (EDIFACT without groups — two levels):**

```json
"envelope": {
    "interchange": {
        "header": [{"code": "UNB", "tag": "InterchangeHeader", "fields": [...]}],
        "trailer": [{"code": "UNZ", "tag": "InterchangeTrailer", "fields": [...]}]
    },
    "transaction": {
        "header": [{"code": "UNH", "tag": "MessageHeader", "fields": [...]}],
        "trailer": [{"code": "UNT", "tag": "MessageTrailer", "fields": [...]}]
    }
}
```

### 8. Additional Configuration (Optional)

- **`ignoreSegments`** — array of segment codes to skip during body parsing. Often used by older schemas to suppress envelope segments before the structured `envelope` field existed; new schemas typically leave this empty.
- **`preserveEmptyFields`** *(default `true`)* — when `true`, empty optional fields are emitted as empty strings / nulls / empty arrays. When `false`, empty optional fields are omitted from the output.
- **`includeSegmentCode`** *(default `true`)* — whether the segment `code` is included as a `code` field in the parsed output. Set `false` to drop redundant code fields.
- **`segmentDefinitions`** — map of reusable segment definitions keyed by name, referenced by `{"ref": "..."}` entries from `segments` or any `envelope` level. Resolved during `getSchema` / `denormalizeSchema`; never seen by the runtime parser.

**Example combining body, envelope, and reusable definitions:**

```json
{
    "name": "OrdersD03A",
    "tag": "Orders",
    "delimiters": {
        "segment": "'",
        "field": "+",
        "component": ":",
        "subcomponent": "NOT_USED",
        "repetition": "*",
        "decimalSeparator": "."
    },
    "ignoreSegments": [],
    "preserveEmptyFields": true,
    "includeSegmentCode": true,
    "envelope": {
        "interchange": {
            "header": [{"ref": "UNB"}],
            "trailer": [{"ref": "UNZ"}]
        },
        "transaction": {
            "header": [{"ref": "UNH"}],
            "trailer": [{"ref": "UNT"}]
        }
    },
    "segments": [
        {"code": "BGM", "tag": "BeginningOfMessage", "minOccurances": 1, "fields": [...]},
        {"code": "DTM", "tag": "DateTime", "maxOccurances": 5, "fields": [...]}
    ],
    "segmentDefinitions": {
        "UNB": {"code": "UNB", "tag": "InterchangeHeader", "fields": [...]},
        "UNZ": {"code": "UNZ", "tag": "InterchangeTrailer", "fields": [...]},
        "UNH": {"code": "UNH", "tag": "MessageHeader", "fields": [...]},
        "UNT": {"code": "UNT", "tag": "MessageTrailer", "fields": [...]}
    }
}
```
