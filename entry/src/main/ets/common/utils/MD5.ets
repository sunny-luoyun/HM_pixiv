import cryptoFramework from '@ohos.security.cryptoFramework';
import buffer from '@ohos.buffer';

export async function md5String(text: string): Promise<string> {
  const md = cryptoFramework.createMd('MD5');
  const data = new Uint8Array(buffer.from(text, 'utf-8').buffer);
  await md.update({ data: data });
  const mdOutput = await md.digest();
  const hexArray: string[] = [];
  for (let i = 0; i < mdOutput.data.length; i++) {
    const byte = mdOutput.data[i];
    hexArray.push((byte >>> 4).toString(16));
    hexArray.push((byte & 0x0f).toString(16));
  }
  return hexArray.join('');
}
