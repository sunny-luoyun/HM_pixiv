import { BaseLlmService } from './LlmProvider';
import { getDeepSeekService } from './DeepSeekService';
import { OpenAiCompatService } from './OpenAiCompatService';
import { StorageKeys } from '../common/constants/StorageKeys';

let _llmInstance: BaseLlmService | null = null;
let _llmProvider: string = '';

export function getLlmService(): BaseLlmService {
  const provider = AppStorage.get<string>(StorageKeys.LLM_PROVIDER) ?? 'deepseek';

  if (!_llmInstance || _llmProvider !== provider) {
    _llmProvider = provider;
    if (provider === 'custom') {
      const baseUrl = AppStorage.get<string>(StorageKeys.CUSTOM_LLM_API_BASE) ?? '';
      const apiKey = AppStorage.get<string>(StorageKeys.CUSTOM_LLM_API_KEY) ?? '';
      const model = AppStorage.get<string>(StorageKeys.CUSTOM_LLM_MODEL) ?? '';
      _llmInstance = new OpenAiCompatService(baseUrl, apiKey, model);
    } else {
      // 复用 DeepSeekService 单例，保证设置页校准与翻译路径状态一致
      _llmInstance = getDeepSeekService();
    }
  }

  // 每次调用都从 AppStorage 同步最新的 apiKey/自定义配置，保证设置修改即时生效
  if (_llmInstance instanceof OpenAiCompatService) {
    const baseUrl = AppStorage.get<string>(StorageKeys.CUSTOM_LLM_API_BASE) ?? '';
    const apiKey = AppStorage.get<string>(StorageKeys.CUSTOM_LLM_API_KEY) ?? '';
    const model = AppStorage.get<string>(StorageKeys.CUSTOM_LLM_MODEL) ?? '';
    _llmInstance.updateConfig(baseUrl, apiKey, model);
  } else {
    _llmInstance.updateApiKey(AppStorage.get<string>(StorageKeys.DEEPSEEK_API_KEY) ?? '');
  }

  _llmInstance.updatePrompts(
    AppStorage.get<string>(StorageKeys.TITLE_PROMPT) ?? '',
    AppStorage.get<string>(StorageKeys.FULL_PROMPT) ?? '',
    AppStorage.get<boolean>(StorageKeys.UNIFIED_PROMPT) ?? false
  );

  return _llmInstance;
}

export function resetLlmServiceInstance(): void {
  _llmInstance = null;
  _llmProvider = '';
}
