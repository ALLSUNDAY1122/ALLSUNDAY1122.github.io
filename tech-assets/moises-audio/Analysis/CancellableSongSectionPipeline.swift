import Foundation

public enum CancellableSongSectionPipeline {
    private struct Descriptor {
        var histogram = Array(repeating: 0.0, count: 26)
        var rms = 0.0
        var coverage = 0.0
    }

    private struct Boundary {
        var time: Double
        var strength: Double
        var energyCue: Bool
    }

    private struct Work {
        var start: Double
        var end: Double
        var descriptor: Descriptor
        var sourceConfidence: Double?
        var cluster = -1
        var structural = "X"
        var functional: String?
        var confidence: Double?
        var duration: Double { end - start }
    }

    public static func analyze(
        signal: AnalysisSignal,
        chords: [ChordEvent],
        configuration: MusicAnalysisConfiguration = .productBaseline
    ) throws -> [SongSection] {
        try AnalysisCancellationPolicy.check()
        let duration = signal.durationSeconds
        guard duration > 0, !signal.monoSamples.isEmpty else { return [] }
        let index = SectionChordTimelineIndex(chords)
        let global = try descriptor(signal, index, 0, duration)
        guard global.rms >= configuration.sectionSilenceRMS,
              global.coverage >= configuration.minimumSectionChordCoverage else {
            return [unknown(duration)]
        }

        let context = min(configuration.sectionContextSeconds, max(1, duration / 4))
        let hop = SongSectionComplexityBudget.effectiveHop(
            durationSeconds: duration,
            configuredHop: configuration.sectionHopSeconds
        )
        var raw: [Boundary] = []
        raw.reserveCapacity(min(SongSectionComplexityBudget.maximumBoundaryCandidates, Int(ceil(duration / hop))))
        if duration >= context * 2 + configuration.minimumSectionSeconds {
            var time = context
            var iteration = 0
            while time <= duration - context + 1e-9,
                  raw.count < SongSectionComplexityBudget.maximumBoundaryCandidates {
                try AnalysisCancellationPolicy.checkIfNeeded(enabled: true, iteration: iteration, stride: 8)
                let left = try descriptor(signal, index, time - context, time)
                let right = try descriptor(signal, index, time, time + context)
                let novelty = distance(left, right)
                let span = min(0.75, context / 2)
                let localLeft = try descriptor(signal, index, max(0, time - span), time)
                let localRight = try descriptor(signal, index, time, min(duration, time + span))
                let jump = min(1, abs(log10(localLeft.rms + 1e-6) - log10(localRight.rms + 1e-6)) * 1.5)
                let cue = jump >= configuration.sectionEnergyJumpThreshold
                raw.append(.init(time: time, strength: max(novelty, cue ? min(1, 0.55 + 0.6 * jump) : 0), energyCue: cue))
                time += hop
                iteration += 1
            }
        }

        var selected: [Boundary] = []
        for i in raw.indices {
            try AnalysisCancellationPolicy.checkIfNeeded(enabled: true, iteration: i, stride: 64)
            let item = raw[i]
            let previous = i > 0 ? raw[i - 1].strength : -1
            let next = i + 1 < raw.count ? raw[i + 1].strength : -1
            guard item.strength >= configuration.sectionNoveltyThreshold,
                  item.energyCue || (item.strength >= previous && item.strength >= next) else { continue }
            let snapped = index.nearestBoundary(to: item.time, maximumDistance: min(1, hop)) ?? item.time
            let edge = item.energyCue
                ? min(configuration.minimumSectionSeconds, configuration.minimumEdgeSectionSeconds)
                : configuration.minimumSectionSeconds
            guard snapped >= edge, duration - snapped >= edge else { continue }
            selected.append(.init(time: snapped, strength: item.strength, energyCue: item.energyCue))
        }
        selected.sort { $0.time < $1.time }

        var filtered: [Boundary] = []
        for (iteration, item) in selected.enumerated() {
            try AnalysisCancellationPolicy.checkIfNeeded(enabled: true, iteration: iteration, stride: 64)
            guard let last = filtered.last else { filtered.append(item); continue }
            let separation = (item.energyCue || last.energyCue)
                ? min(configuration.minimumSectionSeconds, configuration.minimumEdgeSectionSeconds)
                : configuration.minimumSectionSeconds
            if item.time - last.time < separation {
                let a = item.strength + (item.energyCue ? 0.08 : 0)
                let b = last.strength + (last.energyCue ? 0.08 : 0)
                if a > b { filtered[filtered.count - 1] = item }
            } else {
                filtered.append(item)
            }
        }

        let boundaries = deduplicate([0.0] + filtered.map(\.time) + [duration])
        var seeds: [SongSection] = []
        if boundaries.count >= 2 {
            for i in 0..<(boundaries.count - 1) where boundaries[i + 1] > boundaries[i] {
                try AnalysisCancellationPolicy.checkIfNeeded(enabled: true, iteration: i, stride: 16)
                let left = i == 0 ? 0.65 : nearestStrength(boundaries[i], filtered)
                let right = i == boundaries.count - 2 ? 0.65 : nearestStrength(boundaries[i + 1], filtered)
                seeds.append(.init(
                    startSeconds: boundaries[i], endSeconds: boundaries[i + 1], structuralLabel: "seed-\(i)",
                    functionalLabel: nil, confidence: clamp((left + right) / 2)
                ))
            }
        }
        guard !seeds.isEmpty else { return [unknown(duration)] }
        return try hardenIndexed(seeds, signal, index, configuration)
    }

