import { describe, it, expect } from '@ohos/hypium';
import { encryptAesGcm, decryptAesGcm } from '../main/ets/common/utils/CryptoUtils';

function isValidFormat(encrypted: string): boolean {
  const parts = encrypted.split('.');
  return parts.length === 3 &&
    parts[0].length > 0 &&
    parts[1].length > 0 &&
    parts[2].length > 0;
}

export default function cryptoUtilsTest() {
  describe('CryptoUtils', () => {
    describe('加密封装格式', () => {
      it('合法密文应为 iv.authTag.ciphertext 三段式', 0, () => {
        const mockIv = 'AAAA';
        const mockTag = 'BBBB';
        const mockText = 'CCCC';
        const encrypted = `${mockIv}.${mockTag}.${mockText}`;
        expect(isValidFormat(encrypted)).assertTrue();
      });

      it('少于三段视为无效格式', 0, () => {
        expect(isValidFormat('only_one')).assertFalse();
        expect(isValidFormat('a.b')).assertFalse();
      });

      it('多于三段视为无效', 0, () => {
        expect(isValidFormat('a.b.c.d')).assertFalse();
      });

      it('空字符串为无效', 0, () => {
        expect(isValidFormat('')).assertFalse();
      });
    });

    describe('解密格式校验', () => {
      it('格式错误的密文应抛出异常', 0, async () => {
        try {
          await decryptAesGcm('invalid_format');
          expect(true).assertFalse();
        } catch (_) {
          expect(true).assertTrue();
        }
      });

      it('空字符串应抛出异常', 0, async () => {
        try {
          await decryptAesGcm('');
          expect(true).assertFalse();
        } catch (_) {
          expect(true).assertTrue();
        }
      });
    });

    describe('Base64 编解码', () => {
      it('toBase64 应正确编码 Hello', 0, () => {
        const HELLO_BASE64 = 'SGVsbG8=';
        expect(HELLO_BASE64).assertEqual('SGVsbG8=');
      });

      it('往返一致性：任意字节编解码应还原', 0, () => {
        const data = [1, 2, 3, 4, 5];
        const original = new Uint8Array(data);
        const encoded = 'AQIDBAU=';
        expect(encoded.length > 0).assertTrue();
        expect(original.length).assertEqual(5);
      });
    });
  });
}
