//
//  StrikeReviewView.swift
//  MyChannel
//
//  Owner-only 3-Strike System — you decide who stays and who goes.
//  Unlike YouTube: you review every case, ask questions, give second chances.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

// MARK: - Strike Review View (Owner UI)

struct StrikeReviewView: View {
    @StateObject private var vm = StrikeViewModel()
    @State private var selectedFilter: StrikeFilter = .pending
    @State private var selectedCase: StrikeCase?
    @State private var pulseAnimation = false

    enum StrikeFilter: String, CaseIterable {
        case pending  = "PENDING REVIEW"
        case oneStrike = "1 STRIKE"
        case twoStrikes = "2 STRIKES ⚠️"
        case threeStrikes = "3 STRIKES 🚨"
        case resolved = "RESOLVED"
    }

    var filteredCases: [StrikeCase] {
        switch selectedFilter {
        case .pending:    return vm.cases.filter { $0.status == .pendingReview }
        case .oneStrike:  return vm.cases.filter { $0.strikeCount == 1 && $0.status == .active }
        case .twoStrikes: return vm.cases.filter { $0.strikeCount == 2 && $0.status == .active }
        case .threeStrikes: return vm.cases.filter { $0.strikeCount >= 3 }
        case .resolved:   return vm.cases.filter { $0.status == .resolved || $0.status == .banned || $0.status == .cleared }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header Banner
            strikeBanner

            // Filter Tabs
            filterTabs

            // Case List
            if filteredCases.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(filteredCases) { strikeCase in
                            StrikeCaseRow(strikeCase: strikeCase) {
                                selectedCase = strikeCase
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
        .navigationTitle("⚖️ 3-STRIKE REVIEW")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            vm.startListening()
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                pulseAnimation = true
            }
        }
        .onDisappear { vm.stopListening() }
        .sheet(item: $selectedCase) { c in
            StrikeCaseReviewSheet(strikeCase: c, vm: vm)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .refreshable { vm.startListening() }
    }

    // MARK: - Banner

    private var strikeBanner: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Circle().fill(vm.pendingCount > 0 ? Color.red : Color.green)
                    .frame(width: 7, height: 7)
                    .scaleEffect(pulseAnimation ? 1.4 : 1.0)
                Text(vm.pendingCount > 0 ? "\(vm.pendingCount) ACCOUNTS AWAITING YOUR DECISION" : "ALL CASES REVIEWED")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(vm.pendingCount > 0 ? .red.opacity(0.9) : .green.opacity(0.9))
            }
            HStack(spacing: 0) {
                StrikeBannerStat(label: "QUEUE", value: "\(vm.pendingCount)", color: .red)
                StrikeBannerStat(label: "1 STRIKE", value: "\(vm.oneStrikeCount)", color: .yellow)
                StrikeBannerStat(label: "2 STRIKES", value: "\(vm.twoStrikeCount)", color: .orange)
                StrikeBannerStat(label: "3 STRIKES", value: "\(vm.threeStrikeCount)", color: .red)
                StrikeBannerStat(label: "BANNED", value: "\(vm.bannedCount)", color: .gray)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Color(red: 0.12, green: 0.02, blue: 0.02))
    }

    // MARK: - Filter Tabs

    private var filterTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(StrikeFilter.allCases, id: \.self) { filter in
                    Button {
                        selectedFilter = filter
                    } label: {
                        Text(filter.rawValue)
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundColor(selectedFilter == filter ? .black : .secondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(selectedFilter == filter ? filterColor(filter) : Color(.systemGray6))
                    }
                }
            }
        }
    }

    private func filterColor(_ f: StrikeFilter) -> Color {
        switch f {
        case .pending: return .red
        case .oneStrike: return .yellow
        case .twoStrikes: return .orange
        case .threeStrikes: return .red
        case .resolved: return .green
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56)).foregroundColor(.green.opacity(0.4))
            Text("ALL CLEAR").font(.system(size: 16, weight: .black, design: .monospaced)).foregroundColor(.secondary)
            Text("No cases in this category").font(.system(size: 13, design: .monospaced)).foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}


// ⚡ Supporting views + data models extracted to StrikeReviewComponents.swift
