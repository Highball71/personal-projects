import SwiftUI
import XCTest
@testable import Family_Meal_Planner

final class HybridRedesignTests: XCTestCase {
    private let householdID = UUID()

    override func setUp() async throws {
        FakePostgRESTStore.shared.reset()
        URLProtocol.registerClass(FakePostgRESTProtocol.self)
        await MainActor.run { SupabaseManager.shared.setCurrentHousehold(householdID) }
    }

    override func tearDown() async throws {
        await MainActor.run { SupabaseManager.shared.setCurrentHousehold(nil) }
        URLProtocol.unregisterClass(FakePostgRESTProtocol.self)
        FakePostgRESTStore.shared.reset()
    }

    @MainActor
    func testHistoryAddsWithoutReplacingExistingImages() async throws {
        let id = TestFixtures.seedRecipe(householdID: householdID, name: "Family soup")
        let recipes = RecipeService()
        await recipes.fetchRecipes()
        let recipe = try XCTUnwrap(recipes.recipes.first { $0.id == id })
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20))
        let image = renderer.image { context in UIColor.orange.setFill(); context.fill(CGRect(x: 0, y: 0, width: 20, height: 20)) }
        let service = FamilyPhotoService()
        try await service.add(image, caption: "First attempt", to: recipe)
        try await service.add(image, caption: "Second attempt", to: recipe)
        let photos = try await service.photos(for: recipe)
        XCTAssertEqual(photos.count, 2)
        XCTAssertEqual(Set(photos.map(\.imagePath)).count, 2)
        XCTAssertEqual(Set(photos.map(\.caption)), ["First attempt", "Second attempt"])
        await recipes.fetchRecipes()
        XCTAssertEqual(recipes.recipes.first?.homemadeImagePath, recipe.homemadeImagePath)
        XCTAssertEqual(recipes.recipes.first?.sourceImagePath, recipe.sourceImagePath)
    }

    @MainActor
    func testBlockedHistoryUploadDoesNotCreateRecord() async throws {
        let id = TestFixtures.seedRecipe(householdID: householdID, name: "Family soup")
        let recipes = RecipeService()
        await recipes.fetchRecipes()
        let recipe = try XCTUnwrap(recipes.recipes.first { $0.id == id })
        FakePostgRESTStore.shared.storageUploadBlocked = true
        let image = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10)).image { _ in }
        do {
            try await FamilyPhotoService().add(image, caption: "Not saved", to: recipe)
            XCTFail("Blocked uploads must fail")
        } catch { }
        XCTAssertTrue(FakePostgRESTStore.shared.rows(in: "recipe_family_photos").isEmpty)
    }

    @MainActor
    func testTextContrastInBothAppearances() {
        func luminance(_ color: Color, _ style: UIUserInterfaceStyle) -> Double {
            let resolved = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            resolved.getRed(&r, green: &g, blue: &b, alpha: &a)
            func linear(_ x: CGFloat) -> Double { x <= 0.04045 ? Double(x / 12.92) : pow(Double((x + 0.055) / 1.055), 2.4) }
            return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
        }
        let originalPalette = SeasonalAppearance.shared.palette
        let originalBackdrop = SeasonalAppearance.shared.backdrop
        defer {
            SeasonalAppearance.shared.palette = originalPalette
            SeasonalAppearance.shared.backdrop = originalBackdrop
        }
        for text in [Color.fluffyPaperOnInk, .fluffyPaperDimOnInk] {
            let a = luminance(text, .dark), b = luminance(.fluffyInkGround, .dark)
            XCTAssertGreaterThanOrEqual((max(a,b) + 0.05) / (min(a,b) + 0.05), 4.5)
        }
        // Backdrop experiment: fluffyBackground follows the chosen
        // backdrop, so every text × season pair must clear 4.5:1 on
        // every backdrop in both appearances, not just on cream.
        for backdrop in FluffyBackdrop.allCases {
            SeasonalAppearance.shared.backdrop = backdrop
        for palette in SeasonalPalette.allCases {
            SeasonalAppearance.shared.palette = palette
        for style in [UIUserInterfaceStyle.light, .dark] {
            for text in [Color.fluffyPrimary, .fluffySecondary, .fluffyAccent] {
                for surface in [Color.fluffyBackground, .fluffyCard] {
                    let a = luminance(text, style), b = luminance(surface, style)
                    XCTAssertGreaterThanOrEqual(
                        (max(a,b) + 0.05) / (min(a,b) + 0.05), 4.5,
                        "\(backdrop.rawValue) backdrop, \(palette.rawValue), \(style == .dark ? "dark" : "light")")
                }
            }
        }
        }
        }
    }

    /// Backdrop experiment hard rule: no teal or turquoise anywhere —
    /// every sky backdrop hue stays between 205° and 225°. (Cream is
    /// the shipped warm paper and is exempt by design.)
    @MainActor
    func testBackdropSkyHuesNeverDriftTowardTeal() {
        func hueDegrees(_ hex: String) -> Double {
            var int: UInt64 = 0
            Scanner(string: hex).scanHexInt64(&int)
            let r = Double((int >> 16) & 0xFF) / 255
            let g = Double((int >> 8) & 0xFF) / 255
            let b = Double(int & 0xFF) / 255
            let maxC = max(r, g, b), minC = min(r, g, b)
            let delta = maxC - minC
            guard delta > 0 else { return 0 }
            let hue: Double
            if maxC == r      { hue = (g - b) / delta }
            else if maxC == g { hue = 2 + (b - r) / delta }
            else              { hue = 4 + (r - g) / delta }
            return (hue * 60 + 360).truncatingRemainder(dividingBy: 360)
        }
        for backdrop in FluffyBackdrop.allCases where backdrop != .cream {
            for hex in [backdrop.page.light, backdrop.page.dark] {
                let hue = hueDegrees(hex)
                XCTAssertGreaterThanOrEqual(hue, 205, "\(backdrop.rawValue) #\(hex) hue \(hue)")
                XCTAssertLessThanOrEqual(hue, 225, "\(backdrop.rawValue) #\(hex) hue \(hue)")
            }
        }
    }

    @MainActor
    func testSeasonalCalendarAndPinnedChoice() {
        XCTAssertEqual(SeasonalPalette.automatic(month: 1, southernHemisphere: false), .winter)
        XCTAssertEqual(SeasonalPalette.automatic(month: 4, southernHemisphere: false), .spring)
        XCTAssertEqual(SeasonalPalette.automatic(month: 7, southernHemisphere: false), .summer)
        XCTAssertEqual(SeasonalPalette.automatic(month: 10, southernHemisphere: false), .autumn)
        XCTAssertEqual(SeasonalPalette.automatic(month: 1, southernHemisphere: true), .summer)
        let appearance = SeasonalAppearance()
        appearance.refresh(choice: "Spring", southernHemisphere: false)
        XCTAssertEqual(appearance.palette, .spring)
    }

    @MainActor
    func testPhotoManagementPreservesHistoryAndSource() async throws {
        let id = TestFixtures.seedRecipe(householdID: householdID, name: "Soup")
        let recipes = RecipeService()
        await recipes.fetchRecipes()
        let recipe = try XCTUnwrap(recipes.recipes.first { $0.id == id })
        let service = FamilyPhotoService()
        let image = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10)).image { _ in }
        try await service.add(image, caption: "First", to: recipe)
        let addedPhotos = try await service.photos(for: recipe)
        let photo = try XCTUnwrap(addedPhotos.first)
        try await service.setCover(photo, for: recipe)
        await recipes.fetchRecipes()
        XCTAssertEqual(recipes.recipes.first?.familyCoverImagePath, photo.imagePath)
        XCTAssertEqual(recipes.recipes.first?.sourceImagePath, recipe.sourceImagePath)
        try await service.setCover(nil, for: recipe)
        try await service.update(photo, caption: "Updated note", archived: true)
        let updatedPhotos = try await service.photos(for: recipe)
        let archived = try XCTUnwrap(updatedPhotos.first)
        XCTAssertTrue(archived.isArchived)
        XCTAssertEqual(archived.caption, "Updated note")
        try await service.update(archived, caption: archived.caption, archived: false)
        let restored = try await service.photos(for: recipe)
        XCTAssertEqual(restored.count, 1)
        XCTAssertFalse(restored[0].isArchived)
    }

    @MainActor
    func testScannedPageAttachmentPreservesExistingOriginal() {
        let page = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10)).image { _ in }
        let form = SupabaseRecipeFormViewModel()
        form.attachScannedPageIfMissing(page)
        XCTAssertTrue(form.sourceImage === page)
        form.sourceImage = nil
        form.sourceImagePath = "original-page.jpg"
        form.attachScannedPageIfMissing(page)
        XCTAssertNil(form.sourceImage)
        XCTAssertEqual(form.sourceImagePath, "original-page.jpg")
        form.sourceImagePath = nil
        form.sourceImageRemoved = true
        form.attachScannedPageIfMissing(page)
        XCTAssertNil(form.sourceImage)
    }

    @MainActor
    func testCookbookPhotoIsSeparateAndUploadFailurePreservesRecipe() async throws {
        let id = TestFixtures.seedRecipe(householdID: householdID, name: "Book soup")
        let recipes = RecipeService()
        await recipes.fetchRecipes()
        let recipe = try XCTUnwrap(recipes.recipes.first { $0.id == id })
        let image = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20)).image { _ in }
        let service = CookbookPhotoService()
        try await service.save(image, for: recipe)
        await recipes.fetchRecipes()
        let saved = try XCTUnwrap(recipes.recipes.first { $0.id == id })
        let path = try XCTUnwrap(saved.cookbookImagePath)
        let storedImage = try XCTUnwrap(FakePostgRESTStore.shared.storageObject(at: "cookbook-recipe-photos/\(path)"))
        XCTAssertNotNil(UIImage(data: storedImage))
        let signed = try await service.imageURL(path: path)
        let (download, _) = try await URLSession.shared.data(from: signed)
        XCTAssertNotNil(UIImage(data: download), "Signed URL must deliver decodable image bytes")
        XCTAssertEqual(saved.sourceImagePath, recipe.sourceImagePath)
        XCTAssertEqual(saved.homemadeImagePath, recipe.homemadeImagePath)
        XCTAssertNil(saved.familyCoverImagePath)
        XCTAssertTrue(FakePostgRESTStore.shared.rows(in: "recipe_family_photos").isEmpty)
        FakePostgRESTStore.shared.storageUploadBlocked = true
        do { try await service.save(image, for: saved); XCTFail("Blocked upload must fail") }
        catch { }
        await recipes.fetchRecipes()
        XCTAssertEqual(recipes.recipes.first?.cookbookImagePath, path)
        XCTAssertEqual(recipes.recipes.count, 1)
    }

    @MainActor
    func testCookbookPhotoRejectsWrongHousehold() async throws {
        let recipe = try TestFixtures.recipeRow(householdID: UUID(), name: "Other household")
        let image = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20)).image { _ in }
        do { try await CookbookPhotoService().save(image, for: recipe); XCTFail("Wrong household") }
        catch { }
        XCTAssertTrue(FakePostgRESTStore.shared.rows(in: "recipes").isEmpty)
    }

    /// Real SwiftUI views with synthetic recipes and intercepted networking.
    /// Attachments are visual evidence, not pixel assertions.
    @MainActor
    func testScreenRenderings() async throws {
        let names = ["Lemon Herb Roasted Chicken", "Creamy Chicken Soup from the Cookbook", "Pesto Chicken Pasta", "Vegetable Soup"]
        for name in names {
            TestFixtures.seedRecipe(householdID: householdID, name: name,
                                   ingredients: [("chicken", 1, "lb"), ("lemon", 2, "piece")])
        }
        let recipes = RecipeService()
        await recipes.fetchRecipes()
        // Clearly labeled geometric test panels exercise image layout without
        // inventing food photography or copying cookbook artwork into fixtures.
        func panel(_ label: String, page: Bool = false) -> UIImage {
            let size = page ? CGSize(width: 400, height: 700) : CGSize(width: 700, height: 500)
            return UIGraphicsImageRenderer(size: size).image { context in
                UIColor.systemTeal.setFill(); context.fill(CGRect(origin: .zero, size: size))
                UIColor.systemOrange.setFill(); context.fill(CGRect(x: 40, y: 40, width: size.width - 80, height: size.height - 80))
                ("TEST IMAGE\n" + label).draw(in: CGRect(x: 60, y: 120, width: size.width - 120, height: 240),
                    withAttributes: [.font: UIFont.systemFont(ofSize: 36), .foregroundColor: UIColor.black])
            }
        }
        let family = try XCTUnwrap(recipes.recipes.first)
        let book = recipes.recipes[1]
        let source = recipes.recipes[2]
        let familyService = FamilyPhotoService()
        try await familyService.add(panel("Family cooking"), caption: "Test cooking history", to: family)
        let history = try await familyService.photos(for: family)
        try await familyService.setCover(try XCTUnwrap(history.first), for: family)
        try await CookbookPhotoService().save(panel("Cookbook picture"), for: book)
        let originalForm = SupabaseRecipeFormViewModel(recipe: source, ingredients: [])
        originalForm.sourceImage = panel("Original page", page: true)
        let originalSaved = await originalForm.save(recipeService: recipes)
        XCTAssertTrue(originalSaved)
        await recipes.fetchRecipes()
        let recipe = try XCTUnwrap(recipes.recipes.first { $0.id == family.id })
        let bookRecipe = try XCTUnwrap(recipes.recipes.first { $0.id == book.id })
        let sourceRecipe = try XCTUnwrap(recipes.recipes.first { $0.id == source.id })
        let noPhotoRecipe = try XCTUnwrap(recipes.recipes.first { !$0.hasDishPhoto && $0.sourceImagePath == nil })
        let household = HouseholdService()
        let mealPlan = MealPlanService()
        let grocery = GroceryService()
        let auth = AuthService()
        let previousStoreMode = UserDefaults.standard.bool(forKey: "groceryStoreMode")
        defer { UserDefaults.standard.set(previousStoreMode, forKey: "groceryStoreMode") }
        let groceriesSaved = await grocery.addItems([
            GroceryItemInsert(householdID: householdID, name: "Extra-virgin olive oil", quantity: 4, unit: "tbsp"),
            GroceryItemInsert(householdID: householdID, name: "arrowroot flour (or tapioca flour)", quantity: 4, unit: "tsp"),
            GroceryItemInsert(householdID: householdID, name: "Crushed tomatoes", quantity: 2, unit: "can", note: "14 ounces each"),
            GroceryItemInsert(householdID: householdID, name: "Fresh cilantro", quantity: 1, unit: "bunch")
        ])
        XCTAssertTrue(groceriesSaved)
        if let item = grocery.items.first(where: { $0.name == "Fresh cilantro" }) {
            let checked = await grocery.toggleChecked(item)
            XCTAssertTrue(checked)
        }
        let screens: [(String, AnyView)] = [
            ("CookbookStep", AnyView(CookbookPhotoStepView(recipe: recipe, isAfterScan: true) {})),
            ("Browse", AnyView(SupabaseRecipeListView())),
            ("Search", AnyView(SupabaseRecipeListView(initialSearch: "chicken"))),
            ("Details", AnyView(NavigationStack { SupabaseRecipeDetailView(recipe: recipe) })),
            ("BookDetails", AnyView(NavigationStack { SupabaseRecipeDetailView(recipe: bookRecipe) })),
            ("SourceDetails", AnyView(NavigationStack { SupabaseRecipeDetailView(recipe: sourceRecipe) })),
            ("NoPhotoDetails", AnyView(NavigationStack { SupabaseRecipeDetailView(recipe: noPhotoRecipe) })),
            ("Photos", AnyView(NavigationStack { SupabaseRecipeDetailView(recipe: recipe, initialSection: .photos) })),
            ("Planner", AnyView(SupabaseMealPlanView(selectedTab: .constant(.mealPlan)))),
            ("Grocery", AnyView(SupabaseGroceryListView(selectedTab: .constant(.groceries)))),
            ("GroceryStore", AnyView(SupabaseGroceryListView(selectedTab: .constant(.groceries)))),
            ("GroceryError", AnyView(SupabaseGroceryListView(selectedTab: .constant(.groceries))))
        ]
        for (name, screen) in screens {
            UserDefaults.standard.set(name == "GroceryStore", forKey: "groceryStoreMode")
            FakePostgRESTStore.shared.failGETTables = name == "GroceryError" ? ["grocery_items"] : []
            for (dark, large) in [(false, false), (true, false), (false, true)] {
                // Include system tab chrome; isolated pages missed the space
                // occupied by the bottom navigation in the installed build.
                let activeTab = name.hasPrefix("Grocery") ? 2 : name == "Planner" ? 0 : 1
                let root = TabView(selection: .constant(activeTab)) {
                    Group { if activeTab == 0 { screen } else { Text("Meals") } }
                        .tabItem { Label("Meals", systemImage: "calendar") }.tag(0)
                    Group { if activeTab == 1 { screen } else { Text("Recipes") } }
                        .tabItem { Label("Recipes", systemImage: "book") }.tag(1)
                    Group { if activeTab == 2 { screen } else { Text("Grocery") } }
                        .tabItem { Label("Grocery", systemImage: "cart") }.tag(2)
                    Text("Settings").tabItem { Label("Settings", systemImage: "gearshape") }.tag(3)
                }.tint(Color.fluffyAccent)
                    .environmentObject(recipes).environmentObject(household)
                    .environmentObject(mealPlan).environmentObject(grocery).environmentObject(auth)
                    .environment(\.colorScheme, dark ? .dark : .light)
                    .environment(\.dynamicTypeSize, large ? .accessibility3 : .large)
                    .transaction { $0.animation = nil; $0.disablesAnimations = true }
                    .id(UUID())
                let controller = UIHostingController(rootView: root)
                let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
                let window = UIWindow(windowScene: scene)
                window.frame = scene.coordinateSpace.bounds
                window.overrideUserInterfaceStyle = dark ? .dark : .light
                window.rootViewController = controller
                window.makeKeyAndVisible()
                controller.view.frame = window.bounds
                controller.view.setNeedsLayout()
                controller.view.layoutIfNeeded()
                try await Task.sleep(for: .seconds(1))
                let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                    XCTAssertTrue(window.drawHierarchy(in: window.bounds, afterScreenUpdates: true))
                }
                let attachment = XCTAttachment(image: image)
                attachment.name = "\(name)-\(dark ? "dark" : "light")\(large ? "-large-type" : "")"
                attachment.lifetime = .keepAlways
                add(attachment)
                XCTAssertGreaterThan(controller.view.bounds.width, 300)
                window.isHidden = true
            }
        }
    }
}
