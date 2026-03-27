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

import CoreData
import CloudKit
import os

struct PersistenceController {
    static let shared = PersistenceController()

    /// The CloudKit container identifier (must match entitlements).
    static let cloudKitContainerID = "iCloud.com.highball71.FamilyMealPlanner"

    /// The Core Data container — owns both private and shared stores.
    let container: NSPersistentCloudKitContainer

    /// Direct access to the CKContainer for share acceptance.
    let ckContainer: CKContainer

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.highball71.FamilyMealPlanner",
        category: "Persistence"
    )

    // MARK: - Programmatic Model

    /// Builds the Core Data model in code — equivalent to the
    /// FamilyMealPlanner.xcdatamodeld that was causing indexer crashes.
    ///
    /// Entities (7 total):
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

        // ── CDHousehold entity ───────────────────────────────────────────
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

        // ── CDIngredient entity ──────────────────────────────────────────
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

        // ── CDMealPlan entity ────────────────────────────────────────────
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

        // ── CDGroceryItem entity ─────────────────────────────────────────
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

        // ── CDHouseholdMember entity ────────────────────────────────────
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

        // ── CDMealSuggestion entity ──────────────────────────────────────
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

        // ── CDRecipeRating entity ────────────────────────────────────────
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

        // ── CDRecipe entity (EXPANDED) ───────────────────────────────────
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

        // ── Relationships ────────────────────────────────────────────────

        // CDHousehold → CDRecipe (to-many, cascade)
        let householdToRecipes = NSRelationshipDescription()
        householdToRecipes.name = "recipes"
        householdToRecipes.destinationEntity = recipeEntity
        householdToRecipes.isOptional = true
        householdToRecipes.minCount = 0
        householdToRecipes.maxCount = 0  // to-many
        householdToRecipes.deleteRule = .cascadeDeleteRule

        // CDRecipe → CDHousehold (to-one, nullify)
        let recipeToHousehold = NSRelationshipDescription()
        recipeToHousehold.name = "household"
        recipeToHousehold.destinationEntity = householdEntity
        recipeToHousehold.isOptional = true
        recipeToHousehold.minCount = 0
        recipeToHousehold.maxCount = 1  // to-one
        recipeToHousehold.deleteRule = .nullifyDeleteRule

        // Wire up household ↔ recipes inverse.
        householdToRecipes.inverseRelationship = recipeToHousehold
        recipeToHousehold.inverseRelationship = householdToRecipes

        // CDRecipe → CDIngredient (to-many, cascade)
        let recipeToIngredients = NSRelationshipDescription()
        recipeToIngredients.name = "ingredients"
        recipeToIngredients.destinationEntity = ingredientEntity
        recipeToIngredients.isOptional = true
        recipeToIngredients.minCount = 0
        recipeToIngredients.maxCount = 0  // to-many
        recipeToIngredients.deleteRule = .cascadeDeleteRule

        // CDIngredient → CDRecipe (to-one, nullify)
        let ingredientToRecipe = NSRelationshipDescription()
        ingredientToRecipe.name = "recipe"
        ingredientToRecipe.destinationEntity = recipeEntity
        ingredientToRecipe.isOptional = true
        ingredientToRecipe.minCount = 0
        ingredientToRecipe.maxCount = 1  // to-one
        ingredientToRecipe.deleteRule = .nullifyDeleteRule

        // Wire up recipe ↔ ingredients inverse.
        recipeToIngredients.inverseRelationship = ingredientToRecipe
        ingredientToRecipe.inverseRelationship = recipeToIngredients

        // CDRecipe → CDMealPlan (to-many, nullify)
        let recipeToMealPlans = NSRelationshipDescription()
        recipeToMealPlans.name = "mealPlans"
        recipeToMealPlans.destinationEntity = mealPlanEntity
        recipeToMealPlans.isOptional = true
        recipeToMealPlans.minCount = 0
        recipeToMealPlans.maxCount = 0  // to-many
        recipeToMealPlans.deleteRule = .nullifyDeleteRule

        // CDMealPlan → CDRecipe (to-one, nullify)
        let mealPlanToRecipe = NSRelationshipDescription()
        mealPlanToRecipe.name = "recipe"
        mealPlanToRecipe.destinationEntity = recipeEntity
        mealPlanToRecipe.isOptional = true
        mealPlanToRecipe.minCount = 0
        mealPlanToRecipe.maxCount = 1  // to-one
        mealPlanToRecipe.deleteRule = .nullifyDeleteRule

        // Wire up recipe ↔ mealPlans inverse.
        recipeToMealPlans.inverseRelationship = mealPlanToRecipe
        mealPlanToRecipe.inverseRelationship = recipeToMealPlans

        // CDRecipe → CDRecipeRating (to-many, cascade)
        let recipeToRatings = NSRelationshipDescription()
        recipeToRatings.name = "ratings"
        recipeToRatings.destinationEntity = recipeRatingEntity
        recipeToRatings.isOptional = true
        recipeToRatings.minCount = 0
        recipeToRatings.maxCount = 0  // to-many
        recipeToRatings.deleteRule = .cascadeDeleteRule

        // CDRecipeRating → CDRecipe (to-one, nullify)
        let ratingToRecipe = NSRelationshipDescription()
        ratingToRecipe.name = "recipe"
        ratingToRecipe.destinationEntity = recipeEntity
        ratingToRecipe.isOptional = true
        ratingToRecipe.minCount = 0
        ratingToRecipe.maxCount = 1  // to-one
        ratingToRecipe.deleteRule = .nullifyDeleteRule

        // Wire up recipe ↔ ratings inverse.
        recipeToRatings.inverseRelationship = ratingToRecipe
        ratingToRecipe.inverseRelationship = recipeToRatings

        // CDRecipe → CDMealSuggestion (to-many, cascade)
        let recipeToSuggestions = NSRelationshipDescription()
        recipeToSuggestions.name = "suggestions"
        recipeToSuggestions.destinationEntity = mealSuggestionEntity
        recipeToSuggestions.isOptional = true
        recipeToSuggestions.minCount = 0
        recipeToSuggestions.maxCount = 0  // to-many
        recipeToSuggestions.deleteRule = .cascadeDeleteRule

        // CDMealSuggestion → CDRecipe (to-one, nullify)
        let suggestionToRecipe = NSRelationshipDescription()
        suggestionToRecipe.name = "recipe"
        suggestionToRecipe.destinationEntity = recipeEntity
        suggestionToRecipe.isOptional = true
        suggestionToRecipe.minCount = 0
        suggestionToRecipe.maxCount = 1  // to-one
        suggestionToRecipe.deleteRule = .nullifyDeleteRule

        // Wire up recipe ↔ suggestions inverse.
        recipeToSuggestions.inverseRelationship = suggestionToRecipe
        suggestionToRecipe.inverseRelationship = recipeToSuggestions

        // CDHousehold → CDHouseholdMember (to-many, cascade)
        let householdToMembers = NSRelationshipDescription()
        householdToMembers.name = "members"
        householdToMembers.destinationEntity = householdMemberEntity
        householdToMembers.isOptional = true
        householdToMembers.minCount = 0
        householdToMembers.maxCount = 0  // to-many
        householdToMembers.deleteRule = .cascadeDeleteRule

        // CDHouseholdMember → CDHousehold (to-one, nullify)
        let memberToHousehold = NSRelationshipDescription()
        memberToHousehold.name = "household"
        memberToHousehold.destinationEntity = householdEntity
        memberToHousehold.isOptional = true
        memberToHousehold.minCount = 0
        memberToHousehold.maxCount = 1  // to-one
        memberToHousehold.deleteRule = .nullifyDeleteRule

        // Wire up household ↔ members inverse.
        householdToMembers.inverseRelationship = memberToHousehold
        memberToHousehold.inverseRelationship = householdToMembers

        // ── Set entity properties ────────────────────────────────────────
        householdEntity.properties = [householdID, householdName, householdToRecipes, householdToMembers]

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
            groceryItemUnitRaw, groceryItemIsChecked, groceryItemWeekStart
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

        // ── Model & Configurations ───────────────────────────────────────
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

    init(inMemory: Bool = false) {
        // Build the model programmatically instead of loading from .xcdatamodeld.
        let model = Self.buildModel()
        container = NSPersistentCloudKitContainer(name: "FamilyMealPlanner", managedObjectModel: model)
        ckContainer = CKContainer(identifier: Self.cloudKitContainerID)

        // Capture logger and container locally so closures don't capture mutating 'self'.
        let logger = self.logger
        let container = self.container

        // ── Store descriptions ──────────────────────────────────────────
        //
        // We configure TWO stores:
        //   1. Private store  — the owner's data (default zone)
        //   2. Shared store   — data shared via CKShare (shared zone)
        //
        // This is the Apple-recommended pattern for CloudKit sharing.
        // See: https://developer.apple.com/documentation/coredata/mirroring_a_core_data_store_with_cloudkit

        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("No persistent store descriptions found")
        }

        // ── Private store (owner's data) ────────────────────────────────
        let privateDescription = description.copy() as! NSPersistentStoreDescription

        if inMemory {
            privateDescription.url = URL(fileURLWithPath: "/dev/null")
        }

        let privateOptions = NSPersistentCloudKitContainerOptions(
            containerIdentifier: Self.cloudKitContainerID
        )
        privateOptions.databaseScope = .private
        privateDescription.cloudKitContainerOptions = privateOptions
        privateDescription.configuration = "Private"

        // ── Shared store (household data from CKShare) ──────────────────
        let sharedDescription = description.copy() as! NSPersistentStoreDescription

        // Shared store must be at a DIFFERENT URL than private store.
        let sharedStoreURL = privateDescription.url!
            .deletingLastPathComponent()
            .appendingPathComponent("FamilyMealPlanner-shared.sqlite")
        sharedDescription.url = sharedStoreURL

        let sharedOptions = NSPersistentCloudKitContainerOptions(
            containerIdentifier: Self.cloudKitContainerID
        )
        sharedOptions.databaseScope = .shared
        sharedDescription.cloudKitContainerOptions = sharedOptions
        sharedDescription.configuration = "Shared"

        // Replace the default description with our two stores.
        container.persistentStoreDescriptions = [privateDescription, sharedDescription]

        // ── Load stores ─────────────────────────────────────────────────
        //
        // If loading fails (e.g. model migration from SwiftData → Core Data),
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

        // Merge changes from CloudKit automatically.
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        // Pin the viewContext to the current query generation so that
        // UI reads are consistent even while background imports run.
        try? container.viewContext.setQueryGenerationFrom(.current)

        #if DEBUG
        // Push the full CloudKit schema (including internal sharing fields)
        // to the Development environment. Safe to leave permanently — no-op
        // once all fields exist.
        let containerForSchema = container
        Task.detached(priority: .background) {
            do {
                try containerForSchema.initializeCloudKitSchema(options: [])
                Logger(subsystem: Bundle.main.bundleIdentifier ?? "", category: "Persistence")
                    .info("initializeCloudKitSchema: Development schema updated")
            } catch {
                Logger(subsystem: Bundle.main.bundleIdentifier ?? "", category: "Persistence")
                    .warning("initializeCloudKitSchema failed: \(error.localizedDescription)")
            }
        }
        #endif
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
