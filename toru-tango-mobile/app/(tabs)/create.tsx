import { useMemo, useState } from 'react';
import { Alert, Image, StyleSheet, Text, View } from 'react-native';
import * as ImagePicker from 'expo-image-picker';
import {
  isNativeOcrAvailable,
  recognizeText
} from '@/modules/toru-tango-ocr';
import {
  generateOnDeviceCards,
  getOnDeviceAIAvailability,
  isOnDeviceCardGenerationAvailable,
  type OnDeviceStudyCard
} from '@/modules/toru-tango-ondevice-ai';
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
import { recognizeWithGemini, type SelectedStudyImage } from '@/src/services/geminiOcr';
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
type OcrProvider = 'appleVision' | 'gemini';
type EditableOnDeviceCard = OnDeviceStudyCard & { selected: boolean };

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

function availabilityLabel(status: ReturnType<typeof getOnDeviceAIAvailability>): string {
  return {
    available: '端末内AIを利用可能',
    unsupportedOS: 'iOS 26未満（簡易作問を使用）',
    deviceNotEligible: '非対応端末（簡易作問を使用）',
    appleIntelligenceDisabled: 'Apple Intelligenceが無効（簡易作問を使用）',
    modelNotReady: 'モデル準備中（簡易作問を使用）',
    unavailable: '端末内AIを利用不可（簡易作問を使用）'
  }[status];
}

