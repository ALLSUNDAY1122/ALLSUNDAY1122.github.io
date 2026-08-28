import Foundation

public struct Lane2ManagedArtifactBoundedMutationMetrics: Hashable, Sendable { public let generationsPublished:Int; public let maximumDecodedSegmentEntries:Int; public let maximumMutationBatchEntries:Int }
public enum Lane2ManagedArtifactBoundedMutationFailure: Error, Equatable, Sendable { case invalidRelativePath(String); case corruptManifest(String); case corruptSegment(String); case verificationFailed(Int) }

private final class Lane2SegmentedBoundedMutationFileManagerHandle: @unchecked Sendable {
    let value: FileManager
    init(_ value: FileManager) { self.value = value }
}

public struct Lane2ManagedArtifactSegmentedBoundedMutation: Sendable {
    public static let shardCount=256, entriesPerSegment=512, mutationBatchLimit=256
    public static let managedRootNames=["Imports","Stems","Exports"]
    private struct Manifest: Codable, Equatable, Sendable { let schemaVersion:Int;let shardIndex:Int;let generation:UUID;let segmentCount:Int;let entryCount:Int }
    private struct Segment: Codable, Sendable { let schemaVersion:Int;let shardIndex:Int;let generation:UUID;let segmentIndex:Int;let entries:[Lane2ManagedArtifactRuntimeEntry] }
    public let rootURL:URL; public let recoveryDirectoryName:String; private let fileManagerHandle:Lane2SegmentedBoundedMutationFileManagerHandle
    public init(rootURL:URL,recoveryDirectoryName:String=".LibraryRecovery",fileManager:FileManager = .default){self.rootURL=rootURL.standardizedFileURL;self.recoveryDirectoryName=recoveryDirectoryName;self.fileManagerHandle=Lane2SegmentedBoundedMutationFileManagerHandle(fileManager)}
    private var fileManager:FileManager{fileManagerHandle.value}

    @discardableResult public func upsertManaged(relativePaths:[String]) throws -> Lane2ManagedArtifactBoundedMutationMetrics {
        var published=0,maximumDecoded=0,offset=0;let dedup=Array(Set(relativePaths)).sorted()
        while offset<dedup.count { let end=min(offset+Self.mutationBatchLimit,dedup.count);var grouped:[Int:[Lane2ManagedArtifactRuntimeEntry]]=[:]
            for raw in dedup[offset..<end]{let path=try Self.normalize(raw);guard Self.isManaged(path) else{throw Lane2ManagedArtifactBoundedMutationFailure.invalidRelativePath(raw)};guard let s=try snapshot(path) else{continue};grouped[Self.shardIndex(path),default:[]].append(s)}
            for (shard,updates) in grouped { if try loadManifest(shard)==nil { try Lane2ManagedArtifactSegmentedRuntime(rootURL:rootURL,recoveryDirectoryName:recoveryDirectoryName,fileManager:fileManager).upsertManaged(relativePaths:updates.map(\.relativePath));published+=1;continue };maximumDecoded=max(maximumDecoded,try streamRepublish(shardIndex:shard,updates:updates,removals:[]));published+=1 };offset=end }
        return .init(generationsPublished:published,maximumDecodedSegmentEntries:maximumDecoded,maximumMutationBatchEntries:min(Self.mutationBatchLimit,dedup.count))
    }

    @discardableResult public func removeManaged(relativePaths:[String]) throws -> Lane2ManagedArtifactBoundedMutationMetrics {
        var published=0,maximumDecoded=0,offset=0;let dedup=Array(Set(relativePaths)).sorted()
        while offset<dedup.count { let end=min(offset+Self.mutationBatchLimit,dedup.count);var grouped:[Int:Set<String>]=[:]
            for raw in dedup[offset..<end]{let path=try Self.normalize(raw);guard Self.isManaged(path) else{continue};grouped[Self.shardIndex(path),default:[]].insert(path)}
            for (shard,removals) in grouped { if try loadManifest(shard)==nil { try Lane2ManagedArtifactSegmentedRuntime(rootURL:rootURL,recoveryDirectoryName:recoveryDirectoryName,fileManager:fileManager).removeManaged(relativePaths:Array(removals));published+=1;continue };maximumDecoded=max(maximumDecoded,try streamRepublish(shardIndex:shard,updates:[],removals:removals));published+=1 };offset=end }
        return .init(generationsPublished:published,maximumDecodedSegmentEntries:maximumDecoded,maximumMutationBatchEntries:min(Self.mutationBatchLimit,dedup.count))
    }

