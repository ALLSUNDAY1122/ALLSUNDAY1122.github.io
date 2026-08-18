import { useMemo, useState } from 'react';
import { Alert, Image, StyleSheet, Text, View } from 'react-native';
import * as ImagePicker from 'expo-image-picker';
import {
  isNativeOcrAvailable,
  recognizeText
} from '@/modules/toru-tango-ocr';
import {
  AppButton,
  ChoiceRow,
  commonStyles,
  Field,
  MutedText,
  Page,
  Section,
  colors
} from '@/src/components/ui';
import { useAppStore } from '@/src/context/AppStore';
import { generateAiQuestions } from '@/src/services/ai';
import {
  generateOcrAwareQuestions,
  repairOcrText
} from '@/src/services/ocrAwareQuestionGenerator';
import type {
  Difficulty,
  QuestionCandidate,
  QuestionType
} from '@/src/types';
import { isSameCard } from '@/src/utils/data';

type OcrRotation = 'auto' | 'left' | 'right';

function parseLines(text: string): QuestionCandidate[] {
  return text
    .split(/\n/)
    .map((line) => {
      const parts = line.split(/[｜|\t]/);
      return {
        question: (parts.shift() ?? '').trim(),
        answer: parts.join('｜').trim()
      };
    })
    .filter((candidate) => candidate.question && candidate.answer);
}

function formatLines(candidates: QuestionCandidate[]): string {
  return candidates
    .map((candidate) => `${candidate.question}｜${candidate.answer}`)
    .join('\n');
}

function formatSeconds(milliseconds: number): string {
  if (!milliseconds) return '';
  return `${(milliseconds / 1000).toFixed(1)}秒`;
}

function rotationValue(rotation: OcrRotation): number {
  if (rotation === 'left') return 270;
  if (rotation === 'right') return 90;
  return -1;
}

