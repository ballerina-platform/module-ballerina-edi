import ballerina/io;
import ballerina/file;
import ballerina/lang.regexp;

function getTestSchema(string testName) returns EdiSchema|error {
    string schemaPath = check file:joinPath("tests", "resources", testName, "schema.json");
    json schemaJson = check io:fileReadJson(schemaPath);
    EdiSchema schema = check getSchema(schemaJson);
    return schema;
}

function getEDIMessage(string testName) returns string|error {
    string inputPath = check file:joinPath("tests", "resources", testName, "message.edi");
    return check io:fileReadString(inputPath);
}

function getOutputEDI(string testName) returns string|error {
    string inputPath = check file:joinPath("tests", "resources", testName, "output.edi");
    return check io:fileReadString(inputPath);
}

function saveEDIMessage(string testName, string message) returns error? {
    string path = check file:joinPath("tests", "resources", testName, "output.edi");
    check io:fileWriteString(path, message);
}

function saveJsonMessage(string testName, json message) returns error? {
    string path = check file:joinPath("tests", "resources", testName, "output.json");
    check io:fileWriteJson(path, message);
}

function prepareEDI(string edi, EdiSchema schema) returns string|error {
    string:RegExp decSeprator = check regexp:fromString(schema.delimiters.decimalSeparator ?: ".");
    string:RegExp nulSpaces = re ` |\n|0`;
    string preparedEDI = nulSpaces.replaceAll(edi, "");
    preparedEDI = decSeprator.replaceAll(preparedEDI, "");
    return preparedEDI;
}

