import { BaseState } from './BaseState';
import { BaseVM, BaseVMEvent } from './BaseVM';
import { TranslationStorage } from '../common/utils/TranslationStorage';
import { appState } from '../store/AppState';

export class SettingsEventType {
  static readonly LOAD_SETTINGS = 'LOAD_SETTINGS';
  static readonly TOGGLE_RESET_ON_REACH_END = 'TOGGLE_RESET_ON_REACH_END';
}

@Observed
export class SettingsState extends BaseState {
  resetOnReachEnd: boolean = false;
  isLoggedIn: boolean = false;
}

export class SettingsViewModel extends BaseVM<SettingsState> {
  private static instance: SettingsViewModel;

  static getInstance(): SettingsViewModel {
    if (!SettingsViewModel.instance) {
      SettingsViewModel.instance = new SettingsViewModel();
    }
    return SettingsViewModel.instance;
  }

  private constructor() {
    super(new SettingsState());
  }

  sendEvent(event: BaseVMEvent): void {
    switch (event.type) {
      case SettingsEventType.LOAD_SETTINGS:
        this.loadSettings();
        break;
      case SettingsEventType.TOGGLE_RESET_ON_REACH_END:
        this.toggleResetOnReachEnd((event.param as Record<string, boolean>)['value'] ?? false);
        break;
    }
  }

  loadSettings(): void {
    const state = this.state;
    state.resetOnReachEnd = AppStorage.get<boolean>('resetOnReachEnd') ?? false;
    state.isLoggedIn = AppStorage.get<boolean>('isLoggedIn') ?? false;
  }

  toggleResetOnReachEnd(value: boolean): void {
    this.state.resetOnReachEnd = value;
    AppStorage.setOrCreate('resetOnReachEnd', value);
    TranslationStorage.saveResetOnReachEnd(value);
  }
}
