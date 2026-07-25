'use strict';

const fs = require('fs');
const path = require('path');

const ROOT = process.cwd();
const BASE = path.join(ROOT, 'jichitai-compare');
const PREFECTURE_CODES = ['16', '17', '18', '21', '22', '23', '24', '25', '26', '27', '28', '29', '30'];
const SERVICES = [
  'childMedical',
  'sickChildCare',
  'childcareFee',
  'schoolMeals',
  'postpartumCare',
  'temporaryChildcare',
  'housingSupport',
  'bulkyWaste',
  'disasterPrevention',
];
const COMPLETE_SERVICE_STATUSES = new Set(['verified', 'unavailable']);

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, 'utf8'));
}

function exists(filePath) {
  return fs.existsSync(filePath);
}

function sortedUnique(values) {
  return [...new Set(values.filter(Boolean))].sort();
}

function sameStringSet(a, b) {
  const aa = sortedUnique(a);
  const bb = sortedUnique(b);
  return aa.length === bb.length && aa.every((value, index) => value === bb[index]);
}

function stable(value) {
  if (Array.isArray(value)) return value.map(stable);
  if (value && typeof value === 'object') {
    return Object.fromEntries(Object.keys(value).sort().map((key) => [key, stable(value[key])]));
  }
  return value;
}

function sameJson(a, b) {
  return JSON.stringify(stable(a)) === JSON.stringify(stable(b));
}

function stringify(value) {
  try {
    return JSON.stringify(value);
  } catch {
    return String(value);
  }
}

function writeJson(relativePath, data) {
  const filePath = path.join(BASE, relativePath);
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, `${JSON.stringify(data, null, 2)}\n`, 'utf8');
}

function generatedMunicipalities(document) {
  if (Array.isArray(document)) return document;
  if (document && Array.isArray(document.municipalities)) return document.municipalities;
  if (document && document.data && Array.isArray(document.data.municipalities)) return document.data.municipalities;
  if (document && typeof document === 'object') {
    return Object.values(document).filter((value) => value && typeof value === 'object' && /^\d{5}$/.test(String(value.code || value.municipalityCode || '')));
  }
  return [];
}

const generatedPath = path.join(BASE, 'data/generated/municipalities.json');
const generatedDocument = readJson(generatedPath);
const generatedByCode = new Map(
  generatedMunicipalities(generatedDocument).map((item) => [String(item.code || item.municipalityCode), item]),
);

const structuralErrors = [];
const consistencyMismatches = [];
const warnings = [];
const candidates = {
  fy2026AnyoneDaycareOmission: [],
  generalHousingMisclassification: [],
  statusWithoutCurrentEvidence: [],
  schoolMealsScopeConfusion: [],
  wideAreaUseOmission: [],
  oldFiscalEvidence: [],
};
const spotChecks = [];
const municipalitySummaries = [];
let checkedServiceCount = 0;

