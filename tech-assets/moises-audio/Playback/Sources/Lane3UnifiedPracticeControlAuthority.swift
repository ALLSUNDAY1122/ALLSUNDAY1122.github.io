import Foundation

public enum Lane3PitchControlRejectionReason: String, Codable, Sendable {
    case invalidPitchSemitones
    case interruptionOrLifecycleBlocked
    case transportRecoveryBlocked
    case coordinatorPoisoned
    case coordinatorBusyOutsideSelectedRoute
    case lifecycleChangedDuringMutation
    case coordinatorChangedDuringMutation
    case clickGenerationChangedDuringPitch
    case pitchReadbackMismatch
    case backendRequiresRecovery
    case ticketOverflow
}

public struct Lane3PitchControlExecutionReceipt: Equatable, Sendable {
    public let ticket: UInt64
    public let requestedSemitones: Double
    public let committedSemitones: Double
    public let clickGenerationPreserved: Bool
    public let lifecycleRevisionPreserved: Bool
    public let coordinatorOperationSerialPreserved: Bool
    public let callerCancellationObservedAfterDispatch: Bool
    public let parityPromotionAllowed: Bool

    public init(ticket: UInt64, requestedSemitones: Double, committedSemitones: Double, clickGenerationPreserved: Bool, lifecycleRevisionPreserved: Bool, coordinatorOperationSerialPreserved: Bool, callerCancellationObservedAfterDispatch: Bool, parityPromotionAllowed: Bool = false) {
        self.ticket=ticket; self.requestedSemitones=requestedSemitones; self.committedSemitones=committedSemitones; self.clickGenerationPreserved=clickGenerationPreserved; self.lifecycleRevisionPreserved=lifecycleRevisionPreserved; self.coordinatorOperationSerialPreserved=coordinatorOperationSerialPreserved; self.callerCancellationObservedAfterDispatch=callerCancellationObservedAfterDispatch; self.parityPromotionAllowed=parityPromotionAllowed
    }
}

public struct Lane3PitchControlFailureReceipt: Equatable, Sendable {
    public let ticket: UInt64
    public let requestedSemitones: Double
    public let reason: Lane3PitchControlRejectionReason?
    public let errorDescription: String
    public let automaticRecoveryAttempted: Bool
    public let automaticRecoverySucceeded: Bool
    public let callerCancellationObservedAfterDispatch: Bool
    public let parityPromotionAllowed: Bool
    public init(ticket: UInt64, requestedSemitones: Double, reason: Lane3PitchControlRejectionReason?, errorDescription: String, automaticRecoveryAttempted: Bool = false, automaticRecoverySucceeded: Bool = false, callerCancellationObservedAfterDispatch: Bool, parityPromotionAllowed: Bool = false) {
        self.ticket=ticket; self.requestedSemitones=requestedSemitones; self.reason=reason; self.errorDescription=errorDescription; self.automaticRecoveryAttempted=automaticRecoveryAttempted; self.automaticRecoverySucceeded=automaticRecoverySucceeded; self.callerCancellationObservedAfterDispatch=callerCancellationObservedAfterDispatch; self.parityPromotionAllowed=parityPromotionAllowed
    }
}
public enum Lane3PitchControlOutcome: Equatable, Sendable { case executed(Lane3PitchControlExecutionReceipt); case supersededBeforeDispatch(ticket:UInt64,byTicket:UInt64); case cancelledBeforeDispatch(ticket:UInt64); case rejectedBeforeDispatch(ticket:UInt64,reason:Lane3PitchControlRejectionReason); case failedAfterDispatch(Lane3PitchControlFailureReceipt) }
public struct Lane3UnifiedPracticeControlSnapshot: Equatable, Sendable { public let pitchBarrierClosed:Bool; public let interruptionBlocksPitch:Bool; public let sharedOperationsInFlight:Int; public let pendingPitchTicket:UInt64?; public let executingPitchTicket:UInt64?; public let nextPitchTicket:UInt64; public init(pitchBarrierClosed:Bool,interruptionBlocksPitch:Bool,sharedOperationsInFlight:Int,pendingPitchTicket:UInt64?,executingPitchTicket:UInt64?,nextPitchTicket:UInt64){self.pitchBarrierClosed=pitchBarrierClosed;self.interruptionBlocksPitch=interruptionBlocksPitch;self.sharedOperationsInFlight=sharedOperationsInFlight;self.pendingPitchTicket=pendingPitchTicket;self.executingPitchTicket=executingPitchTicket;self.nextPitchTicket=nextPitchTicket}}

