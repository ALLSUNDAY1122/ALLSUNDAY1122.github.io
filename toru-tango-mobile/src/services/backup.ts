import * as DocumentPicker from 'expo-document-picker';
import * as FileSystem from 'expo-file-system/legacy';
import * as Sharing from 'expo-sharing';
import type { BackupData, Card, StudyHistory } from '@/src/types';
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

  return {
    version: 1,
    exportedAt:
      typeof data.exportedAt === 'string' ? data.exportedAt : new Date().toISOString(),
    cards: data.cards,
    history: data.history
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
