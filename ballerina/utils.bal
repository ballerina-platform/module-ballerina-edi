// Copyright (c) 2023 WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/lang.regexp;

isolated function convertToType(string value, EdiDataType dataType, string? decimalSeparator) returns SimpleType|error {
    string v = value.trim();
    match dataType {
        STRING => {
            return v;
        }
        INT|FLOAT => {
            if decimalSeparator != () {
                string:RegExp decimalSep = check regexp:fromString(decimalSeparator);
                v = decimalSep.replace(v, ".");
            }
            match dataType {
                INT => {
                    return int:fromString(v);
                }
                FLOAT => {
                    return float:fromString(v);
                }
            }
        }
    }
    return error("Undefined type for value:" + value);
}

isolated function getArray(EdiDataType dataType) returns SimpleArray|EdiComponentGroup[] {
    match dataType {
        STRING => {
            string[] values = [];
            return values;
        }
        INT => {
            int[] values = [];
            return values;
        }
        FLOAT => {
            float[] values = [];
            return values;
        }
        COMPOSITE => {
            EdiComponentGroup[] values = [];
            return values;
        }
    }
    string[] values = [];
    return values;
}

public function getDataType(string typeString) returns EdiDataType {
    match typeString {
        "string" => {
            return STRING;
        }
        "int" => {
            return INT;
        }
        "float" => {
            return FLOAT;
        }
    }
    return STRING;
}

isolated function splitFields(string segmentText, string fieldDelimiter, EdiUnitSchema unitSchema) returns string[]|Error {
    if unitSchema is EdiUnitRef {
        return error Error("Segment reference is not supported at runtime.");
    }

    if fieldDelimiter == "FL" {
        EdiSegSchema segSchema;
        if unitSchema is EdiSegSchema {
            segSchema = unitSchema;
        } else {
            EdiUnitSchema firstSegSchema = unitSchema.segments[0];
            if firstSegSchema is EdiUnitRef {
                return error Error("Segment reference is not supported at runtime.");
            }
            if firstSegSchema is EdiSegGroupSchema {
                return error Error("First item of segment group must be a segment. Found a segment group.\nSegment group: " + printSegGroupMap(unitSchema));
            }
            segSchema = firstSegSchema;
        }
        string[] fields = [];
        foreach EdiFieldSchema fieldSchema in segSchema.fields {
            int feildLength = <int>fieldSchema.length;
            if fieldSchema.startIndex < 0 || feildLength < 0 {
                return error Error(string `Start index and field length is not provided for fixed length schema field. Segment: ${segSchema.code}, Field: ${fieldSchema.tag}`);
            }
            int startIndex = fieldSchema.startIndex - 1;
            int endIndex = startIndex + feildLength;
            if startIndex >= segmentText.length() {
                break;
            }
            endIndex = segmentText.length() < endIndex ? segmentText.length() : endIndex;
            string fieldText = segmentText.substring(startIndex, endIndex);
            fields.push(fieldText);
        }
        return fields;
    } else {
        return split(segmentText, fieldDelimiter);
    }
}

isolated function split(string text, string delimiter) returns string[]|Error {
    string preparedText = prepareToSplit(text, delimiter);
    string:RegExp|error validatedDelimiter = regexp:fromString(validateDelimiter(delimiter));
    if validatedDelimiter is error {
        return error Error("Invalid delimiter: " + delimiter);
    }
    return validatedDelimiter.split(preparedText);
}

isolated function splitSegments(string text, string delimiter) returns string[]|Error {
    string:RegExp|error validatedDelimiter = regexp:fromString(validateDelimiter(delimiter));
    if validatedDelimiter is error {
        return error Error("Invalid delimiter: " + delimiter);
    }
    string[] segmentLines = validatedDelimiter.split(text);
    if segmentLines[segmentLines.length() - 1] == "" {
        string _ = segmentLines.remove(segmentLines.length() - 1);
    }
    foreach int i in 0 ... (segmentLines.length() - 1) {
        segmentLines[i] = removeLineBreaks(segmentLines[i]);
    }
    return segmentLines;
}