public actor Lane3UnifiedPracticeControlAuthority {
    private struct PendingPitch { let ticket:UInt64; let semitones:Double; let continuation:CheckedContinuation<Lane3PitchControlOutcome,Never> }
    private let projectID:ProjectID; private let transport:Lane3InstrumentedInterruptionGate; private let practice:Lane3SerializedPracticeClickGate; private let controller:PracticeDSPProductionController; private let coordinator:PracticeDSPGenerationCoordinator; private let telemetryProbe:Lane3DSPRuntimeTelemetryProbe?; private let pitchRange:ClosedRange<Double>
    private var nextPitchTicket:UInt64=0; private var pendingPitch:PendingPitch?; private var pitchDrainRunning=false; private var pitchBarrierClosed=false; private var interruptionBlocksPitch=false; private var executingPitchTicket:UInt64?; private var backendDispatchStarted=false; private var cancellationBeforeDispatch:Set<UInt64>=[]; private var cancellationAfterDispatch:Set<UInt64>=[]
    private var sharedOperationsInFlight=0; private var sharedAdmissionWaiters:[CheckedContinuation<Void,Never>]=[]; private var sharedQuiescenceWaiters:[CheckedContinuation<Void,Never>]=[]
    public init(projectID:ProjectID,transport:Lane3InstrumentedInterruptionGate,practice:Lane3SerializedPracticeClickGate,controller:PracticeDSPProductionController,coordinator:PracticeDSPGenerationCoordinator,telemetryProbe:Lane3DSPRuntimeTelemetryProbe?=nil,pitchRange:ClosedRange<Double>=PracticeDSPCapabilities.appleTimePitchBaseline.pitchSemitoneRange){self.projectID=projectID;self.transport=transport;self.practice=practice;self.controller=controller;self.coordinator=coordinator;self.telemetryProbe=telemetryProbe;self.pitchRange=pitchRange}
    public func submitPitchSemitones(_ semitones:Double) async -> Lane3PitchControlOutcome { guard let ticket=allocatePitchTicket() else{return .rejectedBeforeDispatch(ticket:UInt64.max,reason:.ticketOverflow)}; guard semitones.isFinite,pitchRange.contains(semitones) else{return .rejectedBeforeDispatch(ticket:ticket,reason:.invalidPitchSemitones)}; guard !interruptionBlocksPitch else{return .rejectedBeforeDispatch(ticket:ticket,reason:.interruptionOrLifecycleBlocked)}; return await withTaskCancellationHandler { await withCheckedContinuation { enqueuePitch(PendingPitch(ticket:ticket,semitones:semitones,continuation:$0)) } } onCancel:{ Task{await self.cancelPitch(ticket:ticket)} } }
    public func submitSeek(to p:Double,resume:Bool,loop:PlaybackLoopRange?) async -> Lane3InterruptionGuardedOutcome { await withShared{await transport.submitSeek(to:p,resume:resume,loop:loop)} }
    public func submitLoop(_ loop:PlaybackLoopRange?) async -> Lane3InterruptionGuardedOutcome { await withShared{await transport.submitLoop(loop)} }
    public func submitTempoRatio(_ ratio:Double) async -> Lane3InterruptionGuardedOutcome { await withShared{await transport.submitTempoRatio(ratio)} }
    public func submitMediaLoad(_ asset:LocalAudioAsset) async -> Lane3InterruptionGuardedOutcome { await withShared{await transport.submitMediaLoad(asset)} }
    public func submitMediaReplacement(stems:[StemArtifact],positionSeconds:Double,resume:Bool,loop:PlaybackLoopRange?) async -> Lane3InterruptionGuardedOutcome { await withShared{await transport.submitMediaReplacement(stems:stems,positionSeconds:positionSeconds,resume:resume,loop:loop)} }
    public func submitPlay() async -> Lane3InterruptionGuardedOutcome { await withShared{await transport.submitPlay()} }
    public func submitPause() async -> Lane3InterruptionGuardedOutcome { await withShared{await transport.submitPause()} }
    public func submitRecovery() async -> Lane3InterruptionGuardedOutcome { await withShared{await transport.submitRecovery()} }
    @discardableResult public func setMetronomeEnabled(_ enabled:Bool) async throws -> PracticeDSPGenerationCoordinatorReceipt { try await withSharedThrowing{try await practice.setMetronomeEnabled(enabled)} }
    @discardableResult public func scheduleCountIn(clicks:Int) async throws -> Lane3CountInArmAuthorization { try await withSharedThrowing{try await practice.scheduleCountIn(clicks:clicks)} }
    public func makeCountInPlan(authorization:Lane3CountInArmAuthorization,sourceBeatIntervalSeconds:Double,musicStartSampleTime:Int64,renderOriginSampleTime:Int64,sampleRate:Double,downbeatStride:Int=4) async throws -> DSPCountInPlan { try await withSharedThrowing{try await practice.makeCountInPlan(authorization:authorization,sourceBeatIntervalSeconds:sourceBeatIntervalSeconds,musicStartSampleTime:musicStartSampleTime,renderOriginSampleTime:renderOriginSampleTime,sampleRate:sampleRate,downbeatStride:downbeatStride)} }
    @discardableResult public func markCountInScheduleCommitted(authorization:Lane3CountInArmAuthorization) async throws -> PracticeDSPSerializedCountInReceipt { try await withSharedThrowing{try await practice.markCountInScheduleCommitted(authorization:authorization)} }
    public func makeMetronomeRestorePlan(authorization:Lane3MetronomeRestoreAuthorization,beatTimesSeconds:[Double],sourceStartSeconds:Double,sourceEndSeconds:Double?,renderOriginSampleTime:Int64,sampleRate:Double,downbeatStride:Int=4) async throws -> PracticeDSPMetronomeExecutionPlan { try await withSharedThrowing{try await practice.makeMetronomeRestorePlan(authorization:authorization,beatTimesSeconds:beatTimesSeconds,sourceStartSeconds:sourceStartSeconds,sourceEndSeconds:sourceEndSeconds,renderOriginSampleTime:renderOriginSampleTime,sampleRate:sampleRate,downbeatStride:downbeatStride)} }
    public func submitInterruptionBegan() async -> Lane3SerializedInterruptionBeginEnvelope { interruptionBlocksPitch=true; if let p=pendingPitch{pendingPitch=nil;p.continuation.resume(returning:.rejectedBeforeDispatch(ticket:p.ticket,reason:.interruptionOrLifecycleBlocked))}; return await withShared{await practice.submitInterruptionBegan()} }
    public func submitInterruptionEnded(shouldResume:Bool) async -> Lane3PracticeInterruptionEndEnvelope { let r=await withShared{await practice.submitInterruptionEnded(shouldResume:shouldResume)}; await reopenPitchIfLifecycleIdle(); return r }
    public func retryEndedInterruptionRecovery() async -> Lane3PracticeInterruptionEndEnvelope { let r=await withShared{await practice.retryEndedInterruptionRecovery()}; await reopenPitchIfLifecycleIdle(); return r }
    public func snapshot()->Lane3UnifiedPracticeControlSnapshot{.init(pitchBarrierClosed:pitchBarrierClosed,interruptionBlocksPitch:interruptionBlocksPitch,sharedOperationsInFlight:sharedOperationsInFlight,pendingPitchTicket:pendingPitch?.ticket,executingPitchTicket:executingPitchTicket,nextPitchTicket:nextPitchTicket)}
    private func allocatePitchTicket()->UInt64?{let(n,o)=nextPitchTicket.addingReportingOverflow(1);guard !o else{return nil};nextPitchTicket=n;return n}
    private func enqueuePitch(_ c:PendingPitch){if interruptionBlocksPitch{c.continuation.resume(returning:.rejectedBeforeDispatch(ticket:c.ticket,reason:.interruptionOrLifecycleBlocked));return};if let p=pendingPitch{p.continuation.resume(returning:.supersededBeforeDispatch(ticket:p.ticket,byTicket:c.ticket))};pendingPitch=c;if !pitchDrainRunning{pitchDrainRunning=true;Task{await self.drainPitchQueue()}}}
    private func cancelPitch(ticket:UInt64){if let p=pendingPitch,p.ticket==ticket{pendingPitch=nil;p.continuation.resume(returning:.cancelledBeforeDispatch(ticket:ticket));return};guard executingPitchTicket==ticket else{return};if backendDispatchStarted{cancellationAfterDispatch.insert(ticket)}else{cancellationBeforeDispatch.insert(ticket)}}
    private func drainPitchQueue() async {while let c=pendingPitch{pendingPitch=nil;executingPitchTicket=c.ticket;backendDispatchStarted=false;pitchBarrierClosed=true;await waitForSharedQuiescence();if cancellationBeforeDispatch.remove(c.ticket) != nil{finishPitchBarrier();c.continuation.resume(returning:.cancelledBeforeDispatch(ticket:c.ticket));continue};if interruptionBlocksPitch{finishPitchBarrier();c.continuation.resume(returning:.rejectedBeforeDispatch(ticket:c.ticket,reason:.interruptionOrLifecycleBlocked));continue};backendDispatchStarted=true;let outcome=await executePitch(c);finishPitchBarrier();c.continuation.resume(returning:outcome)};pitchDrainRunning=false}
    private func finishPitchBarrier(){executingPitchTicket=nil;backendDispatchStarted=false;pitchBarrierClosed=false;resumeSharedAdmissionWaiters()}
    private func executePitch(_ c:PendingPitch) async -> Lane3PitchControlOutcome {let lb=await transport.snapshot();guard lb.phase == .idle else{return .rejectedBeforeDispatch(ticket:c.ticket,reason:.interruptionOrLifecycleBlocked)};guard !lb.authorityRecoveryBlocked else{return .rejectedBeforeDispatch(ticket:c.ticket,reason:.transportRecoveryBlocked)};let ab=await coordinator.authoritySnapshot();guard !ab.isPoisoned else{return .rejectedBeforeDispatch(ticket:c.ticket,reason:.coordinatorPoisoned)};guard !ab.operationInFlight else{return .rejectedBeforeDispatch(ticket:c.ticket,reason:.coordinatorBusyOutsideSelectedRoute)};let sb:PracticeDSPGenerationCoordinatorSnapshot;do{sb=try await coordinator.snapshot()}catch{return .failedAfterDispatch(makeFailure(c,reason:nil,error:"preflight snapshot failed: \(error)",recovery:nil))};do{let pitchController=controller; let pitchProjectID=projectID; if let telemetryProbe{try await telemetryProbe.measureAsync(kind:.pitch){try await pitchController.setPitchSemitones(c.semitones,projectID:pitchProjectID)}}else{try await pitchController.setPitchSemitones(c.semitones,projectID:pitchProjectID)}}catch{let needs=(try? await controller.requiresBackendResynchronization(projectID:projectID)) == true;let rec=needs ? await automaticRecovery():nil;return .failedAfterDispatch(makeFailure(c,reason:needs ? .backendRequiresRecovery:nil,error:String(describing:error),recovery:rec))};let aa=await coordinator.authoritySnapshot();let la=await transport.snapshot();let sa:PracticeDSPGenerationCoordinatorSnapshot;do{sa=try await coordinator.snapshot()}catch{return .failedAfterDispatch(makeFailure(c,reason:nil,error:"postflight snapshot failed: \(error)",recovery:nil))};let f:Lane3PitchControlRejectionReason?;if la.phase != .idle || la.lifecycleRevision != lb.lifecycleRevision{f = .lifecycleChangedDuringMutation}else if aa.operationSerial != ab.operationSerial || aa.operationInFlight || aa.isPoisoned || aa.activeBinding != ab.activeBinding{f = .coordinatorChangedDuringMutation}else if sa.dspState.scheduleGeneration != sb.dspState.scheduleGeneration{f = .clickGenerationChangedDuringPitch}else if abs(sa.dspState.pitchSemitones-c.semitones) > 0.000001{f = .pitchReadbackMismatch}else{f=nil};if let f{let rec=await automaticRecovery();return .failedAfterDispatch(makeFailure(c,reason:f,error:f.rawValue,recovery:rec))};return .executed(.init(ticket:c.ticket,requestedSemitones:c.semitones,committedSemitones:sa.dspState.pitchSemitones,clickGenerationPreserved:true,lifecycleRevisionPreserved:true,coordinatorOperationSerialPreserved:true,callerCancellationObservedAfterDispatch:cancellationAfterDispatch.remove(c.ticket) != nil))}
    private func automaticRecovery() async -> Bool {let o=await transport.submitRecovery();guard case let .transport(t)=o else{return false};if case .executed=t{return true};if case let .failedAfterDispatch(r)=t{return r.automaticRecovery.succeeded};return false}
    private func makeFailure(_ c:PendingPitch,reason:Lane3PitchControlRejectionReason?,error:String,recovery:Bool?)->Lane3PitchControlFailureReceipt{.init(ticket:c.ticket,requestedSemitones:c.semitones,reason:reason,errorDescription:error,automaticRecoveryAttempted:recovery != nil,automaticRecoverySucceeded:recovery ?? false,callerCancellationObservedAfterDispatch:cancellationAfterDispatch.remove(c.ticket) != nil)}
    private func withShared<T: Sendable>(_ op:() async -> T) async -> T {await enterSharedOperation();defer{leaveSharedOperation()};return await op()}
    private func withSharedThrowing<T: Sendable>(_ op:() async throws -> T) async throws -> T {await enterSharedOperation();defer{leaveSharedOperation()};return try await op()}
    private func enterSharedOperation() async {while pitchBarrierClosed{await withCheckedContinuation{sharedAdmissionWaiters.append($0)}};sharedOperationsInFlight += 1}
    private func leaveSharedOperation(){precondition(sharedOperationsInFlight>0);sharedOperationsInFlight -= 1;if sharedOperationsInFlight==0{let w=sharedQuiescenceWaiters;sharedQuiescenceWaiters.removeAll(keepingCapacity:true);for x in w{x.resume()}}}
    private func waitForSharedQuiescence() async {while sharedOperationsInFlight>0{await withCheckedContinuation{sharedQuiescenceWaiters.append($0)}}}
    private func resumeSharedAdmissionWaiters(){let w=sharedAdmissionWaiters;sharedAdmissionWaiters.removeAll(keepingCapacity:true);for x in w{x.resume()}}
    private func reopenPitchIfLifecycleIdle() async {let l=await transport.snapshot();if l.phase == .idle && !l.authorityRecoveryBlocked{interruptionBlocksPitch=false}}
}
