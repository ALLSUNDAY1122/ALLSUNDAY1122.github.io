import Foundation

#if canImport(MoisesAudioCore)
import MoisesAudioCore

/// Concrete App-account-deletion binding for the durable Lane 2 lifecycle coordinator.
/// The App layer never deletes library/source artifacts directly; it delegates through the
/// existing crash-safe Lane 2 tombstone and owned-artifact reconciliation path.
extension Lane2DurableLifecycleCoordinator: AccountLibraryDataDeleting {}
#endif
