//
//  View+Notifications.swift
//  MyChannel
//
//  Created by AI Assistant on 7/9/25.
//

import SwiftUI

extension View {
    func modernToast<Content: View>(
        isPresented: Binding<Bool>,
        duration: TimeInterval = 3.0,
        @ViewBuilder content: () -> Content
    ) -> some View {
        self.overlay(
            ZStack {
                if isPresented.wrappedValue {
                    VStack {
                        content()
                            .padding()
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                        
                        Spacer()
                    }
                    .padding(.top, 50)
                    .padding(.horizontal, 20)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isPresented.wrappedValue = false
                            }
                        }
                    }
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isPresented.wrappedValue)
        )
    }
    
    func modernAlert<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        self.overlay(
            ZStack {
                if isPresented.wrappedValue {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isPresented.wrappedValue = false
                            }
                        }
                    
                    content()
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isPresented.wrappedValue)
        )
    }
}