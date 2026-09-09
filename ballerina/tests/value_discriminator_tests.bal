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

import ballerina/io;
import ballerina/test;

@test:Config
function testFieldDiscriminatorsWithoutOptionalSegment() returns error? {
    json schemaJson = check io:fileReadJson("tests/resources/value-discriminators/x12-schema.json");
    EdiSchema schema = check getSchema(schemaJson);
    string ediText = check io:fileReadString("tests/resources/value-discriminators/x12_without_policy.edi");
    json result = check fromEdiString(ediText, schema);
    map<json> resultMap = check result.cloneWithType();

    test:assertFalse(resultMap.hasKey("MemberPolicyNumber"),
        "REF*17 must not be assigned to the optional member policy definition");
    test:assertEquals(check result.SubscriberIdentifier.qualifier, "0F");
    json supplemental = check result.MemberSupplementalIdentifier;
    test:assertTrue(supplemental is json[]);
    json[] supplementalIdentifiers = <json[]>supplemental;
    test:assertEquals(supplementalIdentifiers.length(), 2);
    test:assertEquals(check supplementalIdentifiers[0].qualifier, "17");
    test:assertEquals(check supplementalIdentifiers[1].qualifier, "DX");
}

@test:Config
function testFieldDiscriminatorsWithOptionalSegment() returns error? {
    json schemaJson = check io:fileReadJson("tests/resources/value-discriminators/x12-schema.json");
    EdiSchema schema = check getSchema(schemaJson);
    string ediText = check io:fileReadString("tests/resources/value-discriminators/x12_with_policy.edi");
    json result = check fromEdiString(ediText, schema);

    test:assertEquals(check result.SubscriberIdentifier.qualifier, "0F");
    test:assertEquals(check result.MemberPolicyNumber.qualifier, "1L");
    test:assertEquals(check result.MemberPolicyNumber.identifier, "373");
    json supplemental = check result.MemberSupplementalIdentifier;
    test:assertTrue(supplemental is json[]);
    json[] supplementalIdentifiers = <json[]>supplemental;
    test:assertEquals(supplementalIdentifiers.length(), 3);
    test:assertEquals(check supplementalIdentifiers[0].qualifier, "17");
    test:assertEquals(check supplementalIdentifiers[1].qualifier, "23");
    test:assertEquals(check supplementalIdentifiers[2].qualifier, "DX");
}

@test:Config
function testComponentDiscriminatorsWithSpecializedDefinitions() returns error? {
    json schemaJson = check io:fileReadJson("tests/resources/value-discriminators/edifact-schema.json");
    EdiSchema schema = check getSchema(schemaJson);
    string ediText = check io:fileReadString("tests/resources/value-discriminators/edifact_message.edi");
    json result = check fromEdiString(ediText, schema);

    test:assertEquals(check result.SellersReference.REFERENCE.qualifier, "SS");
    test:assertEquals(check result.SellersReference.REFERENCE.number, "1111-000000");
    test:assertEquals(check result.VatNumber.REFERENCE.qualifier, "VA");
    test:assertEquals(check result.VatNumber.REFERENCE.number, "SE556421030901");
}

@test:Config
function testComponentDiscriminatorsSkipAbsentOptionalDefinition() returns error? {
    json schemaJson = check io:fileReadJson("tests/resources/value-discriminators/edifact-schema.json");
    EdiSchema schema = check getSchema(schemaJson);
    string ediText = check io:fileReadString("tests/resources/value-discriminators/edifact_vat_only.edi");
    json result = check fromEdiString(ediText, schema);
    map<json> resultMap = check result.cloneWithType();

    test:assertFalse(resultMap.hasKey("SellersReference"),
        "RFF+VA must not be assigned to the sellers reference definition");
    test:assertEquals(check result.VatNumber.REFERENCE.qualifier, "VA");
}

@test:Config
function testEmptyDiscriminatorValueDoesNotMatchAnyDefinition() returns error? {
    json schemaJson = check io:fileReadJson("tests/resources/value-discriminators/x12-schema.json");
    EdiSchema schema = check getSchema(schemaJson);
    string ediText = "INS*Y*18~\nREF*0F*110011113~\nREF**Bargained~";
    json|Error result = fromEdiString(ediText, schema);
    test:assertTrue(result is Error,
        "A segment with an empty discriminator value must not be assigned to any discriminated definition");
}

