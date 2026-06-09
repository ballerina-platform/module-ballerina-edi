// Copyright (c) 2026 WSO2 LLC. (http://www.wso2.org).
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

# Interchange Control Header (X12 ISA segment).
#
# + authInfoQualifier - ISA01 — Authorization Information Qualifier
# + authInfo - ISA02 — Authorization Information
# + securityQualifier - ISA03 — Security Information Qualifier
# + securityInfo - ISA04 — Security Information
# + senderQualifier - ISA05 — Interchange ID Qualifier (sender)
# + senderId - ISA06 — Interchange Sender ID
# + receiverQualifier - ISA07 — Interchange ID Qualifier (receiver)
# + receiverId - ISA08 — Interchange Receiver ID
# + date - ISA09 — Interchange Date (YYMMDD)
# + time - ISA10 — Interchange Time (HHMM)
# + version - ISA12 — Interchange Control Version Number
# + controlNumber - ISA13 — Interchange Control Number
# + usageIndicator - ISA15 — Usage Indicator (P=production, T=test)
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

# Functional Group Header (X12 GS segment).
#
# + functionalIdentifier - GS01 — Functional Identifier Code
# + senderId - GS02 — Application Sender's Code
# + receiverId - GS03 — Application Receiver's Code
# + date - GS04 — Date (CCYYMMDD)
# + time - GS05 — Time (HHMM)
# + controlNumber - GS06 — Group Control Number
# + version - GS08 — Version / Release / Industry Identifier Code
public type X12GS record {|
    string functionalIdentifier;
    string senderId;
    string receiverId;
    string date;
    string time;
    string controlNumber;
    string version;
|};

# X12 envelope headers returned by `x12HeadersFromEdiString` or
# `x12HeadersFromEdiFile`. Contains ISA (always present) and optionally GS
# (when a functional group header follows the interchange header).
#
# + isa - Parsed ISA segment (always present)
# + gs - Parsed GS segment when one follows the ISA, otherwise nil
public type X12Headers record {|
    X12ISA isa;
    X12GS gs?;
|};

# Syntax identifier composite (UNB S001 — UNB.0001 / UNB.0002).
#
# + syntaxId - Syntax identifier (UNB.0001), e.g. "UNOA"
# + syntaxVersion - Syntax version number (UNB.0002), e.g. "3"
public type EdifactSyntaxIdentifier record {|
    string syntaxId;
    string syntaxVersion;
|};

# Interchange party composite, used for both the sender (UNB S002) and the
# recipient (UNB S003).
#
# + id - Interchange party identifier
# + qualifier - Interchange party identifier code qualifier
public type EdifactInterchangeParty record {|
    string id;
    string qualifier;
|};

# Date/time of preparation composite (UNB S004 — UNB.0017 / UNB.0019).
#
# + date - Date of preparation (UNB.0017), e.g. "210527"
# + time - Time of preparation (UNB.0019), e.g. "1200"
public type EdifactDateTime record {|
    string date;
    string time;
|};

# Interchange Header (EDIFACT UNB segment).
#
# + syntaxIdentifier - UNB S001 — Syntax identifier composite
# + sender - UNB S002 — Interchange sender composite
# + recipient - UNB S003 — Interchange recipient composite
# + dateAndTime - UNB S004 — Preparation date/time composite
# + controlRef - UNB 0020 — Interchange control reference (mandatory)
public type EdifactUNB record {|
    EdifactSyntaxIdentifier syntaxIdentifier;
    EdifactInterchangeParty sender;
    EdifactInterchangeParty recipient;
    EdifactDateTime dateAndTime;
    string controlRef;
|};

# Message identifier composite (UNH S009 — UNH.0065 / 0052 / 0054 / 0051).
#
# + messageType - Message type identifier (UNH.0065), e.g. "ORDERS"
# + version - Message version number (UNH.0052), e.g. "D"
# + release - Message release number (UNH.0054), e.g. "03A"
# + controlAgency - Controlling agency (UNH.0051), typically "UN"
public type EdifactMessageIdentifier record {|
    string messageType;
    string version;
    string release;
    string controlAgency;
|};

# Message Header (EDIFACT UNH segment).
#
# + messageRef - UNH 0062 — Message reference number
# + messageIdentifier - UNH S009 — Message identifier composite
public type EdifactUNH record {|
    string messageRef;
    EdifactMessageIdentifier messageIdentifier;
|};

# EDIFACT envelope headers returned by `edifactHeadersFromEdiString` or
# `edifactHeadersFromEdiFile`. Contains UNB (always present) and optionally UNH
# (when a message header follows the interchange header).
#
# + unb - Parsed UNB segment (always present)
# + unh - Parsed UNH segment when one follows the UNB, otherwise nil
public type EdifactHeaders record {|
    EdifactUNB unb;
    EdifactUNH unh?;
|};

# A parsed EDI interchange containing the full envelope hierarchy.
#
# The schema's `envelope.group` selects which collection carries the
# transactions: `groups` when a group level is defined (e.g., GS/GE for X12),
# or `transactions` when it is absent (e.g., EDIFACT without UNG/UNE).
# `interchangeFromEdiString` populates only the schema-selected field, and
# `interchangeToEdiString` reads only that field — the other is ignored, so a
# hand-built value that sets both serialises using the schema-selected one.
#
# + interchangeHeader - Parsed interchange header (e.g. ISA / UNB) as JSON
# + groups - Parsed functional groups when `envelope.group` is defined
# + transactions - Parsed transactions when `envelope.group` is absent
# + interchangeTrailer - Parsed interchange trailer (e.g. IEA / UNZ) as JSON
public type EdiInterchange record {|
    json interchangeHeader;
    EdiFunctionalGroup[] groups?;
    EdiTransaction[] transactions?;
    json interchangeTrailer;
|};

# A functional group within an interchange (e.g., GS ... GE for X12).
#
# + groupHeader - Parsed group header (GS) as JSON
# + transactions - Transactions enclosed by this group
# + groupTrailer - Parsed group trailer (GE) as JSON
public type EdiFunctionalGroup record {|
    json groupHeader;
    EdiTransaction[] transactions;
    json groupTrailer;
|};

# A single transaction (or message) within the envelope.
# `body` is the parsed transaction content as JSON, or an `error` when the body
# could not be parsed (fail-safe: a malformed body does not abort the rest of
# the interchange).
#
# + transactionHeader - Parsed transaction header (e.g. ST / UNH) as JSON
# + body - Parsed transaction body as JSON, or the parse error if the body was malformed
# + transactionTrailer - Parsed transaction trailer (e.g. SE / UNT) as JSON
public type EdiTransaction record {|
    json transactionHeader;
    json|error body;
    json transactionTrailer;
|};
