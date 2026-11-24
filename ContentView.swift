import SwiftUI
import UniformTypeIdentifiers
#if canImport(Playgrounds)
import Playgrounds
#endif

@main struct MyApp: App {
    init() {
        #if os(macOS)
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                #if os(macOS)
                .frame(minWidth: 1020, minHeight: 740)
                #endif
        }
    }
}

struct AvailabilityBadgeView: View {
    let isAvailable: Bool

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(isAvailable ? Color.green : Color.red)
                .frame(width: 7, height: 7)
            Text(isAvailable ? "Disponible" : "Non disponible")
                .font(.caption2.bold())
                .foregroundStyle(isAvailable ? Color.green : Color.red)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background((isAvailable ? Color.green : Color.red).opacity(0.14))
        .clipShape(Capsule())
    }
}

struct ContentView: View {
    @StateObject private var store = StoreViewModel()
    @State private var selectedTab: Int = 0
    @State private var selectedProduct: Product?
    @Environment(\.openURL) private var openURL

    private let goldColor = Color(red: 0.90, green: 0.73, blue: 0.23)
    private let darkBg = Color(red: 0.07, green: 0.07, blue: 0.09)
    private let cardBg = Color(red: 0.13, green: 0.13, blue: 0.16)

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                shopTab
                    .tabItem {
                        Label("Boutique", systemImage: "bag.fill")
                    }
                    .tag(0)

                favoritesTab
                    .tabItem {
                        Label("Favoris", systemImage: "heart.fill")
                    }
                    .badge(store.favorites.count)
                    .tag(1)

                CartTabView(store: store, goldColor: goldColor, cardBg: cardBg, darkBg: darkBg, openURL: openURL)
                    .tabItem {
                        Label("Panier", systemImage: "cart.fill")
                    }
                    .badge(store.cartItemCount)
                    .tag(2)

                CMSAdminTabView(store: store, goldColor: goldColor, cardBg: cardBg, darkBg: darkBg)
                    .tabItem {
                        Label("CMS Admin", systemImage: store.isAdminAuthenticated ? "lock.open.fill" : "lock.fill")
                    }
                    .tag(3)

