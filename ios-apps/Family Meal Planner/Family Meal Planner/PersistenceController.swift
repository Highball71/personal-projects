//
//  PersistenceController.swift
//  Family Meal Planner
//
//  Core Data + CloudKit persistence layer.
//  Replaces SwiftData's ModelContainer with an explicit
//  NSPersistentCloudKitContainer that supports household sharing.
//
//  NOTE: The Core Data model is built programmatically (not from an
//  .xcdatamodeld file) to work around an Xcode 26.2 indexer crash
//  triggered by .xcdatamodeld inside PBXFileSystemSynchronizedRootGroup.
//

import Combine
import CoreData
import CloudKit
import os

/// Observable persistence controller that owns the Core Data + CloudKit stack.
///
/// Designed to support a full tear-down and rebuild of the local stores
/// when the CloudKit sync pipeline becomes poisoned (e.g. stale export
/// queue from a previous install). Call `resetLocalStoresAndRebuildContainer()`
/// to destroy local SQLite files and recreate the container from scratch.
@MainActor
final class PersistenceController: ObservableObject {
    static let shared = PersistenceController()

    /// The CloudKit container identifier (must match entitlements).
    static let cloudKitContainerID = "iCloud.com.highball71.FamilyMealPlanner"

    /// The Core Data container — owns both private and shared stores.
    /// Replaced during a local reset; dependents must re-bind after reset.
    @Published private(set) var container: NSPersistentCloudKitContainer

    /// True while a local-store reset is in progress.
    /// The app root checks this flag and removes ALL @FetchRequest views
    /// from the hierarchy during the reset window, preventing stale-object
    /// crashes (CDRecipe, CDHouseholdMember, etc. from the old container).
    @Published private(set) var isResetting = false
    private var hasPerformedReset = false
    /// Direct access to the CKContainer for share acceptance.
    let ckContainer: CKContainer

