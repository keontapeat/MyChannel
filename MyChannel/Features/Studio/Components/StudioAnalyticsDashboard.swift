import SwiftUI
import Charts

/// Phase 17: Creator Studio Analytics Engine
/// Built using native SwiftCharts for FAANG-tier performance and fluid UI.
struct StudioAnalyticsDashboard: View {
    @State private var retentionData: [RetentionPoint] = []
    @State private var viewerData: [ViewerDataPoint] = []
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                
                // Header
                HStack {
                    Text("Analytics Engine")
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundColor(.green)
                        .font(.title2)
                }
                .padding(.horizontal)
                
                // Viewer Graph
                VStack(alignment: .leading, spacing: 8) {
                    Text("Real-Time Concurrent Viewers")
                        .font(.headline)
                        .foregroundColor(.gray)
                    
                    Chart(viewerData) { point in
                        LineMark(
                            x: .value("Time", point.time),
                            y: .value("Viewers", point.viewers)
                        )
                        .foregroundStyle(Color.blue.gradient)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        
                        AreaMark(
                            x: .value("Time", point.time),
                            y: .value("Viewers", point.viewers)
                        )
                        .foregroundStyle(LinearGradient(
                            colors: [Color.blue.opacity(0.3), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                    }
                    .frame(height: 200)
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .hour)) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(.gray.opacity(0.3))
                            AxisValueLabel(format: .dateTime.hour())
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(.gray.opacity(0.3))
                            AxisValueLabel()
                        }
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground).opacity(0.1))
                .cornerRadius(16)
                .padding(.horizontal)
                
                // Retention Curve
                VStack(alignment: .leading, spacing: 8) {
                    Text("7-Day Audience Retention")
                        .font(.headline)
                        .foregroundColor(.gray)
                    
                    Chart(retentionData) { point in
                        LineMark(
                            x: .value("Percentage of Video", point.percentage),
                            y: .value("Audience Retained", point.retention)
                        )
                        .foregroundStyle(Color.green.gradient)
                        .interpolationMethod(.monotone)
                    }
                    .frame(height: 200)
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 5)) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(.gray.opacity(0.3))
                            if let intVal = value.as(Int.self) {
                                AxisValueLabel("\(intVal)%")
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(.gray.opacity(0.3))
                            AxisValueLabel()
                        }
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground).opacity(0.1))
                .cornerRadius(16)
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            loadMockData()
        }
    }
    
    private func loadMockData() {
        // Hydrate with Phase 17 data
        let now = Date()
        viewerData = (0..<24).map { hour in
            let date = Calendar.current.date(byAdding: .hour, value: -24 + hour, to: now)!
            let viewers = Int.random(in: 100...5000)
            return ViewerDataPoint(time: date, viewers: viewers)
        }
        
        var currentRetention = 100.0
        retentionData = (0...100).map { percentage in
            if percentage > 0 {
                // Decay
                currentRetention *= Double.random(in: 0.95...0.99)
            }
            return RetentionPoint(percentage: percentage, retention: currentRetention)
        }
    }
}

struct ViewerDataPoint: Identifiable {
    let id = UUID()
    let time: Date
    let viewers: Int
}

struct RetentionPoint: Identifiable {
    let id = UUID()
    let percentage: Int
    let retention: Double
}

#Preview {
    StudioAnalyticsDashboard()
}
