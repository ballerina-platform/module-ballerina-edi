import ballerina/test;

@test:Config {
    dataProvider:  ediModificationsDataProvider
}
function testSegmentModification(string testName) returns error? {
    EdiSchema schema = check getTestSchema(testName);
    string ediIn = check getEDIMessage(testName);
    json message = check fromEdiString(ediIn, schema);
    check saveJsonMessage(testName, message);

    string ediOut = check toEdiString(message, schema);
    string ediExpected = check getOutputEDI(testName);

    ediOut = check prepareEDI(ediOut, schema);
    ediIn = check prepareEDI(ediExpected, schema);

    test:assertEquals(ediOut, ediIn);
}

function ediModificationsDataProvider() returns string[][] {
    return [
        ["ignore_segments"]
    ];
}