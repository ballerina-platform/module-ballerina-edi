# Ballerina EDI Schema Specification

## Introduction
Ballerina facilitates seamless handling of EDI (Electronic Data Interchange) data by converting it into Ballerina records. To define the structure of EDI data, developers can utilize the Ballerina EDI Schema Specification. This specification outlines the essential elements needed to describe an EDI schema, including the name, delimiters, segments, field definitions, components, subcomponents, and additional configuration options.

## Understanding Structure of EDI

Electronic Data Interchange (EDI) is a standardized format for exchanging business data between different computer systems. An EDI file is organized into `segments`, where each `segment` represents a logical grouping of related data elements that convey specific information. Each segment is identified by a unique `code`, and it contains `fields` that hold the actual data. For example, in a _purchase order_, you might have segments for the _header_, _items_, and _summary_.. Further, fields may contain `components`, and components may have `sub-components`, forming a hierarchical structure.

```
EDI File
├── Segment1 (Header)
│   ├── Field1 (Code)
│   ├── Field2 (OrderId)
│   ├── Field3 (Organization)
│   └── Field4 (Date)
│       ├── Component1 (Year)
│       └── Component2 (Month)
├── Segment2 (Items)
│   ├── Field1 (Code)
│   ├── Field2 (Item)
│   └── Field3 (Quantity)
│       └── Component1 (Measurement)
│           └── Sub-Component1 (Unit)
└── ...
```

This diagram illustrates the hierarchical structure of an EDI file. Segments contain fields, fields may have components, and components can have sub-components. The delimiters are characters used to separate and distinguish these different elements within the EDI file.

## Specification

### 1. Name
The `name` field specifies the name of the EDI schema. Code-generation tools use this as the main record name in the generated Ballerina code.

The optional `tag` field gives the root JSON object a different key when the schema is parsed (defaults to `Root_mapping`).

### 2. Delimiters
The `delimiters` field defines the delimiters used in the EDI data. It includes the following subfields:
   - **segment** *(required)*: The delimiter used to separate segments.
   - **field** *(required)*: The delimiter used to separate fields within a segment.
   - **component** *(required)*: The delimiter used to separate components within a field.
   - **subcomponent** *(optional)*: The delimiter used to separate sub-components within a component. Use the literal value `"NOT_USED"` (also the default) when the format does not have sub-components.
   - **repetition** *(optional)*: The delimiter used to indicate repetition of a field. Use `"NOT_USED"` (default) when the format does not use a separate repetition delimiter.
   - **decimalSeparator** *(optional)*: Character used as the decimal separator inside numeric fields, e.g. `","` for European-style numerics. The parser normalises the value to `"."` before converting to `int` / `float`. Omit (or set to `"."`) when the values already use the standard decimal point.

**Example (X12 — typical):**
```json
"delimiters": {
    "segment": "~",
    "field": "*",
    "component": ":",
    "repetition": "^"
}
```

**Example (EDIFACT — typical):**
```json
"delimiters": {
    "segment": "'",
    "field": "+",
    "component": ":",
    "decimalSeparator": "."
}
```

### 3. Segments
The `segments` field is an array of segment definitions and segment groups. Three forms are supported:

#### 3.1 Segment definition
Each segment definition includes the following subfields:
   - **code:** The code representing the segment.
   - **tag:** A user-friendly tag or name for the segment (becomes the JSON key).
   - **minOccurances:** The minimum number of times the segment must occur (default `0`).
   - **maxOccurances:** The maximum number of times the segment can occur (default `1`, `-1` indicates unlimited occurrences).
   - **truncatable:** Whether trailing empty fields can be omitted on serialization (default `true`).
   - **fields:** An array of field definitions within the segment.

#### 3.2 Segment group
Used to group related segments that repeat together (e.g. an X12 line-item loop). A segment group has:
   - **tag:** A user-friendly tag or name for the group.
   - **minOccurances** / **maxOccurances:** As above.
   - **segments:** An array of nested segments and/or further segment groups.

**Example:**
```json
{
    "tag": "lineItems",
    "minOccurances": 1,
    "maxOccurances": -1,
    "segments": [
        {"code": "LIN", "tag": "lineItem", "fields": [...]},
        {"code": "PIA", "tag": "additionalProductId", "fields": [...]}
    ]
}
```

#### 3.3 Segment reference
For schemas with many repeated segment shapes (typical of EDIFACT), define a segment once in `segmentDefinitions` (see §8) and reference it elsewhere using `ref`:

