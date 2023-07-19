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

    ediOut = prepareEDI(ediOut, schema);
    ediIn = prepareEDI(ediIn, schema);

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

    ediOut = prepareEDI(ediOut, schema);
    ediIn = prepareEDI(ediIn, schema);

    test:assertEquals(ediOut, ediIn);
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
        ["edi-214"]
        // ["edi-837"],
        // ["d3a-invoic-1"],
    ];
}

function fixedLengthTestDataProvider() returns string[][] {
    return [
        ["fixed-length1"]
    ];
}
