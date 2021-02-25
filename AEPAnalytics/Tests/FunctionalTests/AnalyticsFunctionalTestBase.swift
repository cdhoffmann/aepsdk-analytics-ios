/*
 Copyright 2021 Adobe. All rights reserved.
 This file is licensed to you under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License. You may obtain a copy
 of the License at http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software distributed under
 the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR REPRESENTATIONS
 OF ANY KIND, either express or implied. See the License for the specific language
 governing permissions and limitations under the License.
 */

import XCTest
import AEPServices
@testable import AEPAnalytics
@testable import AEPCore


class AnalyticsFunctionalTestBase : XCTestCase {
    var analytics:Analytics!
    var mockRuntime: TestableExtensionRuntime!
    
    var mockDataStore: MockDataStore {
        return ServiceProvider.shared.namedKeyValueService as! MockDataStore
    }
    
    var mockNetworkService: MockNetworking? {
        return ServiceProvider.shared.networkService as? MockNetworking
    }
            
    func setupBase(disableIdRequest: Bool = true) {
        UserDefaults.clear()        
        
        ServiceProvider.shared.namedKeyValueService = MockDataStore()
        ServiceProvider.shared.networkService = MockNetworking()
        AnalyticsDatabase.dataQueueService = MockDataQueueService()
        
        if (disableIdRequest) {
            let dataStore = NamedCollectionDataStore(name: AnalyticsTestConstants.DATASTORE_NAME)
            dataStore.set(key: AnalyticsTestConstants.DataStoreKeys.IGNORE_AID, value: true)
        }
        
        // Setup default network response.
        mockNetworkService?.expectedResponse = HttpConnection(data: nil, response: HTTPURLResponse(url: URL(string: "test.com")!, statusCode: 200, httpVersion: nil, headerFields: nil), error: nil)
        
        resetExtension()
    }
    
    func resetExtension() {        
        mockRuntime = TestableExtensionRuntime()
        analytics = Analytics(runtime: mockRuntime)
        analytics.onRegistered()
    }
    
    func waitFor(interval: TimeInterval) {
        let expectation = XCTestExpectation()
        DispatchQueue.global().asyncAfter(deadline: DispatchTime.now() + interval - 0.1) {
            expectation.fulfill()
        }
        wait(for:[expectation], timeout: interval)
    }
    
    func simulateConfigState(data: [String:Any], event: Event? = nil) {
        mockRuntime.simulateSharedState(extensionName: AnalyticsTestConstants.Configuration.EventDataKeys.SHARED_STATE_NAME,
                                        event: nil,
                                        data: (data, .set))
        
        let event = Event(name: "", type: EventType.configuration, source: EventSource.responseContent, data: data)
        mockRuntime.simulateComingEvent(event: event)
    }
    
    func simulateIdentityState(data: [String:Any], event: Event? = nil) {
        mockRuntime.simulateSharedState(extensionName: AnalyticsTestConstants.Identity.EventDataKeys.SHARED_STATE_NAME,
                                        event: nil,
                                        data: (data, .set))
    }
    
    func simulateLifecycleState(data: [String:Any], event: Event? = nil) {
        mockRuntime.simulateSharedState(extensionName: AnalyticsTestConstants.Lifecycle.EventDataKeys.SHARED_STATE_NAME,
                                        event: nil,
                                        data: (data, .set))
    }
    
    func simulatePlacesState(data: [String:Any], event: Event? = nil) {
        mockRuntime.simulateSharedState(extensionName: AnalyticsTestConstants.Places.EventDataKeys.SHARED_STATE_NAME,
                                        event: nil,
                                        data: (data, .set))
    }
    
    func simulateAssuranceState(event: Event? = nil) {
        let data = [
            AnalyticsTestConstants.Assurance.EventDataKeys.SESSION_ID: "session_id"
        ]
        
        mockRuntime.simulateSharedState(extensionName: AnalyticsTestConstants.Assurance.EventDataKeys.SHARED_STATE_NAME,
                                        event: nil,
                                        data: (data, .set))
    }

    func verifyHit(request: NetworkRequest?, host: String, vars: [String: Any]? = nil, contextData expectedContextData:[String: Any]? = nil) {
        guard let request = request else {
            XCTFail("Request is nil")
            return
        }
        XCTAssertTrue(request.url.absoluteString.starts(with: host))
        if let vars = vars {
            for (key, value) in vars {
                XCTAssertTrue(request.connectPayload.contains("\(key)=\(value)"))
            }
        }
                
        let actualContextData = AnalyticsRequestHelper.getContextData(source: request.connectPayload)
        let expectedContextData = expectedContextData ?? [:]
        
        XCTAssertTrue(NSDictionary(dictionary: actualContextData).isEqual(to: expectedContextData))
    }
    
