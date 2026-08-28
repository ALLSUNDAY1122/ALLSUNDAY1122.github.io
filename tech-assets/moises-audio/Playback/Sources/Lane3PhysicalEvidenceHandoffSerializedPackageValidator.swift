import Foundation

public enum Lane3PhysicalEvidenceHandoffSerializedComponent: String, Codable, Equatable, Sendable {
    case manifest
    case plan
    case deviceBundle
    case resourceTraces
}

public enum Lane3PhysicalEvidenceHandoffSerializedPackageError: Error, Equatable, Sendable {
    case malformedJSON(Lane3PhysicalEvidenceHandoffSerializedComponent)
    case nonCanonicalStructure(Lane3PhysicalEvidenceHandoffSerializedComponent)
    case hostValidationFailed
}

/// Replayable host/HQ receipt for a fully serialized Lane 3 physical-evidence handoff package.
///
/// The four serialized inputs are normalized structurally before hashing, so whitespace/key ordering
/// do not alter identity. Unknown or dropped JSON structure is rejected before any typed evidence is
/// trusted. This remains NON_PARITY and does not assert signer/provenance authenticity.
public struct Lane3PhysicalEvidenceHandoffSerializedPackageReceipt: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let evidenceScope: String
    public let manifestJSONBindingSHA256: String
    public let planJSONBindingSHA256: String
    public let deviceBundleJSONBindingSHA256: String
    public let resourceTracesJSONBindingSHA256: String
    public let hostReceipt: Lane3PhysicalEvidenceHandoffHostReceipt
    public let acceptedForHQReview: Bool
    public let parityPromotionAllowed: Bool
    public let packageBindingSHA256: String

    fileprivate static let receiptScope = "LANE3_HQ_PHYSICAL_EVIDENCE_SERIALIZED_PACKAGE_RECEIPT_V1_NON_PARITY"

    public func verifyIntegrity() -> Bool {
        guard schemaVersion == 1,
              evidenceScope == Self.receiptScope,
              acceptedForHQReview,
              !parityPromotionAllowed,
              hostReceipt.verifyIntegrity() else {
            return false
        }

        return packageBindingSHA256 == Self.computeBinding(
            schemaVersion: schemaVersion,
            evidenceScope: evidenceScope,
            manifestJSONBindingSHA256: manifestJSONBindingSHA256,
            planJSONBindingSHA256: planJSONBindingSHA256,
            deviceBundleJSONBindingSHA256: deviceBundleJSONBindingSHA256,
            resourceTracesJSONBindingSHA256: resourceTracesJSONBindingSHA256,
            hostReceiptBindingSHA256: hostReceipt.receiptBindingSHA256,
            acceptedForHQReview: acceptedForHQReview,
            parityPromotionAllowed: parityPromotionAllowed
        )
    }

    fileprivate static func make(
        manifestJSONBindingSHA256: String,
        planJSONBindingSHA256: String,
        deviceBundleJSONBindingSHA256: String,
        resourceTracesJSONBindingSHA256: String,
        hostReceipt: Lane3PhysicalEvidenceHandoffHostReceipt
    ) -> Lane3PhysicalEvidenceHandoffSerializedPackageReceipt {
        let schemaVersion = 1
        let evidenceScope = receiptScope
        let acceptedForHQReview = true
        let parityPromotionAllowed = false
        let packageBindingSHA256 = computeBinding(
            schemaVersion: schemaVersion,
            evidenceScope: evidenceScope,
            manifestJSONBindingSHA256: manifestJSONBindingSHA256,
            planJSONBindingSHA256: planJSONBindingSHA256,
            deviceBundleJSONBindingSHA256: deviceBundleJSONBindingSHA256,
            resourceTracesJSONBindingSHA256: resourceTracesJSONBindingSHA256,
            hostReceiptBindingSHA256: hostReceipt.receiptBindingSHA256,
            acceptedForHQReview: acceptedForHQReview,
            parityPromotionAllowed: parityPromotionAllowed
        )
        return Lane3PhysicalEvidenceHandoffSerializedPackageReceipt(
            schemaVersion: schemaVersion,
            evidenceScope: evidenceScope,
            manifestJSONBindingSHA256: manifestJSONBindingSHA256,
            planJSONBindingSHA256: planJSONBindingSHA256,
            deviceBundleJSONBindingSHA256: deviceBundleJSONBindingSHA256,
            resourceTracesJSONBindingSHA256: resourceTracesJSONBindingSHA256,
            hostReceipt: hostReceipt,
            acceptedForHQReview: acceptedForHQReview,
            parityPromotionAllowed: parityPromotionAllowed,
            packageBindingSHA256: packageBindingSHA256
        )
    }

    private static func computeBinding(
        schemaVersion: Int,
        evidenceScope: String,
        manifestJSONBindingSHA256: String,
        planJSONBindingSHA256: String,
        deviceBundleJSONBindingSHA256: String,
        resourceTracesJSONBindingSHA256: String,
        hostReceiptBindingSHA256: String,
        acceptedForHQReview: Bool,
        parityPromotionAllowed: Bool
    ) -> String {
        Lane3LongTrackPCMIdentityHasher.digestFields([
            "LANE3_HQ_PHYSICAL_EVIDENCE_SERIALIZED_PACKAGE_RECEIPT_V1",
            String(schemaVersion),
            evidenceScope,
            manifestJSONBindingSHA256,
            planJSONBindingSHA256,
            deviceBundleJSONBindingSHA256,
            resourceTracesJSONBindingSHA256,
            hostReceiptBindingSHA256,
            acceptedForHQReview ? "true" : "false",
            parityPromotionAllowed ? "true" : "false"
        ])
    }
}

