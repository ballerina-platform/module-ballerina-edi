## Overview

Electronic Data Interchange (EDI) is a technology designed to facilitate the electronic transfer of business documents among various organizations. This system empowers businesses to seamlessly exchange standard business transactions like purchase orders, invoices, and shipping notices. These transactions are formatted in a structured, computer-readable manner, eliminating the reliance on paper-based processes and manual data entry. Consequently, EDI technology significantly boosts efficiency and minimizes errors in the business-to-business (B2B) communication landscape.

The Ballerina EDI module offers robust functionality for the effortless conversion of EDI text to JSON, and inversely, JSON to EDI. Tailored to augment integration capabilities, this module is a key component in enhancing the handling of EDI data within Ballerina applications. It provides a more streamlined, efficient approach, ensuring seamless data management and integration in business processes.

## Define EDI Schema

Before utilizing the EDI parser, it is crucial to define the structure of the EDI data intended for import. Developers can refer the [Ballerina EDI Schema Specification](./docs/specs/SchemaSpecification.md) for guidance. This specification outlines the essential elements necessary to describe an EDI schema, covering attributes such as name, delimiters, segments, field definitions, components, sub-components, and additional configuration options.

As an illustrative example, consider the following EDI schema definition for a _simple order_, assumed to be stored as "schema.json":

```json
{
    "name": "SimpleOrder",
    "delimiters" : {"segment" : "~", "field" : "*", "component": ":", "repetition": "^"},
    "segments" : [
        {
            "code": "HDR",
            "tag" : "header",
            "minOccurances": 1,
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

This schema can be used to parse EDI documents featuring one HDR segment, mapped to _header_, and any number of ITM segments, mapped to _items_. The HDR segment incorporates three _fields_, corresponding to _orderId_, _organization_, and _date_. Each ITM segment comprises two fields, mapped to _item_ and _quantity_.

Below is an example of an EDI document that can be parsed using the aforementioned schema. Let's assume that the following EDI information is saved in a file named 'sample.edi':

```
HDR*ORDER_1201*ABC_Store*2008-01-01~
ITM*A-250*12~
ITM*A-45*100~
ITM*D-10*58~
ITM*K-80*250~
ITM*T-46*28~
```

## Reading EDI Files

The utility functions in EDI package allows you to read Electronic Data Interchange (EDI) files and convert them into JSON data. Here's a quick example demonstrating how to read an EDI file, parse it using a defined schema, and print the resulting JSON data:

```ballerina
import ballerina/io;
import ballerina/edi;

public function main() returns error? {
    // Step 1: Load EDI schema from a JSON file
    edi:EdiSchema schema = check edi:getSchema(check io:fileReadJson("resources/schema.json"));

    // Step 2: Read the EDI file as a string
    string ediText = check io:fileReadString("resources/sample.edi");

    // Step 3: Convert EDI string to JSON using the specified schema
    json orderData = check edi:fromEdiString(ediText, schema);

    // Step 4: Print the resulting JSON data
    io:println(orderData.toJsonString());
}
```

In this example, the EDI file (`sample.edi`) is read, and its content is converted into a JSON variable named `orderData`. The JSON variable structure corresponds to the expected output.

## Writing EDI Files

Furthermore, edi module provides functionality to convert JSON data into EDI text using a specified schema. The following code snippet demonstrates how to create a JSON variable representing an order and convert it into an EDI string:

```ballerina
import ballerina/io;
import ballerina/edi;

public function main() returns error? {
    // Step 1: Create a JSON variable representing an order
    json order2 = {
        "header": {
            "code": "HDR",
            "orderId": "ORDER_1201",
            "organization": "ABC_Store",
            "date": "2008-01-01"
        },
        "items": [
            {
                "code": "ITM",
                "item": "A-250",
                "quantity": 12
            },
            {
                "code": "ITM",
                "item": "B-250",
                "quantity": 10
            } // ... Additional items ...
        ]
    };

    // Step 2: Load the EDI schema from a JSON file
    edi:EdiSchema schema = check edi:getSchema(check io:fileReadJson("resources/schema.json"));

    // Step 3: Convert the JSON order data to EDI string using the schema
    string orderEDI = check edi:toEdiString(order2, schema);

    // Step 4: Print the resulting EDI string
    io:println(orderEDI);
}
```

In this example, the `order2` JSON variable is converted into an EDI string using the specified schema, and the resulting EDI string is printed. This demonstrates the capability of the Ballerina EDI module to seamlessly convert JSON data into EDI format.
