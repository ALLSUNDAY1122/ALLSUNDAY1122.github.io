import { NativeModule, requireOptionalNativeModule } from 'expo';

export type OcrRecognitionResult = {
  text: string;
  lines: string[];
  rotation: number;
  score: number;
};

declare class ToruTangoOcrNativeModule extends NativeModule {
  recognizeText(uri: string, rotation: number): Promise<OcrRecognitionResult>;
}

const nativeModule =
  requireOptionalNativeModule<ToruTangoOcrNativeModule>('ToruTangoOcr');

export function isNativeOcrAvailable(): boolean {
  return nativeModule !== null;
}

export async function recognizeText(
  uri: string,
  rotation: number = -1
): Promise<OcrRecognitionResult> {
  if (!nativeModule) {
    throw new Error(
      'Apple Vision OCRはExpo Goでは利用できません。EAS開発ビルドまたは本番ビルドで実行してください。'
    );
  }
  return nativeModule.recognizeText(uri, rotation);
}
