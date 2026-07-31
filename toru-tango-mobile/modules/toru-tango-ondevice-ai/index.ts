import { NativeModule, requireOptionalNativeModule } from 'expo';

export type OnDeviceAIAvailabilityStatus =
  | 'available'
  | 'unsupportedOS'
  | 'deviceNotEligible'
  | 'appleIntelligenceDisabled'
  | 'modelNotReady'
  | 'unavailable';

export type OnDeviceStudyCard = {
  id: string;
  question: string;
  answer: string;
  explanation: string;
  sourceText: string;
  confidence: number;
  tags: string[];
};

export type OnDeviceCardGenerationResult = {
  cards: OnDeviceStudyCard[];
  engine: 'appleOnDeviceModel' | 'deterministicFallback';
  notices: string[];
};

export type OnDeviceCardGenerationRequest = {
  recognizedText: string;
  maximumCardCount?: number;
  difficulty?: 'easy' | 'normal' | 'hard';
  subjectHint?: string;
  prohibitedQuestions?: string[];
};

declare class ToruTangoOnDeviceAINativeModule extends NativeModule {
  availabilityStatus(): OnDeviceAIAvailabilityStatus;
  generateCards(
    recognizedText: string,
    maximumCardCount: number,
    difficulty: 'easy' | 'normal' | 'hard',
    subjectHint: string | null,
    prohibitedQuestions: string[]
  ): Promise<OnDeviceCardGenerationResult>;
}

const nativeModule =
  requireOptionalNativeModule<ToruTangoOnDeviceAINativeModule>(
    'ToruTangoOnDeviceAI'
  );

export function isOnDeviceCardGenerationAvailable(): boolean {
  return nativeModule !== null;
}

export function getOnDeviceAIAvailability(): OnDeviceAIAvailabilityStatus {
  return nativeModule?.availabilityStatus() ?? 'unsupportedOS';
}

export async function generateOnDeviceCards(
  request: OnDeviceCardGenerationRequest
): Promise<OnDeviceCardGenerationResult> {
  if (!nativeModule) {
    throw new Error(
      '端末内AI作問はExpo Goでは利用できません。EAS開発ビルドまたは本番ビルドで実行してください。'
    );
  }

  return nativeModule.generateCards(
    request.recognizedText,
    request.maximumCardCount ?? 8,
    request.difficulty ?? 'normal',
    request.subjectHint?.trim() || null,
    request.prohibitedQuestions ?? []
  );
}
