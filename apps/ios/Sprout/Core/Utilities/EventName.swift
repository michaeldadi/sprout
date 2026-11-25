//
//  EventName.swift
//  Sprout
//
//  Created by Michael Dadi on 8/21/25.
//

enum PushNotificationKey: String {
    case eventName = "event_name"
    // Add other keys here
}

extension Dictionary where Key == String, Value == Any {
  init(eventName: String, properties: [String: Any]? = nil) {
    self.init()
    self[PushNotificationKey.eventName.rawValue] = eventName
     
    if let properties = properties {
      for (key, value) in properties {
        self[key] = value
      }
    }
  }
}
