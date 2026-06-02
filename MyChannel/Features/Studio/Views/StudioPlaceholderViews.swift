import SwiftUI
import AVKit
import Combine

// MARK: - Placeholder Views
struct MembershipMonetizationView: View {
    @Binding var settings: MembershipSettings
    @EnvironmentObject private var appState: AppState
    @StateObject private var membershipService = CreatorMembershipFirestoreService.shared
    @State var membershipEnabled = false
    @State var showingAddTier = false
    @State private var editingTier: MonetizationMembershipTier?
    @State private var isLoading = true
    @State private var statusMessage: String?
    @State var tiers: [MonetizationMembershipTier] = []
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                // Enable/Disable Toggle
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Channel Memberships")
                            .font(.system(size: 22, weight: .bold))
                        Text("Offer exclusive perks to your biggest supporters")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $membershipEnabled)
                        .labelsHidden()
                        .onChange(of: membershipEnabled) { newValue in
                            Task { await setEnabled(newValue) }
                        }
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                
                if isLoading {
                    ProgressView("Loading memberships…")
                        .padding(24)
                }
                
                // Membership Tiers
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Membership Tiers")
                            .font(.system(size: 18, weight: .semibold))
                        Spacer()
                        Button(action: { showingAddTier = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Tier")
                            }
                            .font(.system(size: 14, weight: .semibold))
                        }
                    }
                    
                    if tiers.isEmpty && !isLoading {
                        VStack(spacing: 8) {
                            Image(systemName: "person.2.badge.gearshape")
                                .font(.system(size: 36))
                                .foregroundColor(.secondary)
                            Text("No tiers yet")
                                .font(.system(size: 15, weight: .semibold))
                            Text("Create a tier to offer members-only perks.")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    }
                    
                    ForEach(tiers) { tier in
                        Button {
                            editingTier = tier
                        } label: {
                            MembershipTierCard(tier: tier)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                
                if let statusMessage {
                    Text(statusMessage)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                // Revenue Share Info
                VStack(alignment: .leading, spacing: 12) {
                    Text("Revenue Share")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("You keep")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                            Text("90%")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.green)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("MyChannel takes")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                            Text("10%")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Text("Better revenue share than YouTube's 70/30 split")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.green)
                        .padding(.top, 8)
                }
                .padding()
                .background(AppTheme.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppTheme.Colors.divider.opacity(0.1), lineWidth: 1)
                )
                .cornerRadius(16)
            }
            .padding(16)
        }
        .navigationTitle("Memberships")
        .task { await loadMemberships() }
        .sheet(isPresented: $showingAddTier) {
            MembershipTierEditorSheet(creatorId: appState.currentUser?.id ?? "") {
                Task { await loadMemberships() }
            }
        }
        .sheet(item: $editingTier) { tier in
            MembershipTierEditorSheet(creatorId: appState.currentUser?.id ?? "", existingTier: tier) {
                Task { await loadMemberships() }
            }
        }
    }
    
    private func loadMemberships() async {
        guard let creatorId = appState.currentUser?.id, !creatorId.isEmpty else {
            await MainActor.run { isLoading = false }
            return
        }
        let enabled = await membershipService.isMembershipEnabled(for: creatorId)
        let loaded = (try? await membershipService.getTiers(for: creatorId)) ?? []
        await MainActor.run {
            membershipEnabled = enabled
            tiers = loaded.map { MonetizationMembershipTier(from: $0) }
            isLoading = false
        }
    }
    
    private func setEnabled(_ enabled: Bool) async {
        guard let creatorId = appState.currentUser?.id, !creatorId.isEmpty else { return }
        do {
            try await membershipService.setMembershipEnabled(enabled, for: creatorId)
            await MainActor.run { statusMessage = enabled ? "Memberships enabled ✓" : "Memberships disabled" }
        } catch {
            await MainActor.run { statusMessage = "Couldn't update: \(error.localizedDescription)" }
        }
    }
}

struct MonetizationMembershipTier: Identifiable {
    let id: String
    var name: String
    var price: Double
    var perks: [String]
    var color: Color
    
    init(id: String = UUID().uuidString, name: String, price: Double, perks: [String], color: Color) {
        self.id = id
        self.name = name
        self.price = price
        self.perks = perks
        self.color = color
    }
    
