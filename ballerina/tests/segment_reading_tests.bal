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
function testQualifierBasedLoopDiscrimination() returns error? {
    json schemaJson = check io:fileReadJson("tests/resources/qualifier-discrimination/schema.json");
    EdiSchema schema = check getSchema(schemaJson);
    string ediText = check io:fileReadString("tests/resources/qualifier-discrimination/message.edi");
    json result = check fromEdiString(ediText, schema);

    // LoopTypeA should contain two ENT*A entries (not ENT*B or ENT*C)
    json loopA = check result.LoopTypeA;
    test:assertTrue(loopA is json[], "LoopTypeA should be an array");
    json[] loopAArr = <json[]>loopA;
    test:assertEquals(loopAArr.length(), 2, "LoopTypeA should have 2 occurrences (ENT*A*Alpha1 and ENT*A*Alpha2)");
    test:assertEquals(check loopAArr[0].entity.qualifier, "A", "LoopTypeA[0] qualifier should be 'A'");
    test:assertEquals(check loopAArr[1].entity.qualifier, "A", "LoopTypeA[1] qualifier should be 'A'");

    // LoopTypeB should contain two ENT*B entries
    json loopB = check result.LoopTypeB;
    test:assertTrue(loopB is json[], "LoopTypeB should be an array");
    json[] loopBArr = <json[]>loopB;
    test:assertEquals(loopBArr.length(), 2, "LoopTypeB should have 2 occurrences (ENT*B*Beta1 and ENT*B*Beta2)");
    test:assertEquals(check loopBArr[0].entity.qualifier, "B", "LoopTypeB[0] qualifier should be 'B'");

    // LoopTypeC should contain one ENT*C entry
    json loopC = check result.LoopTypeC;
    test:assertTrue(!(loopC is json[]), "LoopTypeC should not be an array (maxOccurances=1)");
    test:assertEquals(check loopC.entity.qualifier, "C", "LoopTypeC qualifier should be 'C'");
}

@test:Config
function testQualifierDiscriminationFirstOccurrenceLimitation() returns error? {
    json schemaJson = check io:fileReadJson("tests/resources/qualifier-discrimination/schema.json");
    EdiSchema schema = check getSchema(schemaJson);
    string ediText = check io:fileReadString("tests/resources/qualifier-discrimination/message_no_loopA.edi");
    json result = check fromEdiString(ediText, schema);

    json loopA = check result.LoopTypeA;
    test:assertTrue(loopA is json[], "LoopTypeA should be an array (receives ENT*B due to first-occurrence limitation)");
    json[] loopAArr = <json[]>loopA;
    test:assertEquals(loopAArr.length(), 2, "LoopTypeA incorrectly captures both ENT*B segments due to first-occurrence limitation");
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
