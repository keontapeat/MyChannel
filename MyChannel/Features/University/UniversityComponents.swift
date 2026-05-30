// ⚡ PERFORMANCE: Extracted from UniversityHomeView.swift — independent compilation unit.
// All learning cards, certificate rows, leaderboard rows compile in parallel.
import SwiftUI

// MARK: - Supporting Card Views

struct LearningPathCard: View {
    let path: LearningPath

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: path.icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(path.color)
                .frame(width: 44, height: 44)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(path.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(.label))
                    .lineLimit(1)

                Text("\(path.videosCount) videos · \(path.estimatedHours)h")
                    .font(.system(size: 13))
                    .foregroundColor(Color(.secondaryLabel))

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(.systemFill)).frame(height: 4)
                        Capsule().fill(Color(.label).opacity(0.7))
                            .frame(width: geo.size.width * path.progress, height: 4)
                    }
                }
                .frame(height: 4)
            }

            Spacer()

            Text("\(Int(path.progress * 100))%")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Color(.secondaryLabel))
        }
        .padding(14)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separator), lineWidth: 0.5))
    }
}

struct ActivityCard: View {
    let activity: LearningActivity

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: activity.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color(.label))
                .frame(width: 36, height: 36)
                .background(Color(.secondarySystemBackground))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(activity.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(.label))

                Text(activity.timeAgo)
                    .font(.system(size: 12))
                    .foregroundColor(Color(.secondaryLabel))
            }

            Spacer()
        }
        .padding(.vertical, 10)
    }
}

struct TrendingSubjectCard: View {
    let subject: UniversitySubject

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.secondarySystemBackground))
                    .frame(width: 160, height: 90)

                Image(systemName: subject.icon)
                    .font(.system(size: 30, weight: .medium))
                    .foregroundColor(Color(.secondaryLabel))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(subject.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(.label))
                    .lineLimit(2)

                Text("\(subject.videosCount) videos")
                    .font(.system(size: 12))
                    .foregroundColor(Color(.secondaryLabel))
            }
        }
        .frame(width: 160)
        .padding(10)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separator), lineWidth: 0.5))
    }
}

struct CategoryCard: View {
    let category: SubjectCategory

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: category.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color(.label))
                .frame(width: 36, height: 36)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(category.rawValue)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(.label))
                .lineLimit(1)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(.tertiaryLabel))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separator), lineWidth: 0.5))
    }
}

struct SubjectCard: View {
    let subject: UniversitySubject

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.secondarySystemBackground))
                    .frame(height: 70)

                Image(systemName: subject.icon)
                    .font(.system(size: 26, weight: .medium))
                    .foregroundColor(Color(.secondaryLabel))
            }

            Text(subject.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(.label))
                .lineLimit(2)

            Text("\(subject.videosCount) videos")
                .font(.system(size: 11))
                .foregroundColor(Color(.secondaryLabel))
        }
        .padding(10)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separator), lineWidth: 0.5))
    }
}

struct AcademicPathMiniMap: View {
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height

            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: width * 0.18, y: height * 0.78))
                    path.addCurve(
                        to: CGPoint(x: width * 0.82, y: height * 0.30),
                        control1: CGPoint(x: width * 0.28, y: height * 0.28),
                        control2: CGPoint(x: width * 0.62, y: height * 0.88)
                    )
                }
                .stroke(Color(.systemGray4), style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [2, 10]))

                ForEach([CGPoint(x: 0.18, y: 0.78), CGPoint(x: 0.42, y: 0.55), CGPoint(x: 0.60, y: 0.33), CGPoint(x: 0.82, y: 0.30)], id: \.x) { point in
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Color(.systemGray3))
                        )
                        .position(x: width * point.x, y: height * point.y)
                }

                Circle()
                    .fill(UniversityTheme.Colors.accent)
                    .frame(width: 34, height: 34)
                    .shadow(color: UniversityTheme.Colors.accent.opacity(0.3), radius: 8, x: 0, y: 4)
                    .position(x: width * 0.56, y: height * 0.48)
            }
            .padding(12)
        }
    }
}

struct RecommendedPathCard: View {
    let path: LearningPath

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: path.icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(Color(.label))
                .frame(width: 52, height: 52)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(path.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(.label))
                    .lineLimit(1)

                Text(path.description)
                    .font(.system(size: 12))
                    .foregroundColor(Color(.secondaryLabel))
                    .lineLimit(2)

                HStack(spacing: 10) {
                    Label("\(path.videosCount) videos", systemImage: "play.circle")
                    Label("\(path.estimatedHours)h", systemImage: "clock")
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Color(.secondaryLabel))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(.tertiaryLabel))
        }
        .padding(14)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separator), lineWidth: 0.5))
    }
}

// MARK: - Certificate Row Views (clean credential cards)

struct EarnedCertRow: View {
    let certificate: Certificate

    var body: some View {
        HStack(spacing: 14) {
            // Seal icon
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(UniversityTheme.Colors.certificateGold)
                .frame(width: 48, height: 48)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(certificate.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color(.label))

                Text("Earned \(certificate.earnedDate?.formatted(date: .abbreviated, time: .omitted) ?? "N/A")")
                    .font(.system(size: 12))
                    .foregroundColor(Color(.secondaryLabel))

                Text("AI Score: \(certificate.aiVerificationScore)%")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(UniversityTheme.Colors.verified)
            }

            Spacer()

            VStack(spacing: 6) {
                Button { } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(UniversityTheme.Colors.accent)
                }
                .buttonStyle(PlainButtonStyle())

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(.tertiaryLabel))
            }
        }
        .padding(14)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separator), lineWidth: 0.5))
    }
}