                ShopInfoTabView(store: store, goldColor: goldColor, cardBg: cardBg, darkBg: darkBg, openURL: openURL)
                    .tabItem {
                        Label("Infos RBS", systemImage: "storefront.fill")
                    }
                    .tag(4)
            }
            .tint(goldColor)

            if let addedName = store.lastAddedProductName {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.black)
                    Text(addedName)
                        .font(.subheadline.bold())
                        .foregroundStyle(.black)
                        .lineLimit(1)
                    Spacer()
                    if selectedTab != 2 && selectedTab != 3 {
                        Button("Voir Panier") {
                            store.lastAddedProductName = nil
                            selectedTab = 2
                        }
                        .font(.caption.weight(.heavy))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.black)
                        .foregroundStyle(goldColor)
                        .clipShape(Capsule())
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(goldColor)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.4), radius: 10, y: 4)
                .padding(.horizontal, 24)
                .padding(.bottom, 62)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
                        withAnimation {
                            if store.lastAddedProductName == addedName {
                                store.lastAddedProductName = nil
                            }
                        }
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(item: $selectedProduct) { product in
            ProductDetailSheet(
                product: product,
                store: store,
                goldColor: goldColor,
                cardBg: cardBg,
                openURL: openURL
            )
        }
    }

    private let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 260), spacing: 14)
    ]

    private var shopTab: some View {
        ZStack {
            darkBg.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar
                categoryAndSearchSection

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        heroBanner

                        if store.selectedCategory == .all && store.searchText.isEmpty && !store.featuredProducts.isEmpty {
                            featuredCarouselSection
                        }

                        HStack {
                            Text("\(store.selectedCategory.rawValue) (\(store.filteredProducts.count))")
                                .font(.headline.bold())
                                .foregroundStyle(.white)

                            Spacer()

                            Menu {
                                Picker("Trier par", selection: $store.sortOption) {
                                    ForEach(SortOption.allCases) { option in
                                        Text(option.rawValue).tag(option)
                                    }
                                }
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: "arrow.up.arrow.down")
                                    Text(store.sortOption.rawValue)
                                }
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(cardBg)
                                .foregroundStyle(goldColor)
                                .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, 18)

                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(store.filteredProducts) { product in
                                ProductCardView(
                                    product: product,
                                    isFavorite: store.favorites.contains(product.id),
                                    goldColor: goldColor,
                                    cardBg: cardBg,
                                    onTap: { selectedProduct = product },
                                    onAddToCart: {
                                        withAnimation {
                                            store.addToCart(product)
                                        }
                                    },
                                    onToggleFavorite: { store.toggleFavorite(product) }
                                )
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.bottom, 80)
                    }
                    .padding(.top, 14)
                }
            }
        }
    }

    private var favoritesTab: some View {
        ZStack {
            darkBg.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar

                if store.favoriteProducts.isEmpty {
                    Spacer()
                    VStack(spacing: 14) {
                        Image(systemName: "heart.slash")
                            .font(.system(size: 52))
                            .foregroundStyle(goldColor.opacity(0.6))
                        Text("Aucun favori pour le moment")
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                        Text("Touchez le cœur sur vos articles préférés pour les retrouver ici.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 36)
                        Button {
                            selectedTab = 0
                        } label: {
                            Text("Découvrir le catalogue")
                                .fontWeight(.bold)
                                .padding(.horizontal, 22)
                                .padding(.vertical, 12)
                                .background(goldColor)
                                .foregroundStyle(.black)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(store.favoriteProducts) { product in
                                ProductCardView(
                                    product: product,
                                    isFavorite: true,
                                    goldColor: goldColor,
                                    cardBg: cardBg,
                                    onTap: { selectedProduct = product },
                                    onAddToCart: {
                                        withAnimation {
                                            store.addToCart(product)
                                        }
                                    },
                                    onToggleFavorite: { store.toggleFavorite(product) }
                                )
                            }
                        }
                        .padding(18)
                    }
                }
            }
        }
    }

    private var headerBar: some View {
        HStack(spacing: 12) {
            if let logo = RBSImageLoader.image(named: "logo RBS.jpeg") {
                logo
                    .resizable()
                    .scaledToFill()
                    .frame(width: 46, height: 46)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(goldColor.opacity(0.7), lineWidth: 1.5)
                    )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(store.shopName)
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(goldColor)
                    .lineLimit(1)
                HStack(spacing: 5) {
                    Image(systemName: "phone.fill")
                        .font(.caption2)
                        .foregroundStyle(goldColor)
                    Text(store.phoneNumber)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                }
            }

            Spacer()

            Button {
                selectedTab = 3
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: store.isAdminAuthenticated ? "lock.open.fill" : "lock.fill")
                    Text("Admin")
                        .font(.caption.bold())
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(cardBg)
                .foregroundStyle(goldColor)
                .overlay(
                    Capsule().stroke(goldColor.opacity(0.5), lineWidth: 1)
                )
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Button {
                selectedTab = 2
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "cart.fill")
                    if store.cartItemCount > 0 {
                        Text("\(store.cartItemCount)")
                            .font(.caption.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.black)
                            .foregroundStyle(goldColor)
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(goldColor)
                .foregroundStyle(.black)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.9))
    }

    private var categoryAndSearchSection: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(goldColor)
                TextField("Rechercher chaussure, polo, chemise, tissu...", text: $store.searchText)
                    .textFieldStyle(.plain)
                    .foregroundStyle(.white)
                if !store.searchText.isEmpty {
                    Button {
                        store.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.gray)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 18)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ProductCategory.allCases) { category in
                        let isSelected = store.selectedCategory == category
                        Button {
                            withAnimation(.snappy) {
                                store.selectedCategory = category
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: category.icon)
                                Text(category.rawValue)
                                    .fontWeight(.semibold)
                            }
                            .font(.caption)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 8)
                            .background(isSelected ? goldColor : cardBg)
                            .foregroundStyle(isSelected ? .black : .white)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 18)
            }
        }
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.6))
    }

    private var heroBanner: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("RATOUSHA BABY SHOP • DAKAR")
                    .font(.caption2.weight(.heavy))
                    .tracking(1.2)
                    .foregroundStyle(goldColor)

                Text("L'élégance & le style de prestige")
                    .font(.title3.bold())
                    .foregroundStyle(.white)

                Text("Catalogue officiel • Contact & commande directe sur WhatsApp.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }
            Spacer()
            if let logo = RBSImageLoader.image(named: "logo RBS.jpeg") {
                logo
                    .resizable()
                    .scaledToFit()
                    .frame(width: 76, height: 76)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(goldColor.opacity(0.5), lineWidth: 1)
                    )
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [Color.black, cardBg, goldColor.opacity(0.22)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(goldColor.opacity(0.4), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 18)
    }

    private var featuredCarouselSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "crown.fill")
                    .foregroundStyle(goldColor)
                Text("Sélection Prestige RBS")
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                Spacer()
            }
            .padding(.horizontal, 18)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(store.featuredProducts) { product in
                        FeaturedCardView(
                            product: product,
                            goldColor: goldColor,
                            cardBg: cardBg,
                            onTap: { selectedProduct = product },
                            onAdd: {
                                withAnimation {
                                    store.addToCart(product)
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 18)
            }
        }
    }
}