    public static func hardenCancellable(
        sections: [SongSection],
        signal: AnalysisSignal,
        chords: [ChordEvent],
        configuration: MusicAnalysisConfiguration = .productBaseline
    ) throws -> [SongSection] {
        try hardenIndexed(sections, signal, SectionChordTimelineIndex(chords), configuration)
    }

    private static func hardenIndexed(
        _ sections: [SongSection],
        _ signal: AnalysisSignal,
        _ index: SectionChordTimelineIndex,
        _ configuration: MusicAnalysisConfiguration
    ) throws -> [SongSection] {
        try AnalysisCancellationPolicy.check()
        let duration = signal.durationSeconds
        guard duration > 0, !signal.monoSamples.isEmpty else { return [] }
        guard !sections.isEmpty else { return [unknown(duration)] }

        var work: [Work] = []
        work.reserveCapacity(sections.count)
        for (iteration, section) in sections.enumerated() {
            try AnalysisCancellationPolicy.checkIfNeeded(enabled: true, iteration: iteration, stride: 8)
            let start = min(duration, max(0, section.startSeconds))
            let end = min(duration, max(start, section.endSeconds))
            guard end - start > 1e-6 else { continue }
            work.append(.init(start: start, end: end, descriptor: try descriptor(signal, index, start, end), sourceConfidence: section.confidence))
        }
        work.sort { $0.start == $1.start ? $0.end < $1.end : $0.start < $1.start }
        guard !work.isEmpty else { return [unknown(duration)] }
        work = try suppress(work, configuration)
        try cluster(&work, configuration)
        try functional(&work, configuration)
        try AnalysisCancellationPolicy.check()
        return work.map { .init(startSeconds: $0.start, endSeconds: $0.end, structuralLabel: $0.structural, functionalLabel: $0.functional, confidence: $0.confidence) }
    }

    private static func suppress(_ input: [Work], _ configuration: MusicAnalysisConfiguration) throws -> [Work] {
        var output: [Work] = []
        output.reserveCapacity(input.count)
        let mergeSimilarity = min(0.98, max(0.90, configuration.sectionClusterSimilarity + 0.06))
        let maxNovelty = min(0.58, configuration.sectionNoveltyThreshold + 0.10)
        for (iteration, current) in input.enumerated() {
            try AnalysisCancellationPolicy.checkIfNeeded(enabled: true, iteration: iteration, stride: 32)
            guard var previous = output.last else { output.append(current); continue }
            let sim = similarity(previous.descriptor, current.descriptor)
            let canMerge = previous.descriptor.coverage >= configuration.minimumSectionChordCoverage
                && current.descriptor.coverage >= configuration.minimumSectionChordCoverage
                && sim >= mergeSimilarity && 1 - sim <= maxNovelty
            guard canMerge else { output.append(current); continue }
            output.removeLast()
            let left = previous.duration, right = current.duration, total = max(1e-9, left + right)
            previous.end = current.end
            previous.descriptor = blend(previous.descriptor, current.descriptor, left / total, right / total)
            previous.sourceConfidence = weighted(previous.sourceConfidence, current.sourceConfidence, left / total, right / total)
            output.append(previous)
        }
        return output
    }

