@testable import App
import XCTVapor
import Nimble
import JWTKit
//import Quick

// TODO: make the DTOs conform to Equatable and compare the whole DTOs

extension Application {
    static func configuredAppForTests() async throws -> Application {
        let app = try await Application.make(.testing)
        try await configure(app)
        
        try await app.autoRevert()
        try await app.autoMigrate()
        
        return app
    }
    
    func createProfile(authToken: String) async throws -> ProfileDTO {
        var authHeader = HTTPHeaders()
        authHeader.bearerAuthorization = .init(token: authToken)
        
        var profile: ProfileDTO!

        try await test(.POST, "profile", headers: authHeader, afterResponse: { res async throws in
            expect(res.status) == .ok
            profile = try res.content.decode(ProfileDTO.self)
        })
        
        return profile
    }
}

final class AppTests: XCTestCase {
    
    private var app: Application!
    private var jwtApp: Application!
    private var firebaseApp: Application!
    
    override func setUp() async throws {
        // Setup app with JWT auth
        jwtApp = try await Application.configuredAppForTests()
        
        // Setup app with Firebase auth
        firebaseApp = try await Application.configuredAppForTests()
        firebaseApp.authProvider = FirebaseAuthProvider()
        
        // Use JWT app as default for backward compatibility
        app = jwtApp
    }
    
    override func tearDown() async throws {
        try await jwtApp.asyncShutdown()
        try await firebaseApp.asyncShutdown()
        jwtApp = nil
        firebaseApp = nil
        app = nil
    }

    func testProfileControllerWithJWT() async throws {
        try? await testProfileController(app: jwtApp, getToken: { try $0.defaultTestUserToken() })
    }
    
    func testProfileControllerWithFirebase() async throws {
        try? await testProfileController(app: firebaseApp, getToken: { try $0.defaultFirebaseTestUserToken() })
    }
    
    func testOrganizationControllerWithJWT() async throws {
        try? await testOrganizationController(app: jwtApp,
                                              getToken: { try $0.defaultTestUserToken() },
                                              getSecondToken: { try $0.secondTestUserToken() })
    }
    
    func testOrganizationControllerWithFirebase() async throws {
        try? await testOrganizationController(app: firebaseApp,
                                              getToken: { try $0.defaultFirebaseTestUserToken() },
                                              getSecondToken: { try $0.secondFirebaseTestUserToken() })
    }

    private func testProfileController(app: Application, getToken: (Client) throws -> String) async throws {
        await expect { try await Profile.query(on: app.db).count() } == 0

        var authHeader = HTTPHeaders()
        let token = try getToken(app.client)
        authHeader.bearerAuthorization = .init(token: token)

        try await app.test(.POST, "profile", headers: authHeader, afterResponse: { res async throws in
            expect(res.status) == .ok
            let profile = try res.content.decode(ProfileDTO.self)
            expect(profile.email) == (Environment.get("TEST_USER_EMAIL") ?? "test@example.com")
            expect(profile.isSubscribedToNewsletter) == false
        })
        
        await expect { try await Profile.query(on: app.db).count() } == 1
        
        // default organization is created
        await expect { try await Organization.query(on: app.db).count() } == 1
        await expect { try await ProfileOrganizationRole.query(on: app.db).count() } == 1
        
        try await app.test(.POST, "profile", headers: authHeader, afterResponse: { res async throws in
            expect(res.status) == .ok
            let profile = try res.content.decode(ProfileDTO.self)
            expect(profile.email) == (Environment.get("TEST_USER_EMAIL") ?? "test@example.com")
            expect(profile.isSubscribedToNewsletter) == false
        })
        
        await expect { try await Profile.query(on: app.db).count() } == 1
        await expect { try await Organization.query(on: app.db).count() } == 1
        await expect { try await ProfileOrganizationRole.query(on: app.db).count() } == 1
        
        try await app.test(.GET, "profile", headers: authHeader, afterResponse: { res async throws in
            expect(res.status) == .ok
            let profile = try res.content.decode(ProfileDTO.self)
            expect(profile.email) == (Environment.get("TEST_USER_EMAIL") ?? "test@example.com")
            expect(profile.isSubscribedToNewsletter) == false
        })
        
        struct PatchProfileBody: Content {
            var isSubscribedToNewsletter: Bool?
        }
        
        try await app.test(.DELETE, "profile", headers: authHeader, afterResponse: { res async throws in
            expect(res.status) == .noContent
        })
        
        await expect { try await Profile.query(on: app.db).count() } == 0
        
        try await app.test(.POST, "profile", headers: authHeader, afterResponse: { res async throws in
            expect(res.status) == .ok
            let profile = try res.content.decode(ProfileDTO.self)
            expect(profile.email) == (Environment.get("TEST_USER_EMAIL") ?? "test@example.com")
            expect(profile.isSubscribedToNewsletter) == false
        })
        
        await expect { try await Profile.query(on: app.db).count() } == 1
    }
    
