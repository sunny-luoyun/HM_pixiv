import pixivModelsTest from './PixivModels.test';
import subscriptionServiceTest from './SubscriptionService.test';
import loginServiceTest from './LoginService.test';
import pixivServiceTest from './PixivService.test';
import deepSeekServiceTest from './DeepSeekService.test';
import cookieManagerTest from './CookieManager.test';
import appStateTest from './AppState.test';
import appApiServiceTest from './AppApiService.test';
import proxyServiceTest from './ProxyService.test';
import cryptoUtilsTest from './CryptoUtils.test';
import cookieStorageTest from './CookieStorage.test';
import translationStorageTest from './TranslationStorage.test';
import deepSeekTokenizerTest from './DeepSeekTokenizer.test';
import pixivCacheDBTest from './PixivCacheDB.test';
import localUnitTest from './LocalUnit.test';

export default function testsuite() {
  localUnitTest();
  pixivModelsTest();
  subscriptionServiceTest();
  loginServiceTest();
  pixivServiceTest();
  deepSeekServiceTest();
  cookieManagerTest();
  appStateTest();
  appApiServiceTest();
  proxyServiceTest();
  cryptoUtilsTest();
  cookieStorageTest();
  translationStorageTest();
  deepSeekTokenizerTest();
  pixivCacheDBTest();
}
