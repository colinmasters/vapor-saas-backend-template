import Vapor
import JWTKit

// Protocol defining what an auth provider must implement
protocol AuthProvider {
    func verify(_ req: Request) async throws -> JWTUser
}

// Default Vapor JWT implementation
struct VaporAuthProvider: AuthProvider {
    let signers: JWTSigners
    
    init(signers: JWTSigners) {
        self.signers = signers
    }
    
    func verify(_ req: Request) async throws -> JWTUser {
        guard let token = req.headers.bearerAuthorization?.token else {
            throw Abort(.unauthorized, reason: "Missing bearer authorization")
        }
        return try signers.verify(token, as: AuthPayload.self)
    }
}

// Firebase implementation that can be swapped in
struct FirebaseAuthProvider: AuthProvider {
    func verify(_ req: Request) async throws -> JWTUser {
        guard let token = req.headers.bearerAuthorization?.token else {
            throw Abort(.unauthorized, reason: "Missing bearer authorization")
        }
        
        // Verify the Firebase token
        guard let projectId = Environment.get("FIREBASE_PROJECT_ID") else {
            throw Abort(.internalServerError, reason: "Firebase project ID not configured")
        }
        
        // Make request to Firebase Auth API to verify token
        let url = URI("https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com")
        let response = try await req.client.get(url)
        guard response.status == .ok else {
            throw Abort(.unauthorized, reason: "Failed to verify Firebase token")
        }
        
        // Verify token signature and claims
        let jwt = try req.jwt.verify(token, as: AuthPayload.self)
        
        // Verify Firebase-specific claims
        guard jwt.subject.value.count > 0 else {
            throw Abort(.unauthorized, reason: "Invalid subject claim")
        }
        
        return jwt
    }
}

// JWT payload for default Vapor implementation
struct AuthPayload: JWTPayload, JWTUser {
    enum CodingKeys: String, CodingKey {
        case subject = "sub"
        case expiration = "exp"
        case email
        case name
        case picture
    }
    
    let subject: SubjectClaim
    let expiration: ExpirationClaim
    let email: String?
    let name: String?
    let picture: String?
    
    var userID: String { subject.value }
    
    func verify(using signer: JWTSigner) throws {
        try expiration.verifyNotExpired()
    }
}

// Extension to make auth provider configurable
extension Application {
    private struct AuthProviderKey: StorageKey {
        typealias Value = AuthProvider
    }
    
    var authProvider: AuthProvider {
        get {
            if let existing = storage[AuthProviderKey.self] {
                return existing
            }
            // Create default Vapor JWT auth provider
            let signers = JWTSigners()
            if let jwtSecret = Environment.get("JWT_SECRET") {
                // Configure with secret from environment
                signers.use(.hs256(key: jwtSecret))
            } else {
                // For development, use a default secret
                signers.use(.hs256(key: "default-secret-change-me-in-production"))
            }
            let provider = VaporAuthProvider(signers: signers)
            storage[AuthProviderKey.self] = provider
            return provider
        }
        set {
            storage[AuthProviderKey.self] = newValue
        }
    }
}

// Extension for Request to access JWT user
extension Request {
    var jwtUser: JWTUser {
        get async throws {
            try await application.authProvider.verify(self)
        }
    }
}