// MARK: - CMS Admin Views (Ultra-Simple)

struct CMSAdminTabView: View {
    @ObservedObject var store: StoreViewModel
    let goldColor: Color
    let cardBg: Color
    let darkBg: Color

    @State private var editingProduct: Product?
    @State private var name: String = ""
    @State private var category: ProductCategory = .shoes
    @State private var isAvailable: Bool = true
    @State private var imageFilename: String = ""
    @State private var showingFileImporter = false
    @State private var uploadErrorMessage: String?

    @State private var passwordInput: String = ""
    @State private var showPassword: Bool = false
    @State private var loginErrorMessage: String?

    var body: some View {
        ZStack {
            darkBg.ignoresSafeArea()

            if !store.isAdminAuthenticated {
                adminLoginView
            } else {
                cmsAuthenticatedContent
            }
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.image, .jpeg, .png],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                switch RBSImageLoader.importMedia(from: url) {
                case .success(let importedName):
                    uploadErrorMessage = nil
                    imageFilename = importedName
                case .failure(let err):
                    uploadErrorMessage = err.localizedDescription
                }
            }
        }
    }

    private var adminLoginView: some View {
        VStack(spacing: 20) {
            Spacer()

            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(goldColor.opacity(0.15))
                        .frame(width: 74, height: 74)
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(goldColor)
                }

                VStack(spacing: 4) {
                    Text("Accès Administrateur CMS")
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                    Text("Veuillez saisir le mot de passe administrateur pour gérer les articles RBS.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: 10) {
                    Image(systemName: "key.fill")
                        .foregroundStyle(goldColor)

                    Group {
                        if showPassword {
                            TextField("Mot de passe administrateur", text: $passwordInput)
                        } else {
                            SecureField("Mot de passe administrateur", text: $passwordInput)
                        }
                    }
                    .textFieldStyle(.plain)
                    .foregroundStyle(.white)
                    .onSubmit {
                        attemptLogin()
                    }

                    Button {
                        showPassword.toggle()
                    } label: {
                        Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                            .foregroundStyle(.gray)
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .background(Color.black.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(goldColor.opacity(0.4), lineWidth: 1)
                )

                if let loginErrorMessage {
                    Text(loginErrorMessage)
                        .font(.caption.bold())
                        .foregroundStyle(.red)
                }

                Button {
                    attemptLogin()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.open.fill")
                        Text("Déverrouiller le CMS")
                            .font(.headline.bold())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(goldColor)
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
            .padding(26)
            .frame(maxWidth: 420)
            .background(cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(goldColor.opacity(0.35), lineWidth: 1)
            )
            .padding(.horizontal, 20)

            Spacer()
        }
    }

    private func attemptLogin() {
        if store.authenticateAdmin(password: passwordInput) {
            passwordInput = ""
            loginErrorMessage = nil
        } else {
            loginErrorMessage = "Mot de passe incorrect. Accès réservé à l'administrateur."
        }
    }

    private var cmsAuthenticatedContent: some View {
        ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Formulaire direct en haut : Upload photo -> Cocher Disponible -> Nom -> Cocher Type -> Envoyer
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text(editingProduct == nil ? "Ajouter un article" : "Modifier l'article")
                                .font(.title3.bold())
                                .foregroundStyle(goldColor)
                            Spacer()
                            Text(RBSImageLoader.formattedMediaUsage())
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            if editingProduct != nil {
                                Button("Annuler") {
                                    resetForm()
                                }
                                .font(.caption.bold())
                                .foregroundStyle(.red)
                                .buttonStyle(.plain)
                            }
                            Button {
                                store.logoutAdmin()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "lock.fill")
                                    Text("Verrouiller")
                                }
                                .font(.caption.bold())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.red.opacity(0.2))
                                .foregroundStyle(.red)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }

                        // 1. Upload une photo
                        HStack(spacing: 14) {
                            Group {
                                if !imageFilename.isEmpty, let img = RBSImageLoader.image(named: imageFilename) {
                                    img
                                        .resizable()
                                        .scaledToFill()
                                } else {
                                    ZStack {
                                        Color.black.opacity(0.4)
                                        Image(systemName: "photo.badge.plus")
                                            .font(.title2)
                                            .foregroundStyle(goldColor)
                                    }
                                }
                            }
                            .frame(width: 72, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(goldColor.opacity(0.5), lineWidth: 1)
                            )

                            VStack(alignment: .leading, spacing: 6) {
                                Button {
                                    showingFileImporter = true
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "arrow.up.doc.fill")
                                        Text(imageFilename.isEmpty ? "1. Uploader une photo" : "Changer la photo")
                                            .fontWeight(.bold)
                                    }
                                    .font(.subheadline)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 9)
                                    .background(goldColor)
                                    .foregroundStyle(.black)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)

                                if !imageFilename.isEmpty {
                                    Text(imageFilename)
                                        .font(.caption2)
                                        .foregroundStyle(.green)
                                        .lineLimit(1)
                                }

                                if let uploadErrorMessage {
                                    Text(uploadErrorMessage)
                                        .font(.caption2.bold())
                                        .foregroundStyle(.red)
                                }
                            }
                        }

                        // 2. Cocher Disponible / Non disponible
                        VStack(alignment: .leading, spacing: 6) {
                            Text("2. Disponibilité")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)

                            HStack(spacing: 16) {
                                Button {
                                    isAvailable = true
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: isAvailable ? "checkmark.square.fill" : "square")
                                            .font(.title3)
                                            .foregroundStyle(isAvailable ? Color.green : .gray)
                                        Text("Disponible")
                                            .font(.subheadline.bold())
                                            .foregroundStyle(.white)
                                    }
                                }
                                .buttonStyle(.plain)

                                Button {
                                    isAvailable = false
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: !isAvailable ? "checkmark.square.fill" : "square")
                                            .font(.title3)
                                            .foregroundStyle(!isAvailable ? Color.red : .gray)
                                        Text("Non disponible")
                                            .font(.subheadline.bold())
                                            .foregroundStyle(.white)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        // 3. Écrire le nom de l'article
                        VStack(alignment: .leading, spacing: 6) {
                            Text("3. Nom de l'article")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)

                            TextField("Écrire le nom de l'article...", text: $name)
                                .textFieldStyle(.plain)
                                .padding(11)
                                .background(Color.black.opacity(0.45))
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }

                        // 4. Cocher le type
                        VStack(alignment: .leading, spacing: 8) {
                            Text("4. Cocher le type d'article")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 14) {
                                    ForEach(ProductCategory.editableCategories) { cat in
                                        let isChecked = (category == cat)
                                        Button {
                                            category = cat
                                        } label: {
                                            HStack(spacing: 6) {
                                                Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                                                    .foregroundStyle(isChecked ? goldColor : .gray)
                                                Text(cat.rawValue)
                                                    .font(.subheadline.weight(isChecked ? .bold : .regular))
                                                    .foregroundStyle(.white)
                                            }
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 7)
                                            .background(Color.black.opacity(0.35))
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }

                        // 5. Bouton Envoyer
                        Button {
                            submitForm()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "paperplane.fill")
                                Text(editingProduct == nil ? "Envoyer" : "Mettre à jour")
                                    .font(.headline.bold())
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(goldColor)
                            .foregroundStyle(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(18)
                    .background(cardBg)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(goldColor.opacity(0.35), lineWidth: 1)
                    )

                    // Liste des articles existants (Modifier / Supprimer)
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Articles publiés (\(store.products.count))")
                                .font(.headline.bold())
                                .foregroundStyle(.white)
                            Spacer()
                        }

                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(goldColor)
                            TextField("Rechercher un article...", text: $store.cmsSearchText)
                                .textFieldStyle(.plain)
                                .foregroundStyle(.white)
                        }
                        .padding(10)
                        .background(cardBg)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                        LazyVStack(spacing: 10) {
                            ForEach(store.cmsFilteredProducts) { product in
                                CMSProductRowView(
                                    product: product,
                                    goldColor: goldColor,
                                    cardBg: cardBg,
                                    onToggleAvailability: {
                                        store.toggleAvailability(product)
                                    },
                                    onEdit: {
                                        startEditing(product)
                                    },
                                    onDelete: {
                                        store.deleteProduct(product)
                                    }
                                )
                            }
                        }
                    }
                }
                .padding(18)
                .padding(.bottom, 40)
        }
    }

    private func submitForm() {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else {
            uploadErrorMessage = "Veuillez écrire le nom de l'article."
            return
        }
        let chosenImage = imageFilename.isEmpty ? (RBSImageLoader.availableImageFiles().first ?? "logo RBS.jpeg") : imageFilename

        if let existing = editingProduct {
            let updated = Product(
                id: existing.id,
                name: cleanName,
                category: category,
                isAvailable: isAvailable,
                imageFilename: chosenImage,
                isFeatured: existing.isFeatured,
                badge: existing.badge
            )
            store.updateProduct(updated)
        } else {
            let newProduct = Product(
                name: cleanName,
                category: category,
                isAvailable: isAvailable,
                imageFilename: chosenImage
            )
            store.addProduct(newProduct)
        }
        resetForm()
    }

    private func startEditing(_ product: Product) {
        editingProduct = product
        name = product.name
        category = product.category == .all ? .shoes : product.category
        isAvailable = product.isAvailable
        imageFilename = product.imageFilename
        uploadErrorMessage = nil
    }

    private func resetForm() {
        editingProduct = nil
        name = ""
        category = .shoes
        isAvailable = true
        imageFilename = ""
        uploadErrorMessage = nil
    }
}

