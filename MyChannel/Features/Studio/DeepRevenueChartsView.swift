//
//  DeepRevenueChartsView.swift
//  MyChannel
//
//  Created by Keonta.
//

import SwiftUI
import Charts

struct RevenueDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let amount: Double
    let source: String
}

struct DeepRevenueChartsView: View {
    @State private var selectedRange = "Last 28 Days"
    let ranges = ["Last 7 Days", "Last 28 Days", "Last 90 Days", "Year to Date"]
    
    // Sample Data
    let data: [RevenueDataPoint] = [
        RevenueDataPoint(date: Calendar.current.date(byAdding: .day, value: -6, to: Date())!, amount: 120, source: "Ads"),
        RevenueDataPoint(date: Calendar.current.date(byAdding: .day, value: -5, to: Date())!, amount: 150, source: "Ads"),
        RevenueDataPoint(date: Calendar.current.date(byAdding: .day, value: -4, to: Date())!, amount: 200, source: "Sponsorships"),
        RevenueDataPoint(date: Calendar.current.date(byAdding: .day, value: -3, to: Date())!, amount: 180, source: "Ads"),
        RevenueDataPoint(date: Calendar.current.date(byAdding: .day, value: -2, to: Date())!, amount: 220, source: "Super Chat"),
        RevenueDataPoint(date: Calendar.current.date(byAdding: .day, value: -1, to: Date())!, amount: 300, source: "Memberships"),
        RevenueDataPoint(date: Date(), amount: 250, source: "Ads")
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Picker("Date Range", selection: $selectedRange) {
                        ForEach(ranges, id: \.self) { range in
                            Text(range).tag(range)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Estimated Revenue")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("$1,420.00")
                            .font(.system(size: 36, weight: .bold))
                        
                        Text("+15% from previous period")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    
                    Chart(data) { point in
                        BarMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("Revenue", point.amount)
                        )
                        .foregroundStyle(by: .value("Source", point.source))
                    }
                    .frame(height: 300)
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 2)
                    .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Revenue Sources")
                            .font(.headline)
                        
                        HStack {
                            Text("Ads")
                            Spacer()
                            Text("$700.00")
                        }
                        HStack {
                            Text("Sponsorships")
                            Spacer()
                            Text("$200.00")
                        }
                        HStack {
                            Text("Memberships")
                            Spacer()
                            Text("$300.00")
                        }
                        HStack {
                            Text("Super Chat")
                            Spacer()
                            Text("$220.00")
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 2)
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Deep Revenue Intel")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(.systemGroupedBackground))
        }
    }
}

#Preview {
    DeepRevenueChartsView()
}
