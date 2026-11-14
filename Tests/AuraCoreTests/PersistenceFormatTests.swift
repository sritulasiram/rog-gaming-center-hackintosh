import Foundation
import Testing
@testable import AuraCore

/// Saved settings and presets are stored as JSON. These literals are what released
/// versions wrote: if one stops decoding, an update would lose users' saved lighting.
/// Never edit them to make a test pass; add a migration instead.
@Suite struct PersistenceFormatTests {
    func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }

    static let red = #"{"red":255,"green":0,"blue":0}"#
    static let blue = #"{"red":0,"green":0,"blue":255}"#

    @Test func everyModeDecodesFromItsReleasedFormat() throws {
        let red = AuraColor.red, blue = AuraColor.deepBlue
        let cases: [(String, AuraMode)] = [
            (#"{"off":{}}"#, .off),
            (#"{"singleStatic":{"_0":\#(Self.red)}}"#, .singleStatic(red)),
            (#"{"multiStatic":{"_0":[\#(Self.red),\#(Self.blue)]}}"#, .multiStatic([red, blue])),
            (#"{"colorCycle":{"_0":1}}"#, .colorCycle(.slow)),
            (#"{"rainbow":{"_0":3}}"#, .rainbow(.fast)),
            (#"{"singleBreathing":{"_0":\#(Self.red),"_1":\#(Self.blue),"_2":2}}"#, .singleBreathing(red, blue, .medium)),
            (#"{"multiBreathing":{"_0":[\#(Self.red)],"_1":2}}"#, .multiBreathing([red], .medium)),
            (#"{"strobing":{"_0":\#(Self.blue),"_1":3}}"#, .strobing(blue, .fast)),
        ]
        for (json, expected) in cases {
            #expect(try decode(AuraMode.self, json) == expected, "\(json)")
        }
    }

    @Test func encodingMatchesTheReleasedFormat() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let json = String(decoding: try encoder.encode(AuraMode.strobing(.deepBlue, .fast)), as: UTF8.self)
        #expect(json == #"{"strobing":{"_0":{"blue":255,"green":0,"red":0},"_1":3}}"#)
    }

    @Test func presetAndStateDecodeFromTheirReleasedFormat() throws {
        let preset = try decode(AuraPreset.self, #"""
        {"id":"A1","name":"Mine","icon":"paintpalette.fill","isCustom":true,
         "mode":{"singleStatic":{"_0":\#(Self.red)}},"previewColors":[\#(Self.red)]}
        """#)
        #expect(preset.name == "Mine" && preset.isCustom && preset.mode == .singleStatic(.red))

        let state = try decode(LightingState.self, #"""
        {"mode":{"rainbow":{"_0":2}},"brightness":2,"isOn":false,"presetID":"rainbow"}
        """#)
        #expect(state == LightingState(mode: .rainbow(.medium), brightness: 2, isOn: false, presetID: "rainbow"))
    }

    @Test func lossyArrayKeepsReadableElements() throws {
        let presets = try decode(LossyArray<AuraPreset>.self, #"""
        [{"id":"A","name":"Good","icon":"x","isCustom":true,"mode":{"colorCycle":{"_0":2}},"previewColors":[]},
         {"id":"B","name":"From the future","icon":"x","isCustom":true,"mode":{"laserShow":{}},"previewColors":[]},
         42,
         {"id":"C","name":"Also good","icon":"x","isCustom":true,"mode":{"off":{}},"previewColors":[]}]
        """#).elements
        #expect(presets.map(\.id) == ["A", "C"])
    }

    @Test func lossyArrayRejectsNonArrays() {
        #expect(throws: (any Error).self) { try decode(LossyArray<AuraPreset>.self, #"{"a":1}"#) }
    }
}
