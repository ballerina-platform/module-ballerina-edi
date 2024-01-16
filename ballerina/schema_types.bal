// Copyright (c) 2023 WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
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

# Record for representing EDI schema.
#
# + name - Name of the schema. This will be used as the main record name by the code generation tool.  
#
# + tag - Tag for the root element. Can be same as the name.  
#
# + delimiters - Delimiters used to separate EDI segments, fields, components, etc.  
#
# + ignoreSegments - List of segment schemas to be ignored when matching a EDI text. 
# For example, if it is necessary to process X12 transaction sets only, without ISA as GS segments,
# and if the schema contains ISA and GS segments as well, ISA and GS can be provided as ignoreSegments.
#
# + preserveEmptyFields - Indicates how to process EDI fields, components and subcomponents containing empty values.
# true: Includes fields, components and subcomponents with empty values in the generated JSON.
# String values will be represented as empty strings. 
# Multi-value fields (i.e. repeats) will be represented as empty arrays.
# All other types will be represented as null.
# false: Omits fields, components and subcomponents with empty values.
# 
# + includeSegmentCode - Indicates whether or not to include the segment code as a field in output JSON values.
#
# + segments - Array of segment and segment group schemas
# + segmentDefinitions - Map of segment definitions indexed by the segment code
public type EdiSchema record {|
    string name;
    string tag = "Root_mapping";

    record {|
        string segment;
        string 'field;
        string component;
        string subcomponent = "NOT_USED";
        string repetition = "NOT_USED";
        string decimalSeparator?;
    |} delimiters;

    string[] ignoreSegments = [];

    boolean preserveEmptyFields = true;
    boolean includeSegmentCode = true;

    EdiUnitSchema[] segments = [];
    map<EdiSegSchema> segmentDefinitions = {};
|};

public type EdiUnitSchema EdiSegSchema|EdiSegGroupSchema|EdiUnitRef;

public type EdiSegGroupSchema record {|
    string tag;
    int minOccurances = 0;
    int maxOccurances = 1;
    EdiUnitSchema[] segments = [];
|};

public type EdiSegSchema record {|
    string code;
    string tag;
    boolean truncatable = true;
    int minOccurances = 0;
    int maxOccurances = 1;
    EdiFieldSchema[] fields = [];
|};

public type EdiUnitRef record {|
    string ref;
    string tag?;
    int minOccurances = 0;
    int maxOccurances = 1;
|};

public type EdiFieldSchema record {|
    string tag;
    boolean repeat = false;
    boolean required = false;
    boolean truncatable = true;
    EdiDataType dataType = STRING;
    int startIndex = -1;
    Range|int length = -1;
    EdiComponentSchema[] components = [];
|};

public type Range record {|
    int min = 0;
    int max = -1;
|};

public type EdiComponentSchema record {|
    string tag;
    boolean required = false;
    boolean truncatable = true;
    EdiDataType dataType = STRING;
    EdiSubcomponentSchema[] subcomponents = [];
|};

public type EdiSubcomponentSchema record {|
    string tag;
    boolean required = false;
    EdiDataType dataType = STRING;
|};