```json
{"ref": "BGM", "tag": "BeginningOfMessage", "minOccurances": 1, "maxOccurances": 1}
```

The parser expands references into full segment definitions before reading EDI text.

**Example:**
```json
"segments": [
    {
        "code": "HDR",
        "tag": "header",
        "minOccurances": 1,
        "maxOccurances": 1,
        "fields": [
            {"tag": "code", "required": true},
            {"tag": "orderId", "required": true},
            {"tag": "organization"},
            {"tag": "date"}
        ]
    },
    {
        "code": "ITM",
        "tag": "items",
        "minOccurances": 0,
        "maxOccurances": -1,
        "fields": [
            {"tag": "code", "required": true},
            {"tag": "item", "required": true},
            {"tag": "quantity", "required": true, "dataType": "int"}
        ]
    }
]
```


### 4. Definition for Fields

Within the `fields` sub-definition, the `length` attribute is used to specify the length constraints for a field. This object includes parameters for fixed length, minimum length, and maximum length, offering comprehensive control over the size of the field.

- **tag:** A user-friendly tag or name for the field.
- **repeat:** Indicates whether the field can be repeated (default `false`).
- **required:** Indicates whether the field is required (default `false`).
- **truncatable:** Whether trailing empty subfields can be omitted on serialization (default `true`).
- **dataType:** The data type of the field (default `string`).
- **startIndex:** The starting index of the field within the segment (used only for fixed-length records; default `-1` = positional parsing).
- **length:** An object specifying length constraints for the field (default `-1` = unconstrained).
- **components:** An array of component definitions when `dataType` is `composite`.

#### 4.1 Type Constraints

The `dataType` parameter accepts the following types:

- **STRING:** Denoted by the value "string," it signifies that the field should contain textual data.

- **INT:** Denoted by the value "int," it indicates that the field should contain integer numeric data.

- **FLOAT:** Denoted by the value "float," it signifies that the field should contain floating-point numeric data.

- **COMPOSITE:** Denoted by the value "composite," it represents a component group within the field. A composite field may contain multiple sub-components, providing a structured way to organize complex data.

If the `dataType` parameter is not specified, the field is assumed to be of type "string."

#### Example Usage
```json
"fields": [
    {"tag": "CustomerName", "dataType": "string", "length": 50},
    {"tag": "Quantity", "dataType": "int", "length": {"min": 1}},
    {"tag": "Price", "dataType": "float", "length": {"max": 10}},
    {"tag": "Address", "dataType": "composite", "components": [
              {
                "tag": "No",
                "required": false,
                "dataType": "string"
              },
              {
                "tag": "Street",
                "required": false,
                "dataType": "string"
              },
              {
                "tag": "City",
                "required": false,
                "dataType": "string"
              }
            ]}
]
```

#### 4.2 Length Constraints

The `length` object provides the following constraints:

- **Fixed-Length:**
  - If `fixed-length` is specified as `N` and the field's actual length is equal to `N`, Ballerina retains the field as is.
  - If the actual length is less than `N`, Ballerina pads the field with spaces until it fulfills the fixed length.
  - If the actual length exceeds `N`, an error is produced.

- **Length within a Range**
  - **Minimum Length:**
    - Specifies the minimum length of the field.
    - If the length is below the specified minimum, an error is produced.

  - **Maximum Length:**
  - Specifies the maximum length of the field.
  - If the length exceeds the specified maximum, an error is produced.

#### Example Usage
```json
"fields": [
    {"tag": "DocumentNameCode", "length": 10},
    {"tag": "DocumentNumber", "length": {"min": 1}},
    {"tag": "MessageFunction", "length": {"max": 3}},
    {"tag": "ResponseType", "length": {"min": 1, "max": 3}}
]
```

### 5. Definition for Components
For each component within a field, the following sub-definitions are provided:
   - **tag:** A user-friendly tag or name for the component.
   - **required:** Indicates whether the field is required.
   - **dataType:** The data type of the component.