@test:Config
function testUnknownDiscriminatorValueDoesNotMatchAnyDefinition() returns error? {
    json schemaJson = check io:fileReadJson("tests/resources/value-discriminators/x12-schema.json");
    EdiSchema schema = check getSchema(schemaJson);
    string ediText = "INS*Y*18~\nREF*0F*110011113~\nREF*99*SOMETHING~";
    json|Error result = fromEdiString(ediText, schema);
    test:assertTrue(result is Error,
        "A segment with a qualifier outside every definition's value set must not be silently assigned");
}

@test:Config
function testWriterRejectsValueOutsideAllowedSet() returns error? {
    json schemaJson = check io:fileReadJson("tests/resources/value-discriminators/x12-schema.json");
    EdiSchema schema = check getSchema(schemaJson);
    json invalidMessage = {
        MemberLevelDetail: {code: "INS", memberIndicator: "Y", relationship: "18"},
        SubscriberIdentifier: {code: "REF", qualifier: "0F", identifier: "110011113"},
        MemberPolicyNumber: {code: "REF", qualifier: "17", identifier: "Bargained"}
    };
    string|Error result = toEdiString(invalidMessage, schema);
    test:assertTrue(result is Error, "The writer must reject qualifier 17 for MemberPolicyNumber");
}

@test:Config
function testWriterAcceptsValuesInAllowedSet() returns error? {
    json schemaJson = check io:fileReadJson("tests/resources/value-discriminators/x12-schema.json");
    EdiSchema schema = check getSchema(schemaJson);
    json message = {
        MemberLevelDetail: {code: "INS", memberIndicator: "Y", relationship: "18"},
        SubscriberIdentifier: {code: "REF", qualifier: "0F", identifier: "110011113"},
        MemberPolicyNumber: {code: "REF", qualifier: "1L", identifier: "373"}
    };
    string ediText = check toEdiString(message, schema);
    test:assertTrue(ediText.includes("REF*1L*373~"), "Valid policy number segment must be serialized");
}

@test:Config
function testWriterRejectsComponentValueOutsideAllowedSet() returns error? {
    json schemaJson = check io:fileReadJson("tests/resources/value-discriminators/edifact-schema.json");
    EdiSchema schema = check getSchema(schemaJson);
    json invalidMessage = {
        BeginningOfMessage: {code: "BGM", documentName: "82"},
        VatNumber: {code: "RFF", REFERENCE: {qualifier: "SS", number: "SE556421030901"}}
    };
    string|Error result = toEdiString(invalidMessage, schema);
    test:assertTrue(result is Error, "The writer must reject qualifier SS for the VAT number definition");
}

@test:Config
function testEmptyDiscriminatorIsRejectedAtLoadTime() returns error? {
    json schemaJson = {
        "name": "EmptyDiscriminatorTest",
        "delimiters": {"segment": "~", "field": "*", "component": ":"},
        "segments": [
            {
                "code": "REF",
                "tag": "Reference",
                "fields": [{"tag": "code"}, {"tag": "qualifier", "discriminator": []}]
            }
        ]
    };
    EdiSchema|error schema = getSchema(schemaJson);
    test:assertTrue(schema is error, "An empty discriminator must be rejected at schema load time");
}

@test:Config
function testDiscriminatorOutsideValuesIsRejectedAtLoadTime() returns error? {
    // When a node declares both, the discriminating codes must be part of the element's
    // legal code list - otherwise the definition could never match a valid segment.
    json schemaJson = {
        "name": "DiscriminatorSubsetTest",
        "delimiters": {"segment": "~", "field": "*", "component": ":"},
        "segments": [
            {
                "code": "REF",
                "tag": "Reference",
                "fields": [
                    {"tag": "code"},
                    {"tag": "qualifier", "values": ["0F", "1L"], "discriminator": ["ZZ"]}
                ]
            }
        ]
    };
    EdiSchema|error schema = getSchema(schemaJson);
    test:assertTrue(schema is error,
        "A discriminating value outside the element's values set must be rejected at schema load time");
}

@test:Config
function testDiscriminatorSubsetOfValuesIsAccepted() returns error? {
    // The common real-world shape: the element's full standard code list in `values`,
    // the implementation guide's narrowed routing set in `discriminator`.
    json schemaJson = {
        "name": "DiscriminatorSubsetOk",
        "delimiters": {"segment": "~", "field": "*", "component": ":"},
        "preserveEmptyFields": false,
        "segments": [
            {
                "code": "REF",
                "tag": "PolicyNumber",
                "minOccurances": 0,
                "fields": [
                    {"tag": "code"},
                    {"tag": "qualifier", "required": true, "values": ["0F", "1L", "17"], "discriminator": ["1L"]},
                    {"tag": "identifier", "required": true}
                ]
            }
        ]
    };
    EdiSchema schema = check getSchema(schemaJson);
    json result = check fromEdiString("REF*1L*373~", schema);
    test:assertEquals(check result.PolicyNumber.identifier, "373");
    // 17 is legal for the element but is not a discriminating value, so it matches nothing here.
    test:assertTrue(fromEdiString("REF*17*X~", schema) is Error,
        "A value that is legal for the element but not a discriminating value must not match");
}

