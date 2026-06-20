import { describe, it, expect } from '@ohos/hypium';
import { SubscriptionService } from '../main/ets/services/SubscriptionService';

export default function subscriptionServiceTest() {
  describe('SubscriptionService', () => {

    describe('isValidBase64', () => {
      it('标准 Base64 字符串应返回 true', 0, () => {
        expect(SubscriptionService.isValidBase64('SGVsbG9Xb3JsZEFCQ0RFRkdISUpLTE1OT1BRUlNUVVZXWFlaMTIzNDU2Nzg5MA=='))
          .assertTrue();
      });

      it('过短的字符串应返回 false', 0, () => {
        expect(SubscriptionService.isValidBase64('abc')).assertFalse();
        expect(SubscriptionService.isValidBase64('')).assertFalse();
      });

      it('包含换行和空格的 Base64 应通过', 0, () => {
        expect(SubscriptionService.isValidBase64('SGVsbG9Xb3JsZEFC\nQ0RFRkdISUpLTE1O\nT1BRUlNUVVZXWFla\nMTIzNDU2Nzg5MA=='))
          .assertTrue();
      });

      it('非 Base64 字符应返回 false', 0, () => {
        expect(SubscriptionService.isValidBase64('これはBase64ではありません!!長さは十分にありますが')).assertFalse();
      });

      it('长度不是4的倍数（清理后）应返回 false', 0, () => {
        expect(SubscriptionService.isValidBase64('SGVsbG9Xb3JsZEFCQ0RFRkdISUpLTE1OT1BRUlNUVVZXWFlaMTIzNDU2Nzg5MA')).assertFalse();
      });
    });

    describe('base64Decode', () => {
      it('应正确解码 Hello World', 0, () => {
        const result = SubscriptionService.base64Decode('SGVsbG8gV29ybGQ=');
        expect(result).assertEqual('Hello World');
      });

      it('应正确解码含换行的 Base64', 0, () => {
        const result = SubscriptionService.base64Decode('SGVsbG8g\nV29ybGQ=');
        expect(result).assertEqual('Hello World');
      });

      it('应解码代理协议 URL', 0, () => {
        const result = SubscriptionService.base64Decode('c3M6Ly9leGFtcGxlLmNvbToxMjM0NQ==');
        expect(result).assertContain('ss://');
      });

      it('空字符串应返回空字符串', 0, () => {
        expect(SubscriptionService.base64Decode('')).assertEqual('');
      });

      it('应解码含 = 填充的 Base64', 0, () => {
        const result = SubscriptionService.base64Decode('dGVzdA==');
        expect(result).assertEqual('test');
      });
    });

    describe('isClashYaml', () => {
      it('含 port: 的行应识别为 Clash YAML', 0, () => {
        expect(SubscriptionService.isClashYaml('port: 7890\nsocks-port: 7891')).assertTrue();
      });

      it('含 mixed-port: 的行应识别为 Clash YAML', 0, () => {
        expect(SubscriptionService.isClashYaml('mixed-port: 7890')).assertTrue();
      });

      it('含 proxies: 的行应识别为 Clash YAML', 0, () => {
        expect(SubscriptionService.isClashYaml('proxies:\n  - name: Proxy1')).assertTrue();
      });

      it('含 proxy-groups: 的行应识别为 Clash YAML', 0, () => {
        expect(SubscriptionService.isClashYaml('proxy-groups:\n  - name: Auto')).assertTrue();
      });

      it('含 rules: 的行应识别为 Clash YAML', 0, () => {
        expect(SubscriptionService.isClashYaml('rules:\n  - MATCH,Proxy')).assertTrue();
      });

      it('普通代理链接列表不应识别为 Clash YAML', 0, () => {
        expect(SubscriptionService.isClashYaml('ss://Y2hhY2hhMjAtaWV0Zi1wb2x5MTMwNTo0NDM=')).assertFalse();
      });

      it('空字符串不应识别', 0, () => {
        expect(SubscriptionService.isClashYaml('')).assertFalse();
      });
    });

    describe('isProxyUrlList', () => {
      it('含 ss:// 链接应识别为代理列表', 0, () => {
        expect(SubscriptionService.isProxyUrlList('ss://Y2hhY2hhMjAtaWV0Zi1wb2x5MTMwNTo0NDM=')).assertTrue();
      });

      it('含 vmess:// 链接应识别为代理列表', 0, () => {
        expect(SubscriptionService.isProxyUrlList('vmess://eyJ2IjoiMiJ9')).assertTrue();
      });

      it('含 trojan:// 链接应识别为代理列表', 0, () => {
        expect(SubscriptionService.isProxyUrlList('trojan://password@server:443')).assertTrue();
      });

      it('含 vless:// 链接应识别为代理列表', 0, () => {
        expect(SubscriptionService.isProxyUrlList('vless://uuid@server:443')).assertTrue();
      });

      it('含 hysteria:// 链接应识别为代理列表', 0, () => {
        expect(SubscriptionService.isProxyUrlList('hysteria://server:443')).assertTrue();
      });

      it('Clash YAML 内容不应检测为代理列表', 0, () => {
        expect(SubscriptionService.isProxyUrlList('proxies:\n  - name: P\n    type: ss')).assertFalse();
      });

      it('空字符串不应识别', 0, () => {
        expect(SubscriptionService.isProxyUrlList('')).assertFalse();
      });
    });

    describe('detectFormat', () => {
      it('应正确识别 Clash YAML', 0, () => {
        const yaml = 'port: 7890\nproxies:\n  - name: test';
        expect(SubscriptionService.detectFormat(yaml)).assertEqual('yaml');
      });

      it('应正确识别 Base64 编码的 Clash YAML', 0, () => {
        const yaml = 'cG9ydDogNzg5MApwcm94aWVzOgogIC0gbmFtZTogdGVzdAo=';
        expect(SubscriptionService.detectFormat(yaml)).assertEqual('base64_yaml');
      });

      it('应正确识别纯代理 URL 列表', 0, () => {
        expect(SubscriptionService.detectFormat('ss://example.com:8080')).assertEqual('proxy_list');
      });

      it('应正确识别 Base64 编码的代理 URL 列表', 0, () => {
        const list = 'c3M6Ly9leGFtcGxlLmNvbToxMjM0NQ==';
        expect(SubscriptionService.detectFormat(list)).assertEqual('proxy_list');
      });

      it('无法识别的返回 unknown', 0, () => {
        expect(SubscriptionService.detectFormat('これはただのテキストです')).assertEqual('unknown');
        expect(SubscriptionService.detectFormat('')).assertEqual('unknown');
      });
    });
  });
}