struct CMSProductRowView: View {
    let product: Product
    let goldColor: Color
    let cardBg: Color
    let onToggleAvailability: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let img = RBSImageLoader.image(named: product.imageFilename) {
                    img
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        Color.gray.opacity(0.2)
                        Image(systemName: "photo")
                            .foregroundStyle(.gray)
                    }
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(product.name)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(product.category.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onToggleAvailability) {
                HStack(spacing: 5) {
                    Image(systemName: product.isAvailable ? "checkmark.square.fill" : "square")
                    Text(product.isAvailable ? "Disponible" : "Non disponible")
                        .font(.caption.bold())
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background((product.isAvailable ? Color.green : Color.red).opacity(0.2))
                .foregroundStyle(product.isAvailable ? Color.green : Color.red)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)

            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .font(.subheadline.bold())
                    .padding(8)
                    .background(goldColor)
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.subheadline.bold())
                    .padding(8)
                    .background(Color.red.opacity(0.2))
                    .foregroundStyle(.red)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Customer Boutique Components

struct FeaturedCardView: View {
    let product: Product
    let goldColor: Color
    let cardBg: Color
    let onTap: () -> Void
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                Group {
                    if let img = RBSImageLoader.image(named: product.imageFilename) {
                        img
                            .resizable()
                            .scaledToFill()
                    } else {
                        Color.gray.opacity(0.2)
                    }
                }
                .frame(width: 200, height: 150)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .opacity(product.isAvailable ? 1.0 : 0.55)
                .onTapGesture(perform: onTap)

