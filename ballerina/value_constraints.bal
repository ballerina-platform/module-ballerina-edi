// Copyright (c) 2026 WSO2 LLC. (http://www.wso2.com) All Rights Reserved.
//
// WSO2 LLC. licenses this file to you under the Apache License,
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

// EDI formats reuse the same segment code for definitions with different meanings and rely on a
// qualifier value to identify each one (e.g. X12 834 uses REF*0F, REF*1L and REF*17 for three
// different member-level definitions; EDIFACT RFF carries the equivalent qualifier inside the
// C506 composite). Schema nodes declare the legal codes of an element with `values`, and the codes
// that identify a definition with `discriminator`. `values` never affects matching — it is
// validated when writing EDI — so converters can attach full standard code lists without changing
// how existing messages parse; only a node carrying `discriminator` participates in matching.

# Checks whether the given input segment is an instance of the given segment schema.
#
# A segment matches when its code matches and, for every discriminator node in the schema
# (at field, component, or subcomponent level), the corresponding input value is present
# and contained in that node's `discriminator` set. A missing or empty discriminator value
# never matches: a segment that does not carry its identity cannot claim a discriminated schema.
#
# + segSchema - Segment schema to match against
# + fields - Fields of the input segment
# + ediSchema - EDI schema providing the delimiters
# + return - True if the segment code and all discriminator constraints match
isolated function segmentMatches(EdiSegSchema segSchema, string[] fields, EdiSchema ediSchema) returns boolean {
    if fields.length() == 0 || segSchema.code != fields[0].trim() {
        return false;
    }
    foreach int i in 0 ..< segSchema.fields.length() {
        EdiFieldSchema fieldSchema = segSchema.fields[i];
        if !hasDiscriminator(fieldSchema) {
            continue;
        }
        // Raw fields align with schema fields by index, following the same convention as readSegment.
        string rawField = i < fields.length() ? fields[i] : "";
        if !fieldMatches(fieldSchema, rawField, ediSchema) {
            return false;
        }
    }
    return true;
}

isolated function segmentHasDiscriminator(EdiSegSchema segSchema) returns boolean {
    foreach EdiFieldSchema fieldSchema in segSchema.fields {
        if hasDiscriminator(fieldSchema) {
            return true;
        }
    }
    return false;
}

isolated function hasDiscriminator(EdiFieldSchema fieldSchema) returns boolean {
    if fieldSchema.discriminator is string[] {
        return true;
    }
    foreach EdiComponentSchema componentSchema in fieldSchema.components {
        if componentSchema.discriminator is string[] {
            return true;
        }
        foreach EdiSubcomponentSchema subcomponentSchema in componentSchema.subcomponents {
            if subcomponentSchema.discriminator is string[] {
                return true;
            }
        }
    }
    return false;
}

isolated function fieldMatches(EdiFieldSchema fieldSchema, string rawField, EdiSchema ediSchema) returns boolean {
    if fieldSchema.repeat {
        // Discriminators on repeating fields are rejected at schema load time.
        return true;
    }
    string[]? fieldDiscriminator = fieldSchema.discriminator;
    if fieldDiscriminator is string[] {
        // Schema load validation guarantees that a discriminator field is a simple field.
        if !valueInSet(rawField, fieldDiscriminator) {
            return false;
        }
    }
    if fieldSchema.components.length() > 0 {
        string[]|Error components = split(rawField, ediSchema.delimiters.component);
        if components is Error {
            return false;
        }
        foreach int j in 0 ..< fieldSchema.components.length() {
            EdiComponentSchema componentSchema = fieldSchema.components[j];
            string rawComponent = j < components.length() ? components[j] : "";
            string[]? componentDiscriminator = componentSchema.discriminator;
            if componentDiscriminator is string[] && !valueInSet(rawComponent, componentDiscriminator) {
                return false;
            }
            if componentSchema.subcomponents.length() > 0 && hasSubcomponentDiscriminator(componentSchema) {
                string[]|Error subcomponents = split(rawComponent, ediSchema.delimiters.subcomponent);
                if subcomponents is Error {
                    return false;
                }
                foreach int k in 0 ..< componentSchema.subcomponents.length() {
                    EdiSubcomponentSchema subcomponentSchema = componentSchema.subcomponents[k];
                    string[]? subcomponentDiscriminator = subcomponentSchema.discriminator;
                    if subcomponentDiscriminator is () {
                        continue;
                    }
                    string rawSubcomponent = k < subcomponents.length() ? subcomponents[k] : "";
                    if !valueInSet(rawSubcomponent, subcomponentDiscriminator) {
                        return false;
                    }
                }
            }
        }
    }
    return true;
}

