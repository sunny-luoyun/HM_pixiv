export class ApiConfig {
  static readonly PIXIV_WEB = 'https://www.pixiv.net';
  static readonly PIXIV_APP = 'https://app-api.pixiv.net';
  static readonly PIXIV_ACCOUNTS = 'https://accounts.pixiv.net';
  static readonly PIXIV_LOGIN = 'https://accounts.pixiv.net/login';

  static readonly OAUTH_BASE = 'https://oauth.secure.pixiv.net';
  static readonly OAUTH_TOKEN = 'https://oauth.secure.pixiv.net/auth/token';
  static readonly OAUTH_LOGIN = 'https://app-api.pixiv.net/web/v1/login';
  static readonly REDIRECT_URI = 'https://app-api.pixiv.net/web/v1/users/auth/pixiv/callback';

  static readonly DEEPSEEK_API = 'https://api.deepseek.com/chat/completions';
  static readonly DEEPSEEK_BALANCE = 'https://api.deepseek.com/user/balance';

  static readonly USER_AGENT = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36';
  static readonly USER_AGENT_APP = 'PixivAndroidApp/5.0.234 (Android 11; Pixel 5)';
  static readonly REFERER = 'https://www.pixiv.net/';

  static readonly CLIENT_ID = 'MOBrBDS8blbauoSck0ZfDbtuzpyT';
  static readonly CLIENT_SECRET = 'lsACyCD94FhDUtGTXi3QzcFE2uU1hqtDaKeqrdwj';
  static readonly HASH_SECRET = '28c1fdd170a5204386cb1313c7077b34f83e4aaf4aa829ce78c231e05b0bae2c';
}
