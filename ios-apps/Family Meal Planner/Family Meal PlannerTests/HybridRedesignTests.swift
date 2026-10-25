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
        for style in [UIUserInterfaceStyle.light, .dark] {
            for text in [Color.fluffyPrimary, .fluffySecondary, .fluffyAccent] {
                for surface in [Color.fluffyBackground, .fluffyCard] {
                    let a = luminance(text, style), b = luminance(surface, style)
                    XCTAssertGreaterThanOrEqual((max(a,b) + 0.05) / (min(a,b) + 0.05), 4.5)
                }
            }
        }
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
                let root = screen.environmentObject(recipes).environmentObject(household)
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
