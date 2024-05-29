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

type SegmentGroupContext record {|
    int schemaIndex = 0;
    EdiSegmentGroup segmentGroup = {};
    EdiUnitSchema[] unitSchemas;
|};

isolated function readSegmentGroup(EdiUnitSchema[] currentUnitSchema, EdiContext context, boolean rootGroup) returns EdiSegmentGroup|Error {
    SegmentGroupContext sgContext = {unitSchemas: currentUnitSchema};
    EdiSchema ediSchema = context.schema;
    while sgContext.schemaIndex < sgContext.unitSchemas.length() && context.rawIndex < context.ediText.length() {
        EdiUnitSchema? segSchema = currentUnitSchema[sgContext.schemaIndex];
        if segSchema is () {
            return error Error("Segment schema cannot be empty.");
        }
        string segmentDesc = removeLineBreaks(context.ediText[context.rawIndex]);
        // There can be segments that do not follow standard EDI format (e.g. EDIFACT UNA segment).
        // Therefore, it is necessary to check and skip ignore segments before spliting into fields.
        boolean ignoreCurrentSegment = false;
        foreach string ignoreSegment in ediSchema.ignoreSegments {
            if segmentDesc.startsWith(ignoreSegment) {
                ignoreCurrentSegment = true;
                break;
            }
        }
        if ignoreCurrentSegment {
            context.rawIndex += 1;
            continue;
        }
        string[] fields = check splitFields(segmentDesc, ediSchema.delimiters.'field, segSchema, ediSchema.delimiters.escapeCharacter);
        if segSchema is EdiSegSchema {
            log:printDebug(string `Trying to match with segment mapping ${printSegMap(segSchema)}`);
            if segSchema.code != fields[0].trim() {
                check ignoreSchema(segSchema, sgContext, context);
                continue;
            }
            EdiSegment ediRecord = check readSegment(segSchema, fields, ediSchema, segmentDesc);
            check placeEDISegment(ediRecord, segSchema, sgContext, context);
            context.rawIndex += 1;
            continue;

        } else if segSchema is EdiSegGroupSchema {
            log:printDebug(string `Trying to match with segment group mapping ${printSegGroupMap(segSchema)}`);
            EdiUnitSchema firstSegSchema = segSchema.segments[0];
            if firstSegSchema is EdiUnitRef {
                return error Error("First item of segment group must be a segment. " +
                    "Segment references are not supported at runtime. Found a segment reference.\nSegment group: " + printSegGroupMap(segSchema));
            }
            if firstSegSchema is EdiSegGroupSchema {
                return error Error("First item of segment group must be a segment. Found a segment group.\nSegment group: " + printSegGroupMap(segSchema));
            }
            if firstSegSchema.code != fields[0].trim() {
                check ignoreSchema(segSchema, sgContext, context);
                continue;
            }
            EdiSegmentGroup segmentGroup = check readSegmentGroup(segSchema.segments, context, false);
            if segmentGroup.length() > 0 {
                check placeEDISegmentGroup(segmentGroup, segSchema, sgContext, context);
            }
            continue;
        }
    }
    if rootGroup && ediSchema.delimiters.'field != "FL" {
        foreach int i in context.rawIndex ... (context.ediText.length() - 1) {
            string[] unmatchedSegFields = split(context.ediText[context.rawIndex], ediSchema.delimiters.'field, ediSchema.delimiters.escapeCharacter);
            if ediSchema.ignoreSegments.indexOf(unmatchedSegFields[0], 0) == () {
                return error Error(string `Segment text does not match with the schema. 
                    Segment: ${context.ediText[context.rawIndex]}, Curren row: ${context.rawIndex}`);
            }
        }
    }
    check validateRemainingSchemas(sgContext);
    return sgContext.segmentGroup;
}

# Ignores the given segment of segment group schema if any of the below two conditions are satisfied. 
# This function will be called if a schema cannot be mapped with the next available segment text.
#
# 1. Given schema is optional
# 2. Given schema is a repeatable one and it has already occured at least once
#
# If above conditions are not met, schema cannot be ignored, and should result in an error. 
#
# + segSchema - Segment schema or segment group schema to be ignored
# + sgContext - Segment group parsing context  
# + context - EDI parsing context
# + return - Return error if the given mapping cannot be ignored
isolated function ignoreSchema(EdiUnitSchema segSchema, SegmentGroupContext sgContext, EdiContext context) returns Error? {

    if segSchema is EdiUnitRef {
        return error Error("Segment references are not supported at runtime. " +
            "Found a segment reference.\nSegment ref: " + segSchema.toString());
    }

    // If the current segment mapping is optional, we can ignore the current mapping and compare the 
    // current segment with the next mapping.
    if segSchema.minOccurances == 0 {
        log:printDebug(string `Ignoring optional segment: ${printEDIUnitMapping(segSchema)} | 
            Segment text: ${context.rawIndex < context.ediText.length() ? context.ediText[context.rawIndex] : "-- EOF --"}`);
        sgContext.schemaIndex += 1;
        return;
    }

    // If the current segment mapping represents a repeatable segment, and we have already encountered 
    // at least one such segment, we can ignore the current mapping and compare the current segment with 
    // the next mapping.
    if segSchema.maxOccurances != 1 {
        var segments = sgContext.segmentGroup[segSchema.tag];
        if segments is EdiSegment[]|EdiSegmentGroup[] {
            if segments.length() > 0 {
                // This repeatable segment has already occured at least once. So move to the next mapping.
                sgContext.schemaIndex += 1;
                log:printDebug(string `Completed reading repeatable segment: ${printEDIUnitMapping(segSchema)} | 
                    Segment text: ${context.rawIndex < context.ediText.length() ? context.ediText[context.rawIndex] : "-- EOF --"}`);
                return;
            }
        }
    }

    return error Error(string `Mandatory unit is missing in the EDI.
        Unit: ${printEDIUnitMapping(segSchema)}, Current segment text: ${context.ediText[context.rawIndex]}, 
            Current mapping index: ${sgContext.schemaIndex}`);
}

isolated function placeEDISegment(EdiSegment segment, EdiSegSchema segSchema, SegmentGroupContext sgContext, EdiContext context) returns Error? {
    if segSchema.maxOccurances == 1 {
        // Current segment has matched with the current mapping AND current segment is not repeatable.
        // So we can move to the next mapping.
        log:printDebug(string `Completed reading non-repeatable segment: ${printSegMap(segSchema)}.
            Segment text: ${context.ediText[context.rawIndex]}`);
        sgContext.schemaIndex += 1;
        sgContext.segmentGroup[segSchema.tag] = segment;
    } else {
        // Current mapping points to a repeatable segment. So we are using a EDISegment[] array to hold segments.
        // Also we can't increment the mapping index here as next segment can also match with the current mapping
        // as the segment is repeatable.
        var segments = sgContext.segmentGroup[segSchema.tag];
        if segments is EdiSegment[] {
            if (segSchema.maxOccurances != -1 && segments.length() >= segSchema.maxOccurances) {
                return error Error(string `Maximum allowed unit count of the repeatable unit is exceeded.
                Unit: ${segSchema.code}, Maximum limit: ${segSchema.maxOccurances}, Current row: ${context.rawIndex}`);
            }
            segments.push(segment);
        } else if segments is () {
            sgContext.segmentGroup[segSchema.tag] = [segment];
        } else {
            return error Error(string `Segment must be a segment array. Segment: ${segSchema.code}`);
        }
    }
}

isolated function placeEDISegmentGroup(EdiSegmentGroup segmentGroup, EdiSegGroupSchema segGroupSchema, SegmentGroupContext sgContext, EdiContext context) returns Error? {
    if segGroupSchema.maxOccurances == 1 {
        // This is a non-repeatable mapping. So we have to compare the next segment with the next mapping.
        log:printDebug(string `Completed reading non-repeating segment group ${printSegGroupMap(segGroupSchema)} | Current segment text: ${context.rawIndex < context.ediText.length() ? context.ediText[context.rawIndex] : "-- EOF --"}`);
        sgContext.schemaIndex += 1;
        sgContext.segmentGroup[segGroupSchema.tag] = segmentGroup;
    } else {
        // This is a repeatable mapping. So we compare the next segment also with the current mapping.
        // i.e. we don't increment the mapping index.
        var segmentGroups = sgContext.segmentGroup[segGroupSchema.tag];
        if segmentGroups is EdiSegmentGroup[] {
            if segGroupSchema.maxOccurances != -1 && segmentGroups.length() >= segGroupSchema.maxOccurances {
                return error Error(string `Number of (multi-occurance) segment groups in the input exceeds the allowed maximum limit in the schema.
                Allowed maximum: ${segGroupSchema.maxOccurances}, Occurances: ${segmentGroups.length()}, Current row: ${context.rawIndex}, Segment group schema: ${printSegGroupMap(segGroupSchema)}`);
            }
            segmentGroups.push(segmentGroup);
        } else if segmentGroups is () {
            sgContext.segmentGroup[segGroupSchema.tag] = [segmentGroup];
        } else {
            return error Error(string `Segment group must be an array. Segment group: ${segGroupSchema.tag}`);
        }

    }
}

isolated function validateRemainingSchemas(SegmentGroupContext sgContext) returns Error? {
    if sgContext.schemaIndex < sgContext.unitSchemas.length() - 1 {
        int i = sgContext.schemaIndex + 1;
        while i < sgContext.unitSchemas.length() {
            EdiUnitSchema umap = sgContext.unitSchemas[i];
            if umap.minOccurances > 0 {
                return error Error(string `Mandatory segment/segment group is not found. Segment: ${printEDIUnitMapping(umap)}`);
            }
            i += 1;
        }
    }
}
