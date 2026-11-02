import Foundation
import Testing
@testable import fartlekaudiocoach

struct PyramidWorkoutTests {
    private func blocks(count: Int) -> [HeartRateInterval] {
        (0..<count).map { _ in
            HeartRateInterval(iterations: 3, lowerHR: 70, upperHR: 85)
        }
    }

    @Test func intervalRoundTrips() throws {
        let interval = HeartRateInterval(iterations: 4, lowerHR: 65, upperHR: 80)
        let data = try JSONEncoder().encode(interval)
        #expect(try JSONDecoder().decode(HeartRateInterval.self, from: data) == interval)
        #expect(Set([interval, interval]).count == 1)
    }

    @Test func workoutRoundTrips() throws {
        let workout = try PyramidWorkout(
            name: "Custom Pyramid",
            warmupSeconds: 90,
            blocks: blocks(count: 6),
            isFavorite: true,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let data = try JSONEncoder().encode(workout)
        let decoded = try JSONDecoder().decode(PyramidWorkout.self, from: data)
        #expect(decoded == workout)
        #expect(Set([workout, decoded]).count == 1)
    }

    @Test func defaultsAndUniqueIdentifiers() throws {
        let first = try PyramidWorkout(name: "First", blocks: blocks(count: 1))
        let second = try PyramidWorkout(name: "Second", blocks: blocks(count: 1))
        #expect(first.id != second.id)
        #expect(first.blocks[0].id != second.blocks[0].id)
        #expect(first.warmupSeconds == 0)
        #expect(!first.isFavorite)
        #expect(!first.isBuiltIn)
    }

    @Test func rejectsMoreThanSixBlocks() {
        #expect(throws: PyramidWorkout.ValidationError.tooManyBlocks) {
            try PyramidWorkout(name: "Too many", blocks: blocks(count: 7))
        }
    }

    @Test func blockReplacementPreservesLimit() throws {
        var workout = try PyramidWorkout(name: "Editable", blocks: blocks(count: 1))
        try workout.setBlocks(blocks(count: 6))
        let original = workout
        #expect(throws: PyramidWorkout.ValidationError.tooManyBlocks) {
            try workout.setBlocks(blocks(count: 7))
        }
        #expect(workout == original)
    }

    @Test func decodingRejectsMoreThanSixBlocks() throws {
        let workout = try PyramidWorkout(name: "Valid", blocks: blocks(count: 6))
        let data = try JSONEncoder().encode(workout)
        var json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var encodedBlocks = try #require(json["blocks"] as? [[String: Any]])
        encodedBlocks.append(encodedBlocks[0])
        json["blocks"] = encodedBlocks
        let invalidData = try JSONSerialization.data(withJSONObject: json)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(PyramidWorkout.self, from: invalidData)
        }
    }

    @Test func standardTemplatesAreDistinctAndValid() {
        let templates = PyramidWorkout.standardTemplates
        #expect(templates.map(\.name) == ["Flat Fartlek", "Classic Pyramid", "Staircase", "Threshold Waves"])
        #expect(Set(templates.map(\.id)).count == templates.count)
        #expect(PyramidWorkout.flatFartlek == templates[0])
        #expect(PyramidWorkout.flatFartlek.blocks.count == 1)
        #expect(PyramidWorkout.flatFartlek.blocks[0].iterations == 8)
        #expect(PyramidWorkout.flatFartlek.blocks[0].lowerHR == 70)
        #expect(PyramidWorkout.flatFartlek.blocks[0].upperHR == 80)
        for template in templates {
            #expect(template.isBuiltIn)
            #expect(!template.blocks.isEmpty)
            #expect(template.blocks.count <= PyramidWorkout.maximumBlockCount)
            #expect(template.warmupSeconds == 600)
            #expect(!template.isFavorite)
            #expect(Set(template.blocks.map(\.id)).count == template.blocks.count)
            for block in template.blocks {
                #expect(block.iterations > 0)
                #expect(block.lowerHR < block.upperHR)
                #expect((0...100).contains(block.lowerHR))
                #expect((0...100).contains(block.upperHR))
            }
        }
    }

    @Test func newCustomPyramidsAreFreshSixBlockDrafts() throws {
        let first = try PyramidWorkout.newCustomPyramid()
        let second = try PyramidWorkout.newCustomPyramid()
        #expect(first.name == "Custom workout")
        #expect(!first.isBuiltIn)
        #expect(first.blocks.count == 6)
        #expect(Set(first.blocks.map(\.id)).count == 6)
        #expect(first.id != second.id)
        #expect(Set(first.blocks.map(\.id)).isDisjoint(with: second.blocks.map(\.id)))
    }

    @Test func customWorkoutMatchingTemplateRemainsCustom() throws {
        let template = PyramidWorkout.classicPyramid
        let custom = try PyramidWorkout(
            name: template.name,
            warmupSeconds: template.warmupSeconds,
            blocks: template.blocks
        )
        let data = try JSONEncoder().encode(custom)
        let decoded = try JSONDecoder().decode(PyramidWorkout.self, from: data)
        #expect(!decoded.isBuiltIn)
    }

    @Test(arguments: PyramidWorkout.standardTemplates)
    func legacySeededTemplatesAreRecognizedRegardlessOfUUID(template: PyramidWorkout) throws {
        let data = try JSONEncoder().encode(template)
        var json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "isBuiltIn")
        json["id"] = UUID().uuidString
        let legacyData = try JSONSerialization.data(withJSONObject: json)
        let decoded = try JSONDecoder().decode(PyramidWorkout.self, from: legacyData)
        #expect(decoded.isBuiltIn)
        #expect(decoded.id != template.id)
        #expect(decoded.name == template.name)
    }

    @Test func legacyCustomWorkoutRemainsCustom() throws {
        let custom = try PyramidWorkout(name: "My old workout", blocks: blocks(count: 2))
        let data = try JSONEncoder().encode(custom)
        var json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "isBuiltIn")
        let legacyData = try JSONSerialization.data(withJSONObject: json)
        #expect(try JSONDecoder().decode(PyramidWorkout.self, from: legacyData) == custom)
    }
}