    /// Map from the persisted Firestore-backed MembershipTier model.
    init(from tier: MembershipTier) {
        self.id = tier.id
        self.name = tier.name
        self.price = tier.price
        self.perks = tier.benefits
        self.color = Self.color(from: tier.badgeColor)
    }
    
    var badgeColorName: String {
        switch color {
        case .orange: return "orange"
        case .gray: return "gray"
        case .yellow: return "yellow"
        case .blue: return "blue"
        case .purple: return "purple"
        case .green: return "green"
        case .pink: return "pink"
        default: return "blue"
        }
    }
    
    static func color(from name: String) -> Color {
        switch name.lowercased() {
        case "orange": return .orange
        case "gray", "silver": return .gray
        case "yellow", "gold": return .yellow
        case "purple": return .purple
        case "green": return .green
        case "pink": return .pink
        default: return .blue
        }
    }
}

// MARK: - Membership Tier Editor (create / edit / delete — persists to Firestore)

struct MembershipTierEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let creatorId: String
    var existingTier: MonetizationMembershipTier?
    var onSaved: () -> Void = {}
    
    @StateObject private var membershipService = CreatorMembershipFirestoreService.shared
    @State private var name: String
    @State private var priceText: String
    @State private var badgeColor: String
    @State private var perks: [String]
    @State private var newPerk: String = ""
    @State private var isSaving = false
    @State private var showingDeleteConfirm = false
    @State private var errorMessage: String?
    
    private let colorOptions = ["bronze", "orange", "gray", "yellow", "blue", "purple", "green", "pink"]
    
    init(creatorId: String, existingTier: MonetizationMembershipTier? = nil, onSaved: @escaping () -> Void = {}) {
        self.creatorId = creatorId
        self.existingTier = existingTier
        self.onSaved = onSaved
        _name = State(initialValue: existingTier?.name ?? "")
        _priceText = State(initialValue: existingTier.map { String(format: "%.2f", $0.price) } ?? "")
        _badgeColor = State(initialValue: existingTier?.badgeColorName ?? "blue")
        _perks = State(initialValue: existingTier?.perks ?? [])
    }
    
    private var price: Double { Double(priceText) ?? 0 }
    private var canSave: Bool {
        !name.isEmpty && price >= 0.99 && price <= 999.99 && !creatorId.isEmpty && !isSaving
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Tier Details") {
                    TextField("Tier name (e.g. Gold)", text: $name)
                    HStack {
                        Text("$")
                        TextField("4.99", text: $priceText)
                            .keyboardType(.decimalPad)
                    }
                    Picker("Badge color", selection: $badgeColor) {
                        ForEach(colorOptions, id: \.self) { Text($0.capitalized).tag($0) }
                    }
                }
                
                Section("Perks") {
                    ForEach(perks, id: \.self) { perk in
                        Text(perk)
                    }
                    .onDelete { perks.remove(atOffsets: $0) }
                    HStack {
                        TextField("Add a perk", text: $newPerk)
                        Button("Add") {
                            let trimmed = newPerk.trimmingCharacters(in: .whitespaces)
                            guard !trimmed.isEmpty else { return }
                            perks.append(trimmed)
                            newPerk = ""
                        }
                        .disabled(newPerk.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundColor(.red)
                    }
                }
                
                Section {
                    Button {
                        Task { await save() }
                    } label: {
                        HStack {
                            if isSaving { ProgressView().padding(.trailing, 4) }
                            Text(isSaving ? "Saving…" : "Save Tier")
                        }
                    }
                    .disabled(!canSave)
                    
                    if existingTier != nil {
                        Button("Delete Tier", role: .destructive) {
                            showingDeleteConfirm = true
                        }
                    }
                }
            }
            .navigationTitle(existingTier == nil ? "New Tier" : "Edit Tier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Delete Tier?", isPresented: $showingDeleteConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    Task { await deleteTier() }
                }
            } message: {
                Text("Existing members on this tier keep access until their billing period ends.")
            }
        }
    }
    
    private func save() async {
        isSaving = true
        errorMessage = nil
        let tier = MembershipTier(
            id: existingTier?.id ?? UUID().uuidString,
            name: name,
            description: "",
            price: price,
            benefits: perks,
            badgeColor: badgeColor
        )
        do {
            try await membershipService.saveTier(tier, for: creatorId)
            HapticManager.shared.notification(type: .success)
            onSaved()
            dismiss()
        } catch {
            isSaving = false
            errorMessage = error.localizedDescription
        }
    }
    
    private func deleteTier() async {
        guard let id = existingTier?.id else { return }
        isSaving = true
        errorMessage = nil
        do {
            try await membershipService.deleteTier(id)
            HapticManager.shared.notification(type: .success)
            onSaved()
            dismiss()
        } catch {
            isSaving = false
            errorMessage = error.localizedDescription
        }
    }
}

