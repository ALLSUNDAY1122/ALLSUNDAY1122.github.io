import copy, hashlib, io, json, os, sys, tempfile, unittest, wave
from contextlib import contextmanager
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "Evaluation"))
from golden_corpus_intake import main, validate_golden_corpus, validate_golden_corpus_files

def sha(path):
    h=hashlib.sha256()
    with open(path,"rb") as f:
        for b in iter(lambda:f.read(1024*1024),b""): h.update(b)
    return h.hexdigest()

def write_wav(path, seconds, amp, rate=8000, channels=2):
    path=Path(path); path.parent.mkdir(parents=True,exist_ok=True)
    frame=int(amp).to_bytes(2,"little",signed=True)*channels
    with wave.open(str(path),"wb") as w:
        w.setnchannels(channels); w.setsampwidth(2); w.setframerate(rate)
        remain=int(seconds*rate)
        while remain:
            n=min(remain,4096); w.writeframes(frame*n); remain-=n

def file_rec(root, rel): return {"path":str(rel).replace("\\","/"),"sha256":sha(root/rel)}

def make_fixture(root, fid, group, seconds, genre, hard, amp, prod):
    base=Path("fixtures")/fid; mix=base/"mix.wav"; write_wav(root/mix,seconds,amp)
    roles=["vocals","drums","bass","other"]
    m={"schema_version":1,"fixture_id":fid,
       "class":"PROJECT_OWNED_REAL_MULTITRACK" if group=="G1" else "RIGHTS_CLEARED_REAL_REFERENCE",
       "title_alias":"private-"+fid,"rights_record_id":"RIGHTS-"+fid,
       "rights_basis":"written license outside repository","rights_status":"VERIFIED",
       "redistribution_allowed":False,"commercial_engineering_use_allowed":True,
       "reference_service_submission_allowed":True,"real_recorded_music":True,"synthetic":False,
       "requested_roles":roles,"mixture":file_rec(root,mix),"duration_seconds":seconds,
       "sample_rate_hz":8000,"channels":2,"genre_bucket":genre,"hard_cases":list(hard),
       "notes":"private note"}
    if group=="G1":
        refs={}
        for i,role in enumerate(roles):
            rel=base/"refs"/f"{role}.wav"; write_wav(root/rel,seconds,amp+(i+1)*137)
            refs[role]=file_rec(root,rel)
        m["reference_stems"]=refs
    rel=Path("manifests")/f"{fid}.json"; (root/rel).parent.mkdir(parents=True,exist_ok=True)
    (root/rel).write_text(json.dumps(m,indent=2,sort_keys=True)+"\n")
    return rel, prod

def policy():
    return {"schema_version":1,"policy_id":"test-policy-v1",
      "minimum_fixture_count_by_group":{"G1":2,"G2":2},
      "minimum_distinct_genres":3,"minimum_distinct_genres_by_group":{"G1":2,"G2":2},
      "duration_buckets":[{"id":"short","min_seconds":0.001,"max_seconds_exclusive":1.5},
                          {"id":"medium","min_seconds":1.5,"max_seconds_exclusive":2.5},
                          {"id":"long","min_seconds":2.5,"max_seconds_exclusive":None}],
      "required_duration_buckets":["short","medium","long"],
      "minimum_duration_buckets_by_group":{"G1":2,"G2":2},
      "required_role_sets":[{"id":"free-core-4stem","roles":["vocals","drums","bass","other"],"groups":["G1","G2"]}],
      "minimum_distinct_production_buckets":3,
      "minimum_distinct_production_buckets_by_group":{"G1":2,"G2":2},
      "required_production_buckets":["studio","live","acoustic"],
      "required_hard_cases":["dense_mix","reverb"],"minimum_distinct_hard_cases":3,
      "reference_submission_required_groups":["G2"],
      "metadata_duration_tolerance_ms":1.0,"g1_reference_alignment_tolerance_ms":1.0,
      "reject_duplicate_mixture_audio":True}

