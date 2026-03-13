// Copyright (c) 2026 WSO2 LLC. (http://www.wso2.org) All Rights Reserved.
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

// ── X12 Envelope Types ────────────────────────────────────────────────────────

# Represents the X12 ISA (Interchange Control Header) segment.
#
# + authInfoQualifier - Authorization information qualifier (ISA01)
# + authInfo - Authorization information (ISA02)
# + securityQualifier - Security information qualifier (ISA03)
# + securityInfo - Security information (ISA04)
# + senderQualifier - Interchange sender ID qualifier (ISA05)
# + senderId - Interchange sender ID (ISA06)
# + receiverQualifier - Interchange receiver ID qualifier (ISA07)
# + receiverId - Interchange receiver ID (ISA08)
# + date - Interchange date (ISA09)
# + time - Interchange time (ISA10)
# + version - Interchange control version number (ISA12)
# + controlNumber - Interchange control number (ISA13)
# + usageIndicator - Usage indicator: T=Test, P=Production, I=Information (ISA15)
public type X12ISA record {|
    string authInfoQualifier;
    string authInfo;
    string securityQualifier;
    string securityInfo;
    string senderQualifier;
    string senderId;
    string receiverQualifier;
    string receiverId;
    string date;
    string time;
    string version;
    string controlNumber;
    string usageIndicator;
|};

# Represents the X12 GS (Functional Group Header) segment.
#
# + functionalIdentifier - Functional identifier code (GS01)
# + senderId - Application sender's code (GS02)
# + receiverId - Application receiver's code (GS03)
# + date - Date (GS04)
# + time - Time (GS05)
# + controlNumber - Group control number (GS06)
# + version - Responsible agency code + version/release/industry identifier code (GS07+GS08)
public type X12GS record {|
    string functionalIdentifier;
    string senderId;
    string receiverId;
    string date;
    string time;
    string controlNumber;
    string version;
|};

# Represents parsed X12 interchange and functional-group envelope headers.
#
# + isa - Interchange Control Header (ISA segment)
# + gs - Functional Group Header (GS segment), present when available
public type X12Headers record {|
    X12ISA isa;
    X12GS gs?;
|};

# Represents the X12 SE (Transaction Set Trailer) segment.
#
# + segmentCount - Number of included segments (SE01)
# + controlNumber - Transaction set control number (SE02)
public type X12SE record {|
    int segmentCount;
    string controlNumber;
|};

# Represents parsed X12 transaction set trailer.
#
# + se - Transaction Set Trailer (SE segment)
public type X12Trailers record {|
    X12SE se;
|};

// ── EDIFACT Envelope Types ────────────────────────────────────────────────────

# Represents the EDIFACT UNB (Interchange Header) segment.
#
# + syntaxIdentifier - Syntax identifier (UNB S001)
# + sender - Interchange sender (UNB S002)
# + recipient - Interchange recipient (UNB S003)
# + dateAndTime - Date/time of preparation (UNB S004)
# + controlRef - Interchange control reference (UNB 0020)
public type EdifactUNB record {|
    record {|
        string syntaxId;
        string syntaxVersion;
    |} syntaxIdentifier;
    record {|
        string id;
        string qualifier;
    |} sender;
    record {|
        string id;
        string qualifier;
    |} recipient;
    record {|
        string date;
        string time;
    |} dateAndTime;
    string controlRef;
|};

# Represents the EDIFACT UNH (Message Header) segment.
#
# + messageRef - Message reference number (UNH 0062)
# + messageIdentifier - Message identifier (UNH S009)
public type EdifactUNH record {|
    string messageRef;
    record {|
        string messageType;
        string version;
        string release;
        string controlAgency;
    |} messageIdentifier;
|};

# Represents parsed EDIFACT interchange and message envelope headers.
#
# + unb - Interchange Header (UNB segment)
# + unh - Message Header (UNH segment), present when available
public type EdifactHeaders record {|
    EdifactUNB unb;
    EdifactUNH unh?;
|};

# Represents the EDIFACT UNT (Message Trailer) segment.
#
# + segmentCount - Number of segments in the message including UNH and UNT (UNT 0074)
# + messageRef - Message reference number matching UNH (UNT 0062)
public type EdifactUNT record {|
    int segmentCount;
    string messageRef;
|};

# Represents parsed EDIFACT message trailer.
#
# + unt - Message Trailer (UNT segment)
public type EdifactTrailers record {|
    EdifactUNT unt;
|};

// ── Generic Envelope Result ───────────────────────────────────────────────────

# Result type returned by `envelopeFromEdiString`. Contains the parsed envelope
# header and trailer segments with the transaction body left as raw strings.
#
# + headers - Parsed header segments (mapped against schema.headerSegments)
# + body - Raw unparsed body segment strings
# + trailers - Parsed trailer segments (mapped against schema.trailerSegments)
public type EdiEnvelope record {|
    json headers;
    string[] body;
    json trailers;
|};