struct MembershipTierCard: View {
    let tier: MonetizationMembershipTier
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(tier.color.gradient)
                    .frame(width: 12, height: 12)
                
                Text(tier.name)
                    .font(.system(size: 18, weight: .bold))
                
                Spacer()
                
                Text("$\(String(format: "%.2f", tier.price))/mo")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.green)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                ForEach(tier.perks, id: \.self) { perk in
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(tier.color)
                            .font(.system(size: 14))
                        Text(perk)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct StatBox: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
            
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct MerchandiseMonetizationView: View {
    @Binding var settings: MerchandiseSettings
    @EnvironmentObject private var appState: AppState
    @StateObject private var merchService = CreatorMerchFirestoreService.shared
    @State var merchEnabled = false
    @State var showingAddProduct = false
    @State private var editingProduct: CreatorProduct?
    @State private var isLoading = true
    @State private var statusMessage: String?
    @State var products: [CreatorProduct] = []
    
    private var totalStock: Int { products.reduce(0) { $0 + $1.stock } }
    private var catalogValue: Double { products.reduce(0) { $0 + ($1.price * Double($1.stock)) } }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                // Enable/Disable Toggle
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Merchandise Store")
                            .font(.system(size: 22, weight: .bold))
                        Text("Sell your own branded products")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $merchEnabled)
                        .labelsHidden()
                        .onChange(of: merchEnabled) { newValue in
                            Task { await setEnabled(newValue) }
                        }
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                
                // Stats Overview (real catalog figures)
                HStack(spacing: 12) {
                    StatBox(title: "Products", value: "\(products.count)", icon: "bag.fill", color: .orange)
                    StatBox(title: "In Stock", value: "\(totalStock)", icon: "shippingbox.fill", color: .blue)
                    StatBox(title: "Catalog Value", value: "$\(String(format: "%.0f", catalogValue))", icon: "dollarsign.circle.fill", color: .green)
                }
                
                if isLoading {
                    ProgressView("Loading products…").padding(24)
                }
                
                // Products List
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Your Products")
                            .font(.system(size: 18, weight: .semibold))
                        Spacer()
                        Button(action: { showingAddProduct = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Product")
                            }
                            .font(.system(size: 14, weight: .semibold))
                        }
                    }
                    
                    if products.isEmpty && !isLoading {
                        VStack(spacing: 8) {
                            Image(systemName: "bag.badge.plus")
                                .font(.system(size: 36))
                                .foregroundColor(.secondary)
                            Text("No products yet")
                                .font(.system(size: 15, weight: .semibold))
                            Text("Add a product to start your merch shelf.")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    }
                    
                    ForEach(products) { product in
                        Button { editingProduct = product } label: {
                            MerchProductCard(product: product)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                
                if let statusMessage {
                    Text(statusMessage)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                // Integration Info
                VStack(alignment: .leading, spacing: 12) {
                    Text("Powered by MyChannel Merch")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text("When checkout launches, we handle:")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        FeatureRow(icon: "printer.fill", text: "Print on demand manufacturing")
                        FeatureRow(icon: "shippingbox.fill", text: "Worldwide shipping & fulfillment")
                        FeatureRow(icon: "creditcard.fill", text: "Secure payment processing")
                        FeatureRow(icon: "arrow.triangle.2.circlepath", text: "Easy returns & exchanges")
                    }
                    .padding(.top, 8)
                }
                .padding()
                .background(AppTheme.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppTheme.Colors.divider.opacity(0.1), lineWidth: 1)
                )
                .cornerRadius(16)
            }
            .padding(16)
        }
        .navigationTitle("Merchandise")
        .task { await loadMerch() }
        .sheet(isPresented: $showingAddProduct) {
            MerchProductEditorSheet(creatorId: appState.currentUser?.id ?? "") {
                Task { await loadMerch() }
            }
        }
        .sheet(item: $editingProduct) { product in
            MerchProductEditorSheet(creatorId: appState.currentUser?.id ?? "", existingProduct: product) {
                Task { await loadMerch() }
            }
        }
    }
    
    private func loadMerch() async {
        guard let creatorId = appState.currentUser?.id, !creatorId.isEmpty else {
            await MainActor.run { isLoading = false }
            return
        }
        let enabled = await merchService.isMerchEnabled(for: creatorId)
        let loaded = (try? await merchService.getProducts(for: creatorId)) ?? []
        await MainActor.run {
            merchEnabled = enabled
            products = loaded
            isLoading = false
        }
    }
    
    private func setEnabled(_ enabled: Bool) async {
        guard let creatorId = appState.currentUser?.id, !creatorId.isEmpty else { return }
        do {
            try await merchService.setMerchEnabled(enabled, for: creatorId)
            await MainActor.run { statusMessage = enabled ? "Merch store enabled ✓" : "Merch store disabled" }
        } catch {
            await MainActor.run { statusMessage = "Couldn't update: \(error.localizedDescription)" }
        }
    }
}

