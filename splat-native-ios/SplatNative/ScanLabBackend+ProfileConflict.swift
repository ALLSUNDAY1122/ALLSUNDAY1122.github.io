import Foundation
@preconcurrency import Supabase

extension ScanLabBackend {
    func updateProfileWithConflictMapping(handle: String, displayName: String) async throws {
        do {
            try await updateProfile(handle: handle, displayName: displayName)
        } catch let error as PostgrestError {
            guard ScanLabProfilePolicy.mapsToHandleUnavailable(postgrestCode: error.code) else {
                throw error
            }
            throw ScanLabProfileUpdateError.handleUnavailable
        }
    }
}
