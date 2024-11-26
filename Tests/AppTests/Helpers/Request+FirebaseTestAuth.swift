@testable import App
import Foundation
import Vapor
import JWTKit

struct FirebaseAuthPayload: JWTPayload, JWTUser {
    let iss: String
    let aud: String
    let auth_time: Int
    let user_id: String
    let sub: String
    let iat: Int
    let exp: Int
    let email: String?
    let email_verified: Bool
    let name: String?
    let picture: String?
    
    var userID: String { user_id }
    
    func verify(using signer: JWTSigner) throws {
        let expiration = ExpirationClaim(value: Date(timeIntervalSince1970: TimeInterval(exp)))
        try expiration.verifyNotExpired()
    }
}

extension Application {
    func generateFirebaseTestToken(for user: TestUser) throws -> String {
        // Create test JWT signers if not exists
        if storage[FirebaseTestAuthSignersKey.self] == nil {
            let signers = JWTSigners()
            signers.use(.hs256(key: "firebase-test-secret"))
            storage[FirebaseTestAuthSignersKey.self] = signers
        }
        
        let signers = storage[FirebaseTestAuthSignersKey.self]!
        
        // Create Firebase-style auth payload
        let payload = FirebaseAuthPayload(
            iss: "https://securetoken.google.com/test-project",
            aud: "test-project",
            auth_time: Int(Date().timeIntervalSince1970),
            user_id: user.id,
            sub: user.id,
            iat: Int(Date().timeIntervalSince1970),
            exp: Int(Date().timeIntervalSince1970) + 3600,
            email: user.email,
            email_verified: true,
            name: user.name,
            picture: nil
        )
        
        return try signers.sign(payload)
    }
}

private struct FirebaseTestAuthSignersKey: StorageKey {
    typealias Value = JWTSigners
}

extension Client {
    
    func firebaseTestUserToken(email: String = "test@example.com", name: String? = nil) throws -> String {
        let user = TestUser(
            email: email,
            name: name,
            id: UUID().uuidString
        )
        return try Application().generateFirebaseTestToken(for: user)
    }
    
    func defaultFirebaseTestUserToken() throws -> String {
        let email = Environment.get("TEST_USER_EMAIL") ?? "test@example.com"
        return try firebaseTestUserToken(email: email)
    }
    
    func secondFirebaseTestUserToken() throws -> String {
        let email = Environment.get("TEST_USER_2_EMAIL") ?? "test2@example.com"
        return try firebaseTestUserToken(email: email)
    }
}
