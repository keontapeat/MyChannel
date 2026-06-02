//
//  FeatureSlotCalendarView.swift
//  MyChannel
//
//  Month calendar showing feature-slot availability per day. Cells are tinted
//  by how full each day is; tapping a day shows exactly which ranks are taken
//  and which are open, and lets the creator pick that day as their start date.
//

import SwiftUI

struct FeatureSlotCalendarView: View {
    let initialDate: Date
    var onSelectDate: (Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var slots = FeatureSlotService.shared

    @State private var visibleMonth: Date
    @State private var selectedDay: Date

    private let calendar = Calendar.current

    init(initialDate: Date, onSelectDate: @escaping (Date) -> Void) {
        self.initialDate = initialDate
        self.onSelectDate = onSelectDate
        let start = Calendar.current.startOfDay(for: initialDate)
        _visibleMonth = State(initialValue: start)
        _selectedDay = State(initialValue: start)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    monthHeader
                    weekdayHeader
                    monthGrid
                    legend
                    selectedDayDetail
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
            .background(Color(.systemBackground))
            .navigationTitle("Slot Availability")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }.foregroundColor(.primary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Use This Day") {
                        onSelectDate(selectedDay)
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .disabled(selectedDay < calendar.startOfDay(for: Date()))
                }
            }
        }
    }

    // MARK: - Header

    private var monthHeader: some View {
        HStack {
            Button {
                shiftMonth(-1)
            } label: {
                Image(systemName: "chevron.left").font(.system(size: 16, weight: .semibold))
            }
            .disabled(isAtCurrentMonth)
            .opacity(isAtCurrentMonth ? 0.3 : 1)

            Spacer()
            Text(monthTitle)
                .font(.system(size: 17, weight: .bold))
            Spacer()

            Button { shiftMonth(1) } label: {
                Image(systemName: "chevron.right").font(.system(size: 16, weight: .semibold))
            }
        }
        .foregroundColor(.primary)
        .padding(.horizontal, 4)
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(calendar.shortWeekdaySymbols, id: \.self) { sym in
                Text(sym.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Grid

    private var monthGrid: some View {
        let days = daysInMonthGrid()
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                if let day {
                    dayCell(day)
                } else {
                    Color.clear.frame(height: 46)
                }
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let taken = slots.takenRanks(on: day)
        let availability = FeatureSlotDayAvailability(date: day, takenRanks: taken)
        let isPast = day < calendar.startOfDay(for: Date())
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDay)

        return Button {
            guard !isPast else { return }
            selectedDay = day
            HapticManager.shared.impact(style: .light)
        } label: {
            VStack(spacing: 3) {
                Text("\(calendar.component(.day, from: day))")
                    .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isPast ? Color(.tertiaryLabel) : (isSelected ? .white : .primary))
                // availability dots / count
                Text(availability.isFull ? "Full" : "\(availability.availableCount)")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(isSelected ? .white.opacity(0.9) : (availability.isFull ? .red : .green))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(cellBackground(availability: availability, isSelected: isSelected, isPast: isPast))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(isSelected ? Color(.label) : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .disabled(isPast)
    }

    private func cellBackground(availability: FeatureSlotDayAvailability, isSelected: Bool, isPast: Bool) -> Color {
        if isSelected { return Color(.label) }
        if isPast { return Color(.systemGray6).opacity(0.4) }
        if availability.isFull { return Color.red.opacity(0.14) }
        // green→amber as it fills
        return Color.green.opacity(0.06 + availability.fillFraction * 0.20)
    }

    // MARK: - Legend

    private var legend: some View {
        HStack(spacing: 16) {
            legendDot(.green, "Open")
            legendDot(.orange, "Filling up")
            legendDot(.red, "Full")
        }
        .font(.system(size: 12))
        .foregroundColor(.secondary)
        .frame(maxWidth: .infinity)
    }

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 9, height: 9)
            Text(label)
        }
    }

    // MARK: - Selected day detail

    private var selectedDayDetail: some View {
        let taken = slots.takenRanks(on: selectedDay)
        return VStack(alignment: .leading, spacing: 10) {
            Text(selectedDay.formatted(date: .complete, time: .omitted))
                .font(.system(size: 14, weight: .semibold))

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                ForEach(FeatureSlotTier.allRanks, id: \.self) { rank in
                    let isTaken = taken.contains(rank)
                    VStack(spacing: 2) {
                        Text("#\(rank)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(isTaken ? .white : .primary)
                        Text(isTaken ? "Taken" : "Open")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(isTaken ? .white.opacity(0.85) : .green)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(isTaken ? Color.red.opacity(0.7) : Color.green.opacity(0.12))
                    )
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Date math

    private var monthTitle: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: visibleMonth)
    }

    private var isAtCurrentMonth: Bool {
        calendar.isDate(visibleMonth, equalTo: Date(), toGranularity: .month)
    }

    private func shiftMonth(_ delta: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: delta, to: visibleMonth) {
            visibleMonth = newMonth
            HapticManager.shared.impact(style: .light)
        }
    }

    /// Returns leading-padded array of optional dates for the visible month grid.
    private func daysInMonthGrid() -> [Date?] {
        guard
            let monthInterval = calendar.dateInterval(of: .month, for: visibleMonth),
            let range = calendar.range(of: .day, in: .month, for: visibleMonth)
        else { return [] }

        let firstDay = monthInterval.start
        let firstWeekday = calendar.component(.weekday, from: firstDay) // 1...7
        let leadingBlanks = firstWeekday - calendar.firstWeekday
        let pad = (leadingBlanks + 7) % 7

        var cells: [Date?] = Array(repeating: nil, count: pad)
        for dayOffset in 0..<range.count {
            if let date = calendar.date(byAdding: .day, value: dayOffset, to: firstDay) {
                cells.append(calendar.startOfDay(for: date))
            }
        }
        return cells
    }
}