isolated function hasSubcomponentDiscriminator(EdiComponentSchema componentSchema) returns boolean {
    foreach EdiSubcomponentSchema subcomponentSchema in componentSchema.subcomponents {
        if subcomponentSchema.discriminator is string[] {
            return true;
        }
    }
    return false;
}

isolated function valueInSet(string value, string[] allowedValues) returns boolean {
    string normalized = value.trim();
    if normalized == "" {
        return false;
    }
    return allowedValues.indexOf(normalized, 0) !is ();
}

# Validates a value against the value constraints of a schema node when writing EDI.
# A node's `discriminator` is the tighter constraint (schema load guarantees it is a subset of
# `values` when both are present), so it is enforced when present: writing a value outside it
# would produce EDI that no longer identifies this definition. Empty values are not validated
# here — presence rules are enforced by the `required` attribute.
#
# + value - Input value being written
# + values - The node's `values` set, if any
# + discriminator - The node's `discriminator` set, if any
# + segTag - Tag of the containing segment schema (used in error messages)
# + nodeTag - Tag of the schema node (used in error messages)
# + return - Error if the value is not in the effective set
isolated function validateAllowedValue(json value, string[]? values, string[]? discriminator, string segTag, string nodeTag) returns Error? {
    string[]? allowedValues = discriminator is string[] ? discriminator : values;
    if allowedValues is () {
        return;
    }
    string normalized = value.toString().trim();
    if normalized == "" {
        return;
    }
    if allowedValues.indexOf(normalized, 0) is () {
        return error Error(string `Input value is not allowed by the value constraint of the schema.
            Segment: ${segTag}, Element: ${nodeTag}, Input value: ${value.toString()}, Allowed values: ${allowedValues.toString()}`);
    }
}

