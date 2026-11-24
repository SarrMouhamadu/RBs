//
//  File.swift
//  RBS - Ratousha Baby Shop
//
//  Created by Mouhamadou SARR on 16-11-2026.
//

import Foundation
import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

enum ProductCategory: String, CaseIterable, Identifiable, Codable {
    case all = "Tous"
    case shoes = "Chaussures"
    case tops = "Hauts & Chemises"
    case pants = "Pantalons"
    case fabrics = "Tissus"
    case newArrivals = "Nouveautés"

    var id: String { rawValue }

    static var editableCategories: [ProductCategory] {
        [.shoes, .tops, .pants, .fabrics, .newArrivals]
    }

    var icon: String {
        switch self {
        case .all: return "square.grid.2x2.fill"
        case .shoes: return "shoe.fill"
        case .tops: return "tshirt.fill"
        case .pants: return "figure.walk"
        case .fabrics: return "swatchpalette.fill"
        case .newArrivals: return "sparkles"
        }
    }

    var availableSizes: [String] {
        switch self {
        case .shoes:
            return ["39", "40", "41", "42", "43", "44", "45"]
        case .tops, .newArrivals:
            return ["S", "M", "L", "XL", "XXL"]
        case .pants:
            return ["30", "32", "34", "36", "38", "40"]
        case .fabrics:
            return ["3 mètres", "5 mètres", "10 mètres"]
        case .all:
            return ["Standard"]
        }
    }

    var sizeLabel: String {
        switch self {
        case .shoes: return "Pointure"
        case .fabrics: return "Métrage"
        default: return "Taille"
        }
    }
}

enum SortOption: String, CaseIterable, Identifiable {
    case featured = "Populaires"
    case availableFirst = "Disponibles d'abord"
    case unavailableFirst = "Non disponibles"
    case nameAZ = "Nom A-Z"

    var id: String { rawValue }
}

struct Product: Identifiable, Hashable, Codable {
    var id: UUID
    var name: String
    var category: ProductCategory
    var isAvailable: Bool
    var imageFilename: String
    var isFeatured: Bool
    var badge: String?
    var rating: Double
    var description: String

    init(
        id: UUID = UUID(),
        name: String,
        category: ProductCategory,
        isAvailable: Bool = true,
        imageFilename: String,
        isFeatured: Bool = false,
        badge: String? = nil,
        rating: Double = 4.8,
        description: String? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.isAvailable = isAvailable
        self.imageFilename = imageFilename
        self.isFeatured = isFeatured
        self.badge = badge
        self.rating = rating
        self.description = description ?? "Article de qualité supérieure sélectionné par Ratousha Baby Shop (RBS). Finitions soignées, confort optimal et style élégant."
    }

    var availabilityText: String {
        isAvailable ? "Disponible" : "Non disponible"
    }
}

struct CartItem: Identifiable {
    let id = UUID()
    let product: Product
    let size: String
    var quantity: Int
}

enum MediaUploadError: LocalizedError {
    case fileTooLarge(sizeMB: Double)
    case quotaExceeded(usedMB: Double, fileMB: Double)
    case unreadableFile

    var errorDescription: String? {
        switch self {
        case .fileTooLarge(let sizeMB):
            return String(format: "Le fichier fait %.1f Mo. La limite maximale autorisée est de 500 Mo.", sizeMB)
        case .quotaExceeded(let usedMB, let fileMB):
            return String(format: "Quota de 500 Mo dépassé (utilisé : %.1f Mo, fichier : %.1f Mo).", usedMB, fileMB)
        case .unreadableFile:
            return "Impossible de lire le fichier média sélectionné."
        }
    }
}

enum RBSImageLoader {
    static let projectDirectory = "/Users/mouhamadousarr/Desktop/RBS"
    static let maxUploadBytes: Int64 = 500 * 1024 * 1024 // 500 Mo max

