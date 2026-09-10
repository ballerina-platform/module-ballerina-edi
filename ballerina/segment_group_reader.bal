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
        string[] fields = check splitFields(segmentDesc, ediSchema.delimiters.'field, segSchema);
        if segSchema is EdiSegSchema {
            int runEnd = discriminatedSiblingRunEnd(currentUnitSchema, sgContext.schemaIndex);
            if runEnd > sgContext.schemaIndex {
                // A run of consecutive same-code sibling definitions that all declare
                // discriminators is matched as an unordered set: X12 implementation guides
                // and EDIFACT MIGs allow such segments to arrive in any order (e.g. HIPAA
                // "any order" sub-loops, EANCOM interleaved ALC+A / ALC+C occurrences).
                check readDiscriminatedSiblingRun(currentUnitSchema, runEnd, sgContext, context);
                continue;
            }
            log:printDebug(string `Trying to match [Segment]: ${context.ediText[context.rawIndex]} with segment mapping ${printSegMap(segSchema)}`);
            if !segmentMatches(segSchema, fields, ediSchema) {
                check ignoreSchema(segSchema, sgContext, context);
                continue;
            }
            EdiSegment ediRecord = check readSegment(segSchema, fields, ediSchema, segmentDesc);
            check placeEDISegment(ediRecord, segSchema, sgContext, context);
            context.rawIndex += 1;
            continue;

        } else if segSchema is EdiSegGroupSchema {
            log:printDebug(string `Trying to match [Segment]: ${context.ediText[context.rawIndex]} with segment group mapping ${printSegGroupMap(segSchema)}`);

            EdiUnitSchema firstSegSchema = segSchema.segments[0];
            if firstSegSchema is EdiUnitRef {
                return error Error("First item of segment group must be a segment. " +
                    "Segment references are not supported at runtime. Found a segment reference.\nSegment group: " + printSegGroupMap(segSchema));
            }
            if firstSegSchema is EdiSegGroupSchema {
                return error Error("First item of segment group must be a segment. Found a segment group.\nSegment group: " + printSegGroupMap(segSchema));
            }
            // Before proceeding with going through the segment group, check whether the input segment matches an appropriate segment of the segment group.
            boolean firstFieldMatchesResult = firstSegmentMatches(segSchema, fields, ediSchema);
            if !firstFieldMatchesResult {
                check ignoreSchemaGroup(segSchema, sgContext, context);
                continue;
            }
            if segSchema.maxOccurances != 1 {
                EdiSegment|EdiSegment[]|EdiSegmentGroup|EdiSegmentGroup[]? existingGroups = sgContext.segmentGroup[segSchema.tag];
                if existingGroups is EdiSegmentGroup[] && existingGroups.length() > 0 {
                    if subsequentSchemaStartsWith(sgContext, fields[0].trim(), sgContext.schemaIndex + 1)
                            && !qualifierMatchesExistingOccurrence(segSchema, existingGroups[0], fields, ediSchema) {
                        check ignoreSchemaGroup(segSchema, sgContext, context);
                        continue;
                    }
                }
            }
            // This logic is very specific to X12 278 dependent loop - 2000D.
            // Made the logic very specific to X12 to avoid any side effects to other messages.
            // FIXME - This is a temporary fix. Need to find a better way to handle this.
            if context.ediText[0].startsWith("ST*278") && segSchema.tag == "Loop_2000D" && !(context.ediText[context.rawIndex][3] == "23") {
                log:printDebug(string `X12 dependent loop 2000D is detected but the current HL segment does not indicate that there is a dependent. Hence, ignoring the dependent loop.`);
                check ignoreSchemaGroup(segSchema, sgContext, context);
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
            string unmatchedRaw = context.ediText[i];
            string[] unmatchedSegFields = check split(unmatchedRaw, ediSchema.delimiters.'field);
            if ediSchema.ignoreSegments.indexOf(unmatchedSegFields[0], 0) == () {
                return error Error(string `Segment text does not match with the schema.
                    Segment: ${context.ediText[i]}, Current row: ${i}`);
            }
        }
    }
    check validateRemainingSchemas(sgContext);
    return sgContext.segmentGroup;
}

# Checks whether an appropriate segment of the given segment group schema matches the input segment.
# Matching considers the segment code and any discriminator value constraints of the candidate segments.
#
# + segSchema - Segment group schema
# + fields - Fields of the input segment
# + ediSchema - EDI schema providing the delimiters
# + return - Return true if the input segment matches an appropriate segment of the given segment group schema
isolated function firstSegmentMatches(EdiSegGroupSchema segSchema, string[] fields, EdiSchema ediSchema) returns boolean {
    foreach EdiUnitSchema seg in segSchema.segments {
        if seg is EdiSegSchema && segmentMatches(seg, fields, ediSchema) {
            return true;
        }
        if seg is EdiSegGroupSchema {
            // FIXME is this a possible path?
        }
    }
    return false;
}

# Ignores the given segment group schema if any of the below two conditions are satisfied.
# This function will be called if a schema cannot be mapped with the next available segment text.
#
# 1. Given schema group is optional
# 2. Given schema group is a repeatable one and it has already occured at least once
#
# If above conditions are not met, schema cannot be ignored, and should result in an error.
#
# + segGroupSchema - Segment group schema to be ignored
# + sgContext - Segment group parsing context
# + context - EDI parsing context
# + return - Return error if the given mapping cannot be ignored
isolated function ignoreSchemaGroup(EdiSegGroupSchema segGroupSchema, SegmentGroupContext sgContext, EdiContext context) returns Error? {

    // If the current segment group mapping is optional, we can ignore the current mapping and compare the
    // current segment with the next mapping.
    if segGroupSchema.minOccurances == 0 {
        log:printDebug(string `Ignoring optional segment group: ${printSegGroupMap(segGroupSchema)} |
            Segment text: ${context.rawIndex < context.ediText.length() ? context.ediText[context.rawIndex] : "-- EOF --"}`);
        sgContext.schemaIndex += 1;
        return;
    }

    // If the current segment mapping represents a repeatable segment group, and we have already encountered
    // at least one such segment group, we can ignore the current mapping and compare the current segment with
    // the next mapping.
    if segGroupSchema.maxOccurances != 1 {
        EdiSegment|EdiSegment[]|EdiSegmentGroup|EdiSegmentGroup[]? segments = sgContext.segmentGroup[segGroupSchema.tag];
        if segments is EdiSegment[]|EdiSegmentGroup[] {
            if segments.length() > 0 {
                // This repeatable segment has already occured at least once. So move to the next mapping.
                sgContext.schemaIndex += 1;
                log:printDebug(string `Completed reading repeatable segment: ${printSegGroupMap(segGroupSchema)} |
                    Segment text: ${context.rawIndex < context.ediText.length() ? context.ediText[context.rawIndex] : "-- EOF --"}`);
                return;
            }
        }
    }

    return error Error(string `Mandatory segment group is missing in the EDI.
        Unit: ${printSegGroupMap(segGroupSchema)}, Current segment text: ${context.ediText[context.rawIndex]},
            Current mapping index: ${sgContext.schemaIndex}`);
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
        EdiSegment|EdiSegment[]|EdiSegmentGroup|EdiSegmentGroup[]? segments = sgContext.segmentGroup[segSchema.tag];
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
        // Current mapping points to a repeatable segment. So we are using an EDISegment[] array to hold segments.
        // Also we can't increment the mapping index here as next segment can also match with the current mapping
        // as the segment is repeatable.
        EdiSegment|EdiSegment[]|EdiSegmentGroup|EdiSegmentGroup[]? segments = sgContext.segmentGroup[segSchema.tag];
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
        EdiSegment|EdiSegment[]|EdiSegmentGroup|EdiSegmentGroup[]? segmentGroups = sgContext.segmentGroup[segGroupSchema.tag];
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

isolated function subsequentSchemaStartsWith(SegmentGroupContext sgContext, 
                                             string segmentCode, int fromIndex) returns boolean {
    int index = fromIndex;
    while index < sgContext.unitSchemas.length() {
        EdiUnitSchema nextSchema = sgContext.unitSchemas[index];
        if nextSchema is EdiSegGroupSchema {
            foreach EdiUnitSchema seg in nextSchema.segments {
                if seg is EdiSegSchema {
                    if seg.code == segmentCode {
                        return true;
                    }
                    if seg.minOccurances > 0 {
                        break;
                    }
                }
            }
        } else if nextSchema is EdiSegSchema {
            if nextSchema.code == segmentCode {
                return true;
            }
        }
        index += 1;
    }
    return false;
}

isolated function qualifierMatchesExistingOccurrence(EdiSegGroupSchema segGroupSchema, EdiSegmentGroup firstOccurrence,
                                                     string[] currentFields, EdiSchema schema) returns boolean {
    if currentFields.length() < 2 {
        return true;
    }
    EdiSegSchema? openingSegSchema = ();
    foreach EdiUnitSchema seg in segGroupSchema.segments {
        if seg is EdiSegSchema {
            openingSegSchema = seg;
            break;
        }
    }
    if openingSegSchema is () {
        return true;
    }

    int qualifierFieldIndex = schema.includeSegmentCode ? 1 : 0;
    if openingSegSchema.fields.length() <= qualifierFieldIndex {
        return true;
    }
    string qualifierTag = openingSegSchema.fields[qualifierFieldIndex].tag;

    EdiSegment|EdiSegment[]|EdiSegmentGroup|EdiSegmentGroup[]? storedSeg = firstOccurrence[openingSegSchema.tag];
    if storedSeg is EdiSegment {
        EdiComponentGroup|EdiComponentGroup[]|SimpleType|SimpleArray? storedQualifier = storedSeg[qualifierTag];
        string storedQualifierStr = storedQualifier is string ? storedQualifier : "";
        string currentQualifier = currentFields[1].trim();
        return storedQualifierStr == currentQualifier;
    }
    return true;
}

# Returns the index of the last member of the discriminated sibling run starting at the given
# index: the maximal run of consecutive segment definitions sharing one segment code, where every
# member declares at least one discriminator. Returns the start index itself when there is no
# such run of length two or more.
#
# + units - Unit schemas of the current segment group
# + startIndex - Index of the unit the schema cursor is standing on
# + return - Index of the last run member, or `startIndex` when there is no run
isolated function discriminatedSiblingRunEnd(EdiUnitSchema[] units, int startIndex) returns int {
    EdiUnitSchema first = units[startIndex];
    if first !is EdiSegSchema || !segmentHasDiscriminator(first) {
        return startIndex;
    }
    string runCode = first.code;
    int runEnd = startIndex;
    int i = startIndex + 1;
    while i < units.length() {
        EdiUnitSchema unit = units[i];
        if unit is EdiSegSchema && unit.code == runCode && segmentHasDiscriminator(unit) {
            runEnd = i;
            i += 1;
        } else {
            break;
        }
    }
    return runEnd;
}

# Reads input segments into a discriminated sibling run as an unordered set. While the next input
# segment carries the run's segment code, every run member that can still accept an occurrence is
# tried in schema order and the first member whose discriminators match consumes the segment — so
# occurrences may arrive in any order and interleave freely. The run is left when a segment with a
# different code arrives, when a same-code segment matches no member (an unknown discriminator
# value falls through to the later units and, ultimately, the unmatched-segment check), or when
# the input ends. On exit, every mandatory member must have at least one occurrence.
#
# + units - Unit schemas of the current segment group
# + runEnd - Index of the last run member (the run starts at the current schema cursor)
# + sgContext - Segment group parsing context
# + context - EDI parsing context
# + return - Error when a mandatory run member has no occurrence, or when reading a segment fails
isolated function readDiscriminatedSiblingRun(EdiUnitSchema[] units, int runEnd,
        SegmentGroupContext sgContext, EdiContext context) returns Error? {
    EdiSchema ediSchema = context.schema;
    int runStart = sgContext.schemaIndex;
    EdiSegSchema firstMember = <EdiSegSchema>units[runStart];
    string runCode = firstMember.code;
    while context.rawIndex < context.ediText.length() {
        string segmentDesc = removeLineBreaks(context.ediText[context.rawIndex]);
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
        string[] fields = check splitFields(segmentDesc, ediSchema.delimiters.'field, firstMember);
        if fields.length() == 0 || fields[0].trim() != runCode {
            break;
        }
        boolean consumed = false;
        foreach int i in runStart ... runEnd {
            EdiSegSchema member = <EdiSegSchema>units[i];
            if !runMemberCanAcceptMore(member, sgContext) {
                continue;
            }
            if segmentMatches(member, fields, ediSchema) {
                log:printDebug(string `Matched [Segment]: ${segmentDesc} with sibling-run member ${printSegMap(member)}`);
                EdiSegment ediRecord = check readSegment(member, fields, ediSchema, segmentDesc);
                check placeRunOccurrence(ediRecord, member, sgContext);
                context.rawIndex += 1;
                consumed = true;
                break;
            }
        }
        if !consumed {
            break;
        }
    }
    foreach int i in runStart ... runEnd {
        EdiSegSchema member = <EdiSegSchema>units[i];
        if member.minOccurances > 0 && !hasRunOccurrence(member, sgContext) {
            return error Error(string `Mandatory segment is missing in the EDI.
                Unit: ${printSegMap(member)}, Current mapping index: ${i}`);
        }
    }
    sgContext.schemaIndex = runEnd + 1;
}

isolated function runMemberCanAcceptMore(EdiSegSchema member, SegmentGroupContext sgContext) returns boolean {
    var existing = sgContext.segmentGroup[member.tag];
    if member.maxOccurances == 1 {
        return existing is ();
    }
    if existing is EdiSegment[] {
        return member.maxOccurances == -1 || existing.length() < member.maxOccurances;
    }
    return true;
}

isolated function hasRunOccurrence(EdiSegSchema member, SegmentGroupContext sgContext) returns boolean {
    var existing = sgContext.segmentGroup[member.tag];
    if existing is EdiSegment[] {
        return existing.length() > 0;
    }
    return existing !is ();
}

isolated function placeRunOccurrence(EdiSegment segment, EdiSegSchema member, SegmentGroupContext sgContext) returns Error? {
    if member.maxOccurances == 1 {
        sgContext.segmentGroup[member.tag] = segment;
        return;
    }
    var existing = sgContext.segmentGroup[member.tag];
    if existing is EdiSegment[] {
        existing.push(segment);
    } else if existing is () {
        sgContext.segmentGroup[member.tag] = [segment];
    } else {
        return error Error(string `Segment must be a segment array. Segment: ${member.code}`);
    }
}
