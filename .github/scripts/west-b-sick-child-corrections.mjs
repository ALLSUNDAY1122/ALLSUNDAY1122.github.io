import fs from 'node:fs';
import path from 'node:path';

const root = path.join(process.cwd(), 'jichitai-compare');
const checkedAt = '2026-07-25';
const updatedAt = '2026-07-25T11:55:00+09:00';
const corrections = [
  {
    pref: '35', code: '35321', name: '和木町',
    municipalitySummary: '必須9制度を和木町公式情報で再確認し、全9制度をverifiedとして登録。',
    service: {
      status: 'verified',
      summary: '町内施設はないが、広島広域都市圏・山口県内の協定施設で病児・病後児保育を利用可能',
      details: {
        townFacility: '和木町内に病児・病後児保育施設はない',
        reciprocalUse: '広島広域都市圏構成市町および山口県内全市町の協定により協定先施設を相互利用できる',
        conditions: '対象、料金、予約方法、受入可否は利用する市町・施設ごとに確認が必要',
        application: '利用施設または担当課へ事前に問い合わせて登録・予約する'
      },
      source: { url: 'https://www.town.waki.lg.jp/soshiki/8/2056.html', checkedAt },
      additionalSources: [{ url: 'https://www.pref.yamaguchi.lg.jp/soshiki/51/18462.html', checkedAt }]
    }
  },
  {
    pref: '35', code: '35502', name: '阿武町',
    municipalitySummary: '必須9制度を阿武町公式情報で再確認し、8制度をverified、現行の詳細条件を確認できない産後ケアをunavailableとして登録。',
    service: {
      status: 'verified',
      summary: '山口県内全市町の相互利用協定により、県内の病児・病後児保育施設を利用可能',
      details: {
        reciprocalUse: '山口県内在住者は居住市町にかかわらず県内の病児・病後児対応型施設を利用できる',
        exampleFacility: '萩市の病児保育室「いるかのママ」など県内届出施設',
        exampleConditions: 'いるかのママは保育園等通園児から小学6年生まで。平日8時30分～17時30分、土曜8時30分～14時。1日1,500円、土曜1,000円',
        application: '施設ごとに条件が異なるため利用施設または町担当課へ事前確認・登録・予約する'
      },
      source: { url: 'https://www.pref.yamaguchi.lg.jp/soshiki/51/18462.html', checkedAt },
      additionalSources: [{ url: 'https://www.city.hagi.lg.jp/soshiki/35/1439.html', checkedAt }]
    }
  },
  {
    pref: '36', code: '36342', name: '神山町',
    municipalitySummary: '必須9制度を神山町公式情報で再確認し、8制度をverified、2026年度の詳細条件を確認できないこども誰でも通園制度をunavailableとして登録。',
    service: {
      status: 'verified',
      summary: '乳児・幼児・小学生が徳島市等の広域病児・病後児保育施設を利用可能',
      eligibility: { minAgeMonths: 0, maxAgeYears: 12 },
      details: {
        target: '神山町を含む広域利用対象市町に住む乳児・幼児または小学校就学児童で、病気中・回復期に家庭保育が困難な場合',
        broadUse: '徳島市、小松島市、勝浦町、佐那河内村、石井町、神山町、松茂町、北島町、藍住町、板野町、上板町の住民が対象施設を利用可能',
        fee: '施設・居住市町により異なる。徳島市施設の例は1日1,800円で世帯区分による減免あり',
        application: '予約、料金、必要書類は実施施設へ事前確認する'
      },
      source: { url: 'https://www.pref.tokushima.lg.jp/hagukumi/purpose-search/7300846/', checkedAt },
      additionalSources: [{ url: 'https://www.town.kamiyama.lg.jp/support/', checkedAt }]
    }
  },
  {
    pref: '42', code: '42214', name: '南島原市',
    municipalitySummary: '必須9制度を南島原市公式情報で再確認し、全9制度をverifiedとして登録。',
    service: {
      status: 'verified',
      summary: '島原市の病児保育オリーブを広域利用し、平日・土曜に病児を受け入れ',
      details: {
        facility: '病児保育オリーブ（うちだキッズクリニック内）',
        target: '南島原市に住所があり、入院治療を必要とせず症状の急変が認められない病児',
        hours: '月曜～金曜8時30分～17時30分、土曜8時30分～16時30分',
        capacity: '6人',
        fee: '生活保護・市町村民税非課税世帯は無料、その他は1日2,000円、連続利用3日目から1日1,000円',
        limit: '1回の申請につき原則7日間まで連続利用可能',
        application: '事前登録、医療機関受診、原則利用日前日までの予約、利用当日の申込みが必要'
      },
      source: { url: 'https://www.city.minamishimabara.lg.jp/kiji0039904/index.html', checkedAt }
    }
  },
  {
    pref: '45', code: '45341', name: '三股町',
    municipalitySummary: '必須9制度を三股町・宮崎県公式情報で再確認し、全9制度をverifiedとして登録。',
    service: {
      status: 'verified',
      summary: '町内3施設で病児・病後児保育を実施し、ファミサポでも軽度病後児を預かり',
      details: {
        facilities: '稗田保育園 とっこのもり、畠中こども病児院、ソダツバ 保健室',
        currentList: '宮崎県の令和8年4月1日現在の実施施設一覧に町内3施設を掲載',
        familySupport: 'ファミリー・サポート・センターたんぽぽでも軽度の病後児を預かる',
        familySupportFee: '軽度病後児は基準額1時間800円、町助成後500円',
        familySupportPlace: 'まかせて会員宅または三股町子育て支援センター',
        application: '対象、料金、予約方法は各施設または町福祉課へ確認する'
      },
      source: { url: 'https://www.pref.miyazaki.lg.jp/kodomo-seisaku/kyoikukosodate/kodomo/20171215111303.html', checkedAt },
      additionalSources: [{ url: 'https://www.town.mimata.lg.jp/contents/37.html', checkedAt }]
    }
  },
  {
    pref: '45', code: '45382', name: '国富町',
    municipalitySummary: '必須9制度を国富町・宮崎県公式情報で再確認し、8制度をverified、2026年度学校給食費をunavailableとして登録。',
    service: {
      status: 'verified',
      summary: '町内2施設で病児・病後児保育を実施',
      details: {
        facilities: '太田原にじ色こども園 天使の家、もりながナーサリー',
        currentList: '宮崎県の令和8年4月1日現在の実施施設一覧に町内2施設を掲載',
        serviceTypes: '病気中または回復期で集団保育が困難な児童を施設で受け入れる',
        feeSupport: '宮崎県は市町村と連携して病児保育利用料無償化事業を実施',
        application: '対象、料金、必要書類、予約方法は各施設または国富町福祉課へ事前確認する'
      },
      source: { url: 'https://www.pref.miyazaki.lg.jp/kodomo-seisaku/kyoikukosodate/kodomo/20171215111303.html', checkedAt },
      additionalSources: [{ url: 'https://www.town.kunitomi.miyazaki.jp/main/health/children_welfare/page000354.html', checkedAt }]
    }
  }
];