    private func testOrganizationController(app: Application, 
                                          getToken: (Client) throws -> String,
                                          getSecondToken: (Client) throws -> String) async throws {
        await expect { try await Organization.query(on: app.db).count() } == 0
        
        var authHeader = HTTPHeaders()
        let token = try getToken(app.client)
        authHeader.bearerAuthorization = .init(token: token)

        try await app.test(.POST, "profile", headers: authHeader, afterResponse: { res async throws in
            expect(res.status) == .ok
            let profile = try res.content.decode(ProfileDTO.self)
            expect(profile.email) == (Environment.get("TEST_USER_EMAIL") ?? "test@example.com")
            expect(profile.isSubscribedToNewsletter) == false
        })
        
        await expect { try await Organization.query(on: app.db).count() } == 1
        
        struct OrganizationCreateDTO: Content {
            var name: String
        }
        
        var organizationId: UUID!
        
        try await app.test(.POST, "organization", headers: authHeader, beforeRequest: { request async throws in
            try request.content.encode(OrganizationCreateDTO(name: "Test Organization"))
        }, afterResponse: { res in
            expect(res.status) == .ok
            let organization = try res.content.decode(OrganizationDTO.self)
            organizationId = organization.id
            expect(organization.name) == "Test Organization"
        })
        
        await expect { try await Organization.query(on: app.db).count() } == 2
        
        try await app.test(.GET, "organization", headers: authHeader, afterResponse: { res async throws in
            expect(res.status) == .ok
            let organizations = try res.content.decode([OrganizationDTO].self)
        })
        
        try await app.test(.PATCH, "organization/\(organizationId.uuidString)", headers: authHeader, beforeRequest: { request async throws in
            try request.content.encode(OrganizationCreateDTO(name: "New name"))
        }, afterResponse: { res in
            expect(res.status) == .ok
            let organization = try res.content.decode(OrganizationDTO.self)
            organizationId = organization.id
            expect(organization.name) == "New name"
        })
        
        // create 2nd user
        var authHeader2 = HTTPHeaders()
        let token2 = try getSecondToken(app.client)
        authHeader2.bearerAuthorization = .init(token: token2)
        
        await expect { try await Organization.query(on: app.db).count() } == 2

        var user2Id = ""
        try await app.test(.POST, "profile", headers: authHeader2, afterResponse: { res async throws in
            expect(res.status) == .ok
            let profile = try res.content.decode(ProfileDTO.self)
            expect(profile.email) == (Environment.get("TEST_USER_2_EMAIL") ?? "test2@example.com")
            user2Id = profile.id.uuidString
        })
        
        await expect { try await Organization.query(on: app.db).count() } == 3
        
        struct UpdateRoleDTO: Content {
            var email: String
            var role: OrganizationRoleDTO
        }
        
        try await app.test(.PUT, "organization/\(organizationId.uuidString)/members", headers: authHeader, beforeRequest: { request in
            try request.content.encode(UpdateRoleDTO(email: Environment.get("TEST_USER_2_EMAIL") ?? "test2@example.com", role: .lurker))
        }, afterResponse: { res async throws in
            expect(res.status) == .ok
            let member = try res.content.decode(OrganizationMemberDTO.self)
            expect(member.role) == .lurker
        })
        
        try await app.test(.PUT, "organization/\(organizationId.uuidString)/members", headers: authHeader, beforeRequest: { request in
            try request.content.encode(UpdateRoleDTO(email: Environment.get("TEST_USER_2_EMAIL") ?? "test2@example.com", role: .editor))
        }, afterResponse: { res async throws in
            expect(res.status) == .ok
            let member = try res.content.decode(OrganizationMemberDTO.self)
            expect(member.role) == .editor
        })
        
        try await app.test(.DELETE, "organization/\(organizationId.uuidString)/members/\(Environment.get("TEST_USER_2_EMAIL") ?? "test2@example.com")", headers: authHeader, afterResponse: { res async throws in
            expect(res.status) == .noContent
        })
        
        try await app.test(.PUT, "organization/\(organizationId.uuidString)/members", headers: authHeader, beforeRequest: { request in
            try request.content.encode(UpdateRoleDTO(email: "unregistered@example.com", role: .admin))
        }, afterResponse: { res async throws in
            expect(res.status) == .ok
            let member = try res.content.decode(OrganizationMemberDTO.self)
            expect(member.email) == "unregistered@example.com"
            expect(member.role) == .admin
        })
        
        try await app.test(.DELETE, "organization/\(organizationId.uuidString)/members/unregistered@example.com", headers: authHeader, afterResponse: { res async throws in
            expect(res.status) == .noContent
        })
        
        await expect { try await Organization.query(on: app.db).count() } == 3
        
        try await app.test(.DELETE, "organization/\(organizationId.uuidString)", headers: authHeader, afterResponse: { res async throws in
            expect(res.status) == .noContent
        })
        
        await expect { try await Organization.query(on: app.db).count() } == 2
        await expect { try await Profile.query(on: app.db).count() } == 2
        
        try await app.test(.DELETE, "profile", headers: authHeader2, afterResponse: { res async throws in
            expect(res.status) == .noContent
        })
        
        try await app.test(.DELETE, "profile", headers: authHeader, afterResponse: { res async throws in
            expect(res.status) == .noContent
        })
        
        await expect { try await Profile.query(on: app.db).count() } == 0
    }
}
