//
//  FlowLayout.swift
//  MyChannel
//
//  YouTube Parity: Custom flow layout for wrapping tags/chips
//  Created for MyChannel by AI Assistant
//

import SwiftUI

/// Custom layout that flows items horizontally and wraps to new lines (YouTube-style tag layout)
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        let height = rows.reduce(0) { $0 + $1.maxHeight } + CGFloat(rows.count - 1) * spacing
        return CGSize(width: proposal.width ?? 0, height: height)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for (index, size) in row.sizes.enumerated() {
                let subview = subviews[row.startIndex + index]
                subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.maxHeight + spacing
        }
    }
    
    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var currentRow = Row(startIndex: 0, sizes: [], maxHeight: 0)
        var x: CGFloat = 0
        
        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(proposal)
            
            if x + size.width > (proposal.width ?? 0) && !currentRow.sizes.isEmpty {
                rows.append(currentRow)
                currentRow = Row(startIndex: index, sizes: [], maxHeight: 0)
                x = 0
            }
            
            currentRow.sizes.append(size)
            currentRow.maxHeight = max(currentRow.maxHeight, size.height)
            x += size.width + spacing
        }
        
        if !currentRow.sizes.isEmpty {
            rows.append(currentRow)
        }
        
        return rows
    }
    
    struct Row {
        let startIndex: Int
        var sizes: [CGSize]
        var maxHeight: CGFloat
    }
}

