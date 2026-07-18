import preferences from '@ohos.data.preferences';
import common from '@ohos.app.ability.common';
import { encryptAesGcm, decryptAesGcm } from './CryptoUtils';

export class TranslationStorage {
  private static PREFERENCES_NAME = 'app_translation';
  private static KEY_DEEPSEEK_API_KEY = 'deepseek_api_key';
  private static context: common.BaseContext;

  static init(context: common.BaseContext) {
    TranslationStorage.context = context;
  }

  static async saveDeepSeekApiKey(apiKey: string): Promise<void> {
    if (!TranslationStorage.context) throw new Error('TranslationStorage not initialized');
    const pref = await preferences.getPreferences(TranslationStorage.context, TranslationStorage.PREFERENCES_NAME);
    const encrypted = await encryptAesGcm(apiKey);
    await pref.put(TranslationStorage.KEY_DEEPSEEK_API_KEY, encrypted);
    await pref.flush();
  }

  static async getDeepSeekApiKey(): Promise<string> {
    if (!TranslationStorage.context) return '';
    const pref = await preferences.getPreferences(TranslationStorage.context, TranslationStorage.PREFERENCES_NAME);
    const encrypted = await pref.get(TranslationStorage.KEY_DEEPSEEK_API_KEY, '') as string;
    if (!encrypted) return '';
    try {
      return await decryptAesGcm(encrypted);
    } catch {
      return '';
    }
  }

  static async clearDeepSeekApiKey(): Promise<void> {
    if (!TranslationStorage.context) return;
    const pref = await preferences.getPreferences(TranslationStorage.context, TranslationStorage.PREFERENCES_NAME);
    await pref.delete(TranslationStorage.KEY_DEEPSEEK_API_KEY);
    await pref.flush();
  }

  private static KEY_RESET_ON_REACH_END = 'reset_on_reach_end';

  static async saveResetOnReachEnd(enabled: boolean): Promise<void> {
    if (!TranslationStorage.context) return;
    const pref = await preferences.getPreferences(TranslationStorage.context, TranslationStorage.PREFERENCES_NAME);
    await pref.put(TranslationStorage.KEY_RESET_ON_REACH_END, enabled);
    await pref.flush();
  }

  static async getResetOnReachEnd(): Promise<boolean> {
    if (!TranslationStorage.context) return false;
    const pref = await preferences.getPreferences(TranslationStorage.context, TranslationStorage.PREFERENCES_NAME);
    return await pref.get(TranslationStorage.KEY_RESET_ON_REACH_END, false) as boolean;
  }

  private static KEY_MAX_NOVEL_TAGS = 'max_novel_tags';

  static async saveMaxNovelTags(value: number): Promise<void> {
    if (!TranslationStorage.context) return;
    const pref = await preferences.getPreferences(TranslationStorage.context, TranslationStorage.PREFERENCES_NAME);
    await pref.put(TranslationStorage.KEY_MAX_NOVEL_TAGS, value);
    await pref.flush();
  }

  static async getMaxNovelTags(): Promise<number> {
    if (!TranslationStorage.context) return 50;
    const pref = await preferences.getPreferences(TranslationStorage.context, TranslationStorage.PREFERENCES_NAME);
    return await pref.get(TranslationStorage.KEY_MAX_NOVEL_TAGS, 50) as number;
  }

  private static KEY_NOVEL_TAG_FILTER_ENABLED = 'novel_tag_filter_enabled';

  static async saveNovelTagFilterEnabled(enabled: boolean): Promise<void> {
    if (!TranslationStorage.context) return;
    const pref = await preferences.getPreferences(TranslationStorage.context, TranslationStorage.PREFERENCES_NAME);
    await pref.put(TranslationStorage.KEY_NOVEL_TAG_FILTER_ENABLED, enabled);
    await pref.flush();
  }

  static async getNovelTagFilterEnabled(): Promise<boolean> {
    if (!TranslationStorage.context) return true;
    const pref = await preferences.getPreferences(TranslationStorage.context, TranslationStorage.PREFERENCES_NAME);
    return await pref.get(TranslationStorage.KEY_NOVEL_TAG_FILTER_ENABLED, false) as boolean;
  }
}