#### Example Usage
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
    {
        "tag": "contact",
        "repeat": true
    }
]
```
### 6. Definition for Sub-components 
For each sub-component within a component, the following sub-definitions are provided:
   - **tag:** A user-friendly tag or name for the sub-component.
   - **required:** Indicates whether the field is required.
   - **dataType:** The data type of the sub-component.
#### Example Usage
```json        
"code": "ORG",
"tag": "organization",
"fields": [
    {"tag": "code"},{"tag": "partnerCode"},{"tag": "name"},{"tag": "contact",
        "components": [
            {"tag": "mobile", "required": true},
            {"tag": "fixedLine"},
            {"tag": "address", "subcomponents": [{"tag": "streetAddress"},{"tag": "city"},{"tag": "country"}]
            }
        ]
    }
]
```
### 7. Additional Configuration (Optional)
   - **ignoreSegments:** An array of segments to be ignored during processing.
   - **preserveEmptyFields:** Indicates whether empty fields should be preserved (default `true`). When `false`, fields/components/sub-components with empty values are omitted from the output JSON.
   - **includeSegmentCode:** Indicates whether the segment code should be included in the Ballerina record (default `true`).
   - **headerSegments:** An array of envelope-header segment definitions parsed before the message body. Same shape as `segments`. Used by `headersFromEdiString` and `envelopeFromEdiString` to demarcate the envelope. Defaults to `[]`.
   - **trailerSegments:** An array of envelope-trailer segment definitions parsed after the message body. Same shape as `segments`. Used by `envelopeFromEdiString` to terminate the body. Defaults to `[]`.

### 8. Segment Definitions (Optional)
The `segmentDefinitions` field is a map of segment definitions keyed by segment code. It lets you define a segment shape once and reference it from multiple places via the [`ref` form](#33-segment-reference) of a segment entry. EDIFACT schemas generated by `convertEdifactSchema` use this pattern heavily — each EDIFACT segment (BGM, DTM, NAD, …) is declared once in `segmentDefinitions` and referenced from `segments` / `headerSegments` / `trailerSegments` as needed.

**Example:**
```json
{
    "segments": [
        {"ref": "BGM", "tag": "BeginningOfMessage", "minOccurances": 1, "maxOccurances": 1},
        {"ref": "DTM", "tag": "DateTime", "minOccurances": 0, "maxOccurances": -1}
    ],
    "segmentDefinitions": {
        "BGM": {
            "code": "BGM",
            "tag": "BGM",
            "fields": [
                {"tag": "code"},
                {"tag": "documentNameCode"},
                {"tag": "documentNumber"}
            ]
        },
        "DTM": {
            "code": "DTM",
            "tag": "DTM",
            "fields": [
                {"tag": "code"},
                {"tag": "dateTimePeriod", "dataType": "composite", "components": [
                    {"tag": "qualifier"},
                    {"tag": "value"},
                    {"tag": "format"}
                ]}
            ]
        }
    }
}
```

**Example (with envelope):**
```json
{
    "name": "ORDERS_Envelope",
    "delimiters": {"segment": "'", "field": "+", "component": ":", "decimalSeparator": "."},
    "headerSegments": [
        {
            "code": "UNH",
            "tag": "MessageHeader",
            "minOccurances": 1,
            "maxOccurances": 1,
            "fields": [
                {"tag": "code", "dataType": "string"},
                {"tag": "messageRef", "dataType": "string"}
            ]
        }
    ],
    "segments": [
        {"code": "BGM", "tag": "BeginningOfMessage", "minOccurances": 1, "maxOccurances": 1, "fields": [{"tag": "code"}, {"tag": "documentNumber"}]}
    ],
    "trailerSegments": [
        {
            "code": "UNT",
            "tag": "MessageTrailer",
            "minOccurances": 1,
            "maxOccurances": 1,
            "fields": [
                {"tag": "code", "dataType": "string"},
                {"tag": "segmentCount", "dataType": "int"},
                {"tag": "messageRef", "dataType": "string"}
            ]
        }
    ]
}
```

#### Example Usage
```json
{
    "name": "SimpleOrder",
    "delimiters" : {"segment" : "~", "field" : "*", "component": ":", "repetition": "^"},
    "ignoreSegments": ["UNA", "IGN", "UNZ"],
    "preserveEmptyFields": true,
    "includeSegmentCode": true,
    "segments" : [
        {
            "code": "HDR",
            "tag" : "header",
            "fields" : [{"tag": "code"}, {"tag" : "orderId"}, {"tag" : "organization"}, {"tag" : "date"}]
        },
        {
            "code": "ITM",
            "tag" : "items",
            "maxOccurances" : -1,
            "fields" : [{"tag": "code"}, {"tag" : "item"}, {"tag" : "quantity", "dataType" : "int"}]
        }
    ]
}
```