    private func streamRepublish(shardIndex:Int,updates:[Lane2ManagedArtifactRuntimeEntry],removals:Set<String>) throws -> Int {
        guard let source=try loadManifest(shardIndex) else{throw Lane2ManagedArtifactBoundedMutationFailure.verificationFailed(shardIndex)}
        let updatesByPath=Dictionary(uniqueKeysWithValues:updates.map{($0.relativePath,$0)}),paths=updatesByPath.keys.sorted();var updateIndex=0,buffer:[Lane2ManagedArtifactRuntimeEntry]=[];buffer.reserveCapacity(Self.entriesPerSegment);let generation=UUID()
        do{try boundary.ensureDirectory(segmentedDirectoryURL,fileManager:fileManager)}catch{throw Lane2ManagedArtifactBoundedMutationFailure.corruptManifest(segmentedDirectoryURL.lastPathComponent)}
        var outIndex=0,outCount=0,maxDecoded=0,previous:String?
        func append(_ e:Lane2ManagedArtifactRuntimeEntry)throws{if let previous,e.relativePath<=previous{throw Lane2ManagedArtifactBoundedMutationFailure.verificationFailed(shardIndex)};previous=e.relativePath;buffer.append(e);outCount+=1;if buffer.count==Self.entriesPerSegment{try writeSegment(shardIndex:shardIndex,generation:generation,segmentIndex:outIndex,entries:buffer);outIndex+=1;buffer.removeAll(keepingCapacity:true)}}
        for srcIndex in 0..<source.segmentCount { let segment=try loadSegment(manifest:source,segmentIndex:srcIndex);maxDecoded=max(maxDecoded,segment.entries.count)
            for old in segment.entries { while updateIndex<paths.count && paths[updateIndex]<old.relativePath {let p=paths[updateIndex];if !removals.contains(p),let u=updatesByPath[p]{try append(u)};updateIndex+=1}; if updateIndex<paths.count && paths[updateIndex]==old.relativePath{let p=paths[updateIndex];if !removals.contains(p),let u=updatesByPath[p]{try append(u)};updateIndex+=1}else if !removals.contains(old.relativePath){try append(old)} }
        }
        while updateIndex<paths.count{let p=paths[updateIndex];if !removals.contains(p),let u=updatesByPath[p]{try append(u)};updateIndex+=1}
        if !buffer.isEmpty{try writeSegment(shardIndex:shardIndex,generation:generation,segmentIndex:outIndex,entries:buffer);outIndex+=1}
        let manifest=Manifest(schemaVersion:1,shardIndex:shardIndex,generation:generation,segmentCount:outIndex,entryCount:outCount);var verified=0
        for i in 0..<manifest.segmentCount{let s=try loadSegment(manifest:manifest,segmentIndex:i);maxDecoded=max(maxDecoded,s.entries.count);verified+=s.entries.count};guard verified==outCount else{throw Lane2ManagedArtifactBoundedMutationFailure.verificationFailed(shardIndex)}
        let url=manifestURL(shardIndex);do{_=try boundary.requireRegularFileOrMissing(url,within:segmentedDirectoryURL,fileManager:fileManager)}catch{throw Lane2ManagedArtifactBoundedMutationFailure.corruptManifest(url.lastPathComponent)}
        try stableEncoder.encode(manifest).write(to:url,options:[.atomic]);do{try boundary.requireExistingRegularFile(url,within:segmentedDirectoryURL,fileManager:fileManager)}catch{throw Lane2ManagedArtifactBoundedMutationFailure.corruptManifest(url.lastPathComponent)}
        guard try loadManifest(shardIndex)==manifest else{throw Lane2ManagedArtifactBoundedMutationFailure.verificationFailed(shardIndex)};return maxDecoded
    }

