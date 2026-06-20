//
//  UnitSystemTests.swift
//  SanaTests
//
//  Verifies the device-measurement-system → unit-system mapping that defaults
//  a new user's units by location (US → imperial, everything else → metric).
//

import Testing
import Foundation
@testable import Sana

@Suite("UnitSystem default by location")
struct UnitSystemTests {

    @Test("US measurement system → imperial")
    func usIsImperial() {
        #expect(UnitSystem.default(for: .us) == .imperial)
    }

    @Test("Metric measurement system → metric")
    func metricIsMetric() {
        #expect(UnitSystem.default(for: .metric) == .metric)
    }

    @Test("UK measurement system → metric (not imperial)")
    func ukIsMetric() {
        #expect(UnitSystem.default(for: .uk) == .metric)
    }
}
