import Foundation
@preconcurrency import Supabase

extension ScanLabBackend {
    func signOutWithUserSafeError() async {
        do {
            try await client.auth.signOut()
            notice = nil
        } catch {
            notice = ScanLabAuthErrorPolicy.userMessage(for: error, operation: .signOut)
        }
    }
}