    static var documentsImagesDirectory: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("RBSImages")
    }

    static func totalMediaSizeBytes() -> Int64 {
        var dirs: [URL] = []
        let macProjectRes = URL(fileURLWithPath: projectDirectory).appendingPathComponent("Resources")
        if FileManager.default.fileExists(atPath: macProjectRes.path) {
            dirs.append(macProjectRes)
        } else if let bundleRes = Bundle.main.resourceURL {
            dirs.append(bundleRes)
        }
        if let docsDir = documentsImagesDirectory,
           FileManager.default.fileExists(atPath: docsDir.path) {
            dirs.append(docsDir)
        }

        var seenFiles = Set<String>()
        var total: Int64 = 0
        for dir in dirs {
            guard let files = try? FileManager.default.contentsOfDirectory(atPath: dir.path) else { continue }
            for file in files where !seenFiles.contains(file) {
                let lower = file.lowercased()
                guard lower.hasSuffix(".jpeg") || lower.hasSuffix(".jpg") || lower.hasSuffix(".png") else { continue }
                seenFiles.insert(file)
                let path = dir.appendingPathComponent(file).path
                if let attrs = try? FileManager.default.attributesOfItem(atPath: path),
                   let size = attrs[.size] as? NSNumber {
                    total += size.int64Value
                }
            }
        }
        return total
    }

    static func formattedMediaUsage() -> String {
        let usedMB = Double(totalMediaSizeBytes()) / (1024.0 * 1024.0)
        return String(format: "%.1f Mo / 500 Mo max", usedMB)
    }

    static func image(named filename: String) -> Image? {
        var candidates: [URL] = []
        if let docsDir = documentsImagesDirectory {
            candidates.append(docsDir.appendingPathComponent(filename))
        }
        if let bundleRes = Bundle.main.resourceURL {
            candidates.append(bundleRes.appendingPathComponent(filename))
            candidates.append(bundleRes.appendingPathComponent("Resources").appendingPathComponent(filename))
        }
        if filename.hasPrefix("/") {
            candidates.append(URL(fileURLWithPath: filename))
        }
        candidates.append(contentsOf: [
            URL(fileURLWithPath: projectDirectory).appendingPathComponent("Resources").appendingPathComponent(filename),
            URL(fileURLWithPath: projectDirectory).appendingPathComponent(filename)
        ])

        for url in candidates {
            #if os(macOS)
            if let nsImage = NSImage(contentsOf: url) {
                return Image(nsImage: nsImage)
            }
            #elseif os(iOS)
            if let data = try? Data(contentsOf: url),
               let uiImage = UIImage(data: data) {
                return Image(uiImage: uiImage)
            }
            #endif
        }
        return nil
    }

    static func availableImageFiles() -> [String] {
        var set = Set<String>()
        let dirs: [URL] = [
            documentsImagesDirectory,
            URL(fileURLWithPath: projectDirectory).appendingPathComponent("Resources"),
            Bundle.main.resourceURL,
            Bundle.main.resourceURL?.appendingPathComponent("Resources")
        ].compactMap { $0 }

        let excluded = Set(["logo RBS.jpeg", "wave_logo.png", "orange_money_logo.png"])
        for dir in dirs {
            if let files = try? FileManager.default.contentsOfDirectory(atPath: dir.path) {
                for file in files {
                    let lower = file.lowercased()
                    if (lower.hasSuffix(".jpeg") || lower.hasSuffix(".jpg") || lower.hasSuffix(".png")) && !excluded.contains(file) {
                        set.insert(file)
                    }
                }
            }
        }
        return set.sorted { a, b in
            let aIsWA = a.hasPrefix("WhatsApp")
            let bIsWA = b.hasPrefix("WhatsApp")
            if aIsWA != bIsWA { return !aIsWA }
            return a.localizedCaseInsensitiveCompare(b) == .orderedAscending
        }
    }

    static func importMedia(from sourceURL: URL) -> Result<String, MediaUploadError> {
        let accessed = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if accessed { sourceURL.stopAccessingSecurityScopedResource() }
        }

        let fileSize: Int64
        if let attrs = try? FileManager.default.attributesOfItem(atPath: sourceURL.path),
           let sizeNum = attrs[.size] as? NSNumber {
            fileSize = sizeNum.int64Value
        } else if let values = try? sourceURL.resourceValues(forKeys: [.fileSizeKey]),
                  let s = values.fileSize {
            fileSize = Int64(s)
        } else {
            fileSize = 0
        }

        if fileSize > maxUploadBytes {
            let mb = Double(fileSize) / (1024.0 * 1024.0)
            return .failure(.fileTooLarge(sizeMB: mb))
        }

        let currentUsed = totalMediaSizeBytes()
        if currentUsed + fileSize > maxUploadBytes {
            let usedMB = Double(currentUsed) / (1024.0 * 1024.0)
            let fileMB = Double(fileSize) / (1024.0 * 1024.0)
            return .failure(.quotaExceeded(usedMB: usedMB, fileMB: fileMB))
        }

        guard let data = try? Data(contentsOf: sourceURL) else {
            return .failure(.unreadableFile)
        }
        if Int64(data.count) > maxUploadBytes {
            let mb = Double(data.count) / (1024.0 * 1024.0)
            return .failure(.fileTooLarge(sizeMB: mb))
        }

        let ext = sourceURL.pathExtension.isEmpty ? "jpeg" : sourceURL.pathExtension.lowercased()
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "/", with: "_")
        let uniqueName = "\(baseName)_\(Int(Date().timeIntervalSince1970)).\(ext)"

        let projectResDir = URL(fileURLWithPath: projectDirectory).appendingPathComponent("Resources")
        if FileManager.default.fileExists(atPath: projectResDir.path) {
            try? data.write(to: projectResDir.appendingPathComponent(uniqueName), options: .atomic)
        }

        if let docsDir = documentsImagesDirectory {
            try? FileManager.default.createDirectory(at: docsDir, withIntermediateDirectories: true)
            try? data.write(to: docsDir.appendingPathComponent(uniqueName), options: .atomic)
        }

        return .success(uniqueName)
    }
}

