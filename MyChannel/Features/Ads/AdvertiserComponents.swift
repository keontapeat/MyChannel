// ⚡ PERFORMANCE: Extracted from AdvertiserDashboardView.swift — independent compilation unit.
// All stat cards, metric rows, demographic bars compile in parallel with the 551-line main view.
import SwiftUI

// MARK: - Supporting Views

struct AdvertiserStatCard: View {
    let title: String
    let value: String
    let change: Double
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.headline)
            HStack(spacing: 4) {
                Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.caption2)
                Text("\(abs(change), specifier: "%.1f")%")
                    .font(.caption2)
            }
            .foregroundColor(change >= 0 ? .green : .red)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(8)
    }
}

struct AdvertiserQuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(8)
        }
    }
}

struct CampaignRow: View {
    let campaign: AdvertiserCampaign
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(campaign.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(campaign.status.rawValue)
                    .font(.caption)
                    .foregroundColor(campaign.status == .active ? .green : .orange)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("$\(campaign.spent, specifier: "%.2f")")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("of $\(campaign.budget, specifier: "%.2f")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(8)
    }
}

struct CampaignDetailCard: View {
    let campaign: AdvertiserCampaign
    let viewModel: AdvertiserViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(campaign.name)
                    .font(.headline)
                Spacer()
                Menu {
                    Button("Edit") { }
                    Button("Pause") { }
                    Button("Duplicate") { }
                    Button("Delete", role: .destructive) { }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
            
            HStack(spacing: 16) {
                MetricPill(label: "Impressions", value: "\(campaign.impressions)")
                MetricPill(label: "Clicks", value: "\(campaign.clicks)")
                MetricPill(label: "CTR", value: String(format: "%.1f%%", campaign.ctr))
            }
            
            ProgressView(value: campaign.spent / campaign.budget)
                .tint(.blue)
            
            HStack {
                Text("Spent: " + String(format: "$%.2f", campaign.spent))
                    .font(.caption)
                Spacer()
                Text("Budget: " + String(format: "$%.2f", campaign.budget))
                    .font(.caption)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct MetricPill: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(6)
    }
}

struct AdvertiserMetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct FunnelStage: View {
    let label: String
    let value: Int
    let percentage: Double
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.subheadline)
                Spacer()
                Text("\(value)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("(\(percentage, specifier: "%.1f")%)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(.tertiarySystemBackground))
                    Rectangle()
                        .fill(color)
                        .frame(width: geo.size.width * (percentage / 100))
                }
            }
            .frame(height: 8)
            .cornerRadius(4)
        }
    }
}

struct DemographicBar: View {
    let label: String
    let percentage: Double
    let color: Color
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .frame(width: 50, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(.tertiarySystemBackground))
                    Rectangle()
                        .fill(color)
                        .frame(width: geo.size.width * (percentage / 100))
                }
            }
            .frame(height: 20)
            .cornerRadius(4)
            Text("\(percentage, specifier: "%.0f")%")
                .font(.caption)
                .fontWeight(.semibold)
                .frame(width: 40, alignment: .trailing)
        }
    }
}

struct AdvertiserPaymentMethodRow: View {
    let method: PaymentMethod
    
    var body: some View {
        HStack {
            Image(systemName: method.type == .card ? "creditcard.fill" : "building.columns.fill")
                .foregroundColor(.blue)
            VStack(alignment: .leading, spacing: 4) {
                Text(method.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("••••" + method.last4)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if method.isDefault {
                Text("Default")
                    .font(.caption)
                    .foregroundColor(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(4)
            }
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(8)
    }
}

struct TransactionRow: View {
    let transaction: Transaction
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.description)
                    .font(.subheadline)
                Text(transaction.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text(transaction.type == .credit ? "+$\(transaction.amount, specifier: "%.2f")" : "-$\(transaction.amount, specifier: "%.2f")")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(transaction.type == .credit ? .green : .primary)
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(8)
    }
}

struct AudienceCard: View {
    let audience: Audience
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(audience.name)
                    .font(.headline)
                Spacer()
                Text("\(audience.size) users")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(audience.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            HStack {
                ForEach(audience.tags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct CreativeCard: View {
    let creative: Creative
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AsyncImage(url: URL(string: creative.thumbnailUrl)) { image in
                image.resizable()
            } placeholder: {
                Color.gray
            }
            .aspectRatio(16/9, contentMode: .fill)
            .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(creative.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                HStack {
                    Text("\(creative.ctr, specifier: "%.1f")% CTR")
                        .font(.caption2)
                        .foregroundColor(.green)
                    Spacer()
                    Image(systemName: creative.status == .approved ? "checkmark.circle.fill" : "clock.fill")
                        .font(.caption2)
                        .foregroundColor(creative.status == .approved ? .green : .orange)
                }
            }
        }
        .padding(8)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct AdvertiserEmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: action) {
                Text(actionTitle)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }
}

