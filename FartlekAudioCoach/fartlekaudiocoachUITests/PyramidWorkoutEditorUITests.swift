import XCTest

final class PyramidWorkoutEditorUITests: XCTestCase {
    @MainActor
    func testLoadPyramidWorkoutIntoRunner() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()

        for name in ["Flat Fartlek", "Classic Pyramid", "Custom workout"] {
            let picker = app.buttons["selectSession"]
            XCTAssertTrue(picker.waitForExistence(timeout: 20))
            picker.tap()
            XCTAssertTrue(app.navigationBars["Select Session"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.staticTexts["Templates"].exists)
            XCTAssertFalse(app.staticTexts["Pyramid 6-3-1-3-6"].exists)

            let row = name == "Custom workout"
                ? app.buttons["createCustomPyramid"]
                : app.cells.containing(.staticText, identifier: name).firstMatch
            XCTAssertTrue(row.waitForExistence(timeout: 5))
            scrollTo(row, in: app)
            row.tap()
            let use = app.buttons["usePyramidWorkout"]
            XCTAssertTrue(use.waitForExistence(timeout: 5))
            use.tap()

            XCTAssertTrue(app.navigationBars["Fartlek"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.staticTexts[name].exists)
            XCTAssertFalse(app.navigationBars["Editor"].exists)
        }
    }

    @MainActor
    func testCreateAndRenameSavedWorkout() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()

        let sessionPicker = app.buttons["selectSession"]
        XCTAssertTrue(sessionPicker.waitForExistence(timeout: 20))
        sessionPicker.tap()
        XCTAssertTrue(app.navigationBars["Select Session"].waitForExistence(timeout: 5))

        let create = app.buttons["createCustomPyramid"]
        XCTAssertTrue(create.waitForExistence(timeout: 5))
        scrollTo(create, in: app)
        create.tap()

        let uniqueName = "UI Pyramid \(UUID().uuidString.prefix(8))"
        saveWorkout(named: uniqueName, in: app)
        app.navigationBars["Editor"].buttons.element(boundBy: 0).tap()

        let savedRow = app.cells.containing(.staticText, identifier: uniqueName).firstMatch
        XCTAssertTrue(savedRow.waitForExistence(timeout: 5))
        scrollTo(savedRow, in: app)
        savedRow.tap()
        let renamed = uniqueName + " Renamed"
        saveWorkout(named: renamed, in: app)
        app.navigationBars["Editor"].buttons.element(boundBy: 0).tap()

        let renamedRow = app.cells.containing(.staticText, identifier: renamed).firstMatch
        XCTAssertTrue(renamedRow.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts[uniqueName].exists)
        scrollTo(renamedRow, in: app)
        renamedRow.swipeLeft()
        app.buttons["Delete"].firstMatch.tap()
        XCTAssertFalse(app.staticTexts[renamed].exists)
    }

    @MainActor
    private func saveWorkout(named name: String, in app: XCUIApplication) {
        let save = app.buttons["savePyramidWorkout"]
        scrollTo(save, in: app)
        save.tap()
        let alert = app.alerts["Save Workout"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        let field = alert.textFields.firstMatch
        field.tap()
        let currentValue = field.value as? String ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count))
        field.typeText(name)
        alert.buttons["Save"].tap()
        let confirmation = app.descendants(matching: .any)["workoutSavedConfirmation"].firstMatch
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5))
    }

    @MainActor
    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<12 {
            if element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable)
    }
}