// MARK: - Merch Product Editor (create / edit / delete — persists to Firestore)

struct MerchProductEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let creatorId: String
    var existingProduct: CreatorProduct?
    var onSaved: () -> Void = {}
    
    @StateObject private var merchService = CreatorMerchFirestoreService.shared
    @State private var name: String
    @State private var priceText: String
    @State private var stockText: String
    @State private var category: String
    @State private var symbol: String
    @State private var isActive: Bool
    @State private var isSaving = false
    @State private var showingDeleteConfirm = false
    @State private var errorMessage: String?
    
    private let symbolOptions = ["bag.fill", "tshirt", "sun.haze", "iphone", "cup.and.saucer.fill", "gift.fill", "book.fill", "headphones"]
    private let categoryOptions = ["Apparel", "Accessories", "Tech", "Home", "Print", "Other"]
    
    init(creatorId: String, existingProduct: CreatorProduct? = nil, onSaved: @escaping () -> Void = {}) {
        self.creatorId = creatorId
        self.existingProduct = existingProduct
        self.onSaved = onSaved
        _name = State(initialValue: existingProduct?.name ?? "")
        _priceText = State(initialValue: existingProduct.map { String(format: "%.2f", $0.price) } ?? "")
        _stockText = State(initialValue: existingProduct.map { String($0.stock) } ?? "")
        _category = State(initialValue: existingProduct?.category ?? "Apparel")
        _symbol = State(initialValue: existingProduct?.imageSystemName ?? "bag.fill")
        _isActive = State(initialValue: existingProduct?.isActive ?? true)
    }
    
    private var price: Double { Double(priceText) ?? 0 }
    private var stock: Int { Int(stockText) ?? 0 }
    private var canSave: Bool {
        !name.isEmpty && price >= 0.01 && stock >= 0 && !creatorId.isEmpty && !isSaving
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Product") {
                    TextField("Product name", text: $name)
                    HStack {
                        Text("$")
                        TextField("0.00", text: $priceText)
                            .keyboardType(.decimalPad)
                    }
                    HStack {
                        Text("Stock")
                        Spacer()
                        TextField("0", text: $stockText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    Picker("Category", selection: $category) {
                        ForEach(categoryOptions, id: \.self) { Text($0).tag($0) }
                    }
                    Picker("Icon", selection: $symbol) {
                        ForEach(symbolOptions, id: \.self) { sym in
                            Label(sym, systemImage: sym).tag(sym)
                        }
                    }
                    Toggle("Listed (visible to viewers)", isOn: $isActive)
                }
                
                if let errorMessage {
                    Section {
                        Text(errorMessage).font(.system(size: 13)).foregroundColor(.red)
                    }
                }
                
                Section {
                    Button {
                        Task { await save() }
                    } label: {
                        HStack {
                            if isSaving { ProgressView().padding(.trailing, 4) }
                            Text(isSaving ? "Saving…" : "Save Product")
                        }
                    }
                    .disabled(!canSave)
                    
                    if existingProduct != nil {
                        Button("Delete Product", role: .destructive) {
                            showingDeleteConfirm = true
                        }
                    }
                }
            }
            .navigationTitle(existingProduct == nil ? "New Product" : "Edit Product")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Delete Product?", isPresented: $showingDeleteConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    Task { await deleteProduct() }
                }
            } message: {
                Text("This removes the product from your shelf.")
            }
        }
    }
    
    private func save() async {
        isSaving = true
        errorMessage = nil
        let product = CreatorProduct(
            id: existingProduct?.id ?? UUID().uuidString,
            name: name,
            price: price,
            stock: stock,
            imageSystemName: symbol,
            category: category,
            isActive: isActive,
            updatedAt: Date()
        )
        do {
            try await merchService.saveProduct(product, for: creatorId)
            HapticManager.shared.notification(type: .success)
            onSaved()
            dismiss()
        } catch {
            isSaving = false
            errorMessage = error.localizedDescription
        }
    }
    
    private func deleteProduct() async {
        guard let id = existingProduct?.id else { return }
        isSaving = true
        errorMessage = nil
        do {
            try await merchService.deleteProduct(id)
            HapticManager.shared.notification(type: .success)
            onSaved()
            dismiss()
        } catch {
            isSaving = false
            errorMessage = error.localizedDescription
        }
    }
}

