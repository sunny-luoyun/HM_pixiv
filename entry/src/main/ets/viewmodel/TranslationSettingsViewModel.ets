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
}