                if let badge = product.badge {
                    Text(badge.uppercased())
                        .font(.system(size: 9, weight: .heavy))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(goldColor)
                        .foregroundStyle(.black)
                        .clipShape(Capsule())
                        .padding(8)
                }
            }

            Text(product.name)
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .lineLimit(1)

            HStack {
                AvailabilityBadgeView(isAvailable: product.isAvailable)
                Spacer()
                if product.isAvailable {
                    Button(action: onAdd) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(goldColor)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(width: 200)
        .padding(10)
        .background(cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(goldColor.opacity(0.25), lineWidth: 1)
        )
    }
}

struct ProductCardView: View {
    let product: Product
    let isFavorite: Bool
    let goldColor: Color
    let cardBg: Color
    let onTap: () -> Void
    let onAddToCart: () -> Void
    let onToggleFavorite: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let img = RBSImageLoader.image(named: product.imageFilename) {
                        img
                            .resizable()
                            .scaledToFill()
                    } else {
                        ZStack {
                            Color.gray.opacity(0.2)
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundStyle(.gray)
                        }
                    }
                }
                .frame(height: 175)
                .frame(maxWidth: .infinity)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .opacity(product.isAvailable ? 1.0 : 0.5)
                .contentShape(Rectangle())
                .onTapGesture(perform: onTap)