struct MerchProductCard: View {
    let product: CreatorProduct
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: product.imageSystemName)
                .font(.system(size: 40))
                .foregroundColor(.orange)
                .frame(width: 60, height: 60)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(product.name)
                        .font(.system(size: 16, weight: .semibold))
                    if !product.isActive {
                        Text("Hidden")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(.systemGray5), in: Capsule())
                    }
                }
                
                HStack(spacing: 12) {
                    Text("$\(String(format: "%.2f", product.price))")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.green)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text("\(product.stock) in stock")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                Text(product.category)
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.8))
                    .cornerRadius(6)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.orange)
                .font(.system(size: 16))
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.primary)
        }
    }
}

struct DonationMonetizationView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var superChatService = CreatorSuperChatFirestoreService.shared
    @State var superChatEnabled = false
    @State var minDonation = 1.0
    @State private var isLoading = true
    @State private var isSavingSettings = false
    @State private var statusMessage: String?
    @State private var allTimeTotal: Double = 0
    @State var recentDonations: [SuperChatEntry] = []
    
    private var todayTotal: Double {
        let cal = Calendar.current
        return recentDonations.filter { cal.isDateInToday($0.date) }.reduce(0) { $0 + $1.amount }
    }
    private var weekTotal: Double {
        let weekAgo = Date().addingTimeInterval(-7 * 24 * 3600)
        return recentDonations.filter { $0.date >= weekAgo }.reduce(0) { $0 + $1.amount }
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                // Enable/Disable Toggle
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Super Chat & Tips")
                            .font(.system(size: 22, weight: .bold))
                        Text("Let viewers support you during live streams")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $superChatEnabled)
                        .labelsHidden()
                        .onChange(of: superChatEnabled) { _ in
                            Task { await saveSettings() }
                        }
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                
                // Stats Overview (real figures from received Super Thanks)
                HStack(spacing: 12) {
                    StatBox(title: "Today", value: "$\(String(format: "%.0f", todayTotal))", icon: "heart.fill", color: .pink)
                    StatBox(title: "This Week", value: "$\(String(format: "%.0f", weekTotal))", icon: "calendar", color: .blue)
                    StatBox(title: "All Time", value: "$\(String(format: "%.0f", allTimeTotal))", icon: "chart.line.uptrend.xyaxis", color: .green)
                }
                
                if isLoading {
                    ProgressView("Loading Super Chats…").padding(24)
                }
                
                // Settings
                VStack(alignment: .leading, spacing: 16) {
                    Text("Settings")
                        .font(.system(size: 18, weight: .semibold))
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Minimum Donation")
                                .font(.system(size: 14, weight: .medium))
                            Text("Set the minimum amount viewers can donate ($1–$500)")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 8) {
                            Text("$")
                                .foregroundColor(.secondary)
                            TextField("Amount", value: $minDonation, format: .number)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                            Button("Save") {
                                Task { await saveSettings() }
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .disabled(isSavingSettings)
                        }
                    }
                    
                    if let statusMessage {
                        Text(statusMessage)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                
                // Recent Donations (real)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent Super Chats")
                        .font(.system(size: 18, weight: .semibold))
                    
                    if recentDonations.isEmpty && !isLoading {
                        Text("No Super Chats yet. They'll show up here when viewers support you.")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(recentDonations) { donation in
                            DonationCard(donation: donation)
                        }
                    }
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                
                // Revenue Info
                VStack(alignment: .leading, spacing: 12) {
                    Text("💵 Your Cut")
                        .font(.system(size: 18, weight: .bold))
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("You keep")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                            Text("90%")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.pink)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("MyChannel + Processing")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                            Text("10%")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Text("Best revenue share in the industry")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.green)
                        .padding(.top, 8)
                }
                .padding()
                .background(AppTheme.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppTheme.Colors.divider.opacity(0.1), lineWidth: 1)
                )
                .cornerRadius(16)
            }
            .padding(16)
        }
        .navigationTitle("Super Chat")
        .task { await loadSuperChat() }
    }
    
    private func loadSuperChat() async {
        guard let creatorId = appState.currentUser?.id, !creatorId.isEmpty else {
            await MainActor.run { isLoading = false }
            return
        }
        let settings = await superChatService.getSettings(for: creatorId)
        let recent = (try? await superChatService.recentSuperChats(for: creatorId)) ?? []
        let total = await superChatService.totalReceived(for: creatorId)
        await MainActor.run {
            superChatEnabled = settings.enabled
            minDonation = settings.minimumAmount
            recentDonations = recent
            allTimeTotal = total
            isLoading = false
        }
    }
    
    private func saveSettings() async {
        guard let creatorId = appState.currentUser?.id, !creatorId.isEmpty else { return }
        isSavingSettings = true
        do {
            try await superChatService.saveSettings(
                .init(enabled: superChatEnabled, minimumAmount: minDonation),
                for: creatorId
            )
            await MainActor.run {
                statusMessage = "Settings saved ✓"
                isSavingSettings = false
            }
        } catch {
            await MainActor.run {
                statusMessage = error.localizedDescription
                isSavingSettings = false
            }
        }
    }
}

