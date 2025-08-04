//
//  SafeStateManager.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI
import Combine

// MARK: - Safe State Management
@MainActor
class SafeStateManager: ObservableObject {
    private var cancellables = Set<AnyCancellable>()
    private let stateQueue = DispatchQueue(label: "safe.state.queue", qos: .userInitiated)
    
    /// Safely update state with debouncing to prevent rapid changes
    func safeUpdate<T>(_ keyPath: ReferenceWritableKeyPath<SafeStateManager, T>, to value: T, delay: TimeInterval = 0.05) {
        stateQueue.asyncAfter(deadline: .now() + delay) { [weak self] in
            DispatchQueue.main.async {
                self?[keyPath: keyPath] = value
            }
        }
    }
    
    /// Batch multiple state updates to prevent multiple re-renders
    func batchUpdates(_ updates: @escaping () -> Void) {
        DispatchQueue.main.async {
            updates()
        }
    }
}

// MARK: - Safe Property Wrapper for UI State
@propertyWrapper
struct SafeState<T: Equatable>: DynamicProperty {
    @State private var value: T
    @State private var isUpdating = false
    
    init(wrappedValue: T) {
        self._value = State(initialValue: wrappedValue)
    }
    
    var wrappedValue: T {
        get { value }
        nonmutating set {
            // Prevent rapid state changes
            guard !isUpdating else { return }
            
            isUpdating = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                self.value = newValue
                self.isUpdating = false
            }
        }
    }
    
    var projectedValue: Binding<T> {
        Binding(
            get: { wrappedValue },
            set: { wrappedValue = $0 }
        )
    }
}

// MARK: - Network State Protection
class NetworkStateProtector: ObservableObject {
    @Published var isLoading = false
    @Published var hasError = false
    @Published var errorMessage: String?
    
    private var activeRequests = Set<UUID>()
    
    func performSafeNetworkOperation<T>(
        operation: @escaping () async throws -> T,
        onSuccess: @escaping (T) -> Void,
        onError: @escaping (Error) -> Void = { _ in }
    ) {
        let requestId = UUID()
        activeRequests.insert(requestId)
        
        Task { @MainActor in
            isLoading = true
            hasError = false
            errorMessage = nil
            
            do {
                let result = try await operation()
                
                // Only update if this request is still active
                if activeRequests.contains(requestId) {
                    onSuccess(result)
                }
            } catch {
                if activeRequests.contains(requestId) {
                    hasError = true
                    errorMessage = error.localizedDescription
                    onError(error)
                }
            }
            
            activeRequests.remove(requestId)
            if activeRequests.isEmpty {
                isLoading = false
            }
        }
    }
    
    func cancelAllRequests() {
        activeRequests.removeAll()
        isLoading = false
    }
}