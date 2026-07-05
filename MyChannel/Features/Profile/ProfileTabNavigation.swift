//
//  ProfileTabNavigation.swift
//  MyChannel
//
//  Created by Keonta on 7/9/25.
//

import SwiftUI
import UIKit

struct ProfileTabNavigation: View {
    @Binding var selectedTab: ProfileTab
    let user: User
    let scrollOffset: CGFloat
    
    private var isPinned: Bool {
        scrollOffset < -10
    }
    
    var body: some View {
        VStack(spacing: 0) {
            UIKitProfileTabRow(
                selectedTab: $selectedTab,
                user: user
            )
            .frame(height: 56)
        }
        .background {
            if isPinned {
                Rectangle().fill(.ultraThinMaterial)
            } else {
                Color.clear
            }
        }
        .ignoresSafeArea(edges: .horizontal) // ensure material background is edge-to-edge
        .overlay(
            Group {
                if isPinned {
                    Rectangle()
                        .fill(AppTheme.Colors.textSecondary.opacity(0.1))
                        .frame(height: 0.5)
                        .transition(.opacity)
                }
            },
            alignment: .bottom
        )
    }
}

private struct UIKitProfileTabRow: UIViewRepresentable {
    @Binding var selectedTab: ProfileTab
    let user: User
    
    func makeUIView(context: Context) -> UICollectionView {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 12
        layout.minimumLineSpacing = 12
        layout.sectionInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.alwaysBounceHorizontal = true
        collectionView.dataSource = context.coordinator
        collectionView.delegate = context.coordinator
        collectionView.register(ProfileTabCollectionCell.self, forCellWithReuseIdentifier: ProfileTabCollectionCell.reuseIdentifier)
        return collectionView
    }
    
    func updateUIView(_ collectionView: UICollectionView, context: Context) {
        context.coordinator.parent = self
        collectionView.reloadData()
        if context.coordinator.lastCenteredTab != selectedTab,
           let index = ProfileTab.allCases.firstIndex(of: selectedTab) {
            context.coordinator.lastCenteredTab = selectedTab
            collectionView.scrollToItem(
                at: IndexPath(item: index, section: 0),
                at: .centeredHorizontally,
                animated: true
            )
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    final class Coordinator: NSObject, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
        var parent: UIKitProfileTabRow
        var lastCenteredTab: ProfileTab?
        
        init(parent: UIKitProfileTabRow) {
            self.parent = parent
        }
        
        func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            ProfileTab.allCases.count
        }
        
        func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ProfileTabCollectionCell.reuseIdentifier, for: indexPath) as? ProfileTabCollectionCell else {
                return UICollectionViewCell()
            }
            let tab = ProfileTab.allCases[indexPath.item]
            cell.configure(
                tab: tab,
                count: tabCount(for: tab),
                isSelected: parent.selectedTab == tab
            )
            return cell
        }
        
        func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
            let tab = ProfileTab.allCases[indexPath.item]
            parent.selectedTab = tab
            lastCenteredTab = tab
            HapticManager.shared.impact(style: .light)
            collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: true)
        }
        
        func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
            let tab = ProfileTab.allCases[indexPath.item]
            let count = tabCount(for: tab)
            let text = count.map { "\(tab.title) \($0)" } ?? tab.title
            let font = UIFont.systemFont(ofSize: 15, weight: parent.selectedTab == tab ? .semibold : .regular)
            let textWidth = text.size(withAttributes: [.font: font]).width
            // Cell layout: 16pt leading padding + [icon(16) + spacing(8) if selected] + textWidth + 16pt trailing padding
            let iconAndSpacing: CGFloat = parent.selectedTab == tab ? (16 + 8) : 0
            return CGSize(width: ceil(textWidth + iconAndSpacing + 32), height: 56)
        }
        
        private func tabCount(for tab: ProfileTab) -> Int? {
            switch tab {
            case .videos:
                return parent.user.videoCount > 0 ? parent.user.videoCount : nil
            case .shorts:
                return parent.user.videoCount > 5 ? parent.user.videoCount / 3 : nil
            case .live:
                return nil
            case .playlists:
                return parent.user.videoCount > 10 ? parent.user.videoCount / 8 : nil
            case .downloads:
                let count = OfflineDownloadService.shared.completedDownloads.count
                return count > 0 ? count : nil
            case .community:
                return parent.user.subscriberCount > 1000 ? 12 : nil
            case .about:
                return nil
            }
        }
    }
}

private final class ProfileTabCollectionCell: UICollectionViewCell {
    static let reuseIdentifier = "ProfileTabCollectionCell"
    
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let countLabel = UILabel()
    private let indicatorView = UIView()
    private let stackView = UIStackView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        iconView.image = nil
        countLabel.text = nil
        iconView.isHidden = true
        countLabel.isHidden = true
    }
    
    func configure(tab: ProfileTab, count: Int?, isSelected: Bool) {
        iconView.image = UIImage(systemName: tab.iconName)
        iconView.tintColor = UIColor(AppTheme.Colors.primary)
        iconView.isHidden = !isSelected
        titleLabel.text = tab.title
        titleLabel.font = .systemFont(ofSize: 15, weight: isSelected ? .semibold : .regular)
        titleLabel.textColor = UIColor(isSelected ? AppTheme.Colors.textPrimary : AppTheme.Colors.textSecondary)
        countLabel.text = count.map(String.init)
        countLabel.isHidden = count == nil
        countLabel.textColor = UIColor(AppTheme.Colors.textTertiary)
        indicatorView.backgroundColor = UIColor(AppTheme.Colors.primary)
        indicatorView.alpha = isSelected ? 1 : 0
        accessibilityLabel = tab.accessibilityLabel
        accessibilityHint = isSelected ? "Currently selected" : "Double tap to select"
        accessibilityTraits = isSelected ? [.button, .selected] : [.button]
    }
    
    private func setup() {
        isAccessibilityElement = true
        contentView.backgroundColor = .clear
        
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 16).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 16).isActive = true
        
        countLabel.font = .systemFont(ofSize: 13, weight: .regular)
        
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(iconView)
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(countLabel)
        
        indicatorView.translatesAutoresizingMaskIntoConstraints = false
        indicatorView.layer.cornerRadius = 1
        
        contentView.addSubview(stackView)
        contentView.addSubview(indicatorView)
        
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stackView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: -1),
            indicatorView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            indicatorView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            indicatorView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            indicatorView.heightAnchor.constraint(equalToConstant: 2)
        ])
    }
}

#Preview {
    VStack(spacing: 0) {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [AppTheme.Colors.primary, AppTheme.Colors.secondary],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(height: 365)
            .overlay(
                Text("Header Background")
                    .foregroundColor(.white)
                    .font(.title)
            )
        
        ProfileTabNavigation(
            selectedTab: .constant(.videos),
            user: User.sampleUsers[0],
            scrollOffset: 0
        )
        
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(0..<20, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Content Item \(index)")
                            .font(.headline)
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        
                        Text("PERFECTLY FLUSH! NO GAPS!")
                            .font(.body)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(AppTheme.Colors.surface, in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16)
                }
            }
            .padding(.top, 16)
        }
        .background(AppTheme.Colors.background)
    }
}