struct DonationCard: View {
    let donation: SuperChatEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(amountColor(for: donation.amount).gradient)
                    .frame(width: 8, height: 8)
                
                Text(donation.senderName)
                    .font(.system(size: 15, weight: .semibold))
                
                Spacer()
                
                Text("$\(String(format: "%.2f", donation.amount))")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(amountColor(for: donation.amount))
            }
            
            if !donation.message.isEmpty {
                Text(donation.message)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            Text(timeAgo(from: donation.date))
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(amountColor(for: donation.amount).opacity(0.1))
        )
    }
    
    func amountColor(for amount: Double) -> Color {
        if amount >= 100 { return AppTheme.Colors.primary }
        else if amount >= 50 { return AppTheme.Colors.accent }
        else if amount >= 10 { return AppTheme.Colors.warning }
        else { return AppTheme.Colors.textSecondary }
    }
    
    func timeAgo(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "\(seconds)s ago" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        if seconds < 86400 { return "\(seconds / 3600)h ago" }
        return "\(seconds / 86400)d ago"
    }
}

struct RevenueAnalyticsView: View {
    @StateObject var analyticsService = AdvancedAnalyticsService.shared
    @State var selectedPeriod: RevenuePeriod = .month
    
    enum RevenuePeriod: String, CaseIterable {
        case week = "7 Days"
        case month = "30 Days"
        case year = "12 Months"
        case allTime = "All Time"
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                // Period Selector
                Picker("Period", selection: $selectedPeriod) {
                    ForEach(RevenuePeriod.allCases, id: \.self) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                // Total Revenue Card
                VStack(spacing: 12) {
                    Text("Total Revenue")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Text("$\(String(format: "%.2f", analyticsService.estimatedRevenue))")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                    
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 14, weight: .semibold))
                        Text("+\(String(format: "%.1f", analyticsService.revenueGrowth))% from last period")
                            .font(.system(size: 14))
                    }
                    .foregroundColor(.green)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(AppTheme.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppTheme.Colors.divider.opacity(0.1), lineWidth: 1)
                )
                .cornerRadius(16)
                .padding(.horizontal)
                
                // Revenue Breakdown
                VStack(alignment: .leading, spacing: 16) {
                    Text("Revenue by Source")
                        .font(.system(size: 18, weight: .semibold))
                        .padding(.horizontal)
                    
                    let breakdown = getRevenueBreakdown()
                    
                    ForEach(breakdown, id: \.source) { item in
                        MonetizationRevenueSourceRow(
                            icon: item.icon,
                            source: item.source,
                            amount: item.amount,
                            percentage: item.percentage,
                            color: item.color
                        )
                    }
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                
                // Top Performing Videos
                VStack(alignment: .leading, spacing: 16) {
                    Text("Top Earning Videos")
                        .font(.system(size: 18, weight: .semibold))
                        .padding(.horizontal)
                    
                    ForEach(0..<3, id: \.self) { index in
                        MonetizationTopEarningVideoRow(
                            rank: index + 1,
                            title: "Video Title \(index + 1)",
                            revenue: Double.random(in: 100...1000),
                            views: Int.random(in: 10000...100000)
                        )
                    }
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                
                // Payout Info
                VStack(alignment: .leading, spacing: 12) {
                    Text("Next Payout")
                        .font(.system(size: 18, weight: .bold))
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Available Balance")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                            Text("$2,847.50")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.green)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Payout Date")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                            Text("Dec 15")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Button(action: {}) {
                        Text("Request Early Payout")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.blue.gradient)
                            .cornerRadius(12)
                    }
                    .padding(.top, 8)
                }
                .padding()
                .background(AppTheme.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppTheme.Colors.divider.opacity(0.1), lineWidth: 1)
                )
                .cornerRadius(16)
            }
            .padding(16)
        }
        .navigationTitle("Revenue Analytics")
    }
    
    func getRevenueBreakdown() -> [RevenueBreakdownItem] {
        return [
            RevenueBreakdownItem(source: "Ads", amount: 1234.56, percentage: 45, icon: "play.rectangle.fill", color: .red),
            RevenueBreakdownItem(source: "Memberships", amount: 987.50, percentage: 35, icon: "person.badge.plus.fill", color: .blue),
            RevenueBreakdownItem(source: "Super Chat", amount: 425.00, percentage: 15, icon: "heart.fill", color: .pink),
            RevenueBreakdownItem(source: "Merchandise", amount: 200.44, percentage: 5, icon: "bag.fill", color: .orange)
        ]
    }
}

