/*
 Copyright 2020 Adobe. All rights reserved.
 This file is licensed to you under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License. You may obtain a copy
 of the License at http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software distributed under
 the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR REPRESENTATIONS
 OF ANY KIND, either express or implied. See the License for the specific language
 governing permissions and limitations under the License.
 */

import Foundation
import AEPIdentity

class AnalyticsRequestSerializer {

    /// Creates a Map having the VisitorIDs information (types, ids and authentication state) and serializes it.
    /// - Parameter identifiableList an array of Identifiable Type that we want to process in the analytics format.
    /// - Returns the serialized String of Indentifiable VisitorId's. Retuns empty string if Identifiable Array is empty.
    func generateAnalyticsCustomerIdString(from identifiableList: [Identifiable?]) -> String {
        guard !identifiableList.isEmpty else {
            return ""
        }
        var visitorDataMap = [String: String]()
        for identifiable in identifiableList {
            if let identifiable = identifiable, let type = identifiable.type {
                visitorDataMap[serializeIdentifierKeyForAnalyticsId(idType: type)] = identifiable.identifier
                visitorDataMap[serializeAuthenticationKeyForAnalyticsId(idType: type)] = "\(identifiable.authenticationState.rawValue)"
            }
        }

        return "&cid.\(ContextDataUtil.EncodeContextData(data: visitorDataMap))&.cid"
    }

    /// Serialize data into analytics format.
    /// - Parameter idType the idType value from the visitor ID service.
    /// - Returns idType.id, serialized indentifier key for AID
    private func serializeIdentifierKeyForAnalyticsId(idType: String) -> String {
        return "\(idType).id"
    }

    /// Serialize data into analytics format.
    /// - Parameter idType the idType value from the visitor id dervice.
    /// - Returns idType.as, serialized authentication key for AID
    private func serializeAuthenticationKeyForAnalyticsId(idType: String) -> String {
        return "\(idType).as"
    }
}
