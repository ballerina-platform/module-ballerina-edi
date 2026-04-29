isolated function denormalizeSchema(json schema) returns Error? {
    if !(schema is map<json>) {
        return error Error("Schema is not valid.");
    }
    if !schema.hasKey("segmentDefinitions") {
        // This should be a normalized schema
        return;
    }
    json segmentDefinitions = schema.get("segmentDefinitions");
    if !(segmentDefinitions is map<json>) {
        return error Error("Provided segment definitions are not valid. Definitions: " + segmentDefinitions.toString());
    }
    if segmentDefinitions.length() == 0 {
        // This should be a normalized schema
        return;
    }
    json segments = schema.get("segments");
    if !(segments is json[]) {
        return error Error("Schema does not contain segments.");
    }
    check denormalizeSegments(segments, segmentDefinitions);

    // EDIFACT and X12 schemas converted by edi-tools heavily reuse standard
    // envelope segments (UNB, UNH, ISA, ...) via `ref`. Resolve references
    // inside every envelope level so the runtime never sees an unresolved ref.
    if schema.hasKey("envelope") {
        json envelope = schema.get("envelope");
        if envelope is map<json> {
            check denormalizeEnvelope(envelope, segmentDefinitions);
        }
    }

    _ = schema.remove("segmentDefinitions");
}

isolated function denormalizeEnvelope(map<json> envelope, map<json> defs) returns Error? {
    foreach string levelKey in ["interchange", "group", "transaction"] {
        if !envelope.hasKey(levelKey) {
            continue;
        }
        json level = envelope.get(levelKey);
        if !(level is map<json>) {
            continue;
        }
        foreach string sectionKey in ["header", "trailer"] {
            if !level.hasKey(sectionKey) {
                continue;
            }
            json section = level.get(sectionKey);
            if section is json[] {
                check denormalizeSegments(section, defs);
            }
        }
    }
}

isolated function denormalizeSegments(json[] segments, map<json> defs) returns Error? {
    foreach int i in 0...(segments.length() - 1) {
        json segment = segments[i];
        if !(segment is map<json>) {
            return error Error("Segment is not valid. Segment: " + segment.toString());
        }
        json? segmentRef = segment["ref"];
        if segmentRef is string {
            json segmentDef = defs[segmentRef];
            if !(segmentDef is map<json>) {
                return error Error(string `Segement reference not found. Reference: ${segmentRef}`);
            }
            map<json> segmentInstance = segmentDef.clone();
            json? tag = segment["tag"];
            if tag is string {
                segmentInstance["tag"] = tag;
            }
            json? min = segment["minOccurances"];
            if min is int {
                segmentInstance["minOccurances"] = min;
            }
            json? max = segment["maxOccurances"];
            if max is int {
                segmentInstance["maxOccurances"] = max;
            }
            segments[i] = segmentInstance;
        }
        json? childSegments = segment["segments"];
        if childSegments is json[] {
            check denormalizeSegments(childSegments, defs);
        }
    }    
}