    /// The managed object model — built once, reused across container rebuilds.
    let managedObjectModel: NSManagedObjectModel

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.highball71.FamilyMealPlanner",
        category: "Persistence"
    )

    // MARK: - Programmatic Model

    /// Builds the Core Data model in code — equivalent to the
    /// FamilyMealPlanner.xcdatamodeld that was causing indexer crashes.
    ///
    /// Entities (8 total):
    ///   - CDHousehold: Core household data
    ///   - CDRecipe: Recipe details with relationships to ingredients, meal plans, ratings, suggestions
    ///   - CDIngredient: Recipe ingredients
    ///   - CDMealPlan: Scheduled meals
    ///   - CDGroceryItem: Shopping list items
    ///   - CDHouseholdMember: Household member profiles
    ///   - CDMealSuggestion: Meal suggestions with ratings
    ///   - CDRecipeRating: Recipe ratings from household members
    ///
    /// Configurations: "Private" and "Shared", both containing all entities.
    static func buildModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        // -- CDHousehold entity ---
        let householdEntity = NSEntityDescription()
        householdEntity.name = "CDHousehold"
        householdEntity.managedObjectClassName = "CDHousehold"

        let householdID = NSAttributeDescription()
        householdID.name = "id"
        householdID.attributeType = .UUIDAttributeType
        householdID.isOptional = true

        let householdName = NSAttributeDescription()
        householdName.name = "name"
        householdName.attributeType = .stringAttributeType
        householdName.defaultValue = ""
        householdName.isOptional = false

        // -- CDIngredient entity ---
        let ingredientEntity = NSEntityDescription()
        ingredientEntity.name = "CDIngredient"
        ingredientEntity.managedObjectClassName = "CDIngredient"

        let ingredientID = NSAttributeDescription()
        ingredientID.name = "id"
        ingredientID.attributeType = .UUIDAttributeType
        ingredientID.isOptional = true

        let ingredientName = NSAttributeDescription()
        ingredientName.name = "name"
        ingredientName.attributeType = .stringAttributeType
        ingredientName.defaultValue = ""
        ingredientName.isOptional = false

        let ingredientQuantity = NSAttributeDescription()
        ingredientQuantity.name = "quantity"
        ingredientQuantity.attributeType = .doubleAttributeType
        ingredientQuantity.defaultValue = 1.0
        ingredientQuantity.isOptional = false

        let ingredientUnitRaw = NSAttributeDescription()
        ingredientUnitRaw.name = "unitRaw"
        ingredientUnitRaw.attributeType = .stringAttributeType
        ingredientUnitRaw.defaultValue = "piece"
        ingredientUnitRaw.isOptional = false

        // -- CDMealPlan entity ---
        let mealPlanEntity = NSEntityDescription()
        mealPlanEntity.name = "CDMealPlan"
        mealPlanEntity.managedObjectClassName = "CDMealPlan"

        let mealPlanID = NSAttributeDescription()
        mealPlanID.name = "id"
        mealPlanID.attributeType = .UUIDAttributeType
        mealPlanID.isOptional = true

        let mealPlanDate = NSAttributeDescription()
        mealPlanDate.name = "date"
        mealPlanDate.attributeType = .dateAttributeType
        mealPlanDate.isOptional = true

        let mealPlanMealTypeRaw = NSAttributeDescription()
        mealPlanMealTypeRaw.name = "mealTypeRaw"
        mealPlanMealTypeRaw.attributeType = .stringAttributeType
        mealPlanMealTypeRaw.defaultValue = "dinner"
        mealPlanMealTypeRaw.isOptional = false

        // -- CDGroceryItem entity ---
        let groceryItemEntity = NSEntityDescription()
        groceryItemEntity.name = "CDGroceryItem"
        groceryItemEntity.managedObjectClassName = "CDGroceryItem"

        let groceryItemID = NSAttributeDescription()
        groceryItemID.name = "id"
        groceryItemID.attributeType = .UUIDAttributeType
        groceryItemID.isOptional = true

        let groceryItemItemID = NSAttributeDescription()
        groceryItemItemID.name = "itemID"
        groceryItemItemID.attributeType = .stringAttributeType
        groceryItemItemID.defaultValue = ""
        groceryItemItemID.isOptional = false

        let groceryItemName = NSAttributeDescription()
        groceryItemName.name = "name"
        groceryItemName.attributeType = .stringAttributeType
        groceryItemName.defaultValue = ""
        groceryItemName.isOptional = false

        let groceryItemTotalQuantity = NSAttributeDescription()
        groceryItemTotalQuantity.name = "totalQuantity"
        groceryItemTotalQuantity.attributeType = .doubleAttributeType
        groceryItemTotalQuantity.defaultValue = 0
        groceryItemTotalQuantity.isOptional = false

        let groceryItemUnitRaw = NSAttributeDescription()
        groceryItemUnitRaw.name = "unitRaw"
        groceryItemUnitRaw.attributeType = .stringAttributeType
        groceryItemUnitRaw.defaultValue = "none"
        groceryItemUnitRaw.isOptional = false

        let groceryItemIsChecked = NSAttributeDescription()
        groceryItemIsChecked.name = "isChecked"
        groceryItemIsChecked.attributeType = .booleanAttributeType
        groceryItemIsChecked.defaultValue = false
        groceryItemIsChecked.isOptional = false

        let groceryItemWeekStart = NSAttributeDescription()
        groceryItemWeekStart.name = "weekStart"
        groceryItemWeekStart.attributeType = .dateAttributeType
        groceryItemWeekStart.isOptional = true

        // -- CDHouseholdMember entity ---
        let householdMemberEntity = NSEntityDescription()
        householdMemberEntity.name = "CDHouseholdMember"
        householdMemberEntity.managedObjectClassName = "CDHouseholdMember"

        let householdMemberID = NSAttributeDescription()
        householdMemberID.name = "id"
        householdMemberID.attributeType = .UUIDAttributeType
        householdMemberID.isOptional = true

        let householdMemberName = NSAttributeDescription()
        householdMemberName.name = "name"
        householdMemberName.attributeType = .stringAttributeType
        householdMemberName.defaultValue = ""
        householdMemberName.isOptional = false

        let householdMemberIsHeadCook = NSAttributeDescription()
        householdMemberIsHeadCook.name = "isHeadCook"
        householdMemberIsHeadCook.attributeType = .booleanAttributeType
        householdMemberIsHeadCook.defaultValue = false
        householdMemberIsHeadCook.isOptional = false

        // -- CDMealSuggestion entity ---
        let mealSuggestionEntity = NSEntityDescription()
        mealSuggestionEntity.name = "CDMealSuggestion"
        mealSuggestionEntity.managedObjectClassName = "CDMealSuggestion"

        let mealSuggestionID = NSAttributeDescription()
        mealSuggestionID.name = "id"
        mealSuggestionID.attributeType = .UUIDAttributeType
        mealSuggestionID.isOptional = true

        let mealSuggestionDate = NSAttributeDescription()
        mealSuggestionDate.name = "date"
        mealSuggestionDate.attributeType = .dateAttributeType
        mealSuggestionDate.isOptional = true

        let mealSuggestionMealTypeRaw = NSAttributeDescription()
        mealSuggestionMealTypeRaw.name = "mealTypeRaw"
        mealSuggestionMealTypeRaw.attributeType = .stringAttributeType
        mealSuggestionMealTypeRaw.defaultValue = "dinner"
        mealSuggestionMealTypeRaw.isOptional = false

        let mealSuggestionSuggestedBy = NSAttributeDescription()
        mealSuggestionSuggestedBy.name = "suggestedBy"
        mealSuggestionSuggestedBy.attributeType = .stringAttributeType
        mealSuggestionSuggestedBy.defaultValue = ""
        mealSuggestionSuggestedBy.isOptional = false

        let mealSuggestionDateCreated = NSAttributeDescription()
        mealSuggestionDateCreated.name = "dateCreated"
        mealSuggestionDateCreated.attributeType = .dateAttributeType
        mealSuggestionDateCreated.isOptional = true

        // -- CDRecipeRating entity ---
        let recipeRatingEntity = NSEntityDescription()
        recipeRatingEntity.name = "CDRecipeRating"
        recipeRatingEntity.managedObjectClassName = "CDRecipeRating"

        let recipeRatingID = NSAttributeDescription()
        recipeRatingID.name = "id"
        recipeRatingID.attributeType = .UUIDAttributeType
        recipeRatingID.isOptional = true

        let recipeRatingRaterName = NSAttributeDescription()
        recipeRatingRaterName.name = "raterName"
        recipeRatingRaterName.attributeType = .stringAttributeType
        recipeRatingRaterName.defaultValue = ""
        recipeRatingRaterName.isOptional = false

        let recipeRatingRating = NSAttributeDescription()
        recipeRatingRating.name = "rating"
        recipeRatingRating.attributeType = .integer16AttributeType
        recipeRatingRating.defaultValue = 3
        recipeRatingRating.isOptional = false

        let recipeRatingDateRated = NSAttributeDescription()
        recipeRatingDateRated.name = "dateRated"
        recipeRatingDateRated.attributeType = .dateAttributeType
        recipeRatingDateRated.isOptional = true

        // -- CDRecipe entity (EXPANDED) ---
        let recipeEntity = NSEntityDescription()
        recipeEntity.name = "CDRecipe"
        recipeEntity.managedObjectClassName = "CDRecipe"

        let recipeID = NSAttributeDescription()
        recipeID.name = "id"
        recipeID.attributeType = .UUIDAttributeType
        recipeID.isOptional = true

        let recipeName = NSAttributeDescription()
        recipeName.name = "name"
        recipeName.attributeType = .stringAttributeType
        recipeName.defaultValue = ""
        recipeName.isOptional = false

        let recipeCategoryRaw = NSAttributeDescription()
        recipeCategoryRaw.name = "categoryRaw"
        recipeCategoryRaw.attributeType = .stringAttributeType
        recipeCategoryRaw.defaultValue = "dinner"
        recipeCategoryRaw.isOptional = false

        let recipeServings = NSAttributeDescription()
        recipeServings.name = "servings"
        recipeServings.attributeType = .integer16AttributeType
        recipeServings.defaultValue = 4
        recipeServings.isOptional = false

        let recipePrepTimeMinutes = NSAttributeDescription()
        recipePrepTimeMinutes.name = "prepTimeMinutes"
        recipePrepTimeMinutes.attributeType = .integer16AttributeType
        recipePrepTimeMinutes.defaultValue = 30
        recipePrepTimeMinutes.isOptional = false

        let recipeCookTimeMinutes = NSAttributeDescription()
        recipeCookTimeMinutes.name = "cookTimeMinutes"
        recipeCookTimeMinutes.attributeType = .integer16AttributeType
        recipeCookTimeMinutes.defaultValue = 0
        recipeCookTimeMinutes.isOptional = false

        let recipeInstructions = NSAttributeDescription()
        recipeInstructions.name = "instructions"
        recipeInstructions.attributeType = .stringAttributeType
        recipeInstructions.defaultValue = ""
        recipeInstructions.isOptional = false

        let recipeDateCreated = NSAttributeDescription()
        recipeDateCreated.name = "dateCreated"
        recipeDateCreated.attributeType = .dateAttributeType
        recipeDateCreated.isOptional = true

        let recipeIsFavorite = NSAttributeDescription()
        recipeIsFavorite.name = "isFavorite"
        recipeIsFavorite.attributeType = .booleanAttributeType
        recipeIsFavorite.defaultValue = false
        recipeIsFavorite.isOptional = false

        let recipeSourceTypeRaw = NSAttributeDescription()
        recipeSourceTypeRaw.name = "sourceTypeRaw"
        recipeSourceTypeRaw.attributeType = .stringAttributeType
        recipeSourceTypeRaw.isOptional = true

        let recipeSourceDetail = NSAttributeDescription()
        recipeSourceDetail.name = "sourceDetail"
        recipeSourceDetail.attributeType = .stringAttributeType
        recipeSourceDetail.isOptional = true

        let recipeAddedByName = NSAttributeDescription()
        recipeAddedByName.name = "addedByName"
        recipeAddedByName.attributeType = .stringAttributeType
        recipeAddedByName.isOptional = true

        // -- Relationships ---

        // CDHousehold -> CDRecipe (to-many, cascade)
        let householdToRecipes = NSRelationshipDescription()
        householdToRecipes.name = "recipes"
        householdToRecipes.destinationEntity = recipeEntity
        householdToRecipes.isOptional = true
        householdToRecipes.minCount = 0
        householdToRecipes.maxCount = 0  // to-many
        householdToRecipes.deleteRule = .cascadeDeleteRule

        // CDRecipe -> CDHousehold (to-one, nullify)
        let recipeToHousehold = NSRelationshipDescription()
        recipeToHousehold.name = "household"
        recipeToHousehold.destinationEntity = householdEntity
        recipeToHousehold.isOptional = true
        recipeToHousehold.minCount = 0
        recipeToHousehold.maxCount = 1  // to-one
        recipeToHousehold.deleteRule = .nullifyDeleteRule

        // Wire up household <-> recipes inverse.
        householdToRecipes.inverseRelationship = recipeToHousehold
        recipeToHousehold.inverseRelationship = householdToRecipes

        // CDRecipe -> CDIngredient (to-many, cascade)
        let recipeToIngredients = NSRelationshipDescription()
        recipeToIngredients.name = "ingredients"
        recipeToIngredients.destinationEntity = ingredientEntity
        recipeToIngredients.isOptional = true
        recipeToIngredients.minCount = 0
        recipeToIngredients.maxCount = 0  // to-many
        recipeToIngredients.deleteRule = .cascadeDeleteRule

        // CDIngredient -> CDRecipe (to-one, nullify)
        let ingredientToRecipe = NSRelationshipDescription()
        ingredientToRecipe.name = "recipe"
        ingredientToRecipe.destinationEntity = recipeEntity
        ingredientToRecipe.isOptional = true
        ingredientToRecipe.minCount = 0
        ingredientToRecipe.maxCount = 1  // to-one
        ingredientToRecipe.deleteRule = .nullifyDeleteRule

        // Wire up recipe <-> ingredients inverse.
        recipeToIngredients.inverseRelationship = ingredientToRecipe
        ingredientToRecipe.inverseRelationship = recipeToIngredients

        // CDRecipe -> CDMealPlan (to-many, nullify)
        let recipeToMealPlans = NSRelationshipDescription()
        recipeToMealPlans.name = "mealPlans"
        recipeToMealPlans.destinationEntity = mealPlanEntity
        recipeToMealPlans.isOptional = true
        recipeToMealPlans.minCount = 0
        recipeToMealPlans.maxCount = 0  // to-many
        recipeToMealPlans.deleteRule = .nullifyDeleteRule

        // CDMealPlan -> CDRecipe (to-one, nullify)
        let mealPlanToRecipe = NSRelationshipDescription()
        mealPlanToRecipe.name = "recipe"
        mealPlanToRecipe.destinationEntity = recipeEntity
        mealPlanToRecipe.isOptional = true
        mealPlanToRecipe.minCount = 0
        mealPlanToRecipe.maxCount = 1  // to-one
        mealPlanToRecipe.deleteRule = .nullifyDeleteRule

        // Wire up recipe <-> mealPlans inverse.
        recipeToMealPlans.inverseRelationship = mealPlanToRecipe
        mealPlanToRecipe.inverseRelationship = recipeToMealPlans

        // CDRecipe -> CDRecipeRating (to-many, cascade)
        let recipeToRatings = NSRelationshipDescription()
        recipeToRatings.name = "ratings"
        recipeToRatings.destinationEntity = recipeRatingEntity
        recipeToRatings.isOptional = true
        recipeToRatings.minCount = 0
        recipeToRatings.maxCount = 0  // to-many
        recipeToRatings.deleteRule = .cascadeDeleteRule

        // CDRecipeRating -> CDRecipe (to-one, nullify)
        let ratingToRecipe = NSRelationshipDescription()
        ratingToRecipe.name = "recipe"
        ratingToRecipe.destinationEntity = recipeEntity
        ratingToRecipe.isOptional = true
        ratingToRecipe.minCount = 0
        ratingToRecipe.maxCount = 1  // to-one
        ratingToRecipe.deleteRule = .nullifyDeleteRule

        // Wire up recipe <-> ratings inverse.
        recipeToRatings.inverseRelationship = ratingToRecipe
        ratingToRecipe.inverseRelationship = recipeToRatings

        // CDRecipe -> CDMealSuggestion (to-many, cascade)
        let recipeToSuggestions = NSRelationshipDescription()
        recipeToSuggestions.name = "suggestions"
        recipeToSuggestions.destinationEntity = mealSuggestionEntity
        recipeToSuggestions.isOptional = true
        recipeToSuggestions.minCount = 0
        recipeToSuggestions.maxCount = 0  // to-many
        recipeToSuggestions.deleteRule = .cascadeDeleteRule

        // CDMealSuggestion -> CDRecipe (to-one, nullify)
        let suggestionToRecipe = NSRelationshipDescription()
        suggestionToRecipe.name = "recipe"
        suggestionToRecipe.destinationEntity = recipeEntity
        suggestionToRecipe.isOptional = true
        suggestionToRecipe.minCount = 0
        suggestionToRecipe.maxCount = 1  // to-one
        suggestionToRecipe.deleteRule = .nullifyDeleteRule

        // Wire up recipe <-> suggestions inverse.
        recipeToSuggestions.inverseRelationship = suggestionToRecipe
        suggestionToRecipe.inverseRelationship = recipeToSuggestions

        // CDHousehold -> CDHouseholdMember (to-many, cascade)
        let householdToMembers = NSRelationshipDescription()
        householdToMembers.name = "members"
        householdToMembers.destinationEntity = householdMemberEntity
        householdToMembers.isOptional = true
        householdToMembers.minCount = 0
        householdToMembers.maxCount = 0  // to-many
        householdToMembers.deleteRule = .cascadeDeleteRule

        // CDHouseholdMember -> CDHousehold (to-one, nullify)
        let memberToHousehold = NSRelationshipDescription()
        memberToHousehold.name = "household"
        memberToHousehold.destinationEntity = householdEntity
        memberToHousehold.isOptional = true
        memberToHousehold.minCount = 0
        memberToHousehold.maxCount = 1  // to-one
        memberToHousehold.deleteRule = .nullifyDeleteRule

        // Wire up household <-> members inverse.
        householdToMembers.inverseRelationship = memberToHousehold
        memberToHousehold.inverseRelationship = householdToMembers

        // CDHousehold -> CDGroceryItem (to-many, cascade)
        let householdToGroceryItems = NSRelationshipDescription()
        householdToGroceryItems.name = "groceryItems"
        householdToGroceryItems.destinationEntity = groceryItemEntity
        householdToGroceryItems.isOptional = true
        householdToGroceryItems.minCount = 0
        householdToGroceryItems.maxCount = 0  // to-many
        householdToGroceryItems.deleteRule = .cascadeDeleteRule

        // CDGroceryItem -> CDHousehold (to-one, nullify)
        let groceryItemToHousehold = NSRelationshipDescription()
        groceryItemToHousehold.name = "household"
        groceryItemToHousehold.destinationEntity = householdEntity
        groceryItemToHousehold.isOptional = true
        groceryItemToHousehold.minCount = 0
        groceryItemToHousehold.maxCount = 1  // to-one
        groceryItemToHousehold.deleteRule = .nullifyDeleteRule

        // Wire up household <-> groceryItems inverse.
        householdToGroceryItems.inverseRelationship = groceryItemToHousehold
        groceryItemToHousehold.inverseRelationship = householdToGroceryItems

        // -- Set entity properties ---
        householdEntity.properties = [householdID, householdName, householdToRecipes, householdToMembers, householdToGroceryItems]

        ingredientEntity.properties = [
            ingredientID, ingredientName, ingredientQuantity, ingredientUnitRaw,
            ingredientToRecipe
        ]

        mealPlanEntity.properties = [
            mealPlanID, mealPlanDate, mealPlanMealTypeRaw,
            mealPlanToRecipe
        ]

        groceryItemEntity.properties = [
            groceryItemID, groceryItemItemID, groceryItemName, groceryItemTotalQuantity,
            groceryItemUnitRaw, groceryItemIsChecked, groceryItemWeekStart,
            groceryItemToHousehold
        ]

        householdMemberEntity.properties = [
            householdMemberID, householdMemberName, householdMemberIsHeadCook,
            memberToHousehold
        ]

        mealSuggestionEntity.properties = [
            mealSuggestionID, mealSuggestionDate, mealSuggestionMealTypeRaw,
            mealSuggestionSuggestedBy, mealSuggestionDateCreated,
            suggestionToRecipe
        ]

        recipeRatingEntity.properties = [
            recipeRatingID, recipeRatingRaterName, recipeRatingRating, recipeRatingDateRated,
            ratingToRecipe
        ]

        recipeEntity.properties = [
            recipeID, recipeName, recipeCategoryRaw, recipeServings, recipePrepTimeMinutes,
            recipeCookTimeMinutes, recipeInstructions, recipeDateCreated, recipeIsFavorite,
            recipeSourceTypeRaw, recipeSourceDetail, recipeAddedByName,
            recipeToHousehold, recipeToIngredients, recipeToMealPlans, recipeToRatings, recipeToSuggestions
        ]

        // -- Model & Configurations ---
        let allEntities = [
            householdEntity, recipeEntity, ingredientEntity, mealPlanEntity,
            groceryItemEntity, householdMemberEntity, mealSuggestionEntity, recipeRatingEntity
        ]
        model.entities = allEntities

        // Both Private and Shared configurations include all entities.
        // This matches the split-store pattern for CloudKit sharing.
        // Calling setEntities implicitly creates the named configurations.
        model.setEntities(allEntities, forConfigurationName: "Private")
        model.setEntities(allEntities, forConfigurationName: "Shared")

        return model
    }

    // MARK: - Initialization

    init(inMemory: Bool = false) {
        // Build the model programmatically instead of loading from .xcdatamodeld.
        let model = Self.buildModel()
        self.managedObjectModel = model
        self.ckContainer = CKContainer(identifier: Self.cloudKitContainerID)
        self.container = Self.makeContainer(model: model, inMemory: inMemory, logger: logger)
        Self.configureViewContext(container)

        #if DEBUG
        runSchemaInitialization(container)
        #endif
    }

    // MARK: - Container Factory

    /// Creates a new NSPersistentCloudKitContainer with the private + shared
    /// store split. Reusable for both initial setup and post-reset rebuilds.
    private static func makeContainer(
        model: NSManagedObjectModel,
        inMemory: Bool = false,
        logger: Logger
    ) -> NSPersistentCloudKitContainer {
        let container = NSPersistentCloudKitContainer(
            name: "FamilyMealPlanner",
            managedObjectModel: model
        )

        // -- Store descriptions ---
        //
        // We configure TWO stores:
        //   1. Private store  — the owner's data (default zone)
        //   2. Shared store   — data shared via CKShare (shared zone)
        //
        // This is the Apple-recommended pattern for CloudKit sharing.

        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("No persistent store descriptions found")
        }

        // -- Private store (owner's data) ---
        let privateDescription = description.copy() as! NSPersistentStoreDescription

        if inMemory {
            privateDescription.url = URL(fileURLWithPath: "/dev/null")
        }

        let privateOptions = NSPersistentCloudKitContainerOptions(
            containerIdentifier: cloudKitContainerID
        )
        privateOptions.databaseScope = .private
        privateDescription.cloudKitContainerOptions = privateOptions
        privateDescription.configuration = "Private"

        // -- Shared store (household data from CKShare) ---
        let sharedDescription = description.copy() as! NSPersistentStoreDescription

        // Shared store must be at a DIFFERENT URL than private store.
        let sharedStoreURL = privateDescription.url!
            .deletingLastPathComponent()
            .appendingPathComponent("FamilyMealPlanner-shared.sqlite")
        sharedDescription.url = sharedStoreURL

        let sharedOptions = NSPersistentCloudKitContainerOptions(
            containerIdentifier: cloudKitContainerID
        )
        sharedOptions.databaseScope = .shared
        sharedDescription.cloudKitContainerOptions = sharedOptions
        sharedDescription.configuration = "Shared"

        // Replace the default description with our two stores.
        container.persistentStoreDescriptions = [privateDescription, sharedDescription]

        // -- Load stores ---
        //
        // If loading fails (e.g. model migration from SwiftData -> Core Data),
        // destroy the incompatible store and retry once.
        container.loadPersistentStores { description, error in
            if let error {
                logger.warning("Store load failed (\(description.configuration ?? "unknown")): \(error.localizedDescription) — destroying and retrying.")
                if let url = description.url {
                    let coordinator = container.persistentStoreCoordinator
                    try? coordinator.destroyPersistentStore(at: url, type: .sqlite)
                    // Remove leftover -wal and -shm files.
                    let fm = FileManager.default
                    try? fm.removeItem(at: URL(fileURLWithPath: url.path + "-wal"))
                    try? fm.removeItem(at: URL(fileURLWithPath: url.path + "-shm"))
                }
                // Retry loading — fatal if this also fails.
                container.loadPersistentStores { desc2, error2 in
                    if let error2 {
                        logger.error("Retry failed for '\(desc2.configuration ?? "unknown")': \(error2.localizedDescription)")
                        fatalError("Failed to load persistent store after reset: \(error2)")
                    }
                    logger.info("Loaded store after reset: \(desc2.configuration ?? "default")")
                }
                return
            }
            logger.info("Loaded store: \(description.configuration ?? "default") at \(description.url?.absoluteString ?? "unknown")")
        }

        return container
    }

    /// Configures the view context with standard settings for CloudKit sync.
    private static func configureViewContext(_ container: NSPersistentCloudKitContainer) {
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        // Pin the viewContext to the current query generation so that
        // UI reads are consistent even while background imports run.
        try? container.viewContext.setQueryGenerationFrom(.current)
    }

    /// Pushes the CloudKit schema in DEBUG builds.
    ///
    /// Uses a temporary private-only container because
    /// `initializeCloudKitSchema` must NOT be called on a container
    /// that has a `.shared`-scoped store — it would try to create the
    /// Core Data default zone in the shared database, which is illegal.
    private func runSchemaInitialization(_ container: NSPersistentCloudKitContainer) {
        #if DEBUG
        let model = managedObjectModel
        let containerID = Self.cloudKitContainerID
        let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "", category: "Persistence")
        Task.detached(priority: .background) {
            let schemaContainer = NSPersistentCloudKitContainer(
                name: "FamilyMealPlanner-SchemaInit",
                managedObjectModel: model
            )
            guard let desc = schemaContainer.persistentStoreDescriptions.first else { return }
            desc.url = URL(fileURLWithPath: "/dev/null")
            let opts = NSPersistentCloudKitContainerOptions(
                containerIdentifier: containerID
            )
            opts.databaseScope = .private
            desc.cloudKitContainerOptions = opts
            schemaContainer.persistentStoreDescriptions = [desc]
            schemaContainer.loadPersistentStores { _, error in
                if let error { logger.warning("Schema-init store load: \(error.localizedDescription)") }
            }
            do {
                try schemaContainer.initializeCloudKitSchema(options: [])
                logger.info("initializeCloudKitSchema: Development schema updated")
            } catch {
                logger.warning("initializeCloudKitSchema failed: \(error.localizedDescription)")
            }
        }
        #endif
    }

    // MARK: - Local Store Reset

    /// Destroys ALL local Core Data stores (private + shared) and rebuilds
    /// the container from scratch. CloudKit will re-download data on next sync.
    ///
    /// This is the key fix for the sharing hang: the poisoned export queue
    /// lives in Core Data's internal sync metadata inside the SQLite files.
    /// Deleting and recreating the stores forces a clean pipeline.
    ///
    /// Pass the active SyncMonitor so this method can detach it from the old
    /// container and reattach it to the new one. This guarantees no service
    /// retains a stale container reference after the rebuild.
    ///
    /// After calling this method:
    /// - The `container` property is replaced with a new instance
    /// - All old NSManagedObject instances are INVALID — re-fetch everything
    /// - SyncMonitor is reattached to the new container automatically
    /// - A default household is recreated
    func resetLocalStoresAndRebuildContainer(syncMonitor: SyncMonitor? = nil) async throws {
        guard !hasPerformedReset else {
            logger.warning("resetLocalStores: already performed, skipping")
            return
        }

        hasPerformedReset = true
        logger.info("resetLocalStores: starting tear-down")

        // 0. Signal that a reset is in progress.
        //    The app root observes this and removes ALL @FetchRequest views
        //    from the hierarchy, preventing stale-object crashes.
        isResetting = true

        // 1. Detach all observers from the OLD container.
        //    This prevents SyncMonitor from receiving stale notifications
        //    and capturing a reference to the container we're about to destroy.
        if let syncMonitor {
            logger.info("resetLocalStores: detaching SyncMonitor from old container")
            syncMonitor.detach()
            syncMonitor.resetState()
        }

        // 2. Reset the viewContext to release all managed objects.
        container.viewContext.reset()

        // 3. Collect store URLs before we destroy them.
        let storeURLs = container.persistentStoreCoordinator.persistentStores.compactMap { $0.url }

        // 4. Destroy each persistent store via the coordinator.
        let coordinator = container.persistentStoreCoordinator
        for store in coordinator.persistentStores {
            if let url = store.url {
                do {
                    try coordinator.destroyPersistentStore(at: url, type: .sqlite)
                    logger.info("resetLocalStores: destroyed store at \(url.lastPathComponent)")
                } catch {
                    logger.warning("resetLocalStores: destroyPersistentStore failed for \(url.lastPathComponent): \(error.localizedDescription)")
                }
            }
        }

        // 5. Delete sidecar files (.sqlite, .sqlite-shm, .sqlite-wal).
        let fm = FileManager.default
        for url in storeURLs {
            for suffix in ["", "-shm", "-wal"] {
                let fileURL = URL(fileURLWithPath: url.path + suffix)
                try? fm.removeItem(at: fileURL)
            }
        }
        logger.info("resetLocalStores: deleted SQLite files and sidecars")

        // 6. Build a fresh container with the same model.
        let newContainer = Self.makeContainer(
            model: managedObjectModel,
            logger: logger
        )
        Self.configureViewContext(newContainer)

        #if DEBUG
        runSchemaInitialization(newContainer)
        #endif

        // 7. Replace the published container — triggers UI updates via @Published.
        container = newContainer
        logger.info("resetLocalStores: new container built and active")

        // 8. Ensure a default household exists (the app assumes one).
        ensureDefaultHouseholdExists()

        // 9. Reattach SyncMonitor to the NEW container so it observes
        //    fresh CloudKit events and shares the correct container reference.
        if let syncMonitor {
            logger.info("resetLocalStores: reattaching SyncMonitor to new container")
            syncMonitor.attach(to: newContainer)
        }

        logger.info("resetLocalStores: rebuild complete — all references updated")

        // 10. Clear the resetting flag AFTER a brief yield so SwiftUI has
        //     time to tear down old views before we allow new ones to appear.
        //     This ensures @FetchRequest views are freshly created with the
        //     new managedObjectContext, not recycled with stale objects.
        try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1s
        isResetting = false
        logger.info("resetLocalStores: isResetting cleared — views can rebind")
    }

    /// Creates a default household if none exists. Called after a local reset
    /// because the reset deletes all local data (CloudKit will re-sync it,
    /// but until then the app needs a household object to function).
    func ensureDefaultHouseholdExists() {
        let request = CDHousehold.fetchRequest()
        let count = (try? container.viewContext.count(for: request)) ?? 0
        guard count == 0 else { return }

        let household = CDHousehold(context: container.viewContext)
        household.id = UUID()
        household.name = "My Household"

        if let store = privateStore {
            container.viewContext.assign(household, to: store)
        }

        try? container.viewContext.save()
        logger.info("Created default household in PRIVATE store")
    }

    // MARK: - Backfill Orphaned Objects

    /// One-time repair: assigns any CDRecipe or CDGroceryItem with a nil
    /// household to the default household so they become reachable from
    /// the shared object graph.
    ///
    /// This covers data created before the household relationships were
    /// consistently wired at creation time. Safe to call on every launch —
    /// it's a no-op when nothing is orphaned.
    func backfillOrphanedObjects() {
        let ctx = container.viewContext

        // Get (or create) the default household.
        let householdRequest = CDHousehold.fetchRequest()
        householdRequest.fetchLimit = 1
        guard let household = (try? ctx.fetch(householdRequest))?.first else {
            logger.info("backfill: no household found, skipping")
            return
        }

        // Orphaned recipes (household == nil).
        let recipeRequest = CDRecipe.fetchRequest()
        recipeRequest.predicate = NSPredicate(format: "household == nil")
        let orphanedRecipes = (try? ctx.fetch(recipeRequest)) ?? []

        for recipe in orphanedRecipes {
            recipe.household = household
        }

        // Orphaned grocery items (household == nil).
        let groceryRequest = CDGroceryItem.fetchRequest()
        groceryRequest.predicate = NSPredicate(format: "household == nil")
        let orphanedGroceries = (try? ctx.fetch(groceryRequest)) ?? []

        for item in orphanedGroceries {
            item.household = household
        }

        if orphanedRecipes.isEmpty && orphanedGroceries.isEmpty {
            return
        }

        logger.info("backfill: linked \(orphanedRecipes.count) recipes and \(orphanedGroceries.count) grocery items to household")
        try? ctx.save()
    }

    // MARK: - Helpers

    /// Returns the private persistent store (owner's data).
    var privateStore: NSPersistentStore? {
        container.persistentStoreCoordinator.persistentStores.first {
            $0.configurationName == "Private"
        }
    }

    /// Returns the shared persistent store (household data).
    var sharedStore: NSPersistentStore? {
        container.persistentStoreCoordinator.persistentStores.first {
            $0.configurationName == "Shared"
        }
    }
}
