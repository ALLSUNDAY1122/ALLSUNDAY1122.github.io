import * as DocumentPicker from 'expo-document-picker';
import * as FileSystem from 'expo-file-system/legacy';
import * as Sharing from 'expo-sharing';
import type { BackupData, Card, QuestionCandidate, StudyHistory } from '@/src/types';
import { toDateKey } from '@/src/utils/data';

function isCard(value: unknown): value is Card {
  if (!value || typeof value !== 'object') return false;
  const card = value as Record<string, unknown>;
  return (
    typeof card.id === 'string' &&
    typeof card.question === 'string' &&
    typeof card.answer === 'string' &&
    Number.isFinite(card.correct) &&
    Number.isFinite(card.wrong) &&
    (card.lastStudiedAt === null || typeof card.lastStudiedAt === 'string') &&
    typeof card.createdAt === 'string' &&
    typeof card.updatedAt === 'string'
  );
}

function isHistory(value: unknown): value is StudyHistory {
  if (!value || typeof value !== 'object') return false;
  const history = value as Record<string, unknown>;
  return (
    typeof history.id === 'string' &&
    typeof history.cardId === 'string' &&
    typeof history.answeredAt === 'string' &&
    typeof history.dateKey === 'string' &&
    typeof history.correct === 'boolean'
  );
}

function normalizeDecks(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return [...new Set(
    value
      .filter((item): item is string => typeof item === 'string')
      .map((item) => item.trim())
      .filter(Boolean)
  )];
}

function normalizeStudyDays(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return [...new Set(
    value
      .filter((item): item is string => typeof item === 'string')
      .map((item) => item.trim())
      .filter((item) => /^\d{4}-\d{2}-\d{2}$/.test(item))
  )].sort();
}

export function validateBackup(value: unknown): BackupData {
  if (!value || typeof value !== 'object') throw new Error('INVALID_BACKUP');
  const data = value as Partial<BackupData>;
  if (data.version !== 1) throw new Error('UNSUPPORTED_BACKUP_VERSION');
  if (!Array.isArray(data.cards) || !data.cards.every(isCard)) {
    throw new Error('INVALID_CARDS');
  }
  if (!Array.isArray(data.history) || !data.history.every(isHistory)) {
    throw new Error('INVALID_HISTORY');
  }

  const cardIds = new Set(data.cards.map((card) => card.id));
  if (data.history.some((entry) => !cardIds.has(entry.cardId))) {
    throw new Error('ORPHAN_HISTORY');
  }

  const decks = normalizeDecks(data.decks);
  const studyDays = normalizeStudyDays(data.studyDays);

  return {
    version: 1,
    exportedAt:
      typeof data.exportedAt === 'string' ? data.exportedAt : new Date().toISOString(),
    cards: data.cards,
    history: data.history,
    ...(decks.length ? { decks } : {}),
    ...(studyDays.length ? { studyDays } : {})
  };
}

export async function shareBackup(data: BackupData): Promise<void> {
  if (!FileSystem.cacheDirectory) throw new Error('CACHE_UNAVAILABLE');
  const filename = `toru-tango-${toDateKey()}.json`;
  const uri = `${FileSystem.cacheDirectory}${filename}`;
  await FileSystem.writeAsStringAsync(uri, JSON.stringify(data, null, 2), {
    encoding: FileSystem.EncodingType.UTF8
  });

  if (!(await Sharing.isAvailableAsync())) throw new Error('SHARING_UNAVAILABLE');
  await Sharing.shareAsync(uri, {
    mimeType: 'application/json',
    dialogTitle: '撮る単語帳のバックアップを保存'
  });
}

export async function pickBackup(): Promise<BackupData | null> {
  const result = await DocumentPicker.getDocumentAsync({
    type: 'application/json',
    copyToCacheDirectory: true,
    multiple: false
  });

  if (result.canceled) return null;
  const asset = result.assets[0];
  if (!asset) throw new Error('BACKUP_NOT_SELECTED');

  const text = await FileSystem.readAsStringAsync(asset.uri, {
    encoding: FileSystem.EncodingType.UTF8
  });
  return validateBackup(JSON.parse(text));
}

function csvCell(value: string): string {
  const normalized = value.replace(/\r?\n/g, ' ');
  return /[",]/.test(normalized) ? `"${normalized.replace(/"/g, '""')}"` : normalized;
}

export async function shareCardsCsv(cards: Card[]): Promise<void> {
  if (!FileSystem.cacheDirectory) throw new Error('CACHE_UNAVAILABLE');
  const filename = `toru-tango-cards-${toDateKey()}.csv`;
  const uri = `${FileSystem.cacheDirectory}${filename}`;
  const content = [
    '表,裏,メモ',
    ...cards.map((card) => [card.question, card.answer, card.note ?? ''].map(csvCell).join(','))
  ].join('\n');
  await FileSystem.writeAsStringAsync(uri, `\uFEFF${content}`, {
    encoding: FileSystem.EncodingType.UTF8
  });
  if (!(await Sharing.isAvailableAsync())) throw new Error('SHARING_UNAVAILABLE');
  await Sharing.shareAsync(uri, { mimeType: 'text/csv', dialogTitle: 'カードCSVを保存' });
}

function parseCsvLine(line: string): string[] {
  const cells: string[] = [];
  let cell = '';
  let quoted = false;
  for (let index = 0; index < line.length; index += 1) {
    const character = line[index];
    if (character === '"') {
      if (quoted && line[index + 1] === '"') {
        cell += '"';
        index += 1;
      } else {
        quoted = !quoted;
      }
    } else if (character === ',' && !quoted) {
      cells.push(cell.trim());
      cell = '';
    } else {
      cell += character;
    }
  }
  cells.push(cell.trim());
  return cells;
}

export async function pickCardsCsv(): Promise<QuestionCandidate[] | null> {
  const result = await DocumentPicker.getDocumentAsync({
    type: ['text/csv', 'text/*'],
    copyToCacheDirectory: true,
    multiple: false
  });
  if (result.canceled) return null;
  const asset = result.assets[0];
  if (!asset) throw new Error('CSV_NOT_SELECTED');
  const text = (await FileSystem.readAsStringAsync(asset.uri, {
    encoding: FileSystem.EncodingType.UTF8
  })).replace(/^\uFEFF/, '');
  return text
    .split(/\r?\n/)
    .map(parseCsvLine)
    .slice(1)
    .map(([question, answer]) => ({ question: question ?? '', answer: answer ?? '' }))
    .filter((candidate) => candidate.question.trim() && candidate.answer.trim());
}