    func verifyIdentityChange(aid: String?, vid: String?) {
        // Verify shared state
        XCTAssertNotNil(mockRuntime.createdSharedStates.last ?? nil)
        if let lastSharedState = mockRuntime.createdSharedStates.last {
            let actualAid = lastSharedState?[AnalyticsTestConstants.DataStoreKeys.AID] as? String ?? ""
            let actualVid = lastSharedState?[AnalyticsTestConstants.DataStoreKeys.VID] as? String ?? ""
            // For locally generated AID, we just check if aid value is of correct length
            if (aid == "*") {
                XCTAssertEqual(actualAid.count, 33)
            } else {
                XCTAssertEqual(actualAid, aid ?? "")
            }
            
            XCTAssertEqual(actualVid, vid ?? "")
        }
        
        //Verify dispatched event
        // If both aid and vid are nil, no event is dispatched
        if aid != nil, vid != nil {
            XCTAssertNotNil(mockRuntime.dispatchedEvents.last ?? nil)
            if let lastEvent = mockRuntime.dispatchedEvents.last {
                XCTAssertEqual(lastEvent.type, EventType.analytics)
                XCTAssertEqual(lastEvent.source, EventSource.responseIdentity)
                let actualAid = lastEvent.data?[AnalyticsTestConstants.DataStoreKeys.AID] as? String ?? ""
                let actualVid = lastEvent.data?[AnalyticsTestConstants.DataStoreKeys.VID] as? String ?? ""
                // For locally generated AID, we just check if aid value is of correct length
                if (aid == "*") {
                    XCTAssertEqual(actualAid.count, 33)
                } else {
                    XCTAssertEqual(actualAid, aid ?? "")
                }
                XCTAssertEqual(actualVid, vid ?? "")
            }
        }
    }
    
    func verifyQueueSize(size: Int) {
        XCTAssertNotNil(mockRuntime.dispatchedEvents.last ?? nil)
        if let lastEvent = mockRuntime.dispatchedEvents.last {
            XCTAssertEqual(lastEvent.type, EventType.analytics)
            XCTAssertEqual(lastEvent.source, EventSource.responseContent)
            
            let queueSize = lastEvent.data?[AnalyticsTestConstants.EventDataKeys.QUEUE_SIZE] as? Int ?? -1
            XCTAssertEqual(queueSize, size)
        }
    }
    
    func dispatchDefaultConfigAndIdentityStates(configData: [String:Any]? = nil) {
        let identitySharedState: [String: Any] = [
            AnalyticsTestConstants.Identity.EventDataKeys.VISITOR_ID_MID : "mid",
            AnalyticsTestConstants.Identity.EventDataKeys.VISITOR_ID_BLOB : "blob",
            AnalyticsTestConstants.Identity.EventDataKeys.VISITOR_ID_LOCATION_HINT : "lochint",
        ]
        simulateIdentityState(data: identitySharedState)
        
        var configSharedState: [String: Any] = [
            AnalyticsTestConstants.Configuration.EventDataKeys.ANALYTICS_SERVER : "test.com",
            AnalyticsTestConstants.Configuration.EventDataKeys.ANALYTICS_REPORT_SUITES : "rsid",
            AnalyticsTestConstants.Configuration.EventDataKeys.GLOBAL_PRIVACY : "optedin",
            AnalyticsTestConstants.Configuration.EventDataKeys.MARKETING_CLOUD_ORGID_KEY : "orgid",
            AnalyticsTestConstants.Configuration.EventDataKeys.ANALYTICS_BATCH_LIMIT : 0,
            AnalyticsTestConstants.Configuration.EventDataKeys.ANALYTICS_OFFLINE_TRACKING : true,
            AnalyticsTestConstants.Configuration.EventDataKeys.ANALYTICS_BACKDATE_PREVIOUS_SESSION : true,
            AnalyticsTestConstants.Configuration.EventDataKeys.ANALYTICS_LAUNCH_HIT_DELAY : 0
        ]
        if let configData = configData {
            configSharedState.merge(configData) { (_, newValue) in
                return newValue
            }
        }
        simulateConfigState(data: configSharedState)
    }
}