@MainActor
final class StoreViewModel: ObservableObject {
    @Published var products: [Product] = []
    @Published var selectedCategory: ProductCategory = .all
    @Published var sortOption: SortOption = .featured
    @Published var searchText: String = ""
    @Published var cmsSearchText: String = ""
    @Published var cmsCategoryFilter: ProductCategory = .all
    @Published var cart: [CartItem] = []
    @Published var favorites: Set<UUID> = []
    @Published var lastAddedProductName: String?
    @Published var isAdminAuthenticated: Bool = false

    let shopName = "RATOUSHA BABY SHOP"
    let shopShortName = "RBS"
    let phoneNumber = "+221 78 136 00 57"
    let whatsappNumber = "221781360057"

    private let adminPasswordKey = "rbs_admin_password"

    var adminPassword: String {
        get { UserDefaults.standard.string(forKey: adminPasswordKey) ?? "RBS2026" }
        set { UserDefaults.standard.set(newValue, forKey: adminPasswordKey) }
    }

    func authenticateAdmin(password: String) -> Bool {
        let trimmed = password.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == adminPassword {
            isAdminAuthenticated = true
            return true
        }
        return false
    }

    func logoutAdmin() {
        isAdminAuthenticated = false
    }

    private var cmsStorageURL: URL {
        let projectFile = URL(fileURLWithPath: RBSImageLoader.projectDirectory).appendingPathComponent("products_cms.json")
        let projectDirExists = FileManager.default.fileExists(atPath: RBSImageLoader.projectDirectory)
        if projectDirExists && FileManager.default.isWritableFile(atPath: RBSImageLoader.projectDirectory) {
            return projectFile
        }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("products_cms.json")
    }

    init() {
        loadCatalog()
    }

    var featuredProducts: [Product] {
        products.filter { $0.isFeatured }
    }

    var availableProductsCount: Int {
        products.filter { $0.isAvailable }.count
    }

    var unavailableProductsCount: Int {
        products.filter { !$0.isAvailable }.count
    }

    var favoriteProducts: [Product] {
        products.filter { favorites.contains($0.id) }
    }

    var filteredProducts: [Product] {
        let base = products.filter { product in
            let matchesCategory = (selectedCategory == .all) || (product.category == selectedCategory)
            let matchesSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                product.name.localizedCaseInsensitiveContains(searchText) ||
                product.category.rawValue.localizedCaseInsensitiveContains(searchText) ||
                product.availabilityText.localizedCaseInsensitiveContains(searchText)
            return matchesCategory && matchesSearch
        }

        switch sortOption {
        case .featured:
            return base
        case .availableFirst:
            return base.sorted { $0.isAvailable && !$1.isAvailable }
        case .unavailableFirst:
            return base.sorted { !$0.isAvailable && $1.isAvailable }
        case .nameAZ:
            return base.sorted { $0.name < $1.name }
        }
    }

    var cmsFilteredProducts: [Product] {
        products.filter { product in
            let matchesCat = (cmsCategoryFilter == .all) || (product.category == cmsCategoryFilter)
            let matchesQuery = cmsSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                product.name.localizedCaseInsensitiveContains(cmsSearchText) ||
                product.category.rawValue.localizedCaseInsensitiveContains(cmsSearchText) ||
                product.availabilityText.localizedCaseInsensitiveContains(cmsSearchText) ||
                (product.badge?.localizedCaseInsensitiveContains(cmsSearchText) == true)
            return matchesCat && matchesQuery
        }
    }