export default function CreateScreen() {
  const { cards, addCard, addCards } = useAppStore();
  const [sourceText, setSourceText] = useState('');
  const [deckName, setDeckName] = useState('メイン');
  const [type, setType] = useState<QuestionType>('mix');
  const [difficulty, setDifficulty] = useState<Difficulty>('normal');
  const [count, setCount] = useState<'5' | '10' | '15' | '20'>('10');
  const [generatedText, setGeneratedText] = useState('');
  const [generateStatus, setGenerateStatus] = useState('');
  const [generating, setGenerating] = useState(false);
  const [question, setQuestion] = useState('');
  const [answer, setAnswer] = useState('');
  const [bulkText, setBulkText] = useState('');
  const [images, setImages] = useState<SelectedStudyImage[]>([]);
  const [ocrText, setOcrText] = useState('');
  const [ocrStatus, setOcrStatus] = useState('');
  const [ocrRunning, setOcrRunning] = useState(false);
  const [ocrRotation, setOcrRotation] = useState<OcrRotation>('auto');
  const [ocrProvider, setOcrProvider] = useState<OcrProvider>('appleVision');
  const [onDeviceCards, setOnDeviceCards] = useState<EditableOnDeviceCard[]>([]);
  const [onDeviceGenerating, setOnDeviceGenerating] = useState(false);
  const [onDeviceStatus, setOnDeviceStatus] = useState('');
  const [onDeviceEngine, setOnDeviceEngine] = useState<
    'appleOnDeviceModel' | 'deterministicFallback' | null
  >(null);

  const candidateCount = useMemo(
    () => parseLines(generatedText).length,
    [generatedText]
  );
  const nativeOcrAvailable = isNativeOcrAvailable();
  const nativeOnDeviceAIAvailable = isOnDeviceCardGenerationAvailable();
  const onDeviceAvailability = getOnDeviceAIAvailability();
  const busy = generating || onDeviceGenerating;

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
    setOnDeviceCards([]);
    setOnDeviceStatus('');
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
    setOnDeviceCards([]);
    setOnDeviceStatus('');
    setGeneratedText(formatLines(candidates));
    setGenerateStatus(
      candidates.length
        ? `OCR空白と罫線ノイズを整形し、端末内で${candidates.length}枚作成しました。AIは使用していません。`
        : 'OCR文字を整形しましたが、確認できる事実を抽出できませんでした。AI作問を使うか、認識結果を修正してください。'
    );
  };

  const generateWithOnDeviceAI = async () => {
    if (onDeviceGenerating) return;
    const initialText = sourceText.trim() || ocrText.trim();
    if (initialText.length < 20) {
      Alert.alert(
        'OCR結果が短すぎます',
        '認識結果または教材本文を20文字以上に修正してください。'
      );
      return;
    }
    if (!nativeOnDeviceAIAvailable) {
      Alert.alert(
        '開発ビルドが必要です',
        '端末内AI作問はExpo Goでは動作しません。EAS開発ビルドまたは本番ビルドで確認してください。'
      );
      return;
    }

    const text = repairOcrText(initialText);
    setSourceText(text);
    setGeneratedText('');
    setGenerateStatus('');
    setOnDeviceGenerating(true);
    setOnDeviceStatus('iPhone内で作問しています…');
    try {
      const result = await generateOnDeviceCards({
        recognizedText: text,
        maximumCardCount: Number(count),
        difficulty,
        prohibitedQuestions: cards.map((card) => card.question)
      });
      setOnDeviceCards(result.cards.map((card) => ({ ...card, selected: true })));
      setOnDeviceEngine(result.engine);
      const method =
        result.engine === 'appleOnDeviceModel' ? '端末内AI' : '簡易作問';
      const notice = result.notices.length ? ` ${result.notices.join(' ')}` : '';
      setOnDeviceStatus(
        `${method}で${result.cards.length}枚作成しました。問題・答え・解説を確認して保存してください。${notice}`
      );
    } catch (error) {
      setOnDeviceCards([]);
      setOnDeviceEngine(null);
      setOnDeviceStatus(
        `端末内作問に失敗しました：${error instanceof Error ? error.message : '原因不明のエラー'}`
      );
    } finally {
      setOnDeviceGenerating(false);
    }
  };

  const updateOnDeviceCard = (
    id: string,
    field: 'question' | 'answer' | 'explanation',
    value: string
  ) => {
    setOnDeviceCards((current) =>
      current.map((card) => (card.id === id ? { ...card, [field]: value } : card))
    );
  };

  const toggleOnDeviceCard = (id: string) => {
    setOnDeviceCards((current) =>
      current.map((card) =>
        card.id === id ? { ...card, selected: !card.selected } : card
      )
    );
  };

  const removeOnDeviceCard = (id: string) => {
    setOnDeviceCards((current) => current.filter((card) => card.id !== id));
  };

  const saveOnDeviceCards = (saveAll = false) => {
    const targets = saveAll
      ? onDeviceCards
      : onDeviceCards.filter((card) => card.selected);
    if (!targets.length) {
      Alert.alert('保存対象がありません', '保存するカードを1枚以上選択してください。');
      return;
    }
    const added = addCards(
      targets.map((card) => ({ question: card.question, answer: card.answer })),
      deckName
    );
    Alert.alert('追加結果', `${added}枚のカードを追加しました。`);
    if (added > 0) {
      const savedIds = new Set(targets.map((card) => card.id));
      setOnDeviceCards((current) =>
        current.filter((card) => !savedIds.has(card.id))
      );
    }
  };

  const clearOcrResult = () => {
    setOcrText('');
    setOcrStatus('認識結果を消去しました。');
  };

  const retakePhoto = () => {
    setImages([]);
    setOcrText('');
    setOcrStatus('');
    void selectPhoto(true);
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
    const added = addCards(parseLines(generatedText), deckName);
    Alert.alert('追加結果', `${added}枚のカードを追加しました。`);
    if (added > 0) setGeneratedText('');
  };

  const saveDirect = () => {
    if (!addCard(question, answer, deckName)) {
      Alert.alert('追加できません', '未入力または同じカードが保存済みです。');
      return;
    }
    setQuestion('');
    setAnswer('');
  };

  const saveBulk = () => {
    const added = addCards(parseLines(bulkText), deckName);
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
          quality: 0.8
        })
      : await ImagePicker.launchImageLibraryAsync({
          mediaTypes: ['images'],
          quality: 0.8,
          allowsMultipleSelection: true,
          selectionLimit: 10,
          orderedSelection: true
        });

    if (!result.canceled) {
      const selected = result.assets.map((asset) => ({
        uri: asset.uri,
        mimeType: asset.mimeType
      }));
      setImages((current) => {
        const merged = [...current, ...selected];
        return merged.filter((image, index) => merged.findIndex((item) => item.uri === image.uri) === index).slice(0, 10);
      });
      setOcrText('');
      setOnDeviceCards([]);
      setOcrStatus(`${selected.length}枚の写真を追加しました。文字認識の方法を選んで実行してください。`);
    }
  };

  const removeImage = (uri: string) => {
    setImages((current) => current.filter((image) => image.uri !== uri));
  };

  const runAppleVisionOcr = async () => {
    if (!images.length) {
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
    setOcrStatus(`端末内OCRで${images.length}枚の日本語を認識しています…`);
    try {
      const recognized: string[] = [];
      let failed = 0;
      for (const image of images) {
        try {
          const result = await recognizeText(image.uri, rotationValue(ocrRotation));
          if (result.text.trim()) recognized.push(result.text);
          else failed += 1;
        } catch {
          failed += 1;
        }
      }
      const repaired = repairOcrText(recognized.join('\n\n'));
      if (repaired.length < 5) throw new Error('有効な文字を認識できませんでした。');
      setOcrText(repaired);
      setOcrStatus(
        `端末内OCRが${recognized.length}枚を認識しました${failed ? `（${failed}枚は読み取れませんでした）` : ''}。結果を修正して教材本文へ送ってください。`
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

  const runGeminiOcr = async () => {
    setOcrRunning(true);
    setOcrStatus(`Geminiで${images.length}枚の文字を認識しています…`);
    try {
      const repaired = repairOcrText(await recognizeWithGemini(images));
      if (repaired.length < 5) throw new Error('有効な文字を認識できませんでした。');
      setOcrText(repaired);
      setOcrStatus(`Gemini OCRが${images.length}枚を認識しました。結果を必ず確認・修正してください。`);
    } catch (error) {
      setOcrText('');
      setOcrStatus(
        `Gemini OCRに失敗しました：${error instanceof Error ? error.message : '原因不明のエラー'}`
      );
    } finally {
      setOcrRunning(false);
    }
  };

  const runOcr = () => {
    if (!images.length) {
      Alert.alert('写真がありません', '先に教材を撮影するか写真を選んでください。');
      return;
    }
    if (ocrProvider === 'appleVision') {
      void runAppleVisionOcr();
      return;
    }
    Alert.alert(
      'Geminiへ写真を送信します',
      '選択した写真は文字認識のためCloudflare Workerを経由してGoogle Gemini APIへ送信されます。教材写真に個人情報がないことを確認してください。',
      [
        { text: 'キャンセル', style: 'cancel' },
        { text: '同意して認識', onPress: () => void runGeminiOcr() }
      ]
    );
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
            label="写真を選ぶ（複数可）"
            variant="secondary"
            onPress={() => void selectPhoto(false)}
          />
        </View>
        {images.length ? (
          <View style={styles.imageList}>
            <Text style={styles.imageCount}>選択中：{images.length} / 10枚</Text>
            <View style={styles.thumbnailRow}>
              {images.map((image, index) => (
                <View key={image.uri} style={styles.thumbnailItem}>
                  <Image source={{ uri: image.uri }} style={styles.thumbnail} />
                  <Text style={styles.thumbnailLabel}>{index + 1}枚目</Text>
                  <AppButton
                    label="外す"
                    variant="secondary"
                    onPress={() => removeImage(image.uri)}
                  />
                </View>
              ))}
            </View>
          </View>
        ) : null}
        {images.length ? (
          <AppButton label="撮り直す" variant="secondary" onPress={retakePhoto} />
        ) : null}
        <Text style={styles.optionLabel}>文字認識の方法</Text>
        <ChoiceRow
          value={ocrProvider}
          onChange={setOcrProvider}
          options={[
            { value: 'appleVision', label: '端末内OCR' },
            { value: 'gemini', label: 'Gemini OCR' }
          ]}
        />
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
          label={ocrRunning ? '文字認識中…' : `${ocrProvider === 'gemini' ? 'Gemini' : '端末内'}で文字を読む`}
          onPress={runOcr}
          disabled={ocrRunning || !images.length}
        />
        <MutedText>
          端末内OCRは写真を外部送信しません。Gemini OCRは写真をGoogle Gemini APIへ送信し、認識前に確認を求めます。
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
            <AppButton
              label="認識結果を消去"
              variant="secondary"
              onPress={clearOcrResult}
            />
          </>
        ) : null}
      </Section>

      <Section title="教材から自動作問">
        <MutedText>
          当面はGemini 3.5 Flash-Liteを使用します。無料枠には利用上限があり、教材本文は作問のためGoogleのAPIへ送信されます。OCR由来の文字間空白と罫線ノイズは作問前に自動整形します。
        </MutedText>
        <Field
          label="単語帳名"
          value={deckName}
          onChangeText={setDeckName}
          placeholder="例：日本史・定期テスト"
        />
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
            label={
              onDeviceGenerating
                ? 'iPhone内で作問しています…'
                : 'iPhone内で問題を作る'
            }
            variant="success"
            onPress={() => void generateWithOnDeviceAI()}
            disabled={busy || !nativeOnDeviceAIAvailable}
          />
          <AppButton
            label={generating ? 'Geminiで作問中…' : 'AIで作問（Gemini）'}
            onPress={() => void generateWithAi()}
            disabled={busy}
          />
          <AppButton
            label="端末内で簡易作問"
            variant="secondary"
            onPress={generateLocally}
            disabled={busy}
          />
        </View>
        <MutedText>
          「iPhone内で問題を作る」はOCR文字を外部送信しません。iOS 26以降・Apple
          Intelligence対応時はFoundation Modelsを使い、利用できない場合は端末内の簡易作問へ自動で切り替えます。現在の状態：
          {availabilityLabel(onDeviceAvailability)}
        </MutedText>
        {onDeviceStatus ? <Text style={styles.status}>{onDeviceStatus}</Text> : null}
        {onDeviceCards.length ? (
          <View style={styles.generatedCards}>
            <Text style={styles.resultHeading}>
              端末内作問結果（{onDeviceCards.length}枚・
              {onDeviceEngine === 'appleOnDeviceModel' ? '端末内AI' : '簡易作問'}）
            </Text>
            {onDeviceCards.map((card, index) => (
              <View key={card.id} style={styles.generatedCard}>
                <Text style={styles.cardHeading}>カード {index + 1}</Text>
                <AppButton
                  label={card.selected ? '保存対象 ✓' : '保存対象にする'}
                  variant={card.selected ? 'success' : 'secondary'}
                  onPress={() => toggleOnDeviceCard(card.id)}
                />
                <Field
                  label="問題（編集可能）"
                  multiline
                  value={card.question}
                  onChangeText={(value) =>
                    updateOnDeviceCard(card.id, 'question', value)
                  }
                />
                <Field
                  label="答え（編集可能）"
                  multiline
                  value={card.answer}
                  onChangeText={(value) =>
                    updateOnDeviceCard(card.id, 'answer', value)
                  }
                />
                <Field
                  label="解説（編集可能・保存前確認用）"
                  multiline
                  value={card.explanation}
                  onChangeText={(value) =>
                    updateOnDeviceCard(card.id, 'explanation', value)
                  }
                />
                <Text style={styles.metadata}>
                  確信度 {Math.round(card.confidence * 100)}% ・タグ：
                  {card.tags.join('、') || 'なし'}
                </Text>
                <Text style={styles.evidence}>根拠：{card.sourceText}</Text>
                <AppButton
                  label="この候補を削除"
                  variant="danger"
                  onPress={() => removeOnDeviceCard(card.id)}
                />
              </View>
            ))}
            <View style={commonStyles.row}>
              <AppButton
                label="全カードを保存"
                onPress={() => saveOnDeviceCards(true)}
              />
              <AppButton
                label="選択したカードを保存"
                variant="success"
                onPress={() => saveOnDeviceCards(false)}
              />
              <AppButton
                label="同じOCR結果から作り直す"
                variant="secondary"
                onPress={() => void generateWithOnDeviceAI()}
                disabled={busy}
              />
              <AppButton
                label="OCR結果へ戻る"
                variant="secondary"
                onPress={() => setOnDeviceCards([])}
              />
            </View>
          </View>
        ) : null}
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
  imageList: { gap: 8 },
  imageCount: { color: colors.text, fontWeight: '800' },
  thumbnailRow: { flexDirection: 'row', flexWrap: 'wrap', gap: 10 },
  thumbnailItem: { width: 104, gap: 5 },
  thumbnail: { width: 104, height: 104, borderRadius: 10, resizeMode: 'cover' },
  thumbnailLabel: { color: colors.muted, fontSize: 12, textAlign: 'center' },
  generatedCards: { gap: 10 },
  resultHeading: { color: colors.text, fontSize: 16, fontWeight: '800' },
  generatedCard: {
    backgroundColor: colors.background,
    borderColor: colors.border,
    borderRadius: 14,
    borderWidth: 1,
    gap: 9,
    padding: 12
  },
  cardHeading: { color: colors.text, fontSize: 15, fontWeight: '800' },
  metadata: { color: colors.muted, fontSize: 12, lineHeight: 18 },
  evidence: { color: colors.text, fontSize: 12, lineHeight: 18 }
});
