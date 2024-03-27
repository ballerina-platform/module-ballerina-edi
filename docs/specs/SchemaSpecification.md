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

The `name` field specifies the name of the EDI schema.

### 2. Delimiters

The `delimiters` field defines the delimiters used in the EDI data. It includes the following subfields:
   - **segment:** The delimiter used to separate segments.
   - **field:** The delimiter used to separate fields within a segment.
   - **component:** The delimiter used to separate components within a field.
   - **repetition:** The delimiter used to indicate repetition of a field or component.
   - **escapeCharacter:** The escape/release character used to treat delimiters as literals instead.

**Example:**
```json
"delimiters": {
    "segment": "~",
    "field": "*",
    "component": ":",
    "repetition": "^",
    "escapeCharacter": "?"
}
```

### 3. Segments

The `segments` field is an array of segment definitions. Each segment definition includes the following subfields:
   - **code:** The code representing the segment.
   - **tag:** A user-friendly tag or name for the segment.
   - **minOccurances:** The minimum number of times the segment must occur.
   - **maxOccurances:** The maximum number of times the segment can occur (-1 indicates unlimited occurrences).
   - **fields:** An array of field definitions within the segment.

**Example:**

```json
{
    "name": "SimpleOrder",
    "delimiters": {"segment": "~", "field": "*", "component": ":", "repetition": "^"},
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
}
```

### 4. Definition for Fields

Within the `fields` sub-definition, the `length` attribute is used to specify the length constraints for a field. This object includes parameters for fixed length, minimum length, and maximum length, offering comprehensive control over the size of the field.

- **tag:** A user-friendly tag or name for the field.
- **repeat:** Indicates whether the field can be repeated.
- **required:** Indicates whether the field is required.
- **dataType:** The data type of the field.
- **startIndex:** The starting index of the field within the segment.
- **length:** An object specifying length constraints for the field.

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
   - **preserveEmptyFields:** Indicates whether empty fields should be preserved.
   - **includeSegmentCode:** Indicates whether the segment code should be included in the Ballerina record.

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