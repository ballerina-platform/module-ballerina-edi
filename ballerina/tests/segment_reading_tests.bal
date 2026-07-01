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

@test:Config
function testMultiTransactionMerge() returns error? {
    EdiSchema schema = check getTestSchema("multi-txn-834");
    string ediText = check getEDIMessage("multi-txn-834");

    json result = check fromEdiString(ediText, schema);

    json members = check result.members;
    test:assertTrue(members is json[], "members field should be a JSON array");
    json[] memberList = <json[]>members;
    test:assertEquals(memberList.length(), 2, "Two ST/SE transaction sets should produce two merged members");

    // Member from the first transaction set (ST*834*0001)
    test:assertEquals(check memberList[0].NM103__MemberLastName, "DOE");
    test:assertEquals(check memberList[0].NM104__MemberFirstName, "JOHN");

    // Member from the second transaction set (ST*834*0002)
    test:assertEquals(check memberList[1].NM103__MemberLastName, "SMITH");
    test:assertEquals(check memberList[1].NM104__MemberFirstName, "JANE");

    // REF is present only in transaction 2: it must survive the merge (key absent from base).
    json ref = check result.REF;
    test:assertFalse(ref is (), "REF segment from transaction 2 must not be dropped during merge");
    test:assertEquals(check ref.REF01__ReferenceIdentificationQualifier, "1L");
    test:assertEquals(check ref.REF02__MemberGroupOrPolicyNumber, "GRP002");
}