    // MARK: - CMS CRUD Operations

    func addProduct(_ product: Product) {
        products.insert(product, at: 0)
        saveCatalogToDisk()
        lastAddedProductName = "Article créé : \(product.name)"
    }

    func updateProduct(_ updated: Product) {
        if let index = products.firstIndex(where: { $0.id == updated.id }) {
            products[index] = updated
            saveCatalogToDisk()
            lastAddedProductName = "Article modifié : \(updated.name)"
        }
    }

    func deleteProduct(_ product: Product) {
        products.removeAll { $0.id == product.id }
        cart.removeAll { $0.product.id == product.id }
        favorites.remove(product.id)
        saveCatalogToDisk()
        lastAddedProductName = "Article supprimé : \(product.name)"
    }

    func toggleAvailability(_ product: Product) {
        guard let index = products.firstIndex(where: { $0.id == product.id }) else { return }
        products[index].isAvailable.toggle()
        let status = products[index].availabilityText
        saveCatalogToDisk()
        lastAddedProductName = "\(products[index].name) : \(status)"
    }

    func toggleFeatured(_ product: Product) {
        guard let index = products.firstIndex(where: { $0.id == product.id }) else { return }
        products[index].isFeatured.toggle()
        saveCatalogToDisk()
    }

    func resetCatalogToDefaults() {
        products = Self.defaultCatalog()
        saveCatalogToDisk()
        lastAddedProductName = "Catalogue réinitialisé (\(products.count) articles)"
    }

