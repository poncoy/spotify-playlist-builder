//
//  DeviceID.swift
//  LaSed
//
//  Versión: 0.1.0
//  Actualizado: 09/09/2026
//
import Foundation

enum DeviceID {
    private static let key = "com.poncoy.lased.deviceId"

    static var current: String {
        if let saved = UserDefaults.standard.string(forKey: key) {
            return saved
        }
        let new = UUID().uuidString
        UserDefaults.standard.set(new, forKey: key)
        return new
    }
}
