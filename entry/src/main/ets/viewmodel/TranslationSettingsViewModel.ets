import { BaseState } from './BaseState';
import { BaseVM, BaseVMEvent } from './BaseVM';
import { getDeepSeekService } from '../services/DeepSeekService';
import { TranslationStorage } from '../common/utils/TranslationStorage';
import common from '@ohos.app.ability.common';

export class TranslationSettingsEventType {
  static readonly LOAD_SETTINGS = 'LOAD_SETTINGS';
  static readonly CHECK_API_KEY = 'CHECK_API_KEY';
  static readonly CLEAR_API_KEY = 'CLEAR_API_KEY';
  static readonly FETCH_BALANCE = 'FETCH_BALANCE';
  static readonly RESET_RATIO = 'RESET_RATIO';
}

@Observed
export class TranslationSettingsState extends BaseState {
  deepseekApiKey: string = '';
  showApiKeyText: boolean = false;
  apiKeyCheckState: 'idle' | 'checking' | 'ok' | 'fail' = 'idle';
  balanceAmount: string = '';
  balanceFetchState: 'idle' | 'loading' | 'ok' | 'fail' = 'idle';
  ratioValue: number = 0;
  ratioCount: number = 0;
  llmProvider: string = 'deepseek';
  customApiBase: string = '';
  customModel: string = '';
  customApiKey: string = '';
  titlePrompt: string = '';
  fullPrompt: string = '';
  unifiedPrompt: boolean = false;
}

export class TranslationSettingsViewModel extends BaseVM<TranslationSettingsState> {
  private static instance: TranslationSettingsViewModel;

  static getInstance(): TranslationSettingsViewModel {
    if (!TranslationSettingsViewModel.instance) {
      TranslationSettingsViewModel.instance = new TranslationSettingsViewModel();
    }
    return TranslationSettingsViewModel.instance;
  }

  private constructor() {
    super(new TranslationSettingsState());
  }

  sendEvent(event: BaseVMEvent): void {
    switch (event.type) {
      case TranslationSettingsEventType.LOAD_SETTINGS:
        this.loadSettings();
        break;
      case TranslationSettingsEventType.CHECK_API_KEY:
        this.checkApiKeyValidity();
        break;
      case TranslationSettingsEventType.CLEAR_API_KEY:
        this.clearApiKey();
        break;
      case TranslationSettingsEventType.FETCH_BALANCE:
        this.fetchBalance();
        break;
      case TranslationSettingsEventType.RESET_RATIO:
        this.resetRatio();
        break;
    }
  }

  async loadSettings(): Promise<void> {
    const state = this.state;
    state.deepseekApiKey = AppStorage.get<string>('deepseekApiKey') ?? '';
    state.llmProvider = AppStorage.get<string>('llmProvider') ?? 'deepseek';
    state.customApiBase = AppStorage.get<string>('customLlmApiBase') ?? '';
    state.customModel = AppStorage.get<string>('customLlmModel') ?? '';
    state.customApiKey = AppStorage.get<string>('customLlmApiKey') ?? '';
    state.titlePrompt = AppStorage.get<string>('titlePrompt') ?? '';
    state.fullPrompt = AppStorage.get<string>('fullPrompt') ?? '';
    state.unifiedPrompt = AppStorage.get<boolean>('unifiedPrompt') ?? false;
    await this.loadRatioInfo();
    if (state.deepseekApiKey.length > 0) {
      await this.fetchBalance();
    }
  }

  async loadRatioInfo(): Promise<void> {
    const ctx = AppStorage.get<common.UIAbilityContext>('appContext');
    if (ctx) {
      const service = getDeepSeekService();
      await service.loadRatio(ctx);
      this.state.ratioValue = service.getAdaptiveRatio();
      this.state.ratioCount = service.getRatioCount();
    }
  }

  async checkApiKeyValidity(): Promise<void> {
    const state = this.state;
    state.apiKeyCheckState = 'checking';
    const service = getDeepSeekService();
    const result = await service.fetchBalance(state.deepseekApiKey);
    if (result.success) {
      state.apiKeyCheckState = 'ok';
      state.balanceAmount = result.data;
      state.balanceFetchState = 'ok';
    } else {
      state.apiKeyCheckState = 'fail';
    }
  }

  async clearApiKey(): Promise<void> {
    const state = this.state;
    state.deepseekApiKey = '';
    AppStorage.setOrCreate('deepseekApiKey', '');
    await TranslationStorage.clearDeepSeekApiKey();
    state.apiKeyCheckState = 'idle';
    state.balanceAmount = '';
    state.balanceFetchState = 'idle';
  }

  async fetchBalance(): Promise<void> {
    const state = this.state;
    state.balanceFetchState = 'loading';
    const service = getDeepSeekService();
    const result = await service.fetchBalance(state.deepseekApiKey);
    if (result.success) {
      state.balanceAmount = result.data;
      state.balanceFetchState = 'ok';
    } else {
      state.balanceFetchState = 'fail';
    }
  }

  async resetRatio(): Promise<void> {
    const service = getDeepSeekService();
    await service.resetAdaptiveRatio();
    await this.loadRatioInfo();
  }

  updateApiKey(key: string): void {
    const state = this.state;
    state.deepseekApiKey = key;
    state.apiKeyCheckState = 'idle';
    AppStorage.setOrCreate('deepseekApiKey', key);
    TranslationStorage.saveDeepSeekApiKey(key);
  }

  updateLlmProvider(provider: string): void {
    const state = this.state;
    state.llmProvider = provider;
    AppStorage.setOrCreate('llmProvider', provider);
    TranslationStorage.saveLlmProvider(provider);
    if (provider === 'deepseek' && state.deepseekApiKey.length > 0) {
      this.fetchBalance();
    }
  }

  updateCustomConfig(field: 'base' | 'model' | 'key', value: string): void {
    const state = this.state;
    if (field === 'base') {
      state.customApiBase = value;
      AppStorage.setOrCreate('customLlmApiBase', value);
      TranslationStorage.saveCustomApiBase(value);
    } else if (field === 'model') {
      state.customModel = value;
      AppStorage.setOrCreate('customLlmModel', value);
      TranslationStorage.saveCustomModel(value);
    } else {
      state.customApiKey = value;
      AppStorage.setOrCreate('customLlmApiKey', value);
      TranslationStorage.saveCustomApiKey(value);
    }
  }

  updateTitlePrompt(prompt: string): void {
    const state = this.state;
    state.titlePrompt = prompt;
    AppStorage.setOrCreate('titlePrompt', prompt);
    TranslationStorage.saveTitlePrompt(prompt);
  }

  updateFullPrompt(prompt: string): void {
    const state = this.state;
    state.fullPrompt = prompt;
    AppStorage.setOrCreate('fullPrompt', prompt);
    TranslationStorage.saveFullPrompt(prompt);
  }

  updateUnifiedPrompt(enabled: boolean): void {
    const state = this.state;
    state.unifiedPrompt = enabled;
    AppStorage.setOrCreate('unifiedPrompt', enabled);
    TranslationStorage.saveUnifiedPrompt(enabled);
  }

  resetPrompts(): void {
    const state = this.state;
    state.titlePrompt = '';
    state.fullPrompt = '';
    AppStorage.setOrCreate('titlePrompt', '');
    AppStorage.setOrCreate('fullPrompt', '');
    TranslationStorage.saveTitlePrompt('');
    TranslationStorage.saveFullPrompt('');
  }
}