# Validates the value constraints of a schema at load time and lints same-code sibling
# definitions for missing or overlapping discriminators.
#
# + schema - Schema to validate
# + return - Error if a discriminator is empty, declared on a repeating field, declared on a node
# whose value is not a simple value (composite fields and components with subcomponents), or
# inconsistent with the node's `values` set
isolated function validateValueConstraints(EdiSchema schema) returns Error? {
    check validateUnitList(schema.segments, schema);
    EdiEnvelopeSchema? envelope = schema.envelope;
    if envelope is EdiEnvelopeSchema {
        check validateUnitList(envelope.interchange.header, schema);
        check validateUnitList(envelope.interchange.trailer, schema);
        EdiEnvelopeLevel? groupLevel = envelope.group;
        if groupLevel is EdiEnvelopeLevel {
            check validateUnitList(groupLevel.header, schema);
            check validateUnitList(groupLevel.trailer, schema);
        }
        check validateUnitList(envelope.'transaction.header, schema);
        check validateUnitList(envelope.'transaction.trailer, schema);
    }
}

isolated function validateUnitList(EdiUnitSchema[] units, EdiSchema schema) returns Error? {
    foreach EdiUnitSchema unit in units {
        if unit is EdiSegSchema {
            check validateSegmentValueConstraints(unit, schema);
        } else if unit is EdiSegGroupSchema {
            check validateUnitList(unit.segments, schema);
        }
        // Segment references are resolved during denormalization before this validation runs.
    }
    check lintSameCodeSiblings(units);
}

isolated function validateSegmentValueConstraints(EdiSegSchema segSchema, EdiSchema schema) returns Error? {
    foreach EdiFieldSchema fieldSchema in segSchema.fields {
        boolean composite = fieldSchema.components.length() > 0;
        // The value of a composite field is a component group; only its simple leaves hold values
        // a constraint could apply to, so a constraint here could never be applied.
        check rejectConstraintsOnGroup(composite, fieldSchema.values, fieldSchema.discriminator,
                segSchema.tag, fieldSchema.tag, "composite field", "component");
        if fieldSchema.discriminator is string[] && fieldSchema.repeat {
            return error Error(string `Discriminators are not supported on repeating fields.
                Segment: ${segSchema.tag}, Field: ${fieldSchema.tag}`);
        }
        check validateNodeConstraints(fieldSchema.values, fieldSchema.discriminator, segSchema.tag, fieldSchema.tag);

        foreach EdiComponentSchema componentSchema in fieldSchema.components {
            boolean grouped = componentSchema.subcomponents.length() > 0;
            check rejectConstraintsOnGroup(grouped, componentSchema.values, componentSchema.discriminator,
                    segSchema.tag, componentSchema.tag, "component with subcomponents", "subcomponent");
            check validateNodeConstraints(componentSchema.values, componentSchema.discriminator,
                    segSchema.tag, componentSchema.tag);
            // Repetitions of a field are position-insignificant, so nothing inside a repeating
            // field can identify a definition. Rejecting here prevents a discriminator that the
            // matcher would silently ignore.
            check rejectDiscriminatorInRepeat(fieldSchema.repeat, componentSchema.discriminator,
                    segSchema.tag, fieldSchema.tag, componentSchema.tag);
            foreach EdiSubcomponentSchema subcomponentSchema in componentSchema.subcomponents {
                check validateNodeConstraints(subcomponentSchema.values, subcomponentSchema.discriminator,
                        segSchema.tag, subcomponentSchema.tag);
                check rejectDiscriminatorInRepeat(fieldSchema.repeat, subcomponentSchema.discriminator,
                        segSchema.tag, fieldSchema.tag, subcomponentSchema.tag);
                // A sub-component can only be isolated when the schema declares a sub-component
                // delimiter; without one the whole component text would decide the identity.
                if subcomponentSchema.discriminator is string[] && schema.delimiters.subcomponent == "NOT_USED" {
                    return error Error(string `A sub-component discriminator requires "delimiters.subcomponent" to be configured.
                        Segment: ${segSchema.tag}, Sub-component: ${subcomponentSchema.tag}`);
                }
            }
        }
    }
}

// Constraints must sit on the element that holds the value, never on a node whose value is a group
// of child elements.
isolated function rejectConstraintsOnGroup(boolean isGroup, string[]? values, string[]? discriminator,
        string segTag, string nodeTag, string nodeKind, string childKind) returns Error? {
    if !isGroup {
        return;
    }
    if values !is () {
        return error Error(string `"values" on a ${nodeKind} must be declared on the ${childKind} holding the value.
            Segment: ${segTag}, Element: ${nodeTag}`);
    }
    if discriminator !is () {
        return error Error(string `"discriminator" on a ${nodeKind} must be declared on the ${childKind} holding the value.
            Segment: ${segTag}, Element: ${nodeTag}`);
    }
}

isolated function rejectDiscriminatorInRepeat(boolean repeating, string[]? discriminator, string segTag,
        string fieldTag, string nodeTag) returns Error? {
    if repeating && discriminator is string[] {
        return error Error(string `Discriminators are not supported inside repeating fields.
            Segment: ${segTag}, Field: ${fieldTag}, Element: ${nodeTag}`);
    }
}

// A discriminator must list at least one code, and when the node also declares `values` (the
// element's full legal code list), every discriminating code must be one of them.
isolated function validateNodeConstraints(string[]? values, string[]? discriminator, string segTag, string nodeTag) returns Error? {
    if discriminator is () {
        return;
    }
    if discriminator.length() == 0 {
        return error Error(string `"discriminator" must list at least one value.
            Segment: ${segTag}, Element: ${nodeTag}`);
    }
    if values is string[] {
        foreach string code in discriminator {
            if values.indexOf(code, 0) is () {
                return error Error(string `Discriminating value is not one of the values allowed by the element.
                    Segment: ${segTag}, Element: ${nodeTag}, Value: ${code}, Allowed values: ${values.toString()}`);
            }
        }
    }
}

// Checks sibling definitions sharing a segment code:
// - Mixing discriminated and non-discriminated siblings of one code is rejected: a code-only
//   sibling would capture the segments its discriminated siblings rejected, silently.
// - When no sibling has a discriminator, first-in-order matching applies and each sibling is
//   reported with a warning.
// - Overlapping discriminator value sets are reported with a warning (the earlier definition
//   in schema order wins).
isolated function lintSameCodeSiblings(EdiUnitSchema[] units) returns Error? {
    map<EdiSegSchema[]> segmentsByCode = {};
    foreach EdiUnitSchema unit in units {
        if unit is EdiSegSchema {
            EdiSegSchema[]? siblings = segmentsByCode[unit.code];
            if siblings is EdiSegSchema[] {
                siblings.push(unit);
            } else {
                segmentsByCode[unit.code] = [unit];
            }
        }
    }
    foreach [string, EdiSegSchema[]] [code, siblings] in segmentsByCode.entries() {
        if siblings.length() < 2 {
            continue;
        }
        string[][] signatures = [];
        string[] undiscriminatedTags = [];
        boolean anyDiscriminated = false;
        foreach EdiSegSchema sibling in siblings {
            string[] signature = discriminatorSignature(sibling);
            if signature.length() == 0 {
                undiscriminatedTags.push(sibling.tag);
            } else {
                anyDiscriminated = true;
            }
            signatures.push(signature);
        }
        if anyDiscriminated && undiscriminatedTags.length() > 0 {
            return error Error(string `Definitions sharing the segment code "${code}" mix discriminated and non-discriminated siblings.
                A definition without a discriminator would capture the segments its discriminated siblings rejected.
                Definitions without discriminators: ${undiscriminatedTags.toString()}`);
        }
        if !anyDiscriminated {
            foreach string tag in undiscriminatedTags {
                log:printWarn(string `Multiple sibling definitions share the segment code "${code}" and the definition "${tag}" has no discriminator. Input segments are assigned to the first definition in schema order.`);
            }
        }
        foreach int i in 0 ..< siblings.length() {
            foreach int j in (i + 1) ..< siblings.length() {
                foreach string entry in signatures[i] {
                    if signatures[j].indexOf(entry, 0) !is () {
                        log:printWarn(string `Sibling definitions "${siblings[i].tag}" and "${siblings[j].tag}" of segment code "${code}" allow the same discriminator value (${entry}). The earlier definition in schema order wins.`);
                        break;
                    }
                }
            }
        }
    }
}

// Builds a set of "position=value" entries for every discriminator value a segment accepts.
isolated function discriminatorSignature(EdiSegSchema segSchema) returns string[] {
    string[] signature = [];
    foreach int i in 0 ..< segSchema.fields.length() {
        EdiFieldSchema fieldSchema = segSchema.fields[i];
        string[]? fieldDiscriminator = fieldSchema.discriminator;
        if fieldDiscriminator is string[] {
            foreach string value in fieldDiscriminator {
                signature.push(string `${i}=${value}`);
            }
        }
        foreach int j in 0 ..< fieldSchema.components.length() {
            EdiComponentSchema componentSchema = fieldSchema.components[j];
            string[]? componentDiscriminator = componentSchema.discriminator;
            if componentDiscriminator is string[] {
                foreach string value in componentDiscriminator {
                    signature.push(string `${i}.${j}=${value}`);
                }
            }
            foreach int k in 0 ..< componentSchema.subcomponents.length() {
                EdiSubcomponentSchema subcomponentSchema = componentSchema.subcomponents[k];
                string[]? subcomponentDiscriminator = subcomponentSchema.discriminator;
                if subcomponentDiscriminator is string[] {
                    foreach string value in subcomponentDiscriminator {
                        signature.push(string `${i}.${j}.${k}=${value}`);
                    }
                }
            }
        }
    }
    return signature;
}
