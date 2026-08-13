/**
 * AppStorage 键名常量，替代硬编码字符串
 */
export class StorageKeys {
  static readonly IS_DARK_MODE = 'isDarkMode';
  static readonly IS_LOGGED_IN = 'isLoggedIn';
  static readonly APP_CONTEXT = 'appContext';
  static readonly UI_CONTEXT = 'uiContext';
  static readonly DEEPSEEK_API_KEY = 'deepseekApiKey';
  static readonly LLM_PROVIDER = 'llmProvider';
  static readonly CUSTOM_LLM_API_BASE = 'customLlmApiBase';
  static readonly CUSTOM_LLM_API_KEY = 'customLlmApiKey';
  static readonly CUSTOM_LLM_MODEL = 'customLlmModel';
  static readonly TITLE_PROMPT = 'titlePrompt';
  static readonly FULL_PROMPT = 'fullPrompt';
  static readonly UNIFIED_PROMPT = 'unifiedPrompt';
  static readonly RESET_ON_REACH_END = 'resetOnReachEnd';

  static readonly NAV_ROOT_STACK = 'navRootStack';
  static readonly PAGE_CONTEXT = 'pageContext';
}
