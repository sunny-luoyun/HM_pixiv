import util from '@ohos.util';
import common from '@ohos.app.ability.common';

interface TokenizerData {
  rankLookup: Map<string, number>;
  resultLookup: Map<string, number>;
  byteTokenIds: Int32Array;
}

const RAW_FILE_NAME = 'deepseek_tokenizer.bin';

export class DeepSeekTokenizer {
  private data: TokenizerData | null = null;

  private async loadFromRawFile(context: common.UIAbilityContext): Promise<Uint8Array> {
    const mgr = context.resourceManager;
    return await mgr.getRawFileContent(RAW_FILE_NAME);
  }

  private parseData(buf: Uint8Array): TokenizerData {
    const view = new DataView(buf.buffer, buf.byteOffset, buf.byteLength);
    let offset = 0;

    const magic = String.fromCharCode(buf[0], buf[1], buf[2], buf[3]);
    if (magic !== 'DSKT') {
      throw new Error(`Invalid tokenizer data: bad magic`);
    }
    offset += 4;

    const version = view.getInt32(offset, true); offset += 4;
    const vocabSize = view.getInt32(offset, true); offset += 4;
    const mergesSize = view.getInt32(offset, true); offset += 4;
    offset += 4;

    // Skip vocab section
    const vocabDataLen = view.getInt32(offset, true); offset += 4;
    offset += vocabDataLen;

    // Parse merge entries: id1(4B), id2(4B), mergedId(4B)
    const rankLookup = new Map<string, number>();
    const resultLookup = new Map<string, number>();
    for (let i = 0; i < mergesSize; i++) {
      const id1 = view.getInt32(offset, true); offset += 4;
      const id2 = view.getInt32(offset, true); offset += 4;
      const mergedId = view.getInt32(offset, true); offset += 4;
      const key = id1 + ',' + id2;
      rankLookup.set(key, i);
      resultLookup.set(key, mergedId);
    }

    // Byte token IDs
    const byteTokenIds = new Int32Array(256);
    for (let b = 0; b < 256; b++) {
      byteTokenIds[b] = view.getInt32(offset, true); offset += 4;
    }

    return { rankLookup, resultLookup, byteTokenIds };
  }

  async init(context: common.UIAbilityContext): Promise<void> {
    const raw = await this.loadFromRawFile(context);
    this.data = this.parseData(raw);
  }

  private getData(): TokenizerData {
    if (!this.data) {
      throw new Error('DeepSeekTokenizer not initialized');
    }
    return this.data;
  }

  private splitByPattern(text: string, pattern: string): string[] {
    const result: string[] = [];
    const regex = new RegExp(pattern, 'gu');
    let lastIndex = 0;
    while (true) {
      const match = regex.exec(text);
      if (match === null) {
        break;
      }
      const idx = match.index;
      if (idx > lastIndex) {
        result.push(text.slice(lastIndex, idx));
      }
      result.push(match[0]);
      lastIndex = idx + match[0].length;
    }
    if (lastIndex < text.length) {
      result.push(text.slice(lastIndex));
    }
    return result;
  }

  private preTokenize(text: string): string[] {
    let parts: string[] = [text];
    let splitResult: string[] = [];

    for (let pi = 0; pi < parts.length; pi++) {
      const s = this.splitByPattern(parts[pi], '\\p{N}{1,3}');
      for (let si = 0; si < s.length; si++) {
        splitResult.push(s[si]);
      }
    }
    parts = splitResult;
    splitResult = [];

    for (let pi = 0; pi < parts.length; pi++) {
      const s = this.splitByPattern(parts[pi], '[\\u4e00-\\u9fa5\\u3040-\\u309f\\u30a0-\\u30ff]+');
      for (let si = 0; si < s.length; si++) {
        splitResult.push(s[si]);
      }
    }
    parts = splitResult;
    splitResult = [];

    const complex = "[!\"#$%&'()*+,\\-./:;<=>?@\\[\\\\\\]^_`{|}~][A-Za-z]+|[^\\r\\n\\p{L}\\p{P}\\p{S}]?[\\p{L}\\p{M}]+| ?[\\p{P}\\p{S}]+[\\r\\n]*|\\s*[\\r\\n]+|\\s+(?!\\S)|\\s+";
    for (let pi = 0; pi < parts.length; pi++) {
      const s = this.splitByPattern(parts[pi], complex);
      for (let si = 0; si < s.length; si++) {
        splitResult.push(s[si]);
      }
    }
    parts = splitResult;

    const filtered: string[] = [];
    for (let i = 0; i < parts.length; i++) {
      if (parts[i].length > 0) {
        filtered.push(parts[i]);
      }
    }
    return filtered;
  }

  private utf8Encode(text: string): Uint8Array {
    const encoder = new util.TextEncoder();
    return encoder.encodeInto(text);
  }

  private bpeMerge(tokenIds: number[]): number[] {
    const data = this.getData();
    const ids = tokenIds.slice();

    while (ids.length > 1) {
      let bestRank = Infinity;
      let bestIdx = -1;
      let bestMergedId = 0;

      for (let i = 0; i < ids.length - 1; i++) {
        const key = ids[i] + ',' + ids[i + 1];
        const rank = data.rankLookup.get(key);
        if (rank !== undefined && rank < bestRank) {
          const mergedId = data.resultLookup.get(key);
          if (mergedId !== undefined) {
            bestRank = rank;
            bestIdx = i;
            bestMergedId = mergedId;
          }
        }
      }

      if (bestIdx === -1) {
        break;
      }

      ids[bestIdx] = bestMergedId;
      ids.splice(bestIdx + 1, 1);
    }

    return ids;
  }

  encode(text: string): number[] {
    const data = this.getData();
    const words = this.preTokenize(text);
    const result: number[] = [];

    for (let wi = 0; wi < words.length; wi++) {
      const bytes = this.utf8Encode(words[wi]);
      const tokenIds: number[] = new Array(bytes.length);
      for (let i = 0; i < bytes.length; i++) {
        tokenIds[i] = data.byteTokenIds[bytes[i]];
      }
      const merged = this.bpeMerge(tokenIds);
      for (let i = 0; i < merged.length; i++) {
        result.push(merged[i]);
      }
    }

    return result;
  }

  countTokens(text: string): number {
    const data = this.getData();
    const words = this.preTokenize(text);
    let total = 0;

    for (let wi = 0; wi < words.length; wi++) {
      const bytes = this.utf8Encode(words[wi]);
      const tokenIds: number[] = new Array(bytes.length);
      for (let i = 0; i < bytes.length; i++) {
        tokenIds[i] = data.byteTokenIds[bytes[i]];
      }
      total += this.bpeMerge(tokenIds).length;
    }

    return total;
  }
}

let _instance: DeepSeekTokenizer | null = null;

export async function getDeepSeekTokenizer(context: common.UIAbilityContext): Promise<DeepSeekTokenizer> {
  if (!_instance) {
    _instance = new DeepSeekTokenizer();
    await _instance.init(context);
  }
  return _instance;
}
