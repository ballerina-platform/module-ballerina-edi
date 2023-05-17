// Copyright (c) 2020 WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
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

import ballerina/jballerina.java;

// Configurations
configurable boolean enabled = false;
configurable string provider = "";
configurable boolean metricsEnabled = false;
configurable string metricsReporter = "";
configurable boolean tracingEnabled = false;
configurable string tracingProvider = "";

function init() returns error? {
    boolean isMissingMetricsReporter = ((enabled || metricsEnabled) && (provider == "" && metricsReporter == ""));
    boolean isMissingTracingProvider = ((enabled || tracingEnabled) && (provider == "" && tracingProvider == ""));
    if (isMissingMetricsReporter || isMissingTracingProvider) {
        string[] enabledObservers = [];
        string[] missingProviders = [];
        if (isMissingMetricsReporter) {
            enabledObservers.push("metrics");
            missingProviders.push("metrics reporter");
        }
        if (isMissingTracingProvider) {
            enabledObservers.push("tracing");
            missingProviders.push("tracing provider");
        }
        return error("Observability (" + " and ".join(...enabledObservers) + ") enabled without " +
            " and ".join(...missingProviders) + ". Please visit https://central.ballerina.io/ballerina/observe for " +
            "the list of officially supported Observability providers.");
    }

    externInitializeModule();
}

# Check whether observability is enabled.
# + return -  observability enabled/disabled.
public isolated function isObservabilityEnabled() returns boolean = @java:Method {
    name: "isObservabilityEnabled",
    'class: "io.ballerina.runtime.observability.ObserveUtils"
} external;

# Check whether metrics is enabled.
# + return -  metrics enabled/disabled.
public isolated function isMetricsEnabled() returns boolean = @java:Method {
    name: "isMetricsEnabled",
    'class: "io.ballerina.runtime.observability.ObserveUtils"
} external;

# Retrieve metrics provider.
# + return - metrics provider.
public isolated function getMetricsProvider() returns string = @java:Method {
    name: "getMetricsProvider",
    'class: "io.ballerina.runtime.observability.ObserveUtils"
} external;

# Retrieve metrics reporter.
# + return - metrics reporter.
public isolated function getMetricsReporter() returns string = @java:Method {
    name: "getMetricsReporter",
    'class: "io.ballerina.runtime.observability.ObserveUtils"
} external;

# Check whether tracing is enabled.
# + return - tracing enabled/disabled.
public isolated function isTracingEnabled() returns boolean = @java:Method {
    name: "isTracingEnabled",
    'class: "io.ballerina.runtime.observability.ObserveUtils"
} external;

# Retrieve tracer provider.
# + return - Tracing provider.
public isolated function getTracingProvider() returns string = @java:Method {
    name: "getTracingProvider",
    'class: "io.ballerina.runtime.observability.ObserveUtils"
} external;

# Initializing the module.
function externInitializeModule() = @java:Method {
    'class: "io.ballerina.stdlib.observe.nativeimpl.Utils",
    name: "initializeModule"
} external;
