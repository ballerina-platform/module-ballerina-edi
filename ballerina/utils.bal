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

isolated function convertToType(string value, EdiDataType dataType, string? decimalSeparator, boolean isIsa02orIsa04Field = false) returns SimpleType|error {
    string v = isIsa02orIsa04Field ? value : value.trim();
    match dataType {
        STRING => {
            return v;
        }
        INT|FLOAT => {
            if decimalSeparator != () && decimalSeparator != "." {
                // The configured decimal separator is replaced via a literal
                // character scan rather than `regexp:fromString`. Separators may
                // be regex metacharacters (e.g. ".", "^", "]", "\\", "-") and any
                // form of regex compilation would silently corrupt the value.
                // Fixes ballerina-platform/ballerina-library#8771.
                v = replaceLiteral(v, decimalSeparator, ".");
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

// Replaces every occurrence of `target` in `text` with `replacement` using a
// straight character scan. Used in places where the search string may contain
// regex metacharacters and a regex-based replacement would have to escape them.
isolated function replaceLiteral(string text, string target, string replacement) returns string {
    if target.length() == 0 {
        return text;
    }
    // Accumulate slices and join once — repeated `+=` concatenation is
    // quadratic on long values.
    string[] parts = [];
    int targetLen = target.length();
    int sliceStart = 0;
    int i = 0;
    while i + targetLen <= text.length() {
        if text.substring(i, i + targetLen) == target {
            parts.push(text.substring(sliceStart, i));
            parts.push(replacement);
            i += targetLen;
            sliceStart = i;
        } else {
            i += 1;
        }
    }
    parts.push(text.substring(sliceStart));
    return string:'join("", ...parts);
}

// Splits a string by a single-character delimiter without regex. Avoids the
// overhead and escape issues of regex-based split when the delimiter could be
// a regex metacharacter.
isolated function splitByDelimiter(string text, string delimiter) returns string[] {
    string[] parts = [];
    int startIdx = 0;
    int i = 0;
    while i < text.length() {
        if text.substring(i, i + 1) == delimiter {
            parts.push(text.substring(startIdx, i));
            startIdx = i + 1;
        }
        i += 1;
    }
    parts.push(text.substring(startIdx));
    return parts;
}

// Returns the index of the first unescaped occurrence of `terminator` in `text`,
// or `text.length()` if none is found. Characters preceded by `release` are
// treated as escaped and skipped — used for EDIFACT, where the release character
// (default `?`, or position 6 of UNA when present) escapes embedded delimiters
// and segment terminators.
isolated function indexOfUnescaped(string text, string terminator, string release) returns int {
    int i = 0;
    while i < text.length() {
        string ch = text.substring(i, i + 1);
        if ch == release && i + 1 < text.length() {
            i += 2;
            continue;
        }
        if ch == terminator {
            return i;
        }
        i += 1;
    }
    return text.length();
}

// Strips a single leading byte-order mark (U+FEFF) from the given text. Files
// produced by some Windows tools are BOM-prefixed, which would otherwise make
// envelope detection fail with a misleading "does not start with ..." error.
isolated function stripBom(string text) returns string {
    return text.startsWith("\u{FEFF}") ? text.substring(1) : text;
}

// Splits a string by a single-character delimiter, treating characters preceded
// by the release character as escaped (EDIFACT release semantics, default `?`).
// The returned parts still contain the release sequences — call
// `unescapeReleased` on each part before using the values.
isolated function splitUnescaped(string text, string delimiter, string release) returns string[] {
    string[] parts = [];
    int startIdx = 0;
    int i = 0;
    while i < text.length() {
        string ch = text.substring(i, i + 1);
        if ch == release && i + 1 < text.length() {
            i += 2;
            continue;
        }
        if ch == delimiter {
            parts.push(text.substring(startIdx, i));
            startIdx = i + 1;
        }
        i += 1;
    }
    parts.push(text.substring(startIdx));
    return parts;
}

// Un-escapes EDIFACT release sequences: each occurrence of the release
// character causes the following character to be taken literally
// (`?+` -> `+`, `?:` -> `:`, `?'` -> `'`, `??` -> `?`).
isolated function unescapeReleased(string text, string release) returns string {
    // Accumulate slices and join once — repeated `+=` concatenation is
    // quadratic on long segments.
    string[] parts = [];
    int sliceStart = 0;
    int i = 0;
    while i < text.length() {
        if text.substring(i, i + 1) == release && i + 1 < text.length() {
            parts.push(text.substring(sliceStart, i));
            parts.push(text.substring(i + 1, i + 2));
            i += 2;
            sliceStart = i;
        } else {
            i += 1;
        }
    }
    parts.push(text.substring(sliceStart));
    return string:'join("", ...parts);
}

// Returns the leading segment code from a segment string — the substring up to
// the first occurrence of the field delimiter. Used to compare segment codes
// exactly so that body codes sharing a prefix with envelope codes
// (e.g. "SEG*..." vs trailer "SE") do not match.
isolated function getSegmentCode(string segText, string fieldDelim) returns string {
    int? delimPos = segText.indexOf(fieldDelim);
    return delimPos is int ? segText.substring(0, delimPos) : segText;
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
    string sgcode = "[Tag: " + sgmap.tag + "] ";
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
