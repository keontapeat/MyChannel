//
//  Date+Extensions.swift
//  MyChannel
//  
//  Created by AI Assistant on 7/9/25.
//

import Foundation

extension Date {
    func timeAgoSince(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: self)
    }
    
    static func from(timeIntervalSince1970: TimeInterval) -> Date {
        return Date(timeIntervalSince1970: timeIntervalSince1970)
    }
    
    var timeAgoDisplay: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}