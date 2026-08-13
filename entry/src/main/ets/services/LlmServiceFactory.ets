import { BaseLlmService } from './LlmProvider';
import { DeepSeekService } from './DeepSeekService';
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
      const apiKey = AppStorage.get<string>(StorageKeys.DEEPSEEK_API_KEY) ?? '';
      _llmInstance = new DeepSeekService(apiKey);
    }
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
