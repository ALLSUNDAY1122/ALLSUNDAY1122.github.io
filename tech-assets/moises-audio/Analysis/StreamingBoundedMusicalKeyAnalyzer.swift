import Foundation

public enum StreamingBoundedMusicalKeyAnalyzer {
    private static let majorProfile: [Double] = [6.35,2.23,3.48,2.33,4.38,4.09,2.52,5.19,2.39,3.66,2.29,2.88]
    private static let minorProfile: [Double] = [6.33,2.68,3.52,5.38,2.60,3.53,2.54,4.75,3.98,2.69,3.34,3.17]
    private struct KeyCandidate { let tonic:Int; let mode:String; let score:Double; let triadSupport:Double }
    private struct KeyEvidence { let best:KeyCandidate; let normalizedMargin:Double; let activePitchClasses:Int }
    private struct ModalCandidate { let tonic:Int; let mode:String; let score:Double; let tonicSupport:Double; let alteredSupport:Double; let conventionalSupport:Double }
    private static let modalDefinitions:[(name:String,scale:[Int],altered:Int,conventional:Int,qualityThird:Int)] = [
        ("dorian",[0,2,3,5,7,9,10],9,8,3),("phrygian",[0,1,3,5,7,8,10],1,2,3),("lydian",[0,2,4,6,7,9,11],6,5,4),("mixolydian",[0,2,4,5,7,9,10],10,11,4),("locrian",[0,1,3,5,6,8,10],6,7,3)
    ]

    public static func analyzeCancellable(
        reader: AnalysisPreparedSampleReader,
        configuration: MusicAnalysisConfiguration = .productBaseline
    ) throws -> MusicalKey? {
        try AnalysisCancellationPolicy.check()
        guard reader.sampleCount >= configuration.analysisWindowSize else { return nil }
        let globalRMS = try reader.rms(maximumSamples: AnalysisWorkingSetPolicy.maximumRMSProbeSamples)
        let windowSize = configuration.analysisWindowSize
        let available = max(1, (reader.sampleCount - windowSize) / max(1, configuration.analysisHopSize) + 1)
        let selected = min(configuration.maximumKeyWindows, available)
        let starts = uniformlySpacedWindowStarts(sampleCount: reader.sampleCount, windowSize: windowSize, count: selected)
        var windows: [[Double]] = []
        windows.reserveCapacity(starts.count)
        for (index, start) in starts.enumerated() {
            try AnalysisCancellationPolicy.checkIfNeeded(enabled: true, iteration: index, stride: AnalysisCancellationPolicy.keyWindowCheckStride)
            windows.append(try reader.finiteWindow(range: start..<(start + windowSize)))
        }
        return try analyzePreparedWindowsCancellable(
            windows: windows,
            sampleRate: reader.sampleRate,
            globalRMS: globalRMS,
            configuration: configuration
        )
    }

    public static func analyzePreparedWindowsCancellable(
        windows: [[Double]],
        sampleRate: Double,
        globalRMS: Double,
        configuration: MusicAnalysisConfiguration = .productBaseline
    ) throws -> MusicalKey? {
        try AnalysisCancellationPolicy.check()
        guard sampleRate.isFinite, sampleRate > 0,
              globalRMS.isFinite, globalRMS > 1e-5,
              windows.count >= 2 else { return nil }
        var localChromas: [[Double]] = []
        localChromas.reserveCapacity(windows.count)
        for (index, window) in windows.enumerated() {
            try AnalysisCancellationPolicy.checkIfNeeded(enabled: true, iteration: index, stride: AnalysisCancellationPolicy.keyWindowCheckStride)
            guard window.count >= 2 else { continue }
            let local = try chromaForPreparedWindow(window, sampleRate: sampleRate)
            let total = local.reduce(0,+)
            guard total > 1e-10 else { continue }
            localChromas.append(local.map { $0 / total })
        }
        guard localChromas.count >= 2 else { return nil }
        let chroma = normalizedSum(localChromas)
        guard let global = keyEvidence(chroma), global.activePitchClasses >= 3 else { return nil }
        let ranked = rankedCandidates(chroma)
        if let relative = relativeCounterpart(of: global.best, in: ranked) {
            let gap = max(0, global.best.score - relative.score) / max(abs(global.best.score), 1e-9)
            let tonicGap = abs(chroma[global.best.tonic] - chroma[relative.tonic])
            if gap < configuration.keyRelativeAmbiguityMargin, tonicGap < 0.035 { return nil }
        }
        if global.activePitchClasses >= 5,
           let modal = bestModalCandidate(chroma),
           modal.tonic == global.best.tonic,
           modal.tonicSupport >= 0.55,
           modal.alteredSupport >= 0.20,
           modal.alteredSupport > modal.conventionalSupport * 1.20,
           modal.score >= 0.72 { return nil }
        let halves = temporalHalves(localChromas)
        var agreement = 1.0
        if let first = keyEvidence(halves.first),
           let second = keyEvidence(halves.second),
           first.activePitchClasses >= 5,
           second.activePitchClasses >= 5,
           first.normalizedMargin >= configuration.keyModulationMargin,
           second.normalizedMargin >= configuration.keyModulationMargin,
           (first.best.tonic != second.best.tonic || first.best.mode != second.best.mode) { return nil }
        else if let first = keyEvidence(halves.first), let second = keyEvidence(halves.second) {
            agreement = Double([first.best, second.best].filter { $0.tonic == global.best.tonic && $0.mode == global.best.mode }.count) / 2
        }
        let confidence = clamp01(min(1, global.normalizedMargin / 0.08) * 0.68 + global.best.triadSupport * 0.20 + agreement * 0.12)
        guard confidence >= configuration.minimumKeyConfidence else { return nil }
        try AnalysisCancellationPolicy.check()
        return MusicalKey(tonicPitchClass: global.best.tonic, mode: global.best.mode, confidence: confidence)
    }