    private static func cluster(_ work: inout [Work], _ configuration: MusicAnalysisConfiguration) throws {
        var prototypes: [Descriptor] = []
        var weights: [Double] = []
        prototypes.reserveCapacity(min(SongSectionComplexityBudget.maximumPrototypeClusters, work.count))
        weights.reserveCapacity(min(SongSectionComplexityBudget.maximumPrototypeClusters, work.count))
        for i in work.indices {
            try AnalysisCancellationPolicy.checkIfNeeded(enabled: true, iteration: i, stride: 16)
            let d = work[i].descriptor
            guard d.coverage >= configuration.minimumSectionChordCoverage, d.rms >= configuration.sectionSilenceRMS else {
                work[i].cluster = -1; work[i].structural = "X"; work[i].functional = nil; work[i].confidence = nil; continue
            }
            var best: Int?, bestSimilarity = -Double.infinity
            for p in prototypes.indices {
                let value = similarity(d, prototypes[p])
                if value > bestSimilarity { best = p; bestSimilarity = value }
            }
            if let best, bestSimilarity >= configuration.sectionClusterSimilarity {
                work[i].cluster = best
                let old = weights[best], new = max(1e-9, work[i].duration), total = old + new
                prototypes[best] = blend(prototypes[best], d, old / total, new / total)
                weights[best] = total
            } else if prototypes.count < SongSectionComplexityBudget.maximumPrototypeClusters {
                work[i].cluster = prototypes.count; prototypes.append(d); weights.append(max(1e-9, work[i].duration))
            } else {
                work[i].cluster = -1; work[i].structural = "X"; work[i].functional = nil; work[i].confidence = nil
            }
        }
        for i in work.indices where work[i].cluster >= 0 {
            try AnalysisCancellationPolicy.checkIfNeeded(enabled: true, iteration: i, stride: 32)
            let sim = similarity(work[i].descriptor, prototypes[work[i].cluster])
            let source = work[i].sourceConfidence.map { min(1, max(0, $0)) } ?? 0.55
            work[i].structural = structural(work[i].cluster)
            work[i].confidence = clamp(0.48 * source + 0.30 * work[i].descriptor.coverage + 0.22 * sim)
            work[i].functional = nil
        }
    }

