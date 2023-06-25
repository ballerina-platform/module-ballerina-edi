## Module Overview

EDI module provides functionality to convert EDI text to json and json to EDI text. Schema of EDI files have to be provided in json format.

## Compatibility

|                                   | Version               |
|:---------------------------------:|:---------------------:|
| Ballerina Language                | 2201.5.0              |
| Java Development Kit (JDK)        | 17                    |

## Example

A simple EDI schema is shown below (let's assume that this is saved in edi-schema1.json file):

````json
{
    "name": "SimpleOrder",
    "delimiters" : {"segment" : "~", "field" : "*"},
    "segments" : {
        "HDR": {
            "tag" : "header",
            "fields" : [{"tag" : "code"}, {"tag" : "orderId"}, {"tag" : "organization"}, {"tag" : "date"}]
        },
        "ITM": {
            "tag" : "items",
            "maxOccurances" : -1,
            "fields" : [{"tag" : "code"}, {"tag" : "item"}, {"tag" : "quantity", "dataType" : "int"}]
        }
    }
}
````

Above schema can be used to parse EDI documents with one HDR segment (mapped to "header") and any number of ITM segments (mapped to "items"). HDR segment contains three fields, which are mapped to "orderId", "organization" and "date". Each ITM segment contains two fields mapped to "item" and "quantity". Below is a sample EDI document that can be parsed using the above schema (let's assume that below EDI is saved in edi-sample1.edi file):

````edi
HDR*ORDER_1201*ABC_Store*2008-01-01~
ITM*A-250*12
ITM*A-45*100
ITM*D-10*58
ITM*K-80*250
ITM*T-46*28
````

### Reading EDI files

Below code reads the edi-sample1.edi into a json variable named "orderData".

````ballerina
import ballerina/io;
import balarina/edi;

public function main() returns error? {
    edi:EdiSchema schema = check edi:getSchema(check io:fileReadJson("resources/edi-schema1.json"));
    string ediText = check io:fileReadString("resources/edi-sample1.edi");
    json orderData = check edi:fromEdiString(ediText, schema);
    io:println(orderData.toJsonString());
}
````
"orderData" json variable value will be as follows (i.e. output of io:println(orderData.toJsonString())):

````json
{
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
      "item": "A-45",
      "quantity": 100
    },
    {
      "code": "ITM",
      "item": "D-10",
      "quantity": 58
    },
    {
      "code": "ITM",
      "item": "K-80",
      "quantity": 250
    },
    {
      "code": "ITM",
      "item": "T-46",
      "quantity": 28
    }
  ]
}
````

### Writing EDI files

Ballerina EDI module can also convert JSON data into EDI texts, based on a given schema. Below code demonstrates the conversion of a json data to EDI text based on the schema used in the above example:

````ballerina
import ballerina/io;
import balarinax/edi;

public function main() returns error? {
    json order2 = {...};
    edi:EdiSchema schema = check edi:getSchema(check io:fileReadJson("resources/edi-schema1.json"));
    string orderEDI = check edi:toEdiString(order2, schema);
    io:println(orderEDI);
}
````