for (const correction of corrections) {
  const sourcePath = path.join(root, 'data', 'municipalities', correction.pref, `${correction.code}.json`);
  const source = JSON.parse(fs.readFileSync(sourcePath, 'utf8'));
  source.services.sickChildCare = correction.service;
  source.summary = correction.municipalitySummary;
  source.updatedAt = checkedAt;
  fs.writeFileSync(sourcePath, JSON.stringify(source, null, 2) + '\n');

  const taskPath = path.join(root, 'operations', 'tasks', `${correction.code}.json`);
  const task = JSON.parse(fs.readFileSync(taskPath, 'utf8'));
  const services = Object.values(source.services ?? {});
  task.verifiedCount = services.filter((service) => service.status === 'verified').length;
  task.unavailableCount = services.filter((service) => service.status === 'unavailable').length;
  task.researchingCount = services.filter((service) => service.status === 'researching').length;
  task.needsMediumReviewCount = services.filter((service) => service.status === 'needs_medium_review').length;
  task.lastCheckedAt = checkedAt;
  task.lastUpdatedAt = updatedAt;
  task.lastUpdatedBy = '西日本調査班B';
  task.officialSources = services.flatMap((service) => [service.source?.url, ...(service.additionalSources ?? []).map((source) => source.url)]).filter(Boolean);
  task.notes = (Array.isArray(task.notes) ? task.notes : []).filter((note) => !note.includes('病児') && !note.includes('病後児'));
  task.notes.push(`病児保育横断監査で利用可能性を公式確認し、sickChildCareをunavailableからverifiedへ訂正。${correction.service.summary}`);
  fs.writeFileSync(taskPath, JSON.stringify(task, null, 2) + '\n');
}

const review = {
  schemaVersion: '1.0.0',
  reviewId: 'west-b-sick-child-crosscheck-review-20260725',
  auditId: 'west-b-sick-child-crosscheck-20260725',
  sessionId: 'west-b',
  reviewedAt: updatedAt,
  scope: { municipalityCount: 250, sickChildCareCount: 250, mechanicalCandidateCount: 38 },
  results: { confirmedStatusCorrectionCount: 6, correctedStatusCount: 6, retainedWithoutCorrectionCount: 32, unresolvedConfirmedErrorCount: 0 },
  corrections: corrections.map((item) => ({ code: item.code, name: item.name, service: 'sickChildCare', beforeStatus: 'unavailable', afterStatus: 'verified', summary: item.service.summary, primarySource: item.service.source.url })),
  retainedPolicy: '一般的な子育て一覧、計画書、ファミリーサポート一般預かりのみで病児・病後児の利用可能性を確認できない候補は保守的判定を維持。',
  conclusion: 'six_verified_unavailable_misclassifications_corrected'
};
fs.writeFileSync(path.join(root, 'operations', 'audits', 'west-b-sick-child-crosscheck-review-20260725.json'), JSON.stringify(review, null, 2) + '\n');

const checkpointPath = path.join(root, 'operations', 'control', 'session-checkpoints', 'west-b.json');
const checkpoint = JSON.parse(fs.readFileSync(checkpointPath, 'utf8'));
checkpoint.sickChildCareCrosscheck = {
  auditId: 'west-b-sick-child-crosscheck-20260725',
  reviewId: review.reviewId,
  auditedMunicipalityCount: 250,
  mechanicalCandidateCount: 38,
  confirmedCorrectionCount: 6,
  correctedCount: 6,
  unresolvedConfirmedErrorCount: 0,
  status: 'correction_branch_validated_pending_pr',
  correctionBranch: 'fix/west-b-sick-child-crosscheck-corrections-v2-20260725'
};
checkpoint.updatedAt = updatedAt;
fs.writeFileSync(checkpointPath, JSON.stringify(checkpoint, null, 2) + '\n');
