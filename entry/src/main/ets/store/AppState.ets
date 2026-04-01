// entry/src/main/ets/store/AppState.ets
import { AppStorage } from '@kit.ArkUI';

@Observed
export class AppState {
  static userInfo: UserInfo = new UserInfo();

  static setUserInfo(info: UserInfo) {
    AppState.userInfo = info;
    AppStorage.setOrCreate('userInfo', info);
  }
}

export class UserInfo {
  isLoggedIn: boolean = false;
  userName: string = '';
}