@test:Config
function testDiscriminatorOnRepeatingFieldIsRejectedAtLoadTime() returns error? {
    json schemaJson = {
        "name": "InvalidRepeatDiscriminatorTest",
        "delimiters": {"segment": "~", "field": "*", "component": ":"},
        "segments": [
            {
                "code": "REF",
                "tag": "Reference",
                "fields": [
                    {"tag": "code"},
                    {"tag": "qualifier", "repeat": true, "discriminator": ["1L"]}
                ]
            }
        ]
    };
    EdiSchema|error schema = getSchema(schemaJson);
    test:assertTrue(schema is error, "Discriminators on repeating fields must be rejected at schema load time");
}

@test:Config
function testDiscriminatorOnCompositeFieldIsRejectedAtLoadTime() returns error? {
    json schemaJson = {
        "name": "InvalidCompositeDiscriminatorTest",
        "delimiters": {"segment": "~", "field": "*", "component": ":"},
        "segments": [
            {
                "code": "RFF",
                "tag": "Reference",
                "fields": [
                    {"tag": "code"},
                    {
                        "tag": "REFERENCE",
                        "discriminator": ["VA"],
                        "components": [{"tag": "qualifier"}, {"tag": "number"}]
                    }
                ]
            }
        ]
    };
    EdiSchema|error schema = getSchema(schemaJson);
    test:assertTrue(schema is error,
        "Discriminators on composite fields must be declared on the component holding the value");
}

@test:Config
function testAnyOrderSiblingRunSingleOccurrence() returns error? {
    json schemaJson = check io:fileReadJson("tests/resources/value-discriminators/x12-schema.json");
    EdiSchema schema = check getSchema(schemaJson);
    // Discriminated same-code siblings arrive in reverse of schema order.
    string ediText = "INS*Y*18~\nREF*17*Bargained~\nREF*1L*373~\nREF*0F*110011113~\nREF*DX*1018~";
    json result = check fromEdiString(ediText, schema);

    test:assertEquals(check result.SubscriberIdentifier.qualifier, "0F");
    test:assertEquals(check result.MemberPolicyNumber.identifier, "373");
    json supplemental = check result.MemberSupplementalIdentifier;
    test:assertTrue(supplemental is json[]);
    json[] supplementalIdentifiers = <json[]>supplemental;
    test:assertEquals(supplementalIdentifiers.length(), 2);
    test:assertEquals(check supplementalIdentifiers[0].qualifier, "17");
    test:assertEquals(check supplementalIdentifiers[1].qualifier, "DX");
}

@test:Config
function testInterleavedRepeatableSiblingRun() returns error? {
    json schemaJson = {
        "name": "InterleavedRun",
        "delimiters": {"segment": "'", "field": "+", "component": ":"},
        "preserveEmptyFields": false,
        "segments": [
            {"code": "ALC", "tag": "Allowance", "minOccurances": 0, "maxOccurances": -1, "fields": [
                {"tag": "code"}, {"tag": "kind", "discriminator": ["A"]}, {"tag": "v"}]},
            {"code": "ALC", "tag": "Charge", "minOccurances": 0, "maxOccurances": -1, "fields": [
                {"tag": "code"}, {"tag": "kind", "discriminator": ["C"]}, {"tag": "v"}]}
        ]
    };
    EdiSchema schema = check getSchema(schemaJson);
    json result = check fromEdiString("ALC+A+1'\nALC+C+3'\nALC+A+2'", schema);
    json allowance = check result.Allowance;
    json charge = check result.Charge;
    test:assertTrue(allowance is json[] && charge is json[]);
    test:assertEquals((<json[]>allowance).length(), 2, "Interleaved A occurrences must both land in Allowance");
    test:assertEquals((<json[]>charge).length(), 1);
    test:assertEquals(check (<json[]>allowance)[1].v, "2");
}

@test:Config
function testSiblingRunMandatoryMemberMissing() returns error? {
    json schemaJson = check io:fileReadJson("tests/resources/value-discriminators/x12-schema.json");
    EdiSchema schema = check getSchema(schemaJson);
    // The mandatory SubscriberIdentifier (REF*0F) never arrives.
    string ediText = "INS*Y*18~\nREF*17*Bargained~\nREF*DX*1018~";
    json|Error result = fromEdiString(ediText, schema);
    test:assertTrue(result is Error, "A mandatory run member with no occurrence must be reported");
}

