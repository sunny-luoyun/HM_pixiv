import cryptoFramework from '@ohos.security.cryptoFramework';
import buffer from '@ohos.buffer';

const KEY_DATA = new Uint8Array([
  0x2b, 0x7e, 0x15, 0x16, 0x28, 0xae, 0xd2, 0xa6,
  0xab, 0xf7, 0xcf, 0x5c, 0x88, 0x09, 0x3e, 0x7a
]);

function toBase64(bytes: Uint8Array): string {
  return buffer.from(bytes.buffer).toString('base64');
}

function fromBase64(str: string): Uint8Array {
  return new Uint8Array(buffer.from(str, 'base64').buffer);
}

async function getKey(): Promise<cryptoFramework.SymKey> {
  const generator = cryptoFramework.createSymKeyGenerator('AES128');
  return await generator.convertKey({ data: KEY_DATA, format: 'raw' });
}

export async function encryptAesGcm(plainText: string): Promise<string> {
  const key = await getKey();
  const cipher = cryptoFramework.createCipher('AES128|GCM|PKCS7');

  const random = cryptoFramework.createRandom();
  const ivBlob = await random.generateRandom(12);
  const iv = ivBlob.data as Uint8Array;

  await cipher.init(cryptoFramework.CryptoMode.ENCRYPT_MODE, key, { iv: { data: iv } });

  const plainBytes = new Uint8Array(buffer.from(plainText, 'utf-8').buffer);
  const result = await cipher.doFinal({ data: plainBytes });
  const ciphertext = result.data as Uint8Array;
  const authTag = cipher.getAuthTag();

  return `${toBase64(iv)}.${toBase64(authTag.data as Uint8Array)}.${toBase64(ciphertext)}`;
}

export async function decryptAesGcm(encrypted: string): Promise<string> {
  const parts = encrypted.split('.');
  if (parts.length !== 3) throw new Error('密文格式错误');

  const iv = fromBase64(parts[0]);
  const tag = fromBase64(parts[1]);
  const ciphertext = fromBase64(parts[2]);

  const key = await getKey();
  const cipher = cryptoFramework.createCipher('AES128|GCM|PKCS7');

  await cipher.init(cryptoFramework.CryptoMode.DECRYPT_MODE, key, {
    iv: { data: iv },
    authTag: { data: tag }
  });

  const result = await cipher.doFinal({ data: ciphertext });
  const plainBytes = result.data as Uint8Array;
  return buffer.from(plainBytes.buffer).toString('utf-8');
}
