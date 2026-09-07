import Foundation

@main
struct L3HQPhysicalEvidenceHandoffExpectedPlanCommitmentSelfTestMain {
    static func main() throws {
        let baseline = makePlan()
        let commitment = try Lane3PhysicalEvidenceHandoffExpectedPlanCommitmentBuilder.make(
            expectedPlan: baseline
        )
        precondition(commitment.verifyIntegrity())
        precondition(!commitment.parityPromotionAllowed)
        precondition(commitment.sessionIdentifier == baseline.sessionIdentifier)
        precondition(commitment.appBuildCommitSHA == baseline.appBuildCommitSHA)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let commitmentJSON = try encoder.encode(commitment)
        let receipt = try Lane3PhysicalEvidenceHandoffExpectedPlanCommitmentHostValidator.validate(
            commitmentJSON: commitmentJSON,
            expectedPlan: baseline
        )
        precondition(receipt.acceptedForExpectedPlanUse)
        precondition(!receipt.parityPromotionAllowed)
        precondition(receipt.verifyIntegrity())
        precondition(
            Lane3PhysicalEvidenceHandoffExpectedPlanCommitmentHostValidator.verify(
                receipt: receipt,
                commitmentJSON: commitmentJSON,
                expectedPlan: baseline
            )
        )

        try expectSchemaShapeMismatch(mutateJSON(commitmentJSON) { dictionary in
            dictionary["unexpected"] = "rejected"
        })
        try expectSchemaShapeMismatch(mutateJSON(commitmentJSON) { dictionary in
            dictionary.removeValue(forKey: "fixtureID")
        })
        try expectIntegrityFailure(mutateJSON(commitmentJSON) { dictionary in
            dictionary["commitmentBindingSHA256"] = String(repeating: "f", count: 64)
        })
        try expectParityFailure(mutateJSON(commitmentJSON) { dictionary in
            dictionary["parityPromotionAllowed"] = true
        })

        try expectPlanMismatch(commitmentJSON, makePlan(sessionIdentifier: "different-session"))
        try expectPlanMismatch(commitmentJSON, makePlan(appBuildCommitSHA: String(repeating: "b", count: 40)))
        try expectPlanMismatch(commitmentJSON, makePlan(fixtureID: "different-fixture"))
        try expectPlanMismatch(commitmentJSON, makePlan(referenceSnapshotID: "different-reference"))
        try expectPlanMismatch(commitmentJSON, makePlan(currentMoisesVersion: "different-version"))
        try expectPlanMismatch(commitmentJSON, makePlan(stepMutation: { steps in
            guard let first = steps.first else { return steps }
            var modified = steps
            modified[0] = Lane3PhysicalEvidenceSessionStep(
                ordinal: first.ordinal,
                kind: first.kind,
                scenario: first.scenario,
                minimumRepetitions: first.minimumRepetitions + 1,
                minimumDurationSeconds: first.minimumDurationSeconds,
                targetedParityRows: first.targetedParityRows,
                requiredArtifactRoles: first.requiredArtifactRoles
            )
            return modified
        }))
        try expectPlanMismatch(commitmentJSON, makePlan(stepMutation: { steps in
            guard let first = steps.first else { return steps }
            var modified = steps
            modified[0] = Lane3PhysicalEvidenceSessionStep(
                ordinal: first.ordinal,
                kind: first.kind,
                scenario: first.scenario,
                minimumRepetitions: first.minimumRepetitions,
                minimumDurationSeconds: first.minimumDurationSeconds + 1,
                targetedParityRows: first.targetedParityRows,
                requiredArtifactRoles: first.requiredArtifactRoles + ["unexpected-role"]
            )
            return modified
        }))

        let nonStartable = makePlan(appBuildCommitSHA: "not-a-git-sha")
        do {
            _ = try Lane3PhysicalEvidenceHandoffExpectedPlanCommitmentBuilder.make(
                expectedPlan: nonStartable
            )
            preconditionFailure("non-startable plan must not produce a commitment")
        } catch let error as Lane3PhysicalEvidenceHandoffExpectedPlanCommitmentError {
            precondition(error == .invalidPlanEnvelope)
        }

        print("L3_HQ_PHYSICAL_EVIDENCE_HANDOFF_EXPECTED_PLAN_COMMITMENT_SELF_TEST_PASS baseline=true schemaClosed=true digestMutationRejected=true parityRejected=true sessionBuildFixtureReferenceStepSubstitutionRejected=true nonStartableRejected=true nonParity=true")
    }