@contextmanager
def corpus():
    t=tempfile.TemporaryDirectory(); root=Path(t.name)
    specs=[("G1-A","G1",1.0,"rock",["dense_mix"],1000,"studio"),
           ("G1-B","G1",3.0,"jazz",["reverb"],2000,"live"),
           ("G2-A","G2",2.0,"pop",["sparse_arrangement"],3000,"acoustic"),
           ("G2-B","G2",3.0,"electronic",["dense_mix","reverb"],4000,"live")]
    entries=[]
    for args in specs:
        rel,prod=make_fixture(root,*args)
        entries.append({"manifest_path":str(rel),"manifest_sha256":sha(root/rel),
                        "expected_group":args[1],"production_bucket":prod})
    index={"schema_version":1,"corpus_id":"CORPUS-A","corpus_revision":"r1","fixtures":entries}
    try: yield root,index,policy()
    finally: t.cleanup()

def load_manifest(root,index,i):
    p=root/index["fixtures"][i]["manifest_path"]; return p,json.loads(p.read_text())

def save_manifest(root,index,i,m,refresh=True):
    p=root/index["fixtures"][i]["manifest_path"]; p.write_text(json.dumps(m,indent=2,sort_keys=True)+"\n")
    if refresh:index["fixtures"][i]["manifest_sha256"]=sha(p)