    private static func functional(_ work: inout [Work], _ configuration: MusicAnalysisConfiguration) throws {
        let eligible = work.indices.filter { work[$0].cluster >= 0 && (work[$0].confidence ?? 0) >= configuration.minimumFunctionalSectionConfidence }
        guard !eligible.isEmpty else { return }
        let energies = eligible.map { work[$0].descriptor.rms }.sorted()
        let median = energies[energies.count / 2]
        if let first = eligible.first, first == work.startIndex, work[first].duration <= 14, work[first].descriptor.rms < median * 0.82 { work[first].functional = "intro" }
        if let last = eligible.last, last == work.index(before: work.endIndex), work[last].duration <= 14, work[last].descriptor.rms < median * 0.82 { work[last].functional = "outro" }

        var occurrences: [Int: [Int]] = [:]
        for (iteration, i) in eligible.enumerated() where work[i].functional == nil {
            try AnalysisCancellationPolicy.checkIfNeeded(enabled: true, iteration: iteration, stride: 64)
            occurrences[work[i].cluster, default: []].append(i)
        }
        let repeated = occurrences.keys.filter { occurrences[$0, default: []].count >= 2 }
        guard repeated.count >= 2 else { try bridgeOnly(&work, eligible); return }
        var avgEnergy: [Int: Double] = [:], avgDuration: [Int: Double] = [:]
        for (iteration, c) in repeated.enumerated() {
            try AnalysisCancellationPolicy.checkIfNeeded(enabled: true, iteration: iteration, stride: 16)
            let ids = occurrences[c, default: []]
            avgEnergy[c] = ids.reduce(0.0) { $0 + work[$1].descriptor.rms } / Double(ids.count)
            avgDuration[c] = ids.reduce(0.0) { $0 + work[$1].duration } / Double(ids.count)
        }
        guard let chorus = repeated.max(by: {
            avgEnergy[$0, default: 0] * (1 + min(0.20, avgDuration[$0, default: 0] / 80))
                < avgEnergy[$1, default: 0] * (1 + min(0.20, avgDuration[$1, default: 0] / 80))
        }) else { return }
        var pre = Set<Int>()
        for c in repeated where c != chorus {
            let ids = occurrences[c, default: []]
            let qualifying = ids.filter { $0 + 1 < work.count && work[$0 + 1].cluster == chorus && work[$0].duration <= 18 }.count
            if qualifying >= 2, Double(qualifying) / Double(ids.count) >= 0.75 { pre.insert(c) }
        }
        let verseCandidates = repeated.filter { $0 != chorus && !pre.contains($0) }
        guard let verse = verseCandidates.max(by: { occurrences[$0, default: []].count < occurrences[$1, default: []].count }) else { try bridgeOnly(&work, eligible); return }
        let ce = avgEnergy[chorus, default: 0], ve = avgEnergy[verse, default: 0]
        guard abs(ce - ve) / max(1e-9, max(ce, ve)) >= 0.08 else { try bridgeOnly(&work, eligible); return }
        for (iteration, i) in eligible.enumerated() where work[i].functional == nil {
            try AnalysisCancellationPolicy.checkIfNeeded(enabled: true, iteration: iteration, stride: 64)
            if work[i].cluster == chorus { work[i].functional = "chorus" }
            else if work[i].cluster == verse { work[i].functional = "verse" }
            else if pre.contains(work[i].cluster) { work[i].functional = "pre-chorus" }
        }
        let chorusIndices = eligible.filter { work[$0].functional == "chorus" }
        if let first = chorusIndices.first, let last = chorusIndices.last {
            for i in eligible where work[i].functional == nil && work[i].duration <= 24 && occurrences[work[i].cluster, default: []].count == 1 && i > first && i < last { work[i].functional = "bridge" }
        }
    }

    private static func bridgeOnly(_ work: inout [Work], _ eligible: [Int]) throws {
        let counts = Dictionary(grouping: eligible, by: { work[$0].cluster }).mapValues(\.count)
        for (iteration, i) in eligible.enumerated() {
            try AnalysisCancellationPolicy.checkIfNeeded(enabled: true, iteration: iteration, stride: 64)
            guard work[i].functional == nil, work[i].duration <= 24, counts[work[i].cluster, default: 0] == 1,
                  i > 0, i + 1 < work.count, work[i - 1].cluster == work[i + 1].cluster,
                  counts[work[i - 1].cluster, default: 0] >= 2 else { continue }
            work[i].functional = "bridge"
        }
    }

