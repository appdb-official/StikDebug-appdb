//
//  DeviceConnectionContext.swift
//  StikJIT
//
//  Created by Stephen.
//

import Foundation

enum DeviceConnectionContext {
    static var targetIPAddress: String {
        let stored = UserDefaults.standard.string(forKey: "customTargetIP")
        if let stored, !stored.isEmpty {
            return stored
        }
        return "10.7.0.1"
    }
}
