import http from '@ohos.net.http';
import fileIo from '@ohos.file.fs';
import common from '@ohos.app.ability.common';

export interface FetchResult {
  success: boolean;
  content?: string;
  rawContent?: string;
  error?: string;
  fileName?: string;
}

export class SubscriptionService {

  static async fetch(url: string): Promise<FetchResult> {
    if (!url) {
      return { success: false, error: '订阅 URL 为空' };
    }

    const httpRequest = http.createHttp();
    try {
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        connectTimeout: 15000,
        readTimeout: 15000,
        usingCache: false,
      });

      if (response.responseCode !== 200) {
        return {
          success: false,
          error: `服务器返回状态码 ${response.responseCode}`
        };
      }

      let rawContent = response.result as string;
      if (!rawContent) {
        return { success: false, error: '响应内容为空' };
      }

      // Save raw content - Go code will handle format detection
      let fileName = await SubscriptionService.saveToFile(rawContent);

      return {
        success: true,
        content: rawContent,
        rawContent: rawContent,
        fileName: fileName,
      };
    } catch (err) {
      return {
        success: false,
        error: `请求失败: ${String(err)}`
      };
    } finally {
      httpRequest.destroy();
    }
  }

  static detectFormat(content: string): 'yaml' | 'proxy_list' | 'base64_yaml' | 'unknown' {
    if (SubscriptionService.isValidBase64(content)) {
      let decoded = SubscriptionService.base64Decode(content);
      if (decoded && SubscriptionService.isClashYaml(decoded)) {
        return 'base64_yaml';
      }
      if (decoded && SubscriptionService.isProxyUrlList(decoded)) {
        return 'proxy_list';
      }
    }

    if (SubscriptionService.isClashYaml(content)) {
      return 'yaml';
    }

    if (SubscriptionService.isProxyUrlList(content)) {
      return 'proxy_list';
    }

    return 'unknown';
  }

  static isClashYaml(content: string): boolean {
    let lines = content.split('\n');
    for (let line of lines) {
      let trimmed = line.trim();
      if (trimmed.startsWith('port:') || trimmed.startsWith('mixed-port:') ||
          trimmed.startsWith('proxies:') || trimmed.startsWith('proxy-groups:') ||
          trimmed.startsWith('mode:') || trimmed.startsWith('rules:')) {
        return true;
      }
    }
    return false;
  }

  static isProxyUrlList(content: string): boolean {
    let lines = content.split('\n');
    let proxyCount = 0;
    for (let line of lines) {
      let trimmed = line.trim();
      if (trimmed.startsWith('ss://') || trimmed.startsWith('vmess://') ||
          trimmed.startsWith('trojan://') || trimmed.startsWith('vless://') ||
          trimmed.startsWith('hysteria://') || trimmed.startsWith('hy2://') ||
          trimmed.startsWith('tuic://') || trimmed.startsWith('wireguard://')) {
        proxyCount++;
      }
    }
    return proxyCount > 0;
  }

  static isValidBase64(str: string): boolean {
    if (str.length < 20) return false;
    let cleaned = str.replace(/[\r\n\s]/g, '');
    let base64Regex = /^[A-Za-z0-9+/]*={0,2}$/;
    return base64Regex.test(cleaned) && cleaned.length % 4 === 0;
  }

  static base64Decode(input: string): string {
    let cleaned = input.replace(/[\r\n\s]/g, '');
    let chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    let result = '';

    let i = 0;
    while (i < cleaned.length) {
      let a = cleaned[i];
      let b = cleaned[i + 1] || '=';
      let c = cleaned[i + 2] || '=';
      let d = cleaned[i + 3] || '=';

      let aIdx = chars.indexOf(a);
      let bIdx = chars.indexOf(b);
      let cIdx = chars.indexOf(c);
      let dIdx = chars.indexOf(d);

      if (aIdx === -1 || bIdx === -1) break;

      let triple = (aIdx << 18) + (bIdx << 12) +
        ((cIdx >= 0 ? cIdx : 0) << 6) +
        (dIdx >= 0 ? dIdx : 0);

      result += String.fromCharCode((triple >>> 16) & 0xFF);
      if (c !== '=') result += String.fromCharCode((triple >>> 8) & 0xFF);
      if (d !== '=') result += String.fromCharCode(triple & 0xFF);

      i += 4;
    }

    return result;
  }

  static async saveToFile(content: string): Promise<string> {
    const ctx = globalThis.appContext as common.UIAbilityContext;
    if (!ctx) return '';
    const cacheDir: string = ctx.cacheDir;
    const fileName = `proxy_subscription_${Date.now()}.yaml`;
    const filePath = cacheDir + '/' + fileName;
    try {
      const buf = new ArrayBuffer(content.length);
      const view = new Uint8Array(buf);
      for (let i = 0; i < content.length; i++) {
        view[i] = content.charCodeAt(i) & 0xFF;
      }
      const file = fileIo.openSync(filePath, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY);
      fileIo.writeSync(file.fd, buf);
      fileIo.closeSync(file);
      return fileName;
    } catch (err) {
      console.error('保存订阅文件失败:', err);
      return '';
    }
  }

  static getSavedFilePath(fileName: string): string {
    const ctx = globalThis.appContext as common.UIAbilityContext;
    if (!ctx) return '';
    return ctx.cacheDir + '/' + fileName;
  }
}
