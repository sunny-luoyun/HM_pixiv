export interface UgoiraFrame {
  file: string;
  delay: number;
}

export interface UgoiraMetaBody {
  src: string;
  originalSrc: string;
  mimeType: string;
  frames: UgoiraFrame[];
}

export interface UgoiraMetaResponse {
  error: boolean;
  message?: string;
  body: UgoiraMetaBody;
}

export const ILLUST_TYPE_UGOIRA: number = 2;