    private func saveCatalogToDisk() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(products) {
            try? data.write(to: cmsStorageURL, options: .atomic)
        }
    }

    // MARK: - Cart & Orders

    var cartItemCount: Int {
        cart.reduce(0) { $0 + $1.quantity }
    }

    func addToCart(_ product: Product, size: String? = nil, quantity: Int = 1) {
        guard product.isAvailable else {
            lastAddedProductName = "Cet article est actuellement non disponible"
            return
        }
        let chosenSize = size ?? product.category.availableSizes.first ?? "Standard"
        if let index = cart.firstIndex(where: { $0.product.id == product.id && $0.size == chosenSize }) {
            cart[index].quantity += quantity
        } else {
            cart.append(CartItem(product: product, size: chosenSize, quantity: quantity))
        }
        lastAddedProductName = "Ajouté : \(product.name) (\(chosenSize))"
    }

    func updateQuantity(for item: CartItem, delta: Int) {
        guard let index = cart.firstIndex(where: { $0.id == item.id }) else { return }
        let newQty = cart[index].quantity + delta
        if newQty <= 0 {
            cart.remove(at: index)
        } else {
            cart[index].quantity = newQty
        }
    }

    func clearCart() {
        cart.removeAll()
    }

    func toggleFavorite(_ product: Product) {
        if favorites.contains(product.id) {
            favorites.remove(product.id)
        } else {
            favorites.insert(product.id)
        }
    }

    func directProductWhatsAppURL(product: Product, size: String, quantity: Int) -> URL? {
        let lines = [
            "Bonjour *RBS (Ratousha Baby Shop)* 👋,",
            product.isAvailable ? "Je souhaite commander cet article :" : "Je souhaite connaître la disponibilité de cet article :",
            "• *\(product.name)*",
            "• Statut affiché : *\(product.availabilityText)*",
            "• \(product.category.sizeLabel) : *\(size)*",
            "• Quantité : *\(quantity)*"
        ]
        let message = lines.joined(separator: "\n")
        let encoded = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "https://wa.me/\(whatsappNumber)?text=\(encoded)")
    }

    func whatsappOrderURL() -> URL? {
        var lines: [String] = [
            "Bonjour *RBS (Ratousha Baby Shop)* 👋,",
            "Je suis intéressé(e) par (\(cartItemCount) article\(cartItemCount > 1 ? "s" : "")) :"
        ]
        for item in cart {
            lines.append("• \(item.quantity)x *\(item.product.name)* [\(item.product.category.sizeLabel): \(item.size)] — \(item.product.availabilityText)")
        }
        let message = lines.joined(separator: "\n")
        let encoded = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "https://wa.me/\(whatsappNumber)?text=\(encoded)")
    }

    func phoneCallURL() -> URL? {
        URL(string: "tel://+\(whatsappNumber)")
    }

    private func loadCatalog() {
        if let data = try? Data(contentsOf: cmsStorageURL),
           let decoded = try? JSONDecoder().decode([Product].self, from: data),
           !decoded.isEmpty {
            self.products = decoded
            return
        }
        self.products = Self.defaultCatalog()
        saveCatalogToDisk()
    }

    static func defaultCatalog() -> [Product] {
        var catalog: [Product] = [
            // Chaussures (Noms conformes App Store Guideline 5.2.1 sans marques tierces)
            Product(name: "Sneakers Sport Bleu & Rouge", category: .shoes, isAvailable: true, imageFilename: "chaussure nike blue et rouge.jpeg", isFeatured: true, badge: "Best-Seller", rating: 4.9),
            Product(name: "Sneakers Running RBS Premium", category: .shoes, isAvailable: true, imageFilename: "chaussures nike.jpeg", isFeatured: true, badge: "Populaire", rating: 4.9),
            Product(name: "Baskets Urbaines RBS Original", category: .shoes, isAvailable: true, imageFilename: "adidas.jpeg", isFeatured: true, badge: "Tendance", rating: 4.8),
            Product(name: "Mocassins Cuir Marron", category: .shoes, isAvailable: true, imageFilename: "maron chaussures.jpeg", isFeatured: true, badge: "Prestige", rating: 5.0),
            Product(name: "Chaussures Homme Classique", category: .shoes, isAvailable: true, imageFilename: "chaussures hommes.jpeg", isFeatured: true, badge: "Luxe", rating: 4.9),
            Product(name: "Chaussures Noires Élégance", category: .shoes, isAvailable: true, imageFilename: "chaussures noire homme.jpeg", isFeatured: false, rating: 4.8),
            Product(name: "Derby Ville Noir", category: .shoes, isAvailable: true, imageFilename: "chaussures noir.jpeg", isFeatured: false, rating: 4.7),
            Product(name: "Crampons Football Pro", category: .shoes, isAvailable: true, imageFilename: "chaussures foot.jpeg", isFeatured: false, badge: "Sport", rating: 4.8),
            Product(name: "Crampons Terrain Élite", category: .shoes, isAvailable: true, imageFilename: "chaussurs foot.jpeg", isFeatured: false, rating: 4.7),
            Product(name: "Chaussures Détente RBS", category: .shoes, isAvailable: true, imageFilename: "chaussures.jpeg", isFeatured: false, rating: 4.6),
            Product(name: "Mocassins Confort Souple", category: .shoes, isAvailable: true, imageFilename: "chaussures .jpeg", isFeatured: false, rating: 4.7),
            Product(name: "Baskets Sport Casual", category: .shoes, isAvailable: true, imageFilename: "chaussures copie.jpeg", isFeatured: false, rating: 4.8),
            Product(name: "Sneakers Urbaines RBS", category: .shoes, isAvailable: true, imageFilename: "chaussurs.jpeg", isFeatured: false, rating: 4.7),

            // Hauts & Chemises
            Product(name: "Polo Maille Piquée Prestige", category: .tops, isAvailable: true, imageFilename: "lacoste.jpeg", isFeatured: true, badge: "Best-Seller", rating: 4.9),
            Product(name: "Ensemble Kaku Prestige", category: .tops, isAvailable: true, imageFilename: "kaku.jpeg", isFeatured: true, badge: "Exclusif", rating: 5.0),
            Product(name: "Chemise Bleue Royale", category: .tops, isAvailable: true, imageFilename: "chemine blue.jpeg", isFeatured: true, badge: "Nouveau", rating: 4.8),
            Product(name: "Chemise Bleu Ciel Slim", category: .tops, isAvailable: true, imageFilename: "chemineblue.jpeg", isFeatured: false, rating: 4.8),
            Product(name: "Chemise Cérémonie RBS", category: .tops, isAvailable: true, imageFilename: "chemine .jpeg", isFeatured: false, rating: 4.7),
            Product(name: "T-Shirt Bleu Coton Premium", category: .tops, isAvailable: true, imageFilename: "t-shirt blue.jpeg", isFeatured: false, rating: 4.8),
            Product(name: "T-Shirt Gris Chiné", category: .tops, isAvailable: true, imageFilename: "t-shirt gris.jpeg", isFeatured: false, rating: 4.7),
            Product(name: "T-Shirt Orange Éclat", category: .tops, isAvailable: true, imageFilename: "t-shirt orange.jpeg", isFeatured: false, rating: 4.7),
            Product(name: "T-Shirt Rouge Intense", category: .tops, isAvailable: true, imageFilename: "t-shirt rouge.jpeg", isFeatured: false, rating: 4.8),

            // Pantalons
            Product(name: "Jean Denim Coupe Droite", category: .pants, isAvailable: true, imageFilename: "jean.jpeg", isFeatured: true, badge: "Indispensable", rating: 4.9),

            // Tissus
            Product(name: "Tissu Blanc Bazin / Fil à Fil", category: .fabrics, isAvailable: true, imageFilename: "tissue blanc .jpeg", isFeatured: true, badge: "Qualité Supérieure", rating: 4.9),
            Product(name: "Tissu Gris Prestige", category: .fabrics, isAvailable: true, imageFilename: "tissue gris .jpeg", isFeatured: false, rating: 4.8),
            Product(name: "Tissu Marron Royal", category: .fabrics, isAvailable: true, imageFilename: "tissue maron.jpeg", isFeatured: false, rating: 4.8)
        ]

        let uniqueWhatsAppFiles = [
            "WhatsApp Image 2026-11-12 at 21.26.46.jpeg",
            "WhatsApp Image 2026-11-12 at 21.26.47.jpeg",
            "WhatsApp Image 2026-11-12 at 21.26.49.jpeg",
            "WhatsApp Image 2026-11-12 at 21.26.50.jpeg",
            "WhatsApp Image 2026-11-12 at 21.26.51.jpeg",
            "WhatsApp Image 2026-11-12 at 21.28.05 (1).jpeg",
            "WhatsApp Image 2026-11-12 at 21.28.05 (2).jpeg",
            "WhatsApp Image 2026-11-12 at 21.28.06 (4).jpeg",
            "WhatsApp Image 2026-11-12 at 21.28.06 (6).jpeg",
            "WhatsApp Image 2026-11-12 at 21.28.07 (2).jpeg",
            "WhatsApp Image 2026-11-12 at 21.28.07 (3).jpeg",
            "WhatsApp Image 2026-11-12 at 21.28.07 (4).jpeg",
            "WhatsApp Image 2026-11-12 at 21.28.07.jpeg",
            "WhatsApp Image 2026-11-12 at 21.28.08 (1).jpeg",
            "WhatsApp Image 2026-11-12 at 21.28.08 (2).jpeg",
            "WhatsApp Image 2026-11-12 at 21.28.08 (3).jpeg",
            "WhatsApp Image 2026-11-12 at 21.28.08 (4).jpeg",
            "WhatsApp Image 2026-11-12 at 21.28.08 (5).jpeg",
            "WhatsApp Image 2026-11-12 at 21.28.08.jpeg",
            "WhatsApp Image 2026-11-12 at 21.28.09 (1).jpeg",
            "WhatsApp Image 2026-11-12 at 21.28.09 (2).jpeg",
            "WhatsApp Image 2026-11-12 at 21.28.09 (3).jpeg",
            "WhatsApp Image 2026-11-12 at 21.28.09 (4).jpeg",
            "WhatsApp Image 2026-11-12 at 21.28.09 (5).jpeg",
            "WhatsApp Image 2026-11-12 at 21.28.09 (6).jpeg",
            "WhatsApp Image 2026-11-12 at 21.28.09.jpeg",
            "WhatsApp Image 2026-11-12 at 21.28.10 (1).jpeg",
            "WhatsApp Image 2026-11-12 at 21.28.10 (2).jpeg",
            "WhatsApp Image 2026-11-12 at 21.28.10 (3).jpeg",
            "WhatsApp Image 2026-11-12 at 21.28.10 (4).jpeg",
            "WhatsApp Image 2026-11-12 at 21.28.10 (5).jpeg",
            "WhatsApp Image 2026-11-12 at 21.28.10 (6).jpeg",
            "WhatsApp Image 2026-11-12 at 21.28.10 (7).jpeg",
            "WhatsApp Image 2026-11-12 at 21.28.11 (1).jpeg",
            "WhatsApp Image 2026-11-12 at 21.28.11.jpeg"
        ]

        for (idx, file) in uniqueWhatsAppFiles.enumerated() {
            catalog.append(
                Product(
                    name: "Arrivage Exclusif RBS #\(idx + 1)",
                    category: .newArrivals,
                    isAvailable: true,
                    imageFilename: file,
                    isFeatured: idx < 3,
                    badge: idx < 5 ? "Nouveau" : nil,
                    rating: 4.8
                )
            )
        }

        return catalog
    }
}
