import ballerina/io;
import ballerina/test;

@test:Config {
    dataProvider: segmentTestDataProvider
}
function testSegments(string testName) returns error? {
    EdiSchema schema = check getTestSchema(testName);
    string ediIn = check getEDIMessage(testName);
    json message = check fromEdiString(ediIn, schema);
    check saveJsonMessage(testName, message);

    string ediOut = check toEdiString(message, schema);
    check saveEDIMessage(testName, ediOut);

    ediOut = check prepareEDI(ediOut, schema);
    ediIn = check prepareEDI(ediIn, schema);

    test:assertEquals(ediOut, ediIn);
}

@test:Config {
    dataProvider: fixedLengthTestDataProvider
}
function testFixedLengthEDIs(string testName) returns error? {
    EdiSchema schema = check getTestSchema(testName);
    schema.preserveEmptyFields = true;
    string ediIn = check getEDIMessage(testName);
    json message = check fromEdiString(ediIn, schema);
    check saveJsonMessage(testName, message);

    string ediOut = check toEdiString(message, schema);
    check saveEDIMessage(testName, ediOut);

    ediOut = check prepareEDI(ediOut, schema);
    ediIn = check prepareEDI(ediIn, schema);

    test:assertEquals(ediOut, ediIn);
}

@test:Config {
    dataProvider: dynamicLengthTestDataProvider
}
function testDynamicLengthEDIs(string testName) returns error? {
    EdiSchema schema = check getTestSchema(testName);
    schema.preserveEmptyFields = true;
    string ediIn = check getEDIMessage(testName);
    json message = check fromEdiString(ediIn, schema);
    check saveJsonMessage(testName, message);

    string ediOut = check toEdiString(message, schema);
    check saveEDIMessage(testName, ediOut);

    ediOut = check prepareEDI(ediOut, schema);
    ediIn = check prepareEDI(ediIn, schema);

    test:assertEquals(ediOut, ediIn);
}

@test:Config {
    dataProvider: wrongDynamicLengthSchemaTestDataProvider
}
function testDynamicLengthEDIsWithWrongSchema1(string testName) returns error? {
    EdiSchema schema = check getTestSchema(testName);
    schema.preserveEmptyFields = true;
    string ediIn = check getEDIMessage(testName);
    string maxViolationError = "Input field length exceeds the maximum length specified in the segment schema";
    string minViolationError = "Input field length is less than the minimum length specified in the segment schema";
    json|error message = fromEdiString(ediIn, schema);
    if (message is error) {
        if message.message().startsWith(maxViolationError) || message.message().startsWith(minViolationError) {
            test:assertTrue(true);
        } else {
            test:assertFail("Expected error message not found");
        }
    } else {
        test:assertFail("Expected an error but got a json message");
    }
}

@test:Config
function testDenormalization() returns error? {
    json schemaJson = check io:fileReadJson("tests/resources/denormalization/normalized_schema.json");
    EdiSchema schema = check getSchema(schemaJson);
    check io:fileWriteJson("tests/resources/denormalization/denormalized_schema_output.json", schema.toJson());
}

@test:Config
function testDenormalization2() returns error? {
    json schemaJson = check io:fileReadJson("tests/resources/denormalization2/normalized_schema.json");
    EdiSchema schema = check getSchema(schemaJson);
    check io:fileWriteJson("tests/resources/denormalization2/denormalized_schema_output.json", schema.toJson());
}

function segmentTestDataProvider() returns string[][] {
    return [
        ["sample1"],
        ["sample2"],
        ["sample3"],
        ["sample4"],
        ["sample5"],
        ["sample6"],
        ["sample7"],
        ["edi-214"],
        ["x12-278"]
        // ["edi-837"],
        // ["d3a-invoic-1"],
    ];
}

function fixedLengthTestDataProvider() returns string[][] {
    return [
        ["fixed-length1"]
    ];
}

function dynamicLengthTestDataProvider() returns string[][] {
    return [
        ["dynamic-length1"]
    ];
}

function wrongDynamicLengthSchemaTestDataProvider() returns string[][] {
    return [
        ["dynamic-length2"],
        ["dynamic-length3"]
    ];
}


@test:Config {}
function testIsa02AndIsa04() returns error? {
    string isaSegment = "ISA*00*          *00*          *ZZ*VIMLY *ZZ*MAGNACARE *260415*2028*^*00501*000213133*0*P*:~";
    json schemaJson = {
        "name": "ISATest",
        "delimiters": {"segment": "~", "field": "*", "component": ":", "repetition": "^"},
        "includeSegmentCode": true,
        "segments": [
            {
                "code": "ISA",
                "tag": "InterchangeControlHeader",
                "fields": [
                    {"tag": "code", "required": true, "dataType": "string"},
                    {"tag": "ISA01__AuthorizationInformationQualifier", "required": true, "dataType": "string"},
                    {"tag": "ISA02__AuthorizationInformation", "required": true, "dataType": "string"},
                    {"tag": "ISA03__SecurityInformationQualifier", "required": true, "dataType": "string"},
                    {"tag": "ISA04__SecurityInformation", "required": true, "dataType": "string"},
                    {"tag": "ISA05__InterchangeIDQualifier", "required": true, "dataType": "string"},
                    {"tag": "ISA06__InterchangeSenderID", "required": true, "dataType": "string"},
                    {"tag": "ISA07__InterchangeIDQualifier", "required": true, "dataType": "string"},
                    {"tag": "ISA08__InterchangeReceiverID", "required": true, "dataType": "string"},
                    {"tag": "ISA09__InterchangeDate", "required": true, "dataType": "string"},
                    {"tag": "ISA10__InterchangeTime", "required": true, "dataType": "string"},
                    {"tag": "ISA11__RepetitionSeparator", "required": true, "dataType": "string"},
                    {"tag": "ISA12__InterchangeControlVersionNumber", "required": true, "dataType": "string"},
                    {"tag": "ISA13__InterchangeControlNumber", "required": true, "dataType": "string"},
                    {"tag": "ISA14__AcknowledgmentRequested", "required": true, "dataType": "string"},
                    {"tag": "ISA15__UsageIndicator", "required": true, "dataType": "string"},
                    {"tag": "ISA16__ComponentElementSeparator", "required": true, "dataType": "string"}
                ]
            }
        ]
    };
    EdiSchema schema = check getSchema(schemaJson);
    json result = check fromEdiString(isaSegment, schema);
    map<json> msg = check result.ensureType();
    map<json> isa = check msg["InterchangeControlHeader"].ensureType();
    // Whitespace-only required fields must parse without error and store as string.
    test:assertEquals(isa["ISA02__AuthorizationInformation"], "");
    test:assertEquals(isa["ISA04__SecurityInformation"], "");
    // Other fields parsed correctly.
    test:assertEquals(isa["ISA01__AuthorizationInformationQualifier"], "00");
    test:assertEquals(isa["ISA06__InterchangeSenderID"], "VIMLY");
    test:assertEquals(isa["ISA08__InterchangeReceiverID"], "MAGNACARE");
    test:assertEquals(isa["ISA13__InterchangeControlNumber"], "000213133");
}
