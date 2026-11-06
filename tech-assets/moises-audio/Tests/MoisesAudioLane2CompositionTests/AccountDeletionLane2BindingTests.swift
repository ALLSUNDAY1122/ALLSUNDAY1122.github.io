import XCTest
import MoisesAudioCore
import MoisesAudioLane2

final class AccountDeletionLane2BindingTests: XCTestCase {
    func testDurableLifecycleCoordinatorConformsToAccountLibraryDeletionSeam() {
        requireAccountLibraryDeletionConformance(Lane2DurableLifecycleCoordinator.self)
    }

    private func requireAccountLibraryDeletionConformance<T: AccountLibraryDataDeleting>(_: T.Type) {}
}