                HStack {
                    if let badge = product.badge {
                        Text(badge)
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(goldColor)
                            .foregroundStyle(.black)
                            .clipShape(Capsule())
                    }
                    Spacer()
                    Button(action: onToggleFavorite) {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .foregroundStyle(isFavorite ? .red : .white)
                            .padding(7)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(8)
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 4) {
                    Text(product.category.rawValue.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(goldColor)
                    Spacer()
                    Image(systemName: "star.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(goldColor)
                    Text(String(format: "%.1f", product.rating))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                }

                Text(product.name)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .onTapGesture(perform: onTap)

                HStack {
                    AvailabilityBadgeView(isAvailable: product.isAvailable)

                    Spacer()

                    if product.isAvailable {
                        Button(action: onAddToCart) {
                            HStack(spacing: 3) {
                                Image(systemName: "plus")
                                Text("Ajouter")
                            }
                            .font(.caption2.bold())
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(goldColor)
                            .foregroundStyle(.black)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 2)
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 4)
        }
        .padding(8)
        .background(cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

struct ProductDetailSheet: View {
    let product: Product
    @ObservedObject var store: StoreViewModel
    let goldColor: Color
    let cardBg: Color
    let openURL: OpenURLAction
    @Environment(\.dismiss) private var dismiss

    @State private var selectedSize: String = ""
    @State private var quantity: Int = 1

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text(product.category.rawValue.uppercased())
                        .font(.caption.bold())
                        .foregroundStyle(goldColor)
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                if let img = RBSImageLoader.image(named: product.imageFilename) {
                    img
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: 320)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(product.name)
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                        HStack(spacing: 6) {
                            ForEach(0..<5, id: \.self) { _ in
                                Image(systemName: "star.fill")
                                    .font(.caption)
                                    .foregroundStyle(goldColor)
                            }
                            Text("(\(String(format: "%.1f", product.rating)))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    AvailabilityBadgeView(isAvailable: product.isAvailable)
                }

                Text(product.description)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))

                VStack(alignment: .leading, spacing: 8) {
                    Text("Choisir la \(product.category.sizeLabel.lowercased()) :")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(product.category.availableSizes, id: \.self) { size in
                                let isChosen = selectedSize == size
                                Button {
                                    selectedSize = size
                                } label: {
                                    Text(size)
                                        .font(.subheadline.weight(.semibold))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(isChosen ? goldColor : cardBg)
                                        .foregroundStyle(isChosen ? .black : .white)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                HStack {
                    Text("Quantité :")
                        .font(.subheadline.bold())
                    Spacer()
                    HStack(spacing: 14) {
                        Button {
                            if quantity > 1 { quantity -= 1 }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title3)
                        }
                        .buttonStyle(.plain)

                        Text("\(quantity)")
                            .font(.headline.monospacedDigit())

                        Button {
                            quantity += 1
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                    }
                }

                VStack(spacing: 10) {
                    if product.isAvailable {
                        Button {
                            store.addToCart(product, size: selectedSize, quantity: quantity)
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: "cart.badge.plus")
                                Text("Ajouter au panier")
                                    .fontWeight(.bold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(goldColor)
                            .foregroundStyle(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        if let url = store.directProductWhatsAppURL(product: product, size: selectedSize, quantity: quantity) {
                            openURL(url)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "message.fill")
                            Text(product.isAvailable ? "Commander directement sur WhatsApp" : "Demander la disponibilité sur WhatsApp")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Color.green)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 6)
            }
            .padding(22)
        }
        .background(Color(red: 0.09, green: 0.09, blue: 0.11))
        .onAppear {
            selectedSize = product.category.availableSizes.first ?? "Standard"
        }
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 540)
        #endif
    }
}

struct CartTabView: View {
    @ObservedObject var store: StoreViewModel
    let goldColor: Color
    let cardBg: Color
    let darkBg: Color
    let openURL: OpenURLAction

    var body: some View {
        ZStack {
            darkBg.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Text("Mon Panier RBS")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    Spacer()
                    if !store.cart.isEmpty {
                        Button("Vider le panier") {
                            store.clearCart()
                        }
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .buttonStyle(.plain)
                    }
                }
                .padding(18)
                .background(Color.black.opacity(0.85))

                if store.cart.isEmpty {
                    Spacer()
                    VStack(spacing: 14) {
                        Image(systemName: "cart")
                            .font(.system(size: 54))
                            .foregroundStyle(goldColor.opacity(0.6))
                        Text("Votre panier est vide")
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                        Text("Ajoutez des articles disponibles pour commander rapidement sur WhatsApp.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 36)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            ForEach(store.cart) { item in
                                HStack(spacing: 12) {
                                    if let img = RBSImageLoader.image(named: item.product.imageFilename) {
                                        img
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 64, height: 64)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.product.name)
                                            .font(.subheadline.bold())
                                            .foregroundStyle(.white)
                                        Text("\(item.product.category.sizeLabel) : \(item.size)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        AvailabilityBadgeView(isAvailable: item.product.isAvailable)
                                    }
                                    Spacer()
                                    HStack(spacing: 10) {
                                        Button {
                                            store.updateQuantity(for: item, delta: -1)
                                        } label: {
                                            Image(systemName: "minus.circle.fill")
                                                .font(.title3)
                                        }
                                        .buttonStyle(.plain)

                                        Text("\(item.quantity)")
                                            .font(.subheadline.bold().monospacedDigit())

                                        Button {
                                            store.updateQuantity(for: item, delta: 1)
                                        } label: {
                                            Image(systemName: "plus.circle.fill")
                                                .font(.title3)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(12)
                                .background(cardBg)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }

                            HStack {
                                Text("Total d'articles sélectionnés")
                                    .font(.headline)
                                Spacer()
                                Text("\(store.cartItemCount) article\(store.cartItemCount > 1 ? "s" : "")")
                                    .font(.title3.bold())
                                    .foregroundStyle(goldColor)
                            }
                            .padding(14)
                            .background(cardBg)
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                            Button {
                                if let url = store.whatsappOrderURL() {
                                    openURL(url)
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "message.fill")
                                    Text("Envoyer la commande sur WhatsApp")
                                        .fontWeight(.bold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                                .background(Color.green)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(18)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
    }
}

struct ShopInfoTabView: View {
    @ObservedObject var store: StoreViewModel
    let goldColor: Color
    let cardBg: Color
    let darkBg: Color
    let openURL: OpenURLAction
    @State private var showingPrivacyPolicy = false

    var body: some View {
        ZStack {
            darkBg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    if let logo = RBSImageLoader.image(named: "logo RBS.jpeg") {
                        logo
                            .resizable()
                            .scaledToFit()
                            .frame(width: 150, height: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(goldColor, lineWidth: 2)
                            )
                            .padding(.top, 24)
                    }

                    VStack(spacing: 6) {
                        Text(store.shopName)
                            .font(.title2.weight(.heavy))
                            .foregroundStyle(goldColor)
                        Text("Prêt-à-porter • Chaussures • Chemises • Tissus de prestige")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    VStack(spacing: 12) {
                        infoRow(icon: "phone.fill", title: "Téléphone & WhatsApp", value: store.phoneNumber)
                        infoRow(icon: "clock.fill", title: "Disponibilité", value: "Lundi – Dimanche : 09h00 à 22h00")
                    }
                    .padding(.horizontal, 18)

                    HStack(spacing: 12) {
                        Button {
                            if let url = URL(string: "https://wa.me/\(store.whatsappNumber)") {
                                openURL(url)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "message.fill")
                                Text("Écrire sur WhatsApp")
                                    .fontWeight(.bold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.green)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)

                        Button {
                            if let url = store.phoneCallURL() {
                                openURL(url)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "phone.fill")
                                Text("Appeler")
                                    .fontWeight(.bold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(goldColor)
                            .foregroundStyle(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 18)

                    Button {
                        showingPrivacyPolicy = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "hand.raised.shield.fill")
                                .foregroundStyle(goldColor)
                            Text("Politique de confidentialité & Conditions d'utilisation")
                                .font(.caption.bold())
                                .foregroundStyle(.white.opacity(0.85))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(14)
                        .background(cardBg)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 18)
                }
                .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $showingPrivacyPolicy) {
            PrivacyPolicySheetView(store: store, goldColor: goldColor, cardBg: cardBg)
        }
    }

    private func infoRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(goldColor)
                .frame(width: 36, height: 36)
                .background(goldColor.opacity(0.15))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
            }
            Spacer()
        }
        .padding(14)
        .background(cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct PrivacyPolicySheetView: View {
    @ObservedObject var store: StoreViewModel
    let goldColor: Color
    let cardBg: Color
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Politique de confidentialité")
                    .font(.title3.bold())
                    .foregroundStyle(goldColor)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(18)
            .background(Color.black.opacity(0.9))

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    policySection(
                        title: "1. Collecte de données",
                        body: "L'application \(store.shopName) (RBS) ne collecte aucune donnée personnelle ni bancaire à l'insu de l'utilisateur. Les articles placés dans les favoris ou le panier sont conservés uniquement localement sur votre appareil."
                    )
                    policySection(
                        title: "2. Absence de paiement intégré",
                        body: "Aucune transaction financière ni saisie de moyen de paiement n'est effectuée au sein de l'application. L'application sert exclusivement de catalogue permettant de vérifier la disponibilité des articles."
                    )
                    policySection(
                        title: "3. Prise de contact via WhatsApp / Téléphone",
                        body: "Lorsque vous cliquez sur « Commander sur WhatsApp » ou « Appeler », l'application ouvre l'application externe WhatsApp ou Téléphone uniquement à votre demande explicite afin de contacter \(store.shopName) (\(store.phoneNumber))."
                    )
                    policySection(
                        title: "4. Accès aux fichiers et photos (Espace Admin)",
                        body: "L'accès aux fichiers images est utilisé exclusivement par l'administrateur de la boutique dans l'onglet CMS afin d'illustrer les articles du catalogue (dans la limite de 500 Mo)."
                    )
                    policySection(
                        title: "5. Contact & Support",
                        body: "Pour toute question relative à vos données ou au catalogue RBS, contactez-nous directement au \(store.phoneNumber)."
                    )
                }
                .padding(18)
            }
        }
        .background(Color(red: 0.08, green: 0.08, blue: 0.10))
        #if os(macOS)
        .frame(width: 500, height: 520)
        #endif
    }

    private func policySection(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(goldColor)
            Text(body)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    ContentView()
}