for (const prefectureCode of PREFECTURE_CODES) {
  const municipalityDir = path.join(BASE, 'data/municipalities', prefectureCode);
  if (!exists(municipalityDir)) {
    structuralErrors.push({ type: 'missing_prefecture_directory', prefectureCode });
    continue;
  }

  const files = fs.readdirSync(municipalityDir)
    .filter((name) => /^\d{5}\.json$/.test(name))
    .sort();

  const sampleIndexes = sortedUnique([0, Math.floor((files.length - 1) / 2), files.length - 1].filter((index) => index >= 0));
  for (const sampleIndex of sampleIndexes) {
    const code = files[sampleIndex]?.replace(/\.json$/, '');
    if (code) spotChecks.push({ prefectureCode, municipalityCode: code, status: 'pending_official_manual_review' });
  }

  for (const filename of files) {
    const municipalityPath = path.join(municipalityDir, filename);
    const municipality = readJson(municipalityPath);
    const code = filename.replace(/\.json$/, '');
    const services = municipality.services || {};
    const serviceKeys = Object.keys(services).sort();
    checkedServiceCount += serviceKeys.length;

    const summary = {
      code,
      name: municipality.name || null,
      prefectureCode,
      verified: 0,
      unavailable: 0,
      incomplete: 0,
    };

    if (String(municipality.code) !== code) {
      structuralErrors.push({ type: 'municipality_code_mismatch', code, storedCode: municipality.code, path: path.relative(ROOT, municipalityPath) });
    }
    if (String(municipality.prefectureCode) !== prefectureCode) {
      structuralErrors.push({ type: 'prefecture_code_mismatch', code, prefectureCode, storedPrefectureCode: municipality.prefectureCode });
    }
    if (!municipality.name) {
      structuralErrors.push({ type: 'missing_municipality_name', code });
    }
    if (!sameStringSet(serviceKeys, SERVICES)) {
      structuralErrors.push({ type: 'service_key_mismatch', code, expected: SERVICES, actual: serviceKeys });
    }

    const primarySourceUrls = [];
    for (const serviceKey of SERVICES) {
      const service = services[serviceKey];
      if (!service) continue;
      const status = service.status;
      if (status === 'verified') summary.verified += 1;
      else if (status === 'unavailable') summary.unavailable += 1;
      else summary.incomplete += 1;

      if (service.source?.url) primarySourceUrls.push(service.source.url);
      if (!service.source?.url) {
        warnings.push({ type: 'missing_primary_source', code, service: serviceKey, status });
        if (status === 'verified') {
          candidates.statusWithoutCurrentEvidence.push({ code, name: municipality.name, prefectureCode, service: serviceKey, reason: 'verified_without_primary_source' });
        }
      }
      if (!service.source?.checkedAt) {
        warnings.push({ type: 'missing_checked_at', code, service: serviceKey, status });
      }

      const text = stringify(service);
      const hasAnyoneDaycare = /こども誰でも通園|誰でも通園|乳児等通園支援/.test(text);
      if (serviceKey === 'temporaryChildcare' && status === 'verified' && /一時預かり|一時保育/.test(text) && !hasAnyoneDaycare) {
        candidates.fy2026AnyoneDaycareOmission.push({ code, name: municipality.name, prefectureCode, service: serviceKey, reason: 'ordinary_temporary_childcare_only' });
      }

      if (serviceKey === 'housingSupport' && status === 'verified') {
        const hasGeneralProgram = /住居確保給付|空き家|耐震|省エネ|太陽光|蓄電|新婚|若者|移住|定住|住宅取得|リフォーム|改修/.test(text);
        const hasChildSpecific = /子育て世帯|子育て家庭|18歳未満|高校生以下|中学生以下|小学生以下|妊婦|妊娠|児童.*加算|子ども.*加算|こども.*加算|多子|三世代/.test(text);
        if (hasGeneralProgram && !hasChildSpecific) {
          candidates.generalHousingMisclassification.push({ code, name: municipality.name, prefectureCode, service: serviceKey, reason: 'general_program_without_child_specific_condition' });
        }
      }

      if (status === 'unavailable' && ['sickChildCare', 'postpartumCare', 'temporaryChildcare'].includes(serviceKey)) {
        candidates.wideAreaUseOmission.push({ code, name: municipality.name, prefectureCode, service: serviceKey, reason: 'unavailable_requires_wide_area_check' });
      }

      if (serviceKey === 'schoolMeals') {
        const hasAidOnly = /就学援助/.test(text);
        const hasGeneralBurden = /無償|無料|保護者負担|一般世帯|月額|年額|1食|一食|\d[,\d]*円/.test(text);
        if (hasAidOnly && !hasGeneralBurden) {
          candidates.schoolMealsScopeConfusion.push({ code, name: municipality.name, prefectureCode, service: serviceKey, reason: 'financial_aid_without_general_household_burden' });
        }
      }

      if (/2023|2024|令和5年度|令和6年度/.test(text)) {
        candidates.oldFiscalEvidence.push({ code, name: municipality.name, prefectureCode, service: serviceKey, reason: 'old_fiscal_year_text_present' });
      }

      if (status === 'unavailable' && (!service.details || Object.keys(service.details).length === 0)) {
        candidates.statusWithoutCurrentEvidence.push({ code, name: municipality.name, prefectureCode, service: serviceKey, reason: 'unavailable_without_explanatory_details' });
      }
    }

    if (summary.incomplete === 0 && municipality.status !== 'verified') {
      structuralErrors.push({ type: 'top_level_status_mismatch', code, expected: 'verified', actual: municipality.status });
    }

    const taskPath = path.join(BASE, 'operations/tasks', `${code}.json`);
    if (!exists(taskPath)) {
      structuralErrors.push({ type: 'missing_task', code });
    } else {
      const task = readJson(taskPath);
      if (String(task.municipalityCode) !== code) structuralErrors.push({ type: 'task_code_mismatch', code, actual: task.municipalityCode });
      if (String(task.prefectureCode) !== prefectureCode) structuralErrors.push({ type: 'task_prefecture_mismatch', code, actual: task.prefectureCode });
      if (task.municipalityName !== municipality.name) structuralErrors.push({ type: 'task_name_mismatch', code, municipalityName: municipality.name, taskName: task.municipalityName });
      if (task.status !== 'merged') structuralErrors.push({ type: 'task_status_not_merged', code, actual: task.status });
      if (Number(task.nextServiceIndex) !== 9) structuralErrors.push({ type: 'task_next_service_index_mismatch', code, actual: task.nextServiceIndex });
      if (!sameStringSet(task.completedServices || [], SERVICES)) structuralErrors.push({ type: 'task_completed_services_mismatch', code, actual: task.completedServices || [] });
      if (Number(task.verifiedCount) !== summary.verified) structuralErrors.push({ type: 'task_verified_count_mismatch', code, expected: summary.verified, actual: task.verifiedCount });
      if (Number(task.unavailableCount) !== summary.unavailable) structuralErrors.push({ type: 'task_unavailable_count_mismatch', code, expected: summary.unavailable, actual: task.unavailableCount });
      if (Number(task.researchingCount || 0) !== 0 || Number(task.needsMediumReviewCount || 0) !== 0) {
        structuralErrors.push({ type: 'task_unresolved_count_present', code, researchingCount: task.researchingCount, needsMediumReviewCount: task.needsMediumReviewCount });
      }
      if (!sameStringSet(task.officialSources || [], primarySourceUrls)) {
        structuralErrors.push({ type: 'task_official_sources_mismatch', code, expected: sortedUnique(primarySourceUrls), actual: sortedUnique(task.officialSources || []) });
      }
    }

    const generated = generatedByCode.get(code);
    if (!generated) {
      consistencyMismatches.push({ surface: 'generated_json', type: 'missing_municipality', code });
    } else {
      for (const field of ['code', 'prefectureCode', 'prefecture', 'name', 'officialUrl', 'status', 'summary']) {
        if (!sameJson(generated[field], municipality[field])) {
          consistencyMismatches.push({ surface: 'generated_json', type: 'field_mismatch', code, field, source: municipality[field], generated: generated[field] });
        }
      }
      if (!sameJson(generated.services, municipality.services)) {
        consistencyMismatches.push({ surface: 'generated_json', type: 'services_mismatch', code });
      }
    }

    const htmlPath = path.join(BASE, 'municipality', code, 'index.html');
    if (!exists(htmlPath)) {
      consistencyMismatches.push({ surface: 'static_page', type: 'missing_page', code });
    } else {
      const html = fs.readFileSync(htmlPath, 'utf8');
      const canonical = `https://allsunday1122.github.io/jichitai-compare/municipality/${code}/`;
      if (!html.includes(`<h1>${municipality.name}`) && !html.includes(municipality.name)) {
        consistencyMismatches.push({ surface: 'static_page', type: 'municipality_name_missing', code, name: municipality.name });
      }
      if (!html.includes(canonical)) {
        consistencyMismatches.push({ surface: 'static_page', type: 'canonical_missing_or_wrong', code, expected: canonical });
      }
      if (municipality.officialUrl && !html.includes(municipality.officialUrl)) {
        consistencyMismatches.push({ surface: 'static_page', type: 'official_url_missing', code, expected: municipality.officialUrl });
      }
      for (const serviceKey of SERVICES) {
        const service = services[serviceKey];
        if (service?.source?.url && !html.includes(service.source.url)) {
          consistencyMismatches.push({ surface: 'static_page', type: 'service_source_url_missing', code, service: serviceKey, expected: service.source.url });
        }
      }
    }

    municipalitySummaries.push(summary);
  }
}

