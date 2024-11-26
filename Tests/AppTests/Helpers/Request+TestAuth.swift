@testable import App
import Foundation
import Vapor
import JWTKit

struct TestUser {
    let email: String
    let name: String?
    let id: String
}

extension Application {
    func generateTestToken(for user: TestUser) throws -> String {
        // Create test JWT signers if not exists
        if storage[TestAuthSignersKey.self] == nil {
            let signers = JWTSigners()
            signers.use(.hs256(key: "test-secret"))
            storage[TestAuthSignersKey.self] = signers
        }
        
        let signers = storage[TestAuthSignersKey.self]!
        
        // Create auth payload using the existing AuthPayload from App module
        let payload = AuthPayload(
            subject: .init(value: user.id),
            expiration: .init(value: .now.addingTimeInterval(3600)),
            email: user.email,
            name: user.name,
            picture: nil
        )
        
        return try signers.sign(payload)
    }
}

private struct TestAuthSignersKey: StorageKey {
    typealias Value = JWTSigners
}

extension Client {
    
    func testUserToken(email: String = "test@example.com", name: String? = nil) throws -> String {
        let user = TestUser(
            email: email,
            name: name,
            id: UUID().uuidString
        )
        return try Application().generateTestToken(for: user)
    }
    
    func defaultTestUserToken() throws -> String {
        let email = Environment.get("TEST_USER_EMAIL") ?? "test@example.com"
        return try testUserToken(email: email)
    }
    
    func secondTestUserToken() throws -> String {
        let email = Environment.get("TEST_USER_2_EMAIL") ?? "test2@example.com"
        return try testUserToken(email: email)
    }
}
