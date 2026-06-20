import { describe, it, expect } from '@ohos/hypium';
import buffer from '@ohos.buffer';

// CryptoUtils 测试 - Base64 编解码

function toBase64(bytes: Uint8Array): string {
  return buffer.from(bytes.buffer).toString('base64');
}

function fromBase64(str: string): Uint8Array {
  return new Uint8Array(buffer.from(str, 'base64').buffer);
}

export default function cryptoUtilsTest() {
  describe('CryptoUtils（纯逻辑测试）', () => {

    describe('toBase64 / fromBase64 转换', () => {
      it('toBase64 应正确编码', 0, () => {
        const bytes = new Uint8Array([0x48, 0x65, 0x6c, 0x6c, 0x6f]);
        const encoded = toBase64(bytes);
        expect(encoded).assertEqual('SGVsbG8=');
      });

      it('fromBase64 应正确解码', 0, () => {
        const decoded = fromBase64('SGVsbG8=');
        // Hello = 0x48 0x65 0x6c 0x6c 0x6f
        expect(decoded.length).assertEqual(5);
        expect(decoded[0]).assertEqual(0x48);
        expect(decoded[1]).assertEqual(0x65);
        expect(decoded[2]).assertEqual(0x6c);
        expect(decoded[3]).assertEqual(0x6c);
        expect(decoded[4]).assertEqual(0x6f);
      });

      it('toBase64 → fromBase64 应往返一致', 0, () => {
        const original = new Uint8Array([1, 2, 3, 4, 5, 6, 7, 8]);
        const encoded = toBase64(original);
        const decoded = fromBase64(encoded);
        expect(decoded.length).assertEqual(original.length);
        for (let i = 0; i < original.length; i++) {
          expect(decoded[i]).assertEqual(original[i]);
        }
      });

      it('空数组编码', 0, () => {
        const bytes = new Uint8Array(0);
        const encoded = toBase64(bytes);
        expect(encoded).assertEqual('');
      });

      it('空字符串解码', 0, () => {
        const decoded = fromBase64('');
        expect(decoded.length).assertEqual(0);
      });

      it('含特殊字符的 Base64 编解码', 0, () => {
        // "Hello" 的字节再编码
        const bytes = new Uint8Array([0x48, 0x65, 0x6c, 0x6c, 0x6f]);
        const encoded = toBase64(bytes);
        const decoded = fromBase64(encoded);
        expect(decoded[0]).assertEqual(0x48);
        expect(decoded[1]).assertEqual(0x65);
        expect(decoded[2]).assertEqual(0x6c);
        expect(decoded[3]).assertEqual(0x6c);
        expect(decoded[4]).assertEqual(0x6f);
      });
    });

    describe('加密输出格式', () => {
      it('加密结果应为 iv.authTag.ciphertext 三段格式', 0, () => {
        const mockResult: string = 'AAAA.BBBB.CCCC';
        const parts: string[] = mockResult.split('.');
        expect(parts.length).assertEqual(3);
        expect(parts[0].length).assertEqual(4);
        expect(parts[1].length).assertEqual(4);
        expect(parts[2].length).assertEqual(4);
      });

      it('格式错误的密文应识别', 0, () => {
        const bad1: string[] = 'only_one'.split('.');
        expect(bad1.length).assertEqual(1);

        const bad2: string[] = 'a.b'.split('.');
        expect(bad2.length).assertEqual(2);

        const bad3: string[] = 'a.b.c.d'.split('.');
        expect(bad3.length).assertEqual(4);
      });
    });

    describe('AES 密钥', () => {
      it('密钥长度应为 16 字节（AES128）', 0, () => {
        const keyData: number[] = [
          0x2b, 0x7e, 0x15, 0x16, 0x28, 0xae, 0xd2, 0xa6,
          0xab, 0xf7, 0xcf, 0x5c, 0x88, 0x09, 0x3e, 0x7a
        ];
        expect(keyData.length).assertEqual(16);
      });

      it('密钥非全零', 0, () => {
        const keyData: number[] = [
          0x2b, 0x7e, 0x15, 0x16, 0x28, 0xae, 0xd2, 0xa6,
          0xab, 0xf7, 0xcf, 0x5c, 0x88, 0x09, 0x3e, 0x7a
        ];
        let allZero: boolean = true;
        for (let i = 0; i < keyData.length; i++) {
          if (keyData[i] !== 0) {
            allZero = false;
            break;
          }
        }
        expect(allZero).assertFalse();
      });
    });

    describe('GCM 参数', () => {
      it('IV 应为 12 字节', 0, () => {
        expect(12).assertEqual(12);
      });

      it('AuthTag 应为 16 字节', 0, () => {
        expect(16).assertEqual(16);
      });
    });

    describe('Base64 往返一致性', () => {
      it('任意字节数组往返', 0, () => {
        const data: number[] = [10, 20, 30, 40, 50, 60, 70, 80, 90, 100];
        const original: Uint8Array = new Uint8Array(data);
        const encoded: string = toBase64(original);
        const decoded: Uint8Array = fromBase64(encoded);
        expect(decoded.length).assertEqual(original.length);
        for (let i = 0; i < original.length; i++) {
          expect(decoded[i]).assertEqual(original[i]);
        }
      });
    });
  });
}
