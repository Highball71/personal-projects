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
        defer { SeasonalAppearance.shared.palette = originalPalette }
        for palette in SeasonalPalette.allCases {
            SeasonalAppearance.shared.palette = palette
        for style in [UIUserInterfaceStyle.light, .dark] {
            for text in [Color.fluffyPrimary, .fluffySecondary, .fluffyAccent] {
                for surface in [Color.fluffyBackground, .fluffyCard] {
                    let a = luminance(text, style), b = luminance(surface, style)
                    XCTAssertGreaterThanOrEqual((max(a,b) + 0.05) / (min(a,b) + 0.05), 4.5)
                }
            }
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
        let recipe = try XCTUnwrap(recipes.recipes.first)
        let household = HouseholdService()
        let mealPlan = MealPlanService()
        let grocery = GroceryService()
        let auth = AuthService()
        let screens: [(String, AnyView)] = [
            ("Browse", AnyView(SupabaseRecipeListView())),
            ("Search", AnyView(SupabaseRecipeListView(initialSearch: "chicken"))),
            ("Details", AnyView(NavigationStack { SupabaseRecipeDetailView(recipe: recipe) })),
            ("Photos", AnyView(NavigationStack { SupabaseRecipeDetailView(recipe: recipe, initialSection: .photos) })),
            ("Planner", AnyView(SupabaseMealPlanView(selectedTab: .constant(.mealPlan))))
        ]
        for (name, screen) in screens {
            for (dark, large) in [(false, false), (true, false), (false, true)] {
                // Include system tab chrome; isolated pages missed the space
                // occupied by the bottom navigation in the installed build.
                let root = TabView(selection: .constant(1)) {
                    Text("Meals").tabItem { Label("Meals", systemImage: "calendar") }.tag(0)
                    screen.tabItem { Label("Recipes", systemImage: "book") }.tag(1)
                    Text("Grocery").tabItem { Label("Grocery", systemImage: "cart") }.tag(2)
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