    private static func makePlan(
        sessionIdentifier: String = "hq-pre-capture-plan-session",
        appBuildCommitSHA: String = String(repeating: "a", count: 40),
        fixtureID: String = "hq-rights-cleared-fixture",
        referenceSnapshotID: String = "moises-current-snapshot",
        currentMoisesVersion: String = "current-moises-version",
        stepMutation: (([Lane3PhysicalEvidenceSessionStep]) -> [Lane3PhysicalEvidenceSessionStep])? = nil
    ) -> Lane3PhysicalEvidenceSessionPlan {
        let input = Lane3PhysicalEvidenceSessionPreflightInput(
            sessionIdentifier: sessionIdentifier,
            appBuildCommitSHA: appBuildCommitSHA,
            deviceModel: "iPhone17,1",
            osVersion: "iOS-19.0",
            audioRoute: .wiredHeadphones,
            physicalIPhone: true,
            selectedXcodeBuild: true,
            fixtureID: fixtureID,
            fixtureDurationSeconds: 1_800,
            rightsClearedRealAudio: true,
            currentMoisesReferenceSnapshotID: referenceSnapshotID,
            currentMoisesVersion: currentMoisesVersion,
            availableScenarioHarnesses: Lane3DeviceEvidenceScenario.allCases,
            timingInstrumentationReady: true,
            externalAudibleMarkerReady: true,
            candidateCaptureReady: true,
            currentMoisesCaptureReady: true,
            humanListeningReady: true,
            interruptionTriggerReady: true,
            processRSSSamplingReady: true,
            thermalSamplingReady: true,
            batterySamplingReady: true,
            batteryDrainMeasurementModeReady: true,
            currentMoisesResourceSamplingReady: true
        )
        let baseline = Lane3PhysicalEvidenceSessionOrchestrator.makePlan(input: input)
        guard let stepMutation else { return baseline }
        return Lane3PhysicalEvidenceSessionPlan(
            input: input,
            issues: baseline.preflightIssues,
            steps: stepMutation(baseline.steps),
            targetedParityRows: baseline.targetedParityRows
        )
    }

    private static func mutateJSON(
        _ data: Data,
        mutation: (inout [String: Any]) -> Void
    ) throws -> Data {
        guard var dictionary = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            preconditionFailure("expected JSON object")
        }
        mutation(&dictionary)
        return try JSONSerialization.data(withJSONObject: dictionary, options: [.sortedKeys])
    }

    private static func expectPlanMismatch(
        _ commitmentJSON: Data,
        _ plan: Lane3PhysicalEvidenceSessionPlan
    ) throws {
        do {
            _ = try Lane3PhysicalEvidenceHandoffExpectedPlanCommitmentHostValidator.validate(
                commitmentJSON: commitmentJSON,
                expectedPlan: plan
            )
            preconditionFailure("alternate expected plan must be rejected")
        } catch let error as Lane3PhysicalEvidenceHandoffExpectedPlanCommitmentHostValidationError {
            precondition(error == .expectedPlanMismatch)
        }
    }

    private static func expectSchemaShapeMismatch(_ data: Data) throws {
        do {
            _ = try Lane3PhysicalEvidenceHandoffExpectedPlanCommitmentHostValidator.validate(
                commitmentJSON: data,
                expectedPlan: makePlan()
            )
            preconditionFailure("schema mutation must be rejected")
        } catch let error as Lane3PhysicalEvidenceHandoffExpectedPlanCommitmentHostValidationError {
            precondition(error == .schemaShapeMismatch)
        }
    }

    private static func expectIntegrityFailure(_ data: Data) throws {
        do {
            _ = try Lane3PhysicalEvidenceHandoffExpectedPlanCommitmentHostValidator.validate(
                commitmentJSON: data,
                expectedPlan: makePlan()
            )
            preconditionFailure("digest mutation must be rejected")
        } catch let error as Lane3PhysicalEvidenceHandoffExpectedPlanCommitmentHostValidationError {
            precondition(error == .invalidCommitmentIntegrity)
        }
    }

    private static func expectParityFailure(_ data: Data) throws {
        do {
            _ = try Lane3PhysicalEvidenceHandoffExpectedPlanCommitmentHostValidator.validate(
                commitmentJSON: data,
                expectedPlan: makePlan()
            )
            preconditionFailure("PARITY request must be rejected")
        } catch let error as Lane3PhysicalEvidenceHandoffExpectedPlanCommitmentHostValidationError {
            precondition(error == .parityPromotionRequested)
        }
    }
}
