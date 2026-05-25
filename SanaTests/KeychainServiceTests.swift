// Sana — KeychainServiceTests.swift
import Testing
@testable import Sana

// Run serially to avoid Keychain race conditions between test cases.
@Suite("KeychainService", .serialized)
struct KeychainServiceTests {

    // Clean up all test-used keys before each test.
    init() {
        KeychainService.delete(for: .userEmail)
        KeychainService.delete(for: .authUserID)
        KeychainService.delete(for: .authProvider)
        KeychainService.delete(for: .authPasswordHash)
    }

    // MARK: - Save & Load

    @Test("saved value can be loaded back")
    func saveAndLoad() {
        KeychainService.save("test@example.com", for: .userEmail)
        #expect(KeychainService.load(for: .userEmail) == "test@example.com")
    }

    @Test("load returns nil for missing key")
    func loadMissing() {
        #expect(KeychainService.load(for: .userEmail) == nil)
    }

    @Test("saving overwrites existing value")
    func saveOverwrites() {
        KeychainService.save("first@example.com", for: .userEmail)
        KeychainService.save("second@example.com", for: .userEmail)
        #expect(KeychainService.load(for: .userEmail) == "second@example.com")
    }

    @Test("save returns true on success")
    func saveReturnsTrue() {
        let result = KeychainService.save("hello@test.com", for: .userEmail)
        #expect(result == true)
    }

    // MARK: - Delete

    @Test("delete removes the value")
    func deleteRemovesValue() {
        KeychainService.save("gone@example.com", for: .userEmail)
        KeychainService.delete(for: .userEmail)
        #expect(KeychainService.load(for: .userEmail) == nil)
    }

    @Test("delete on missing key returns false without crashing")
    func deleteMissing() {
        let result = KeychainService.delete(for: .userEmail)
        #expect(result == false)
    }

    // MARK: - Different keys don't collide

    @Test("different keys store independently")
    func keysAreIndependent() {
        KeychainService.save("user-abc-123", for: .authUserID)
        KeychainService.save("apple", for: .authProvider)
        #expect(KeychainService.load(for: .authUserID) == "user-abc-123")
        #expect(KeychainService.load(for: .authProvider) == "apple")
    }

    @Test("deleting one key leaves others intact")
    func deleteOneKeyLeavesOthers() {
        KeychainService.save("user@test.com", for: .userEmail)
        KeychainService.save("user-id-999", for: .authUserID)
        KeychainService.delete(for: .userEmail)
        #expect(KeychainService.load(for: .userEmail) == nil)
        #expect(KeychainService.load(for: .authUserID) == "user-id-999")
    }

    // MARK: - Empty string edge case

    @Test("empty string can be stored and retrieved")
    func emptyString() {
        KeychainService.save("", for: .userEmail)
        // Note: empty string saves succeed; callers should treat empty as "not set"
        let loaded = KeychainService.load(for: .userEmail)
        #expect(loaded == "")
    }

    // MARK: - Unicode

    @Test("unicode values survive round-trip")
    func unicodeValue() {
        let value = "ağrı@örnek.com 🌿"
        KeychainService.save(value, for: .userEmail)
        #expect(KeychainService.load(for: .userEmail) == value)
    }
}
