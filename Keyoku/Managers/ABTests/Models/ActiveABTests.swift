//
//  ActiveABTests.swift
//
//
//
//
import SwiftUI

struct ActiveABTests: Codable {

    private(set) var boolTest: Bool
    private(set) var enumTest: EnumTestOption
    private(set) var homePracticeLayout: HomePracticeLayoutOption

    init(
        boolTest: Bool,
        enumTest: EnumTestOption,
        homePracticeLayout: HomePracticeLayoutOption = .expanded
    ) {
        self.boolTest = boolTest
        self.enumTest = enumTest
        self.homePracticeLayout = homePracticeLayout
    }

    enum CodingKeys: String, CodingKey {
        case boolTest = "_202411_BoolTest"
        case enumTest = "_202411_EnumTest"
        case homePracticeLayout = "_202503_HomePracticeLayout"
    }

    var eventParameters: [String: Any] {
        let dict: [String: Any?] = [
            "test\(CodingKeys.boolTest.rawValue)": boolTest,
            "test\(CodingKeys.enumTest.rawValue)": enumTest.rawValue,
            "test_202503_HomePracticeLayout": homePracticeLayout.rawValue
        ]
        return dict.compactMapValues({ $0 })
    }

    mutating func update(boolTest newValue: Bool) {
        boolTest = newValue
    }

    mutating func update(enumTest newValue: EnumTestOption) {
        enumTest = newValue
    }

    mutating func update(homePracticeLayout newValue: HomePracticeLayoutOption) {
        homePracticeLayout = newValue
    }
}

enum HomePracticeLayoutOption: String, Codable {
    case expanded
    case compact
}

// MARK: REMOTE CONFIG

import FirebaseRemoteConfig

extension ActiveABTests {

    init(config: RemoteConfig) {
        let boolTest = config.configValue(forKey: ActiveABTests.CodingKeys.boolTest.rawValue).boolValue
        self.boolTest = boolTest

        let enumTestStringValue = config.configValue(forKey: ActiveABTests.CodingKeys.enumTest.rawValue).stringValue
        if let option = EnumTestOption(rawValue: enumTestStringValue) {
            self.enumTest = option
        } else {
            self.enumTest = .default
        }

        let homePracticeLayoutString = config.configValue(forKey: ActiveABTests.CodingKeys.homePracticeLayout.rawValue).stringValue
        if let option = HomePracticeLayoutOption(rawValue: homePracticeLayoutString) {
            self.homePracticeLayout = option
        } else {
            self.homePracticeLayout = .expanded
        }
    }

    // Converted to a NSObject dictionary to setDefaults within FirebaseABTestService
    var asNSObjectDictionary: [String: NSObject]? {
        [
            CodingKeys.boolTest.rawValue: boolTest as NSObject,
            CodingKeys.enumTest.rawValue: enumTest.rawValue as NSObject,
            CodingKeys.homePracticeLayout.rawValue: homePracticeLayout.rawValue as NSObject
        ]
    }
}
