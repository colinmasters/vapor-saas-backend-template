import Fluent

struct CreateProfile: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(Profile.schema)
            .id()
            .field(.authId, .string, .required)
            .field(.email, .string, .required)
            .field(.name, .string)
            .field(.avatarUrl, .string)
            .field(.subscribedToNewsletterAt, .date)
            .field(.createdAt, .datetime)
            .field(.updatedAt, .datetime)
            .field(.lastSeenAt, .datetime)
            .unique(on: .authId)
            .unique(on: .email)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema(Profile.schema).delete()
    }
}
