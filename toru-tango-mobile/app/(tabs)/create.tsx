import { useMemo, useState } from 'react';
import { Alert, Image, StyleSheet, Text, View } from 'react-native';
import * as ImagePicker from 'expo-image-picker';
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
import { generateLocalQuestions } from '@/src/services/localQuestionGenerator';
import type {
  Difficulty,
  QuestionCandidate,
  QuestionType
} from '@/src/types';
import { isSameCard } from '@/src/utils/data';

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

  const candidateCount = useMemo(
    () => parseLines(generatedText).length,
    [generatedText]
  );

  const generate = async () => {
    const text = sourceText.trim();
    if (text.length < 20) {
      Alert.alert('教材本文が短すぎます', '20文字以上入力してください。');
      return;
    }

    setGenerating(true);
    setGenerateStatus('作問中…');
    try {
      const candidates = await generateAiQuestions({
        text,
        count: Number(count),
        type,
        difficulty
      });
      if (!candidates.length) throw new Error('AI_EMPTY');
      setGeneratedText(formatLines(candidates));
      setGenerateStatus(`AIで${candidates.length}問を作成しました。追加前に確認してください。`);
    } catch {
      const fallback = generateLocalQuestions(
        text,
        Number(count),
        type,
        difficulty
      );
      setGeneratedText(formatLines(fallback));
      setGenerateStatus(
        fallback.length
          ? `AIへ接続できなかったため、端末内で${fallback.length}問を作成しました。`
          : '問題を作成できませんでした。文章を増やし、句点を入れてください。'
      );
    } finally {
      setGenerating(false);
    }
  };

  const removeDuplicates = () => {
    const accepted: QuestionCandidate[] = [];
    for (const candidate of parseLines(generatedText)) {
      if (cards.some((card) => isSameCard(card, candidate))) continue;
      if (accepted.some((item) => isSameCard(item, candidate))) continue;
      accepted.push(candidate);
    }
    setGeneratedText(formatLines(accepted));
    setGenerateStatus(`${accepted.length}問に整理しました。`);
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
          quality: 0.8
        })
      : await ImagePicker.launchImageLibraryAsync({
          mediaTypes: ['images'],
          quality: 0.8
        });

    if (!result.canceled) setImageUri(result.assets[0].uri);
  };

  return (
    <Page>
      <Text style={commonStyles.title}>撮る単語帳</Text>
      <Text style={commonStyles.subtitle}>
        教材から、15秒で答えられる一問一答を作ります。
      </Text>

      <Section title="教材から自動作問">
        <MutedText>
          AI APIが未設定・通信失敗の場合は、端末内の簡易作問へ自動で切り替わります。
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
        <Text style={styles.optionLabel}>作問数</Text>
        <ChoiceRow
          value={count}
          onChange={setCount}
          options={['5', '10', '15', '20'].map((value) => ({
            value: value as '5' | '10' | '15' | '20',
            label: `${value}問`
          }))}
        />
        <AppButton
          label={generating ? '作問中…' : '問題を作る'}
          onPress={() => void generate()}
          disabled={generating}
        />
        {generateStatus ? <Text style={styles.status}>{generateStatus}</Text> : null}
        {generatedText ? (
          <>
            <Field
              label={`生成結果（${candidateCount}問・編集可能）`}
              multiline
              value={generatedText}
              onChangeText={setGeneratedText}
            />
            <View style={commonStyles.row}>
              <AppButton label="重複を除く" variant="secondary" onPress={removeDuplicates} />
              <AppButton label="カードへ追加" onPress={saveGenerated} />
            </View>
          </>
        ) : null}
      </Section>

      <Section title="直接入力">
        <Field label="問題" value={question} onChangeText={setQuestion} />
        <Field label="答え" value={answer} onChangeText={setAnswer} />
        <AppButton label="カードを追加" onPress={saveDirect} />
      </Section>

      <Section title="まとめて作成">
        <MutedText>1行に「問題｜答え」の形式で入力してください。</MutedText>
        <Field
          label="カードデータ"
          multiline
          value={bulkText}
          onChangeText={setBulkText}
          placeholder={'日本の首都は？｜東京\n日本で最も高い山は？｜富士山'}
        />
        <AppButton label="まとめて追加" onPress={saveBulk} />
      </Section>

      <Section title="教材写真">
        <View style={commonStyles.row}>
          <AppButton label="撮影する" onPress={() => void selectPhoto(true)} />
          <AppButton
            label="写真を選ぶ"
            variant="secondary"
            onPress={() => void selectPhoto(false)}
          />
        </View>
        {imageUri ? <Image source={{ uri: imageUri }} style={styles.preview} /> : null}
        <MutedText>
          写真の撮影・選択まで実装済みです。OCR接続は次の工程で追加します。
        </MutedText>
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
  preview: { width: '100%', height: 240, borderRadius: 12, resizeMode: 'contain' }
});