@test:Config
function testSiblingRunStillRejectsUnknownQualifier() returns error? {
    json schemaJson = check io:fileReadJson("tests/resources/value-discriminators/x12-schema.json");
    EdiSchema schema = check getSchema(schemaJson);
    string ediText = "INS*Y*18~\nREF*0F*110011113~\nREF*99*SOMETHING~";
    json|Error result = fromEdiString(ediText, schema);
    test:assertTrue(result is Error, "A qualifier outside every run member's value set must still be rejected");
}

@test:Config
function testSiblingRunRespectsMaxOccurrences() returns error? {
    json schemaJson = {
        "name": "RunMaxTest",
        "delimiters": {"segment": "~", "field": "*", "component": ":"},
        "preserveEmptyFields": false,
        "segments": [
            {"code": "REF", "tag": "First", "minOccurances": 0, "maxOccurances": 1, "fields": [
                {"tag": "code"}, {"tag": "q", "discriminator": ["A"]}, {"tag": "v"}]},
            {"code": "REF", "tag": "Second", "minOccurances": 0, "maxOccurances": 1, "fields": [
                {"tag": "code"}, {"tag": "q", "discriminator": ["B"]}, {"tag": "v"}]}
        ]
    };
    EdiSchema schema = check getSchema(schemaJson);
    // A second REF*A cannot be absorbed once First is full.
    json|Error result = fromEdiString("REF*A*1~\nREF*A*2~", schema);
    test:assertTrue(result is Error, "A run member must not exceed its maximum occurrences");
}

@test:Config
function testMixedSameCodeSiblingsAreRejectedAtLoadTime() returns error? {
    // A discriminated REF definition followed by a code-only REF definition: the code-only
    // sibling would capture the segments its discriminated sibling rejected.
    json schemaJson = {
        "name": "MixedSiblingsTest",
        "delimiters": {"segment": "~", "field": "*", "component": ":"},
        "segments": [
            {"code": "REF", "tag": "Policy", "minOccurances": 0, "fields": [
                {"tag": "code"}, {"tag": "q", "discriminator": ["1L"]}, {"tag": "v"}]},
            {"code": "REF", "tag": "AnythingElse", "minOccurances": 0, "fields": [
                {"tag": "code"}, {"tag": "q"}, {"tag": "v"}]}
        ]
    };
    EdiSchema|error schema = getSchema(schemaJson);
    test:assertTrue(schema is error,
        "Mixing discriminated and non-discriminated same-code siblings must be rejected at schema load time");
}

@test:Config
function testValuesOnCompositeFieldIsRejectedAtLoadTime() returns error? {
    json schemaJson = {
        "name": "ValuesOnCompositeTest",
        "delimiters": {"segment": "~", "field": "*", "component": ":"},
        "segments": [
            {"code": "RFF", "tag": "Reference", "fields": [
                {"tag": "code"},
                {"tag": "REFERENCE", "values": ["VA"], "components": [
                    {"tag": "qualifier"}, {"tag": "number"}]}
            ]}
        ]
    };
    EdiSchema|error schema = getSchema(schemaJson);
    test:assertTrue(schema is error,
        "values on a composite field must be rejected: the writer can never validate it");
}

@test:Config
function testValuesOnComponentWithSubcomponentsIsRejectedAtLoadTime() returns error? {
    json schemaJson = {
        "name": "ValuesOnComponentTest",
        "delimiters": {"segment": "~", "field": "*", "component": ":", "subcomponent": "^"},
        "segments": [
            {"code": "SEG", "tag": "Sample", "fields": [
                {"tag": "code"},
                {"tag": "comp", "components": [
                    {"tag": "inner", "values": ["A"], "subcomponents": [
                        {"tag": "kind"}, {"tag": "val"}]}
                ]}
            ]}
        ]
    };
    EdiSchema|error schema = getSchema(schemaJson);
    test:assertTrue(schema is error,
        "values on a component with subcomponents must be rejected: the writer can never validate it");
}

@test:Config
function testDiscriminatorInsideRepeatingFieldIsRejectedAtLoadTime() returns error? {
    // Repetitions of a field are position-insignificant, so nothing inside a repeating field
    // can identify a definition. Without this rule the matcher silently ignored such a
    // discriminator and bound the segment to the wrong definition.
    json schemaJson = {
        "name": "RepeatingCompositeDiscriminator",
        "delimiters": {"segment": "~", "field": "*", "component": ":", "repetition": "^"},
        "segments": [
            {"code": "SEG", "tag": "A", "fields": [
                {"tag": "code"},
                {"tag": "c", "repeat": true, "dataType": "composite", "components": [
                    {"tag": "q", "discriminator": ["AA"]}, {"tag": "v"}]}
            ]}
        ]
    };
    EdiSchema|error schema = getSchema(schemaJson);
    test:assertTrue(schema is error,
        "A discriminator inside a repeating field must be rejected at schema load time");
}