for (const key of Object.keys(candidates)) {
  candidates[key].sort((a, b) => `${a.prefectureCode}-${a.code}-${a.service}`.localeCompare(`${b.prefectureCode}-${b.code}-${b.service}`));
}

const now = new Date().toISOString();
const result = {
  schemaVersion: '1.0.0',
  auditId: 'central-quality-cross-audit-20260725',
  generatedAt: now,
  sourceCommit: process.env.GITHUB_SHA || null,
  scope: {
    prefectureCodes: PREFECTURE_CODES,
    expectedMunicipalityCount: 409,
    checkedMunicipalityCount: municipalitySummaries.length,
    expectedServiceCount: 3681,
    checkedServiceCount,
  },
  structural: {
    errorCount: structuralErrors.length,
    warningCount: warnings.length,
    errors: structuralErrors,
    warnings,
  },
  consistency: {
    mismatchCount: consistencyMismatches.length,
  },
  candidateCounts: Object.fromEntries(Object.entries(candidates).map(([key, values]) => [key, values.length])),
  conclusion: structuralErrors.length === 0 && consistencyMismatches.length === 0
    ? 'machine_structural_and_repository_consistency_passed_official_review_candidates_pending'
    : 'machine_mismatches_detected_requires_review',
};

writeJson('operations/audits/central-quality-cross-audit-20260725.json', result);
writeJson('operations/audits/central-quality-cross-audit-candidates-20260725.json', {
  schemaVersion: '1.0.0',
  auditId: 'central-quality-cross-audit-candidates-20260725',
  generatedAt: now,
  policy: 'Candidates are not confirmed errors. Confirm against current official information before correction.',
  candidateCounts: result.candidateCounts,
  candidates,
});
writeJson('operations/audits/central-quality-cross-audit-spotchecks-20260725.json', {
  schemaVersion: '1.0.0',
  auditId: 'central-quality-cross-audit-spotchecks-20260725',
  generatedAt: now,
  selectionMethod: 'first, middle and last municipality code in each of 13 prefectures',
  minimumRequired: 39,
  selectedCount: spotChecks.length,
  priorityServices: ['temporaryChildcare', 'schoolMeals', 'sickChildCare', 'postpartumCare', 'housingSupport'],
  spotChecks,
});
writeJson('operations/audits/central-quality-four-surface-consistency-20260725.json', {
  schemaVersion: '1.0.0',
  auditId: 'central-quality-four-surface-consistency-20260725',
  generatedAt: now,
  checkedMunicipalityCount: municipalitySummaries.length,
  checkedServiceCount,
  mismatchCount: consistencyMismatches.length,
  mismatches: consistencyMismatches,
  note: 'Public HTTP verification is separate; this file checks repository source, task, generated JSON and static pages.',
});

console.log(JSON.stringify({
  checkedMunicipalityCount: municipalitySummaries.length,
  checkedServiceCount,
  structuralErrorCount: structuralErrors.length,
  consistencyMismatchCount: consistencyMismatches.length,
  candidateCounts: result.candidateCounts,
  spotCheckCount: spotChecks.length,
}, null, 2));
