import Vapor
@preconcurrency import JWT

protocol JWTUser {
    var userID: String { get }
    var email: String? { get }
    var name: String? { get }
    var picture: String? { get }
}

extension Application {
    struct JWTKey: StorageKey {
        typealias Value = JWTSigners
    }
    
    var jwt: JWTSigners {
        get {
            if let existing = storage[JWTKey.self] {
                return existing
            }
            
            let signers = JWTSigners()
            if environment == .testing {
                // For testing, use a simple secret
                signers.use(.hs256(key: "test-secret"))
            } else {
                // In production, use your actual secret key
                guard let secret = Environment.get("JWT_SECRET") else {
                    fatalError("JWT_SECRET not set")
                }
                signers.use(.hs256(key: secret))
            }
            
            storage[JWTKey.self] = signers
            return signers
        }
        set {
            storage[JWTKey.self] = newValue
        }
    }
}

extension Request {
    var jwt: JWTSigners {
        return application.jwt
    }
}