@test:Config
function testSubcomponentDiscriminatorWithoutDelimiterIsRejectedAtLoadTime() returns error? {
    // Without a sub-component delimiter the whole component text would decide the identity.
    json schemaJson = {
        "name": "SubcomponentWithoutDelimiter",
        "delimiters": {"segment": "~", "field": "*", "component": ":"},
        "segments": [
            {"code": "SEG", "tag": "S", "fields": [
                {"tag": "code"},
                {"tag": "comp", "dataType": "composite", "components": [
                    {"tag": "inner", "subcomponents": [
                        {"tag": "kind", "discriminator": ["A"]}, {"tag": "val"}]}]}
            ]}
        ]
    };
    EdiSchema|error schema = getSchema(schemaJson);
    test:assertTrue(schema is error,
        "A sub-component discriminator without a sub-component delimiter must be rejected");
}

@test:Config
function testSubcomponentDiscriminatorWithDelimiterIsAccepted() returns error? {
    json schemaJson = {
        "name": "SubcomponentWithDelimiter",
        "delimiters": {"segment": "~", "field": "*", "component": ":", "subcomponent": "^"},
        "preserveEmptyFields": false,
        "segments": [
            {"code": "SEG", "tag": "TypeA", "minOccurances": 0, "fields": [
                {"tag": "code"},
                {"tag": "comp", "dataType": "composite", "components": [
                    {"tag": "inner", "subcomponents": [
                        {"tag": "kind", "discriminator": ["A"]}, {"tag": "val"}]}]}
            ]},
            {"code": "SEG", "tag": "TypeB", "minOccurances": 0, "fields": [
                {"tag": "code"},
                {"tag": "comp", "dataType": "composite", "components": [
                    {"tag": "inner", "subcomponents": [
                        {"tag": "kind", "discriminator": ["B"]}, {"tag": "val"}]}]}
            ]}
        ]
    };
    EdiSchema schema = check getSchema(schemaJson);
    json result = check fromEdiString("SEG*B^42~", schema);
    map<json> resultMap = check result.cloneWithType();
    test:assertFalse(resultMap.hasKey("TypeA"), "A sub-component discriminator must route by its own value");
    test:assertEquals(check result.TypeB.comp.inner.kind, "B");
}

@test:Config
function testUnmatchedSameCodeSegmentStaysAvailableToLaterUnits() returns error? {
    // A same-code segment that matches no member of a run must stay unconsumed: the schema
    // cursor moves past the run, the input cursor does not advance, and a later unit may take
    // the segment. If nothing takes it, the unmatched-segment check reports it.
    json schemaJson = {
        "name": "CursorOwnership",
        "delimiters": {"segment": "~", "field": "*", "component": ":"},
        "preserveEmptyFields": false,
        "segments": [
            {"code": "REF", "tag": "R1", "minOccurances": 0, "fields": [
                {"tag": "code"}, {"tag": "q", "discriminator": ["A"]}, {"tag": "v"}]},
            {"code": "REF", "tag": "R2", "minOccurances": 0, "fields": [
                {"tag": "code"}, {"tag": "q", "discriminator": ["B"]}, {"tag": "v"}]},
            {"code": "DTM", "tag": "D", "minOccurances": 0, "fields": [
                {"tag": "code"}, {"tag": "d"}]},
            {"code": "REF", "tag": "R3", "minOccurances": 0, "fields": [
                {"tag": "code"}, {"tag": "q", "discriminator": ["C"]}, {"tag": "v"}]}
        ]
    };
    EdiSchema schema = check getSchema(schemaJson);

    // The run rejects C; the later unit must receive the segment.
    json fellThrough = check fromEdiString("REF*C*3~", schema);
    test:assertEquals(check fellThrough.R3.v, "3", "an unmatched same-code segment must reach later units");

    // The same, after the run has consumed one of its own occurrences.
    json afterRun = check fromEdiString("REF*A*1~\nREF*C*3~", schema);
    test:assertEquals(check afterRun.R1.v, "1");
    test:assertEquals(check afterRun.R3.v, "3");

    // Matching nothing anywhere is reported, never dropped.
    test:assertTrue(fromEdiString("REF*Z*9~", schema) is Error,
        "a segment no unit accepts must be reported, not silently dropped");
}
