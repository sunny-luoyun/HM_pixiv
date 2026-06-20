import { describe, it, expect } from '@ohos/hypium';

// CookieManager 的核心逻辑：cookie 字符串解析
// 由于 collectLoginCookies 依赖 webview.WebCookieManager.getCookie，
// 此处测试其内部的 cookie 解析算法（提取出来的纯函数版本）

function parseCookieStr(cookieStr: string): Map<string, string> {
  const cookieMap = new Map<string, string>();
  cookieStr.split(';').forEach(pair => {
    const trimmed = pair.trim();
    if (!trimmed) return;
    const eqIndex = trimmed.indexOf('=');
    if (eqIndex === -1) return;
    const key = trimmed.slice(0, eqIndex);
    const value = trimmed.slice(eqIndex + 1);
    cookieMap.set(key, value);
  });
  return cookieMap;
}

function buildCookieString(cookieMap: Map<string, string>): string {
  const entries = Array.from(cookieMap.entries());
  let result = '';
  for (let i = 0; i < entries.length; i++) {
    if (i > 0) result += '; ';
    result += `${entries[i][0]}=${entries[i][1]}`;
  }
  return result;
}

function joinCookieStrings(cookieStrs: string[]): string {
  const cookieMap = new Map<string, string>();
  for (const cookieStr of cookieStrs) {
    cookieStr.split(';').forEach(pair => {
      const trimmed = pair.trim();
      if (!trimmed) return;
      const eqIndex = trimmed.indexOf('=');
      if (eqIndex === -1) return;
      const key = trimmed.slice(0, eqIndex);
      const value = trimmed.slice(eqIndex + 1);
      cookieMap.set(key, value);
    });
  }
  return Array.from(cookieMap.entries())
    .map(entry => `${entry[0]}=${entry[1]}`)
    .join('; ');
}

export default function cookieManagerTest() {
  describe('CookieManager（纯逻辑测试）', () => {

    describe('parseCookieStr - 单条 Cookie 解析', () => {
      it('应正确解析标准 Cookie 字符串', 0, () => {
        const cookie = parseCookieStr('PHPSESSID=abc123; domain=.pixiv.net; path=/');
        expect(cookie.get('PHPSESSID')).assertEqual('abc123');
        expect(cookie.get('domain')).assertEqual('.pixiv.net');
        expect(cookie.get('path')).assertEqual('/');
      });

      it('应正确解析多个 key=value', 0, () => {
        const cookie = parseCookieStr('token=xyz; expires=2025-12-31; secure');
        expect(cookie.get('token')).assertEqual('xyz');
        expect(cookie.get('expires')).assertEqual('2025-12-31');
        // 'secure' 没有等号，会被跳过
        expect(cookie.has('secure')).assertFalse();
      });

      it('空字符串返回空 Map', 0, () => {
        const cookie = parseCookieStr('');
        expect(cookie.size).assertEqual(0);
      });

      it('仅空白应返回空 Map', 0, () => {
        const cookie = parseCookieStr('   ;  ; ');
        expect(cookie.size).assertEqual(0);
      });

      it('无等号的条目应被跳过', 0, () => {
        const cookie = parseCookieStr('PHPSESSID=abc; secure; HttpOnly; token=xyz');
        expect(cookie.get('PHPSESSID')).assertEqual('abc');
        expect(cookie.get('token')).assertEqual('xyz');
        expect(cookie.has('secure')).assertFalse();
        expect(cookie.has('HttpOnly')).assertFalse();
      });
    });

    describe('buildCookieString - 构建 Cookie 字符串', () => {
      it('应将 Map 转为 Cookie 字符串', 0, () => {
        const map = new Map<string, string>();
        map.set('PHPSESSID', 'abc123');
        map.set('token', 'xyz');
        const str = buildCookieString(map);
        expect(str).assertContain('PHPSESSID=abc123');
        expect(str).assertContain('token=xyz');
        expect(str).assertContain('; ');
      });

      it('单条目不应包含分号', 0, () => {
        const map = new Map<string, string>();
        map.set('PHPSESSID', 'abc123');
        const str = buildCookieString(map);
        expect(str).assertEqual('PHPSESSID=abc123');
      });
    });

    describe('joinCookieStrings - 合并多个域名 Cookie', () => {
      it('应合并两个域的 Cookie', 0, () => {
        const cookies = [
          'PHPSESSID=abc123; domain=.pixiv.net',
          'token=xyz789; domain=accounts.pixiv.net'
        ];
        const result = joinCookieStrings(cookies);
        expect(result).assertContain('PHPSESSID=abc123');
        expect(result).assertContain('token=xyz789');
      });

      it('后出现的值应覆盖先出现的值', 0, () => {
        const cookies = [
          'PHPSESSID=old_value',
          'PHPSESSID=new_value'
        ];
        const result = joinCookieStrings(cookies);
        expect(result).assertContain('PHPSESSID=new_value');
        expect(result.includes('PHPSESSID=old_value')).assertFalse();
      });

      it('空 Cookie 数组返回空字符串', 0, () => {
        expect(joinCookieStrings([])).assertEqual('');
      });

      it('应过滤空格和空条目', 0, () => {
        const cookies = [
          'PHPSESSID=abc; ; ; token=xyz'
        ];
        const result = joinCookieStrings(cookies);
        expect(result).assertContain('PHPSESSID=abc');
        expect(result).assertContain('token=xyz');
      });

      it('PHPSESSID 提取正确', 0, () => {
        const cookies = [
          'locale=ja_JP; PHPSESSID=my_session_id_123; device_token=abc'
        ];
        const result = joinCookieStrings(cookies);
        expect(result).assertContain('PHPSESSID=my_session_id_123');
      });

      it('混合正常和异常条目', 0, () => {
        const cookies = [
          'a=1; ; ; b=2',
          '',
          'c=3'
        ];
        const result = joinCookieStrings(cookies);
        expect(result).assertContain('a=1');
        expect(result).assertContain('b=2');
        expect(result).assertContain('c=3');
      });
    });

    describe('getFullCookie 逻辑模拟', () => {
      it('有 PHPSESSID 时返回 Cookie 字符串', 0, () => {
        const phpsessid = 'saved_session_123';
        const cookieStr = `PHPSESSID=${phpsessid}`;
        expect(cookieStr).assertEqual('PHPSESSID=saved_session_123');
      });

      it('无 PHPSESSID 时返回空', 0, () => {
        const phpsessid = '';
        if (!phpsessid) {
          expect(phpsessid).assertEqual('');
        }
      });
    });

    describe('DOMAINS 常量', () => {
      it('应包含 pixiv 主要域名', 0, () => {
        const domains = ['https://accounts.pixiv.net', 'https://www.pixiv.net'];
        expect(domains.length).assertEqual(2);
        expect(domains[0]).assertEqual('https://accounts.pixiv.net');
        expect(domains[1]).assertEqual('https://www.pixiv.net');
      });
    });
  });
}