class GoldenCorpusIntakeTests(unittest.TestCase):
    def assert_code(self, code, fn):
        with self.assertRaises(Exception) as cm: fn()
        self.assertEqual(getattr(cm.exception,"code",None),code,repr(cm.exception))

    def test_valid_lock_privacy_and_order_independence(self):
        with corpus() as (root,index,p):
            a=validate_golden_corpus(root=root,index=index,policy=p)
            self.assertEqual(a["intake_state"],"READY_FOR_HQ_GOLDEN_GATE")
            text=json.dumps(a)
            for forbidden in ("private-G1-A","RIGHTS-G1-A","fixtures/","private note"): self.assertNotIn(forbidden,text)
            lock=a["corpus_lock_sha256"]; index["fixtures"].reverse()
            self.assertEqual(lock,validate_golden_corpus(root=root,index=index,policy=p)["corpus_lock_sha256"])
            p["policy_id"]="test-policy-v2"
            self.assertNotEqual(lock,validate_golden_corpus(root=root,index=index,policy=p)["corpus_lock_sha256"])

    def test_rights_real_audio_and_lock_fail_closed(self):
        cases=[
          ("GOLDEN_MANIFEST_HASH_MISMATCH",lambda r,i,p: i["fixtures"][0].update(manifest_sha256="0"*64)),
          ("EVAL_HASH_MISMATCH",lambda r,i,p: self._mutate(r,i,0,lambda m:m["mixture"].update(sha256="0"*64))),
          ("EVAL_REAL_FIXTURE_FALSE",lambda r,i,p:self._mutate(r,i,2,lambda m:m.update(real_recorded_music=False))),
          ("EVAL_RIGHTS_COMMERCIAL_DENIED",lambda r,i,p:self._mutate(r,i,2,lambda m:m.update(commercial_engineering_use_allowed=False))),
          ("EVAL_REFERENCE_SUBMISSION_DENIED",lambda r,i,p:self._mutate(r,i,2,lambda m:m.update(reference_service_submission_allowed=False))),
          ("GOLDEN_GROUP_CLASS_MISMATCH",lambda r,i,p:i["fixtures"][0].update(expected_group="G2")),
          ("EVAL_REFERENCE_STEM_MISSING",lambda r,i,p:self._mutate(r,i,0,lambda m:m["reference_stems"].pop("vocals"))),
        ]
        for code,mut in cases:
            with self.subTest(code=code), corpus() as (root,index,p):
                mut(root,index,p); self.assert_code(code,lambda:validate_golden_corpus(root=root,index=index,policy=p))

    def test_duplicate_audio_and_identity_fail_closed(self):
        with corpus() as (root,index,p):
            _,m2=load_manifest(root,index,2); _,m3=load_manifest(root,index,3)
            m3["mixture"]=copy.deepcopy(m2["mixture"]);m3["duration_seconds"]=m2["duration_seconds"]
            save_manifest(root,index,3,m3)
            self.assert_code("GOLDEN_MIXTURE_HASH_DUPLICATE",lambda:validate_golden_corpus(root=root,index=index,policy=p))
        with corpus() as (root,index,p):
            _,m0=load_manifest(root,index,0);_,m1=load_manifest(root,index,1)
            m1["fixture_id"]=m0["fixture_id"];save_manifest(root,index,1,m1)
            self.assert_code("GOLDEN_FIXTURE_ID_DUPLICATE",lambda:validate_golden_corpus(root=root,index=index,policy=p))
        with corpus() as (root,index,p):
            _,m=load_manifest(root,index,0);m["reference_stems"]["drums"]=copy.deepcopy(m["reference_stems"]["vocals"]);save_manifest(root,index,0,m)
            self.assert_code("GOLDEN_G1_REFERENCE_HASH_DUPLICATE",lambda:validate_golden_corpus(root=root,index=index,policy=p))

    def test_audio_metadata_alignment_fail_closed(self):
        cases=[("GOLDEN_MIX_SAMPLE_RATE_MISMATCH",lambda m:m.update(sample_rate_hz=16000)),
               ("GOLDEN_MIX_CHANNEL_MISMATCH",lambda m:m.update(channels=1)),
               ("GOLDEN_MIX_DURATION_MISMATCH",lambda m:m.update(duration_seconds=2.1))]
        for code,mut in cases:
            with self.subTest(code=code), corpus() as (root,index,p):
                _,m=load_manifest(root,index,2);mut(m);save_manifest(root,index,2,m)
                self.assert_code(code,lambda:validate_golden_corpus(root=root,index=index,policy=p))
        for code,rate,ch,seconds in [
            ("GOLDEN_G1_REFERENCE_SAMPLE_RATE_MISMATCH",16000,2,1.0),
            ("GOLDEN_G1_REFERENCE_CHANNEL_MISMATCH",8000,1,1.0),
            ("GOLDEN_G1_REFERENCE_DURATION_MISMATCH",8000,2,1.1)]:
            with self.subTest(code=code), corpus() as (root,index,p):
                _,m=load_manifest(root,index,0); rec=m["reference_stems"]["vocals"]; path=root/rec["path"]
                write_wav(path,seconds,1137,rate,ch); rec["sha256"]=sha(path);save_manifest(root,index,0,m)
                self.assert_code(code,lambda:validate_golden_corpus(root=root,index=index,policy=p))

    def test_coverage_fail_closed(self):
        mutations=[
          ("GOLDEN_COVERAGE_GROUP_COUNT",lambda r,i,p:i.update(fixtures=[e for e in i["fixtures"] if e["expected_group"]!="G1"]+[i["fixtures"][0]])),
          ("GOLDEN_COVERAGE_GENRE_GROUP",lambda r,i,p:[self._mutate(r,i,x,lambda m:m.update(genre_bucket="rock")) for x in (0,1)]),
          ("GOLDEN_COVERAGE_DURATION_GROUP",lambda r,i,p:p["minimum_duration_buckets_by_group"].update(G2=3)),
          ("GOLDEN_COVERAGE_PRODUCTION_REQUIRED",lambda r,i,p:p["required_production_buckets"].append("broadcast")),
          ("GOLDEN_COVERAGE_PRODUCTION_GROUP",lambda r,i,p:(i["fixtures"][0].update(production_bucket="studio"),i["fixtures"][1].update(production_bucket="studio"))),
          ("GOLDEN_COVERAGE_ROLE_SET",lambda r,i,p:p["required_role_sets"].append({"id":"advanced","roles":["vocals","guitar"],"groups":["G2"]})),
          ("GOLDEN_COVERAGE_HARD_CASE_REQUIRED",lambda r,i,p:p["required_hard_cases"].append("crowd_noise")),
        ]
        for code,mut in mutations:
            with self.subTest(code=code), corpus() as (root,index,p):
                mut(root,index,p); self.assert_code(code,lambda:validate_golden_corpus(root=root,index=index,policy=p))

    def test_schema_path_and_symlink_fail_closed(self):
        with corpus() as (root,index,p):
            index["unexpected"]="x"; self.assert_code("GOLDEN_SCHEMA_UNKNOWN_FIELD",lambda:validate_golden_corpus(root=root,index=index,policy=p))
        with corpus() as (root,index,p):
            p["unexpected"]="x"; self.assert_code("GOLDEN_SCHEMA_UNKNOWN_FIELD",lambda:validate_golden_corpus(root=root,index=index,policy=p))
        with corpus() as (root,index,p):
            index["fixtures"][0]["manifest_path"]="../outside.json"
            self.assert_code("GOLDEN_PATH_UNSAFE",lambda:validate_golden_corpus(root=root,index=index,policy=p))
        with corpus() as (root,index,p):
            original=root/index["fixtures"][0]["manifest_path"]; link=root/"manifests"/"link.json"
            try: os.symlink(original.name,link)
            except OSError: self.skipTest("symlink unavailable")
            index["fixtures"][0].update(manifest_path="manifests/link.json",manifest_sha256=sha(original))
            self.assert_code("GOLDEN_SYMLINK_FORBIDDEN",lambda:validate_golden_corpus(root=root,index=index,policy=p))

    def test_policy_duration_validation(self):
        with corpus() as (root,index,p):
            p["duration_buckets"][1]["min_seconds"]=1.0
            self.assert_code("GOLDEN_DURATION_BUCKET_OVERLAP",lambda:validate_golden_corpus(root=root,index=index,policy=p))
        with corpus() as (root,index,p):
            p["duration_buckets"][0]["max_seconds_exclusive"]=None
            self.assert_code("GOLDEN_DURATION_BUCKET_AFTER_OPEN",lambda:validate_golden_corpus(root=root,index=index,policy=p))
        with corpus() as (root,index,p):
            p["required_duration_buckets"].append("undefined")
            self.assert_code("GOLDEN_POLICY_DURATION_UNKNOWN",lambda:validate_golden_corpus(root=root,index=index,policy=p))

    def test_files_api_cli_and_stable_error_output(self):
        with corpus() as (root,index,p):
            (root/"index.json").write_text(json.dumps(index));(root/"policy.json").write_text(json.dumps(p))
            report=validate_golden_corpus_files(root=root,index_path="index.json",policy_path="policy.json")
            out=root/"report.json";self.assertEqual(report["intake_state"],"READY_FOR_HQ_GOLDEN_GATE")
            self.assertEqual(main(["--root",str(root),"--index","index.json","--policy","policy.json","--out",str(out)]),0)
            self.assertTrue(out.is_file())
        with corpus() as (root,index,p):
            p["unexpected"]="/Users/private/song.wav";(root/"index.json").write_text(json.dumps(index));(root/"policy.json").write_text(json.dumps(p))
            old=sys.stderr;buf=io.StringIO();sys.stderr=buf
            try: rc=main(["--root",str(root),"--index","index.json","--policy","policy.json","--out",str(root/"x.json")])
            finally: sys.stderr=old
            self.assertEqual(rc,2);self.assertEqual(buf.getvalue().strip(),"GOLDEN_SCHEMA_UNKNOWN_FIELD");self.assertNotIn("/Users",buf.getvalue())

    def _mutate(self,root,index,i,fn):
        _,m=load_manifest(root,index,i);fn(m);save_manifest(root,index,i,m)

if __name__=="__main__":
    unittest.main()