    private static func descriptor(_ signal: AnalysisSignal, _ index: SectionChordTimelineIndex, _ start: Double, _ end: Double) throws -> Descriptor {
        let lower = max(0, start), upper = min(signal.durationSeconds, max(start, end)), duration = max(1e-9, upper - lower)
        var result = Descriptor(), decided = 0.0, chordIteration = 0
        for i in index.overlappingIndices(start: lower, end: upper) {
            try AnalysisCancellationPolicy.checkIfNeeded(enabled: true, iteration: chordIteration, stride: 64)
            let chord = index.entries[i], overlap = max(0, min(upper, chord.endSeconds) - max(lower, chord.startSeconds))
            if overlap > 0 { result.histogram[chordBin(chord.normalizedLabel)] += overlap; if chord.normalizedLabel != "X" && chord.normalizedLabel != "N" { decided += overlap } }
            chordIteration += 1
        }
        let total = result.histogram.reduce(0, +); if total > 0 { result.histogram = result.histogram.map { $0 / total } }
        let lo = max(0, Int((lower * signal.sampleRate).rounded(.down))), hi = min(signal.monoSamples.count, Int((upper * signal.sampleRate).rounded(.up)))
        if hi > lo {
            let step = max(1, Int(ceil(Double(hi - lo) / Double(SongSectionComplexityBudget.descriptorSampleCap))))
            var sum = 0.0, count = 0, sample = lo
            while sample < hi {
                try AnalysisCancellationPolicy.checkIfNeeded(enabled: true, iteration: count, stride: 256)
                let raw = Double(signal.monoSamples[sample]), value = raw.isFinite ? min(16, max(-16, raw)) : 0
                sum += value * value; count += 1; sample += step
            }
            result.rms = count > 0 ? sqrt(sum / Double(count)) : 0
        }
        result.coverage = min(1, decided / duration)
        return result
    }

    private static func chordBin(_ label: String) -> Int {
        if label == "N" { return 24 }; if label == "X" { return 25 }
        let names = ["C":0,"C#":1,"D":2,"D#":3,"E":4,"F":5,"F#":6,"G":7,"G#":8,"A":9,"A#":10,"B":11]
        let root = String(label.split(separator: ":", maxSplits: 1).first ?? "C"), pc = names[root] ?? 0
        return label.contains(":min") ? 12 + pc : pc
    }
    private static func similarity(_ a: Descriptor, _ b: Descriptor) -> Double {
        let chord = cosine(a.histogram, b.histogram), energy = 1 - min(1, abs(log10(a.rms + 1e-6) - log10(b.rms + 1e-6)) / 2)
        return clamp(0.82 * chord + 0.18 * energy)
    }
    private static func distance(_ a: Descriptor, _ b: Descriptor) -> Double { 1 - similarity(a, b) }
    private static func blend(_ a: Descriptor, _ b: Descriptor, _ aw: Double, _ bw: Double) -> Descriptor {
        .init(histogram: zip(a.histogram,b.histogram).map { $0.0 * aw + $0.1 * bw }, rms: a.rms * aw + b.rms * bw, coverage: a.coverage * aw + b.coverage * bw)
    }
    private static func weighted(_ a: Double?, _ b: Double?, _ aw: Double, _ bw: Double) -> Double? {
        switch (a,b) { case let (x?,y?): return clamp(x*aw+y*bw); case let (x?,nil): return clamp(x); case let (nil,y?): return clamp(y); default: return nil }
    }
    private static func nearestStrength(_ time: Double, _ values: [Boundary]) -> Double {
        guard !values.isEmpty else { return 0.5 }; var low=0, high=values.count
        while low<high { let mid=(low+high)/2; if values[mid].time < time { low=mid+1 } else { high=mid } }
        var best=min(low,values.count-1); if low>0, abs(values[low-1].time-time) <= abs(values[best].time-time) { best=low-1 }; return values[best].strength
    }
    private static func deduplicate(_ values: [Double]) -> [Double] { var out:[Double]=[]; for v in values.sorted() { if let last=out.last, abs(last-v)<=1e-6 {continue}; out.append(v) }; return out }
    private static func structural(_ i: Int) -> String { if i<26, let s=UnicodeScalar(65+i){return String(s)}; return "S\(i+1)" }
    private static func unknown(_ duration: Double) -> SongSection { .init(startSeconds:0,endSeconds:duration,structuralLabel:"X",functionalLabel:nil,confidence:nil) }
    private static func cosine(_ a:[Double],_ b:[Double])->Double { let dot=zip(a,b).reduce(0.0){$0+$1.0*$1.1}, l=sqrt(a.reduce(0.0){$0+$1*$1}), r=sqrt(b.reduce(0.0){$0+$1*$1}); return l>1e-12 && r>1e-12 ? dot/(l*r):0 }
    private static func clamp(_ x: Double) -> Double { min(1,max(0,x)) }
}
