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
import ballerina/log;

isolated function readSegment(EdiSegSchema segMapping, string[] fields, EdiSchema schema, string segmentDesc)
    returns EdiSegment|Error {
    log:printDebug(string `Reading ${printSegMap(segMapping)} | Seg text: ${segmentDesc}`);
    if segMapping.truncatable {
        int minFields = getMinimumFields(segMapping);
        if fields.length() < minFields + 1 {
            return error Error(string `Segment schema's field count does not match minimum field count of the truncatable segment.
                Segment: ${fields[0]}, Required minimum field count (excluding the segment code): ${minFields}. Available fields: ${fields.length() - 1}, 
                Segment mapping: ${segMapping.toJsonString()} | Segment text: ${segmentDesc}`);
        }
    } else if segMapping.fields.length() != fields.length() {
        return error Error(string `Segment schema's field count does not match with the input segment.
                Segment: ${fields[0]}, Segment schema: ${segMapping.toJsonString()}, Input segment: ${segmentDesc}`);
    }
    EdiSegment segment = {};
    int fieldNumber = schema.includeSegmentCode ? 0 : 1;
    // while fieldNumber < fields.length() - 1 {
    while fieldNumber < fields.length() {
        if fieldNumber >= segMapping.fields.length() {
            return error Error(string `Segment in the input message containes more fields than the segment schema.
            Input segment: ${fields.toJsonString()},
            Segment schema: ${segMapping.toJsonString()}`);
        }
        EdiFieldSchema fieldMapping = segMapping.fields[fieldNumber];
        string tag = fieldMapping.tag;

        // EDI segment starts with the segment name. So we have to skip the first field.
        // string fieldText = fields[fieldNumber + 1];
        string fieldText = fields[fieldNumber];
        if fieldText.trim().length() == 0 {
            if fieldMapping.required {
                return error Error(string `Required field is not provided. Field: ${fieldMapping.tag}, Segment: ${segMapping.code}`);
            } else {
                if schema.preserveEmptyFields {
                    if fieldMapping.repeat {
                        segment[tag] = getArray(fieldMapping.dataType);
                    } else if fieldMapping.dataType == STRING {
                        segment[tag] = fieldText.trim();
                    } else {
                        segment[tag] = ();
                    }
                }
                fieldNumber = fieldNumber + 1;
                continue;
            }
        }
        if fieldMapping.length is Range {
            Range lenConstraints = <Range>fieldMapping.length;
            if fieldText.length() > lenConstraints.max && lenConstraints.max != -1 {
                return error Error(string `Input field length exceeds the maximum length specified in the segment schema.
                        Input field: ${fieldText}, Max length: ${lenConstraints.max},
                        Segment schema: ${segMapping.toJsonString()}, Segment text: ${segmentDesc}`);
            }
            if fieldText.length() < lenConstraints.min {
                return error Error(string `Input field length is less than the minimum length specified in the segment schema.
                        Input field: ${fieldText}, Min length: ${lenConstraints.min},
                        Segment schema: ${segMapping.toJsonString()}, Segment text: ${segmentDesc}`);
            }
        }
        if fieldMapping.repeat {
            // this is a repeating field (i.e. array). can be a repeat of composites as well.
            SimpleArray|EdiComponentGroup[] repeatValues = check readRepetition(fieldText, schema.delimiters.repetition, schema, fieldMapping);
            if repeatValues.length() > 0 || schema.preserveEmptyFields {
                segment[tag] = repeatValues;
            }
        } else if fieldMapping.components.length() > 0 {
            // this is a composite field (but not a repeat)
            EdiComponentGroup? composite = check readComponentGroup(fieldText, schema, fieldMapping);
            if composite is EdiComponentGroup || schema.preserveEmptyFields {
                segment[tag] = composite;
            }
        } else {
            // this is a simple type field
            SimpleType|error value = convertToType(fieldText, fieldMapping.dataType, schema.delimiters.decimalSeparator);
            if value is error {
                return error Error(string `Input field cannot be converted to the type specified in the segment schema.
                        Input field: ${fieldText}, Schema type: ${fieldMapping.dataType},
                        Segment schema: ${segMapping.toJsonString()}, Segment text: ${segmentDesc}, Error: ${value.message()}`);
            }
            segment[tag] = value;
        }
        fieldNumber = fieldNumber + 1;
    }
    return segment;
}