export default function CreateScreen() {
  const { cards, addCard, addCards } = useAppStore();
  const [sourceText, setSourceText] = useState('');
  const [type, setType] = useState<QuestionType>('mix');
  const [difficulty, setDifficulty] = useState<Difficulty>('normal');
  const [count, setCount] = useState<'5' | '10' | '15' | '20'>('10');
  const [generatedText, setGeneratedText] = useState('');
  const [generateStatus, setGenerateStatus] = useState('');
  const [generating, setGenerating] = useState(false);
  const [question, setQuestion] = useState('');
  const [answer, setAnswer] = useState('');
  const [bulkText, setBulkText] = useState('');
  const [imageUri, setImageUri] = useState<string | null>(null);
  const [ocrText, setOcrText] = useState('');
  const [ocrStatus, setOcrStatus] = useState('');
  const [ocrRunning, setOcrRunning] = useState(false);
  const [ocrRotation, setOcrRotation] = useState<OcrRotation>('auto');

  const candidateCount = useMemo(
    () => parseLines(generatedText).length,
    [generatedText]
  );
  const nativeOcrAvailable = isNativeOcrAvailable();

  const validateSource = (): string | null => {
    const text = sourceText.trim();
    if (text.length < 20) {
      Alert.alert('教材本文が短すぎます', '20文字以上入力してください。');
      return null;
    }
    const repaired = repairOcrText(text);
    setSourceText(repaired);
    return repaired;
  };

  const generateWithAi = async () => {
    const text = validateSource();
    if (!text) return;

    setGenerating(true);
    setGenerateStatus('OCR空白と罫線ノイズを整形し、Geminiで作問中…');
    try {
      const result = await generateAiQuestions({
        text,
        count: Number(count),
        type,
        difficulty
      });
      setGeneratedText(formatLines(result.questions));

      const usage = result.usage.totalTokens
        ? `入力${result.usage.inputTokens}・出力${result.usage.outputTokens}トークン`
        : 'トークン数未取得';
      const cleanup =
        result.quality.duplicateCount || result.quality.rejectedCount
          ? `重複${result.quality.duplicateCount}件・不適切${result.quality.rejectedCount}件を除外`
          : 'サーバー除外0件';
      const elapsed = formatSeconds(result.elapsedMs);

      setGenerateStatus(
        `OCR文字を整形後、${result.provider}（${result.model}）で${result.questions.length}枚作成。${cleanup}。${usage}${elapsed ? `・${elapsed}` : ''}。保存前に内容を確認してください。`
      );
    } catch (error) {
      const message = error instanceof Error ? error.message : '原因不明のエラー';
      setGeneratedText('');
      setGenerateStatus(
        `AI作問に失敗しました：${message}。端末内簡易作問へは自動切替していません。`
      );
    } finally {
      setGenerating(false);
    }
  };

  const generateLocally = () => {
    const text = validateSource();
    if (!text) return;

    const candidates = generateOcrAwareQuestions(
      text,
      Number(count),
      type,
      difficulty
    );
    setGeneratedText(formatLines(candidates));
    setGenerateStatus(
      candidates.length
        ? `OCR空白と罫線ノイズを整形し、端末内で${candidates.length}枚作成しました。AIは使用していません。`
        : 'OCR文字を整形しましたが、確認できる事実を抽出できませんでした。AI作問を使うか、認識結果を修正してください。'
    );
  };

  const removeDuplicates = () => {
    const accepted: QuestionCandidate[] = [];
    for (const candidate of parseLines(generatedText)) {
      if (cards.some((card) => isSameCard(card, candidate))) continue;
      if (accepted.some((item) => isSameCard(item, candidate))) continue;
      accepted.push(candidate);
    }
    setGeneratedText(formatLines(accepted));
    setGenerateStatus(`${accepted.length}枚に整理しました。`);
  };

  const saveGenerated = () => {
    const added = addCards(parseLines(generatedText));
    Alert.alert('追加結果', `${added}枚のカードを追加しました。`);
    if (added > 0) setGeneratedText('');
  };

  const saveDirect = () => {
    if (!addCard(question, answer)) {
      Alert.alert('追加できません', '未入力または同じカードが保存済みです。');
      return;
    }
    setQuestion('');
    setAnswer('');
  };

  const saveBulk = () => {
    const added = addCards(parseLines(bulkText));
    Alert.alert('追加結果', `${added}枚のカードを追加しました。`);
    if (added > 0) setBulkText('');
  };

  const selectPhoto = async (camera: boolean) => {
    const permission = camera
      ? await ImagePicker.requestCameraPermissionsAsync()
      : await ImagePicker.requestMediaLibraryPermissionsAsync();
    if (!permission.granted) {
      Alert.alert(
        '権限が必要です',
        camera ? 'カメラの利用を許可してください。' : '写真の利用を許可してください。'
      );
      return;
    }

    const result = camera
      ? await ImagePicker.launchCameraAsync({
          mediaTypes: ['images'],
          quality: 1
        })
      : await ImagePicker.launchImageLibraryAsync({
          mediaTypes: ['images'],
          quality: 1
        });

    if (!result.canceled) {
      setImageUri(result.assets[0].uri);
      setOcrText('');
      setOcrStatus('写真を選択しました。向きを確認して文字認識を実行してください。');
    }
  };

  const runOcr = async () => {
    if (!imageUri) {
      Alert.alert('写真がありません', '先に教材を撮影するか写真を選んでください。');
      return;
    }
    if (!nativeOcrAvailable) {
      Alert.alert(
        '開発ビルドが必要です',
        'Apple Vision OCRはExpo Goでは動作しません。EAS開発ビルドまたは本番ビルドで確認してください。'
      );
      return;
    }

    setOcrRunning(true);
    setOcrStatus('Apple Visionで日本語を認識しています…');
    try {
      const result = await recognizeText(imageUri, rotationValue(ocrRotation));
      const repaired = repairOcrText(result.text);
      if (repaired.length < 5) throw new Error('有効な文字を認識できませんでした。');
      setOcrText(repaired);
      setOcrStatus(
        `認識完了。採用した向きは${result.rotation}度です。結果を修正して教材本文へ送ってください。`
      );
    } catch (error) {
      setOcrText('');
      setOcrStatus(
        `文字認識に失敗しました：${error instanceof Error ? error.message : '原因不明のエラー'}`
      );
    } finally {
      setOcrRunning(false);
    }
  };

  const useOcrResult = () => {
    const repaired = repairOcrText(ocrText);
    if (repaired.length < 5) {
      Alert.alert('認識結果がありません', '文字認識を実行するか、認識結果を修正してください。');
      return;
    }
    setOcrText(repaired);
    setSourceText(repaired);
    setGenerateStatus('OCR結果を教材本文へ入れました。作問方法を選んでください。');
  };

  return (
    <Page>
      <Text style={commonStyles.title}>撮る単語帳</Text>
      <Text style={commonStyles.subtitle}>
        教材から表裏の単語カードを作り、両面を読み上げて学習します。
      </Text>

      <Section title="教材を撮る・文字を読む">
        <View style={commonStyles.row}>
          <AppButton label="撮影する" onPress={() => void selectPhoto(true)} />
          <AppButton
            label="写真を選ぶ"
            variant="secondary"
            onPress={() => void selectPhoto(false)}
          />
        </View>
        {imageUri ? <Image source={{ uri: imageUri }} style={styles.preview} /> : null}
        <Text style={styles.optionLabel}>文字の向き</Text>
        <ChoiceRow
          value={ocrRotation}
          onChange={setOcrRotation}
          options={[
            { value: 'auto', label: '自動' },
            { value: 'left', label: '左へ90°' },
            { value: 'right', label: '右へ90°' }
          ]}
        />
        <AppButton
          label={ocrRunning ? '文字認識中…' : '写真から文字を読む'}
          onPress={() => void runOcr()}
          disabled={ocrRunning || !imageUri}
        />
        <MutedText>
          正式iOS版はApple Visionを使用します。Expo Goではなく、EAS開発ビルドまたは本番ビルドで動作します。
        </MutedText>
        {ocrStatus ? <Text style={styles.status}>{ocrStatus}</Text> : null}
        {ocrText ? (
          <>
            <Field
              label="認識結果（編集可能）"
              multiline
              value={ocrText}
              onChangeText={setOcrText}
            />
            <AppButton label="認識結果を教材本文へ" onPress={useOcrResult} />
          </>
        ) : null}
      </Section>

      <Section title="教材から自動作問">
        <MutedText>
          当面はGemini 3.5 Flash-Liteを使用します。無料枠には利用上限があり、教材本文は作問のためGoogleのAPIへ送信されます。OCR由来の文字間空白と罫線ノイズは作問前に自動整形します。
        </MutedText>
        <Field
          label="教材本文"
          multiline
          value={sourceText}
          onChangeText={setSourceText}
          placeholder="教材本文を貼り付けてください"
        />
        <Text style={styles.optionLabel}>作問形式</Text>
        <ChoiceRow
          value={type}
          onChange={setType}
          options={[
            { value: 'mix', label: '混合' },
            { value: 'qa', label: '一問一答' },
            { value: 'cloze', label: '穴埋め' }
          ]}
        />
        <Text style={styles.optionLabel}>難易度</Text>
        <ChoiceRow
          value={difficulty}
          onChange={setDifficulty}
          options={[
            { value: 'easy', label: 'やさしい' },
            { value: 'normal', label: '標準' },
            { value: 'hard', label: '難しい' }
          ]}
        />
        <Text style={styles.optionLabel}>最大作成枚数</Text>
        <ChoiceRow
          value={count}
          onChange={setCount}
          options={['5', '10', '15', '20'].map((value) => ({
            value: value as '5' | '10' | '15' | '20',
            label: `${value}枚`
          }))}
        />
        <View style={commonStyles.row}>
          <AppButton
            label={generating ? 'Geminiで作問中…' : 'AIで作問（Gemini）'}
            onPress={() => void generateWithAi()}
            disabled={generating}
          />
          <AppButton
            label="端末内で簡易作問"
            variant="secondary"
            onPress={generateLocally}
            disabled={generating}
          />
        </View>
        {generateStatus ? <Text style={styles.status}>{generateStatus}</Text> : null}
        {generatedText ? (
          <>
            <Field
              label={`生成結果（${candidateCount}枚・表｜裏・編集可能）`}
              multiline
              value={generatedText}
              onChangeText={setGeneratedText}
            />
            <View style={commonStyles.row}>
              <AppButton label="重複を除く" variant="secondary" onPress={removeDuplicates} />
              <AppButton label="単語帳へ追加" onPress={saveGenerated} />
            </View>
          </>
        ) : null}
      </Section>

      <Section title="1枚ずつ作る">
        <Field label="表" value={question} onChangeText={setQuestion} />
        <Field label="裏" value={answer} onChangeText={setAnswer} />
        <AppButton label="単語帳へ追加" onPress={saveDirect} />
      </Section>

      <Section title="まとめて作成">
        <MutedText>1行に「表｜裏」の形式で入力してください。</MutedText>
        <Field
          label="カードデータ"
          multiline
          value={bulkText}
          onChangeText={setBulkText}
          placeholder={'日本の首都は？｜東京\n日本で最も高い山は？｜富士山'}
        />
        <AppButton label="まとめて追加" onPress={saveBulk} />
      </Section>
    </Page>
  );
}

const styles = StyleSheet.create({
  optionLabel: { color: colors.muted, fontSize: 13, fontWeight: '700' },
  status: {
    color: colors.text,
    backgroundColor: colors.background,
    borderRadius: 12,
    padding: 10,
    lineHeight: 20
  },
  preview: { width: '100%', height: 260, borderRadius: 12, resizeMode: 'contain' }
});
