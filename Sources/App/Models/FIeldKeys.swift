import Fluent

extension FieldKey {
    static let name: FieldKey = "name"
    static let createdAt: FieldKey = "created_at"
    static let updatedAt: FieldKey = "updated_at"
    static let apiKey: FieldKey = "api_key"
    static let email: FieldKey = "email"
    static let avatarUrl: FieldKey = "avatar_url"
    static let authId: FieldKey = "auth_id" // Changed from firebaseUserId
    static let subscribedToNewsletterAt: FieldKey = "subscribed_to_newsletter_at"
    static let role: FieldKey = "role"
    static let profileId: FieldKey = "profile_id"
    static let organizationId: FieldKey = "organization_id"
    static let lastSeenAt: FieldKey = "last_seen_at"
}