struct RevenueBreakdownItem {
    let source: String
    let amount: Double
    let percentage: Int
    let icon: String
    let color: Color
}

struct MonetizationRevenueSourceRow: View {
    let icon: String
    let source: String
    let amount: Double
    let percentage: Int
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.1))
                .cornerRadius(10)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(source)
                    .font(.system(size: 16, weight: .semibold))
                
                ProgressView(value: Double(percentage), total: 100)
                    .tint(color)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("$\(String(format: "%.2f", amount))")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.green)
                
                Text("\(percentage)%")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct MonetizationTopEarningVideoRow: View {
    let rank: Int
    let title: String
    let revenue: Double
    let views: Int
    
    var body: some View {
        HStack(spacing: 12) {
            Text("#\(rank)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(rankColor)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                
                Text("\(views.formatted()) views")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("$\(String(format: "%.2f", revenue))")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.green)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var rankColor: Color {
        switch rank {
        case 1: return Color(hex: "FFD700") ?? .yellow // Gold - acceptable for #1
        case 2: return AppTheme.Colors.textSecondary
        case 3: return AppTheme.Colors.textTertiary
        default: return AppTheme.Colors.textSecondary
        }
    }
}

struct AdPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("Ad Preview")
                    .font(.title)
                
                Text("This is how ads will appear in your videos")
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Ad Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// StudioSettingsView now in separate file: MyChannel/Features/Studio/Views/StudioSettingsView.swift


// ⚡ AIToolsStudioView + QuickTabs extracted to StudioAIViews.swift
