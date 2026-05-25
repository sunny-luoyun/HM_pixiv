import preferences from '@ohos.data.preferences';
import common from '@ohos.app.ability.common';

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
    await pref.put(TranslationStorage.KEY_DEEPSEEK_API_KEY, apiKey);
    await pref.flush();
  }

  static async getDeepSeekApiKey(): Promise<string> {
    if (!TranslationStorage.context) return '';
    const pref = await preferences.getPreferences(TranslationStorage.context, TranslationStorage.PREFERENCES_NAME);
    return await pref.get(TranslationStorage.KEY_DEEPSEEK_API_KEY, '') as string;
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
}
