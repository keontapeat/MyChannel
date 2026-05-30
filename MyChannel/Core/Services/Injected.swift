//
//  Injected.swift
//  MyChannel
//
//  Ultra-lightweight @Injected property wrapper for Enterprise DI
//

import Foundation

/// Property wrapper to magically inject dependencies from the DependencyContainer
@propertyWrapper
@MainActor
struct Injected<Service> {
    private var service: Service
    
    init() {
        self.service = DependencyContainer.shared.resolve(Service.self)
    }
    
    var wrappedValue: Service {
        get { return service }
        mutating set { service = newValue } // Allows replacing during Unit Tests
    }
}
