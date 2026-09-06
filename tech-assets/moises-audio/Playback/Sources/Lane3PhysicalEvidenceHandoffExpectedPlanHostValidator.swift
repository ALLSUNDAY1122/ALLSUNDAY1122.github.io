import Foundation

/// Fail-closed host-side admission layered on top of the serialized handoff validator.
///
/// The existing handoff manifest proves that the supplied plan, device bundle, and
/// resource traces form one internally consistent NON_PARITY evidence tuple. This
/// validator additionally requires that tuple to be attached to the exact session
/// plan HQ selected before evidence collection began. That prevents a different,
/// internally coherent session from being accepted merely because its own manifest
/// rebinds correctly.
///
/// `expectedPlan` is a host policy anchor, not a signature or external provenance
/// proof. Callers remain responsible for protecting the source of that expectation.
public enum Lane3PhysicalEvidenceHandoffExpectedPlanValidationError: Error, Equatable, Sendable {
    case expectedPlanMismatch
}

public enum Lane3PhysicalEvidenceHandoffExpectedPlanHostValidator {
    public static func validate(
        expectedPlan: Lane3PhysicalEvidenceSessionPlan,
        manifestJSON: Data,
        plan: Lane3PhysicalEvidenceSessionPlan,
        deviceBundle: Lane3DeviceEvidenceBundle,
        resourceTraces: [Lane3PhysicalEvidenceResourceTraceReceipt]
    ) throws -> Lane3PhysicalEvidenceHandoffHostReceipt {
        guard plan == expectedPlan else {
            throw Lane3PhysicalEvidenceHandoffExpectedPlanValidationError.expectedPlanMismatch
        }

        return try Lane3PhysicalEvidenceHandoffHostValidator.validate(
            manifestJSON: manifestJSON,
            plan: plan,
            deviceBundle: deviceBundle,
            resourceTraces: resourceTraces
        )
    }

    public static func verify(
        receipt: Lane3PhysicalEvidenceHandoffHostReceipt,
        expectedPlan: Lane3PhysicalEvidenceSessionPlan,
        manifestJSON: Data,
        plan: Lane3PhysicalEvidenceSessionPlan,
        deviceBundle: Lane3DeviceEvidenceBundle,
        resourceTraces: [Lane3PhysicalEvidenceResourceTraceReceipt]
    ) -> Bool {
        do {
            let rebound = try validate(
                expectedPlan: expectedPlan,
                manifestJSON: manifestJSON,
                plan: plan,
                deviceBundle: deviceBundle,
                resourceTraces: resourceTraces
            )
            return rebound == receipt && rebound.verifyIntegrity()
        } catch {
            return false
        }
    }
}