struct InProgressCertRow: View {
    let certificate: Certificate

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                Image(systemName: "seal")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(Color(.secondaryLabel))
                    .frame(width: 44, height: 44)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 3) {
                    Text(certificate.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color(.label))

                    Text("\(Int(certificate.progress * 100))% complete · \(certificate.requiredHours)h required")
                        .font(.system(size: 12))
                        .foregroundColor(Color(.secondaryLabel))
                }

                Spacer()

                Text("\(Int(certificate.progress * 100))%")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(.label))
            }

            // Requirements checklist
            VStack(spacing: 6) {
                requirementRow(
                    text: "\(certificate.requiredVideos) videos watched",
                    done: certificate.progress >= 0.5
                )
                requirementRow(
                    text: "\(certificate.requiredHours)h total watch time",
                    done: certificate.progress >= 0.7
                )
                requirementRow(
                    text: "AI verification score ≥ 70",
                    done: certificate.aiVerificationScore >= 70
                )
            }
            .padding(.leading, 58)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.systemFill)).frame(height: 3)
                    Capsule()
                        .fill(Color(.label).opacity(0.6))
                        .frame(width: geo.size.width * certificate.progress, height: 3)
                }
            }
            .frame(height: 3)
            .padding(.leading, 58)
        }
        .padding(14)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separator), lineWidth: 0.5))
    }

    private func requirementRow(text: String, done: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(done ? UniversityTheme.Colors.verified : Color(.tertiaryLabel))
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(done ? Color(.label) : Color(.secondaryLabel))
            Spacer()
        }
    }
}

struct BadgeCard: View {
    let badge: Badge

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: badge.isEarned ? badge.icon : "lock.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(badge.isEarned ? Color(.label) : Color(.tertiaryLabel))
                .frame(width: 56, height: 56)
                .background(Color(.secondarySystemBackground))
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(
                        badge.isEarned ? UniversityTheme.Colors.certificateGold.opacity(0.5) : Color.clear,
                        lineWidth: 1.5
                    )
                )

            Text(badge.title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(badge.isEarned ? Color(.label) : Color(.tertiaryLabel))
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .padding(10)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separator), lineWidth: 0.5))
    }
}

struct MilestoneRow: View {
    let milestone: Milestone
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Timeline dot
            VStack(spacing: 0) {
                Image(systemName: milestone.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(milestone.isCompleted ? UniversityTheme.Colors.verified : Color(.tertiaryLabel))

                if !isLast {
                    Rectangle()
                        .fill(Color(.separator))
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                        .padding(.top, 4)
                }
            }
            .frame(width: 18)

            VStack(alignment: .leading, spacing: 3) {
                Text(milestone.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(.label))

                Text(milestone.description)
                    .font(.system(size: 12))
                    .foregroundColor(Color(.secondaryLabel))

                if milestone.isCompleted {
                    Text("+\(milestone.points) pts")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(UniversityTheme.Colors.verified)
                }
            }
            .padding(.bottom, isLast ? 0 : 20)

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct UniversityLeaderboardRow: View {
    let learner: Learner

    var body: some View {
        HStack(spacing: 14) {
            Text(rankLabel)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(rankColor)
                .frame(width: 30)

            AsyncImage(url: URL(string: learner.avatarURL)) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle().fill(Color(.secondarySystemBackground))
            }
            .frame(width: 36, height: 36)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(learner.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(.label))

                HStack(spacing: 6) {
                    Text("\(learner.certificates) certs")
                    Text("·")
                    Text("\(learner.watchHours)h")
                    Text("·")
                    Label("\(learner.currentStreak)d", systemImage: "flame.fill")
                }
                .font(.system(size: 11))
                .foregroundColor(Color(.secondaryLabel))
            }

            Spacer()

            Text("\(learner.points)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(Color(.label))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var rankLabel: String {
        switch learner.rank {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return "#\(learner.rank)"
        }
    }

    private var rankColor: Color {
        switch learner.rank {
        case 1: return UniversityTheme.Colors.certificateGold
        case 2: return Color(.systemGray)
        case 3: return Color(red: 0.72, green: 0.45, blue: 0.2)
        default: return Color(.secondaryLabel)
        }
    }
}

// MARK: - Placeholder Detail Views
struct LearningPathDetailView: View {
    let path: LearningPath
    var body: some View {
        Text("Path: \(path.title)")
            .navigationTitle(path.title)
    }
}

struct SubjectDetailView: View {
    let subject: UniversitySubject
    var body: some View {
        Text("Subject: \(subject.title)")
            .navigationTitle(subject.title)
    }
}

struct CertificateDetailView: View {
    let certificate: Certificate
    var body: some View {
        Text("Certificate: \(certificate.title)")
            .navigationTitle(certificate.title)
    }
}

struct CertificateRequirementsView: View {
    let certificate: Certificate
    var body: some View {
        Text("Requirements for: \(certificate.title)")
            .navigationTitle(certificate.title)
    }
}

struct AllLearningPathsView: View {
    var body: some View {
        Text("All Learning Paths")
            .navigationTitle("Learning Paths")
    }
}

struct CategorySubjectsView: View {
    let category: SubjectCategory
    var body: some View {
        Text("Category: \(category.rawValue)")
            .navigationTitle(category.rawValue)
    }
}

struct GlobalLeaderboardView: View {
    var body: some View {
        Text("Global Leaderboard")
            .navigationTitle("Leaderboard")
    }
}

#Preview {
    UniversityHomeView()
        .environmentObject(AppState())
}