    private static func chromaForPreparedWindow(_ samples:[Double],sampleRate:Double)throws->[Double]{
        let n=samples.count; guard n>1 else{return Array(repeating:0,count:12)}
        var windowed=Array(repeating:0.0,count:n)
        for local in 0..<n { let hann=0.5-0.5*cos((2*Double.pi*Double(local))/Double(n-1)); windowed[local]=samples[local]*hann }
        var chroma=Array(repeating:0.0,count:12)
        for (offset,midi) in (36...83).enumerated(){
            try AnalysisCancellationPolicy.checkIfNeeded(enabled:true,iteration:offset,stride:8)
            let f=440*pow(2,Double(midi-69)/12); guard f<sampleRate*0.45 else{continue}
            chroma[(midi%12+12)%12]+=sqrt(max(0,goertzelPower(windowed,sampleRate:sampleRate,frequency:f)))
        }
        return chroma
    }
    private static func goertzelPower(_ s:[Double],sampleRate:Double,frequency:Double)->Double{let omega=2*Double.pi*frequency/sampleRate,c=2*cos(omega);var s0=0.0,s1=0.0,s2=0.0;for x in s{s0=x+c*s1-s2;s2=s1;s1=s0};return max(0,s1*s1+s2*s2-c*s1*s2)}
    private static func rankedCandidates(_ chroma:[Double])->[KeyCandidate]{let maxBin=max(chroma.max() ?? 0,1e-12);var out:[KeyCandidate]=[];out.reserveCapacity(24);for tonic in 0..<12{for (mode,p,third) in [("major",majorProfile,4),("minor",minorProfile,3)]{let ps=cosine(chroma,rotatedProfile(p,tonic:tonic));let triad=min(1,(chroma[tonic]*0.45+chroma[(tonic+third)%12]*0.30+chroma[(tonic+7)%12]*0.25)/maxBin);out.append(.init(tonic:tonic,mode:mode,score:ps*0.88+triad*0.12,triadSupport:triad))}};return out.sorted{$0.score>$1.score}}
    private static func keyEvidence(_ c:[Double])->KeyEvidence?{let r=rankedCandidates(c);guard r.count>=2 else{return nil};let b=r[0],s=r[1],m=max(0,b.score-s.score)/max(abs(b.score),1e-9),mx=c.max() ?? 0;return .init(best:b,normalizedMargin:m,activePitchClasses:c.filter{$0>=mx*0.16}.count)}
    private static func relativeCounterpart(of c:KeyCandidate,in r:[KeyCandidate])->KeyCandidate?{let tonic=c.mode=="major" ? (c.tonic+9)%12:(c.tonic+3)%12,mode=c.mode=="major" ? "minor":"major";return r.first{$0.tonic==tonic && $0.mode==mode}}
    private static func bestModalCandidate(_ c:[Double])->ModalCandidate?{let mx=max(c.max() ?? 0,1e-12);var best:ModalCandidate?;for tonic in 0..<12{for d in modalDefinitions{let scale=Set(d.scale.map{($0+tonic)%12}),coverage=scale.reduce(0.0){$0+c[$1]},ts=c[tonic]/mx,asup=c[(tonic+d.altered)%12]/mx,conv=c[(tonic+d.conventional)%12]/mx,third=c[(tonic+d.qualityThird)%12]/mx;let x=ModalCandidate(tonic:tonic,mode:d.name,score:coverage*0.58+ts*0.18+asup*0.14+third*0.10,tonicSupport:ts,alteredSupport:asup,conventionalSupport:conv);if best==nil || x.score>best!.score{best=x}}};return best}
    private static func temporalHalves(_ x:[[Double]])->(first:[Double],second:[Double]){let split=max(1,x.count/2);return(normalizedSum(Array(x[..<split])),normalizedSum(split<x.count ? Array(x[split...]):[]))}
    private static func normalizedSum(_ xs:[[Double]])->[Double]{var r=Array(repeating:0.0,count:12);for x in xs where x.count>=12{for i in 0..<12{r[i]+=x[i]}};let t=r.reduce(0,+);return t>1e-12 ? r.map{$0/t}:r}
    private static func rotatedProfile(_ p:[Double],tonic:Int)->[Double]{(0..<12).map{p[($0-tonic+12)%12]}}
    private static func cosine(_ a:[Double],_ b:[Double])->Double{let dot=zip(a,b).reduce(0.0){$0+$1.0*$1.1},l=sqrt(a.reduce(0.0){$0+$1*$1}),r=sqrt(b.reduce(0.0){$0+$1*$1});return l>1e-12 && r>1e-12 ? dot/(l*r):0}
    private static func uniformlySpacedWindowStarts(sampleCount:Int,windowSize:Int,count:Int)->[Int]{let last=max(0,sampleCount-windowSize);guard count>1,last>0 else{return[0]};return(0..<count).map{Int((Double($0)*Double(last)/Double(count-1)).rounded())}}
    private static func clamp01(_ x:Double)->Double{min(1,max(0,x))}
}
