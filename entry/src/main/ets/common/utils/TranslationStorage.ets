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

  private static KEY_LLM_PROVIDER = 'llm_provider';

  static async saveLlmProvider(provider: string): Promise<void> {
    if (!TranslationStorage.context) return;
    const pref = await preferences.getPreferences(TranslationStorage.context, TranslationStorage.PREFERENCES_NAME);
    await pref.put(TranslationStorage.KEY_LLM_PROVIDER, provider);
    await pref.flush();
  }

  static async getLlmProvider(): Promise<string> {
    if (!TranslationStorage.context) return 'deepseek';
    const pref = await preferences.getPreferences(TranslationStorage.context, TranslationStorage.PREFERENCES_NAME);
    return await pref.get(TranslationStorage.KEY_LLM_PROVIDER, 'deepseek') as string;
  }

  private static KEY_CUSTOM_API_BASE = 'custom_api_base';

  static async saveCustomApiBase(url: string): Promise<void> {
    if (!TranslationStorage.context) return;
    const pref = await preferences.getPreferences(TranslationStorage.context, TranslationStorage.PREFERENCES_NAME);
    await pref.put(TranslationStorage.KEY_CUSTOM_API_BASE, url);
    await pref.flush();
  }

  static async getCustomApiBase(): Promise<string> {
    if (!TranslationStorage.context) return '';
    const pref = await preferences.getPreferences(TranslationStorage.context, TranslationStorage.PREFERENCES_NAME);
    return await pref.get(TranslationStorage.KEY_CUSTOM_API_BASE, '') as string;
  }

  private static KEY_CUSTOM_API_KEY = 'custom_api_key';

  static async saveCustomApiKey(apiKey: string): Promise<void> {
    if (!TranslationStorage.context) throw new Error('TranslationStorage not initialized');
    const pref = await preferences.getPreferences(TranslationStorage.context, TranslationStorage.PREFERENCES_NAME);
    const encrypted = await encryptAesGcm(apiKey);
    await pref.put(TranslationStorage.KEY_CUSTOM_API_KEY, encrypted);
    await pref.flush();
  }

  static async getCustomApiKey(): Promise<string> {
    if (!TranslationStorage.context) return '';
    const pref = await preferences.getPreferences(TranslationStorage.context, TranslationStorage.PREFERENCES_NAME);
    const encrypted = await pref.get(TranslationStorage.KEY_CUSTOM_API_KEY, '') as string;
    if (!encrypted) return '';
    try {
      return await decryptAesGcm(encrypted);
    } catch {
      return '';
    }
  }

  static async clearCustomApiKey(): Promise<void> {
    if (!TranslationStorage.context) return;
    const pref = await preferences.getPreferences(TranslationStorage.context, TranslationStorage.PREFERENCES_NAME);
    await pref.delete(TranslationStorage.KEY_CUSTOM_API_KEY);
    await pref.flush();
  }

  private static KEY_CUSTOM_MODEL = 'custom_model';

  static async saveCustomModel(model: string): Promise<void> {
    if (!TranslationStorage.context) return;
    const pref = await preferences.getPreferences(TranslationStorage.context, TranslationStorage.PREFERENCES_NAME);
    await pref.put(TranslationStorage.KEY_CUSTOM_MODEL, model);
    await pref.flush();
  }

  static async getCustomModel(): Promise<string> {
    if (!TranslationStorage.context) return '';
    const pref = await preferences.getPreferences(TranslationStorage.context, TranslationStorage.PREFERENCES_NAME);
    return await pref.get(TranslationStorage.KEY_CUSTOM_MODEL, '') as string;
  }

  private static KEY_TITLE_PROMPT = 'title_prompt';

  static async saveTitlePrompt(prompt: string): Promise<void> {
    if (!TranslationStorage.context) return;
    const pref = await preferences.getPreferences(TranslationStorage.context, TranslationStorage.PREFERENCES_NAME);
    await pref.put(TranslationStorage.KEY_TITLE_PROMPT, prompt);
    await pref.flush();
  }

  static async getTitlePrompt(): Promise<string> {
    if (!TranslationStorage.context) return '';
    const pref = await preferences.getPreferences(TranslationStorage.context, TranslationStorage.PREFERENCES_NAME);
    return await pref.get(TranslationStorage.KEY_TITLE_PROMPT, '') as string;
  }

  private static KEY_FULL_PROMPT = 'full_prompt';

  static async saveFullPrompt(prompt: string): Promise<void> {
    if (!TranslationStorage.context) return;
    const pref = await preferences.getPreferences(TranslationStorage.context, TranslationStorage.PREFERENCES_NAME);
    await pref.put(TranslationStorage.KEY_FULL_PROMPT, prompt);
    await pref.flush();
  }

  static async getFullPrompt(): Promise<string> {
    if (!TranslationStorage.context) return '';
    const pref = await preferences.getPreferences(TranslationStorage.context, TranslationStorage.PREFERENCES_NAME);
    return await pref.get(TranslationStorage.KEY_FULL_PROMPT, '') as string;
  }

  private static KEY_UNIFIED_PROMPT = 'unified_prompt';

  static async saveUnifiedPrompt(enabled: boolean): Promise<void> {
    if (!TranslationStorage.context) return;
    const pref = await preferences.getPreferences(TranslationStorage.context, TranslationStorage.PREFERENCES_NAME);
    await pref.put(TranslationStorage.KEY_UNIFIED_PROMPT, enabled);
    await pref.flush();
  }

  static async getUnifiedPrompt(): Promise<boolean> {
    if (!TranslationStorage.context) return false;
    const pref = await preferences.getPreferences(TranslationStorage.context, TranslationStorage.PREFERENCES_NAME);
    return await pref.get(TranslationStorage.KEY_UNIFIED_PROMPT, false) as boolean;
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