    private func snapshot(_ path:String)throws->Lane2ManagedArtifactRuntimeEntry?{let url=try absoluteURL(path);do{guard try boundary.nodeExists(url,fileManager:fileManager) else{return nil};try boundary.requireExistingRegularFile(url,within:rootURL,fileManager:fileManager);let a=try fileManager.attributesOfItem(atPath:url.path);let d=a[.modificationDate] as? Date ?? .distantPast;return .init(relativePath:path,modificationTime:d.timeIntervalSince1970)}catch{throw Lane2ManagedArtifactBoundedMutationFailure.invalidRelativePath(path)}}
    private func loadManifest(_ shard:Int)throws->Manifest?{let u=manifestURL(shard);do{guard try boundary.nodeExists(u,fileManager:fileManager) else{return nil};try boundary.requireExistingRegularFile(u,within:segmentedDirectoryURL,fileManager:fileManager)}catch{throw Lane2ManagedArtifactBoundedMutationFailure.corruptManifest(u.lastPathComponent)};let m:Manifest;do{m=try JSONDecoder().decode(Manifest.self,from:Data(contentsOf:u))}catch{throw Lane2ManagedArtifactBoundedMutationFailure.corruptManifest(u.lastPathComponent)};guard m.schemaVersion==1,m.shardIndex==shard,m.entryCount>=0,m.segmentCount==Self.segmentCount(m.entryCount) else{throw Lane2ManagedArtifactBoundedMutationFailure.corruptManifest(u.lastPathComponent)};return m}
    private func loadSegment(manifest:Manifest,segmentIndex:Int)throws->Segment{let u=segmentURL(shardIndex:manifest.shardIndex,generation:manifest.generation,segmentIndex:segmentIndex);do{try boundary.requireExistingRegularFile(u,within:segmentedDirectoryURL,fileManager:fileManager)}catch{throw Lane2ManagedArtifactBoundedMutationFailure.corruptSegment(u.lastPathComponent)};let s:Segment;do{s=try JSONDecoder().decode(Segment.self,from:Data(contentsOf:u))}catch{throw Lane2ManagedArtifactBoundedMutationFailure.corruptSegment(u.lastPathComponent)};guard s.schemaVersion==1,s.shardIndex==manifest.shardIndex,s.generation==manifest.generation,s.segmentIndex==segmentIndex,s.entries.count<=Self.entriesPerSegment else{throw Lane2ManagedArtifactBoundedMutationFailure.corruptSegment(u.lastPathComponent)};var prev:String?;for e in s.entries{let p=try Self.normalize(e.relativePath);guard p==e.relativePath,Self.isManaged(p),Self.shardIndex(p)==manifest.shardIndex,prev==nil || p>prev! else{throw Lane2ManagedArtifactBoundedMutationFailure.corruptSegment(u.lastPathComponent)};prev=p};return s}
    private func writeSegment(shardIndex:Int,generation:UUID,segmentIndex:Int,entries:[Lane2ManagedArtifactRuntimeEntry])throws{guard entries.count<=Self.entriesPerSegment else{throw Lane2ManagedArtifactBoundedMutationFailure.verificationFailed(shardIndex)};let s=Segment(schemaVersion:1,shardIndex:shardIndex,generation:generation,segmentIndex:segmentIndex,entries:entries),u=segmentURL(shardIndex:shardIndex,generation:generation,segmentIndex:segmentIndex);do{try boundary.requireSafeDestination(u,within:segmentedDirectoryURL,fileManager:fileManager)}catch{throw Lane2ManagedArtifactBoundedMutationFailure.corruptSegment(u.lastPathComponent)};try stableEncoder.encode(s).write(to:u,options:[.atomic]);do{try boundary.requireExistingRegularFile(u,within:segmentedDirectoryURL,fileManager:fileManager)}catch{throw Lane2ManagedArtifactBoundedMutationFailure.corruptSegment(u.lastPathComponent)}}
    private func absoluteURL(_ p:String)throws->URL{let p=try Self.normalize(p),u=rootURL.appendingPathComponent(p).standardizedFileURL,prefix=rootURL.path.hasSuffix("/") ? rootURL.path : rootURL.path+"/";guard u.path.hasPrefix(prefix) else{throw Lane2ManagedArtifactBoundedMutationFailure.invalidRelativePath(p)};return u}
    private var boundary:LibraryManagedPathBoundary{.init(rootURL:rootURL)}
    private var segmentedDirectoryURL:URL{rootURL.appendingPathComponent(recoveryDirectoryName,isDirectory:true).appendingPathComponent("ArtifactInventory",isDirectory:true).appendingPathComponent("v1",isDirectory:true).appendingPathComponent("Segmented",isDirectory:true)}
    private func manifestURL(_ i:Int)->URL{segmentedDirectoryURL.appendingPathComponent(String(format:"%02x.manifest.json",i))}
    private func segmentURL(shardIndex:Int,generation:UUID,segmentIndex:Int)->URL{segmentedDirectoryURL.appendingPathComponent(String(format:"%02x.%@.%04d.json",shardIndex,generation.uuidString,segmentIndex))}
    private var stableEncoder:JSONEncoder{let e=JSONEncoder();e.outputFormatting=[.sortedKeys];return e}
    private static func segmentCount(_ c:Int)->Int{guard c>0 else{return 0};let q=c/entriesPerSegment;return q+(c%entriesPerSegment==0 ? 0:1)}
    private static func isManaged(_ p:String)->Bool{p.split(separator:"/").first.map{managedRootNames.contains(String($0))} ?? false}
    private static func normalize(_ raw:String)throws->String{let p=raw.replacingOccurrences(of:"\\",with:"/");guard !p.isEmpty,!p.hasPrefix("/"),!p.contains("\0"),!(p as NSString).isAbsolutePath else{throw Lane2ManagedArtifactBoundedMutationFailure.invalidRelativePath(raw)};let xs=p.split(separator:"/",omittingEmptySubsequences:false);guard xs.count>=2,!xs.contains(where:{$0.isEmpty || $0=="." || $0==".."}) else{throw Lane2ManagedArtifactBoundedMutationFailure.invalidRelativePath(raw)};return xs.joined(separator:"/")}
    private static func shardIndex(_ p:String)->Int{var h:UInt64=14_695_981_039_346_656_037;for b in p.utf8{h^=UInt64(b);h&*=1_099_511_628_211};return Int(h%UInt64(shardCount))}
}