public enum Lane3PhysicalEvidenceHandoffSerializedPackageValidator {
    /// Accepts only serialized evidence inputs. Each JSON document must decode without losing or
    /// inventing structure when round-tripped through its canonical Codable model. The decoded values
    /// are then delegated to the existing host validator for exact cross-evidence rebinding.
    public static func validate(
        manifestJSON: Data,
        planJSON: Data,
        deviceBundleJSON: Data,
        resourceTracesJSON: Data
    ) throws -> Lane3PhysicalEvidenceHandoffSerializedPackageReceipt {
        let manifest = try decodeStrict(
            Lane3PhysicalEvidenceHandoffManifest.self,
            data: manifestJSON,
            component: .manifest
        )
        let plan = try decodeStrict(
            Lane3PhysicalEvidenceSessionPlan.self,
            data: planJSON,
            component: .plan
        )
        let bundle = try decodeStrict(
            Lane3DeviceEvidenceBundle.self,
            data: deviceBundleJSON,
            component: .deviceBundle
        )
        let traces = try decodeStrict(
            [Lane3PhysicalEvidenceResourceTraceReceipt].self,
            data: resourceTracesJSON,
            component: .resourceTraces
        )

        let hostReceipt: Lane3PhysicalEvidenceHandoffHostReceipt
        do {
            hostReceipt = try Lane3PhysicalEvidenceHandoffHostValidator.validate(
                manifestJSON: manifest.canonicalJSON,
                plan: plan.value,
                deviceBundle: bundle.value,
                resourceTraces: traces.value
            )
        } catch {
            throw Lane3PhysicalEvidenceHandoffSerializedPackageError.hostValidationFailed
        }

        let receipt = Lane3PhysicalEvidenceHandoffSerializedPackageReceipt.make(
            manifestJSONBindingSHA256: digestCanonicalJSON(manifest.canonicalJSON),
            planJSONBindingSHA256: digestCanonicalJSON(plan.canonicalJSON),
            deviceBundleJSONBindingSHA256: digestCanonicalJSON(bundle.canonicalJSON),
            resourceTracesJSONBindingSHA256: digestCanonicalJSON(traces.canonicalJSON),
            hostReceipt: hostReceipt
        )
        guard receipt.verifyIntegrity() else {
            throw Lane3PhysicalEvidenceHandoffSerializedPackageError.hostValidationFailed
        }
        return receipt
    }

    /// Replays all four serialized boundaries and requires them to yield the exact prior package receipt.
    public static func verify(
        receipt: Lane3PhysicalEvidenceHandoffSerializedPackageReceipt,
        manifestJSON: Data,
        planJSON: Data,
        deviceBundleJSON: Data,
        resourceTracesJSON: Data
    ) -> Bool {
        guard receipt.verifyIntegrity() else { return false }
        do {
            return try validate(
                manifestJSON: manifestJSON,
                planJSON: planJSON,
                deviceBundleJSON: deviceBundleJSON,
                resourceTracesJSON: resourceTracesJSON
            ) == receipt
        } catch {
            return false
        }
    }

    private struct StrictDecoded<Value: Codable & Sendable>: Sendable {
        let value: Value
        let canonicalJSON: Data
    }

    private static func decodeStrict<Value: Codable & Sendable>(
        _ type: Value.Type,
        data: Data,
        component: Lane3PhysicalEvidenceHandoffSerializedComponent
    ) throws -> StrictDecoded<Value> {
        let originalObject: Any
        do {
            originalObject = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw Lane3PhysicalEvidenceHandoffSerializedPackageError.malformedJSON(component)
        }

        let value: Value
        do {
            value = try JSONDecoder().decode(type, from: data)
        } catch {
            throw Lane3PhysicalEvidenceHandoffSerializedPackageError.malformedJSON(component)
        }

        let encoded: Data
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            encoded = try encoder.encode(value)
        } catch {
            throw Lane3PhysicalEvidenceHandoffSerializedPackageError.malformedJSON(component)
        }

        let reencodedObject: Any
        do {
            reencodedObject = try JSONSerialization.jsonObject(with: encoded)
        } catch {
            throw Lane3PhysicalEvidenceHandoffSerializedPackageError.malformedJSON(component)
        }

        let originalCanonical: Data
        let reencodedCanonical: Data
        do {
            originalCanonical = try JSONSerialization.data(
                withJSONObject: originalObject,
                options: [.sortedKeys]
            )
            reencodedCanonical = try JSONSerialization.data(
                withJSONObject: reencodedObject,
                options: [.sortedKeys]
            )
        } catch {
            throw Lane3PhysicalEvidenceHandoffSerializedPackageError.malformedJSON(component)
        }

        guard originalCanonical == reencodedCanonical else {
            throw Lane3PhysicalEvidenceHandoffSerializedPackageError.nonCanonicalStructure(component)
        }
        return StrictDecoded(value: value, canonicalJSON: reencodedCanonical)
    }

    private static func digestCanonicalJSON(_ data: Data) -> String {
        Lane3LongTrackPCMIdentityHasher.digestFields([
            "LANE3_HQ_CANONICAL_JSON_V1",
            String(decoding: data, as: UTF8.self)
        ])
    }
}