isolated function validateDelimiter(string delimeter) returns string {
    match delimeter {
        "*" => {
            return "[*]";
        }
        "^" => {
            return "\\^";
        }
        "+" => {
            return "\\+";
        }
        "." => {
            return "\\.";
        }
    }
    return delimeter;
}

isolated function prepareToSplit(string content, string delimeter) returns string {
    string preparedContent = content.trim();
    if content.endsWith(delimeter) {
        preparedContent = preparedContent + " ";
    }
    if content.startsWith(delimeter) {
        preparedContent = " " + preparedContent;
    }
    return preparedContent;
}

isolated function printEDIUnitMapping(EdiUnitSchema smap) returns string {
    if smap is EdiSegSchema {
        return string `Segment ${smap.code} | Min: ${smap.minOccurances} | Max: ${smap.maxOccurances} | Trunc: ${smap.truncatable}`;
    } else if smap is EdiSegGroupSchema {
        string sgcode = "";
        foreach EdiUnitSchema umap in smap.segments {
            if umap is EdiSegSchema {
                sgcode += umap.code + "-";
            } else if umap is EdiSegGroupSchema {
                sgcode += printSegGroupMap(umap);
            }
        }
        return string `[Segment group: ${sgcode} ]`;
    } else {
        return smap.toString();
    }
}

isolated function printSegMap(EdiSegSchema smap) returns string {
    return string `Segment ${smap.code} | Min: ${smap.minOccurances} | Max: ${smap.maxOccurances} | Trunc: ${smap.truncatable}`;
}

isolated function printSegGroupMap(EdiSegGroupSchema sgmap) returns string {
    string sgcode = "";
    foreach EdiUnitSchema umap in sgmap.segments {
        if umap is EdiSegSchema {
            sgcode += umap.code + "-";
        } else if umap is EdiSegGroupSchema {
            sgcode += printSegGroupMap(umap);
        }
    }
    return string `[Segment group: ${sgcode} ]`;
}

isolated function getMinimumFields(EdiSegSchema segmap) returns int {
    int fieldIndex = segmap.fields.length() - 1;
    while fieldIndex > 0 {
        if segmap.fields[fieldIndex].required {
            break;
        }
        fieldIndex -= 1;
    }
    return fieldIndex;
}

isolated function getMinimumCompositeFields(EdiFieldSchema fieldSchema) returns int {
    int fieldIndex = fieldSchema.components.length() - 1;
    while fieldIndex > 0 {
        if fieldSchema.components[fieldIndex].required {
            break;
        }
        fieldIndex -= 1;
    }
    return fieldIndex;
}

isolated function getMinimumSubcomponentFields(EdiComponentSchema componentSchema) returns int {
    int fieldIndex = componentSchema.subcomponents.length() - 1;
    while fieldIndex > 0 {
        if componentSchema.subcomponents[fieldIndex].required {
            break;
        }
        fieldIndex -= 1;
    }
    return fieldIndex;
}

isolated function serializeSimpleType(SimpleType v, EdiSchema schema, int fixedLength) returns string {
    string sv = v.toString();
    if v is float {
        if sv.endsWith(".0") {
            sv = sv.substring(0, sv.length() - 2);
        } else if schema.delimiters.decimalSeparator != "." {
            string:RegExp separator = re `\\.`;
            sv = separator.replace(sv, schema.delimiters.decimalSeparator ?: ".");
        }
    }
    return fixedLength > 0 ? addPadding(sv, fixedLength) : sv;
}

isolated function addPadding(string value, int requiredLength) returns string {
    string paddedValue = value;
    int lengthDiff = requiredLength - value.length();
    foreach int i in 1 ... lengthDiff {
        paddedValue += " ";
    }
    return paddedValue;
}

isolated function removeLineBreaks(string value) returns string {
    string:RegExp newline = re `\n`;
    return newline.replaceAll(value, "");
}