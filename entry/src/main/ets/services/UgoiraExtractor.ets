import http from '@ohos.net.http';
import fileIo from '@ohos.file.fs';
import common from '@ohos.app.ability.common';
import { CookieManager } from './CookieManager';
import { ApiConfig } from '../common/constants/ApiConfig';
import { ProxyService } from './ProxyService';
import { UgoiraFrame } from '../models/PixivModels';

interface UgoiraCacheEntry {
  frameFileName: string;
  delay: number;
  localUri: string;
}

interface ZipEntryInfo {
  fileName: string;
  compressedSize: number;
  uncompressedSize: number;
  compressionMethod: number;
  localHeaderOffset: number;
}

const LOCAL_FILE_HEADER_SIG: number = 0x04034b50;
const CENTRAL_DIR_HEADER_SIG: number = 0x02014b50;
const END_CENTRAL_DIR_SIG: number = 0x06054b50;

export class UgoiraExtractor {

  static async extractUgoiraFrames(
    illustId: string,
    zipUrl: string,
    frames: UgoiraFrame[]
  ): Promise<UgoiraCacheEntry[]> {
    const t0: number = Date.now();
    const cacheDir: string = UgoiraExtractor.getUgoiraCacheDir(illustId);
    if (!cacheDir) {
      return [];
    }

    const existing: UgoiraCacheEntry[] = UgoiraExtractor.checkExistingFrames(cacheDir, frames);
    if (existing.length === frames.length) {
      console.info(`[DL] extractUgoiraFrames: cache hit (${existing.length} frames) in ${Date.now() - t0}ms`);
      return existing;
    }
    console.info(`[DL] extractUgoiraFrames: cache miss, need download ZIP`);

    const zipData: ArrayBuffer = await UgoiraExtractor.downloadZip(zipUrl);
    const t1: number = Date.now();
    console.info(`[DL] downloadZip: ${zipData.byteLength} bytes in ${t1 - t0}ms`);
    if (!zipData || zipData.byteLength === 0) {
      return [];
    }
    console.info(`[DL] parseZipEntries start...`);
    const entries: ZipEntryInfo[] = UgoiraExtractor.parseZipEntries(zipData);
    const t2: number = Date.now();
    console.info(`[DL] parseZipEntries: ${entries.length} entries in ${t2 - t1}ms`);
    if (entries.length === 0) {
      return [];
    }

    const extractDir: string = cacheDir + '/frames';
    UgoiraExtractor.ensureDir(extractDir);

    const result: UgoiraCacheEntry[] = [];
    for (let i: number = 0; i < frames.length; i++) {
      const frame: UgoiraFrame = frames[i];
      const entry: ZipEntryInfo | undefined = UgoiraExtractor.findEntry(entries, frame.file);
      if (entry === undefined) {
        continue;
      }
      const data: ArrayBuffer = UgoiraExtractor.readEntryData(zipData, entry);
      if (!data || data.byteLength === 0) {
        continue;
      }
      const outPath: string = extractDir + '/' + frame.file;
      UgoiraExtractor.writeFileSync(outPath, data);
      result.push({
        frameFileName: frame.file,
        delay: frame.delay,
        localUri: 'file://' + outPath,
      });
    }
    const t3: number = Date.now();
    console.info(`[DL] extractFrameFiles: ${result.length} frames written in ${t3 - t2}ms`);
    return result;
  }

  static async clearUgoiraCache(illustId: string): Promise<void> {
    const cacheDir: string = UgoiraExtractor.getUgoiraCacheDir(illustId);
    if (!cacheDir) {
      return;
    }
    try {
      const framesDir: string = cacheDir + '/frames';
      const files: string[] = fileIo.listFileSync(framesDir);
      for (let i: number = 0; i < files.length; i++) {
        try {
          fileIo.unlinkSync(framesDir + '/' + files[i]);
        } catch (_) {}
      }
      try {
        fileIo.rmdirSync(framesDir);
      } catch (_) {}
      try {
        const zipPath: string = cacheDir + '/ugoira.zip';
        fileIo.unlinkSync(zipPath);
      } catch (_) {}
    } catch (_) {}
  }

  private static getUgoiraCacheDir(illustId: string): string {
    const appContext = AppStorage.get<common.UIAbilityContext>('appContext');
    if (!appContext) {
      return '';
    }
    const dir: string = appContext.filesDir + '/ugoira_cache/' + illustId;
    UgoiraExtractor.ensureDir(dir);
    return dir;
  }

  private static ensureDir(dir: string): void {
    try {
      fileIo.mkdirSync(dir, true);
    } catch (_) {}
  }

  private static writeFileSync(path: string, data: ArrayBuffer): void {
    const file = fileIo.openSync(path, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY);
    fileIo.writeSync(file.fd, data);
    fileIo.closeSync(file);
  }

  private static checkExistingFrames(
    cacheDir: string,
    frames: UgoiraFrame[]
  ): UgoiraCacheEntry[] {
    const framesDir: string = cacheDir + '/frames';
    const result: UgoiraCacheEntry[] = [];
    for (let i: number = 0; i < frames.length; i++) {
      const frame: UgoiraFrame = frames[i];
      const p: string = framesDir + '/' + frame.file;
      try {
        const file = fileIo.openSync(p, fileIo.OpenMode.READ_ONLY);
        fileIo.closeSync(file);
        result.push({
          frameFileName: frame.file,
          delay: frame.delay,
          localUri: 'file://' + p,
        });
      } catch (_) {
        return [];
      }
    }
    return result;
  }

  private static async downloadZip(zipUrl: string): Promise<ArrayBuffer> {
    const cookie: string = await CookieManager.getFullCookie();
    const header: Record<string, string> = {
      'Referer': ApiConfig.REFERER,
      'User-Agent': ApiConfig.USER_AGENT,
    };
    if (cookie) {
      header['Cookie'] = cookie;
    }

    const proxyConfig = await ProxyService.getRequestProxyConfig();

    console.info('UgoiraExtractor: downloading ZIP (large file, may take mins)...');
    const httpRequest = http.createHttp();
    try {
      const resp = await httpRequest.request(zipUrl, {
        method: http.RequestMethod.GET,
        header: header,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        usingProxy: proxyConfig || false,
        connectTimeout: 60000,
        readTimeout: 300000,
      });
      if (resp.responseCode !== 200) {
        console.error('UgoiraExtractor: ZIP download failed HTTP ' + resp.responseCode);
        return new ArrayBuffer(0);
      }
      return resp.result as ArrayBuffer;
    } catch (err) {
      console.error('UgoiraExtractor: ZIP download error ' + String(err));
      return new ArrayBuffer(0);
    } finally {
      httpRequest.destroy();
    }
  }

  private static parseZipEntries(data: ArrayBuffer): ZipEntryInfo[] {
    const view: DataView = new DataView(data);
    const endOffset: number = UgoiraExtractor.findEndCentralDir(view);
    if (endOffset < 0) {
      return [];
    }
    const centralDirOffset: number = view.getUint32(endOffset + 16, true);
    const numEntries: number = view.getUint16(endOffset + 8, true);
    if (numEntries === 0) {
      return [];
    }
    const entries: ZipEntryInfo[] = [];
    let offset: number = centralDirOffset;
    for (let i: number = 0; i < numEntries; i++) {
      if (offset + 46 > data.byteLength) {
        break;
      }
      const sig: number = view.getUint32(offset, true);
      if (sig !== CENTRAL_DIR_HEADER_SIG) {
        break;
      }
      const compressionMethod: number = view.getUint16(offset + 10, true);
      const compressedSize: number = view.getUint32(offset + 20, true);
      const uncompressedSize: number = view.getUint32(offset + 24, true);
      const fileNameLen: number = view.getUint16(offset + 28, true);
      const extraLen: number = view.getUint16(offset + 30, true);
      const commentLen: number = view.getUint16(offset + 32, true);
      const localHeaderOffset: number = view.getUint32(offset + 42, true);
      let fileName: string = '';
      if (fileNameLen > 0) {
        const bytes: Uint8Array = new Uint8Array(data, offset + 46, fileNameLen);
        fileName = '';
        for (let j: number = 0; j < bytes.length; j++) {
          fileName += String.fromCharCode(bytes[j]);
        }
      }
      entries.push({
        fileName: fileName,
        compressedSize: compressedSize,
        uncompressedSize: uncompressedSize,
        compressionMethod: compressionMethod,
        localHeaderOffset: localHeaderOffset,
      });
      offset += 46 + fileNameLen + extraLen + commentLen;
    }
    return entries;
  }

  private static findEndCentralDir(view: DataView): number {
    const len: number = view.byteLength;
    const searchStart: number = Math.max(0, len - 65557);
    for (let i: number = len - 22; i >= searchStart; i--) {
      if (view.getUint32(i, true) === END_CENTRAL_DIR_SIG) {
        return i;
      }
    }
    return -1;
  }

  private static readEntryData(data: ArrayBuffer, entry: ZipEntryInfo): ArrayBuffer {
    const view: DataView = new DataView(data);
    const offset: number = entry.localHeaderOffset;
    if (offset + 30 > data.byteLength) {
      return new ArrayBuffer(0);
    }
    const sig: number = view.getUint32(offset, true);
    if (sig !== LOCAL_FILE_HEADER_SIG) {
      return new ArrayBuffer(0);
    }
    const fileNameLen: number = view.getUint16(offset + 26, true);
    const extraLen: number = view.getUint16(offset + 28, true);
    const dataStart: number = offset + 30 + fileNameLen + extraLen;
    if (entry.compressionMethod === 0) {
      const size: number = entry.uncompressedSize > 0 ? entry.uncompressedSize : entry.compressedSize;
      if (dataStart + size > data.byteLength) {
        return new ArrayBuffer(0);
      }
      return data.slice(dataStart, dataStart + size);
    }
    if (entry.compressionMethod === 8 && entry.compressedSize > 0) {
      if (dataStart + entry.compressedSize > data.byteLength) {
        return new ArrayBuffer(0);
      }
      const compressed: ArrayBuffer = data.slice(dataStart, dataStart + entry.compressedSize);
      try {
        return UgoiraExtractor.inflateData(compressed, entry.uncompressedSize);
      } catch (_) {
        return new ArrayBuffer(0);
      }
    }
    return new ArrayBuffer(0);
  }

  private static findEntry(entries: ZipEntryInfo[], fileName: string): ZipEntryInfo | undefined {
    for (let i: number = 0; i < entries.length; i++) {
      const entry: ZipEntryInfo = entries[i];
      if (entry.fileName === fileName || entry.fileName.endsWith('/' + fileName)) {
        return entry;
      }
    }
    return undefined;
  }

  private static inflateData(compressed: ArrayBuffer, uncompressedSize: number): ArrayBuffer {
    console.warn('UgoiraExtractor: DEFLATE entries not yet supported, returning blank buffer');
    return new ArrayBuffer(uncompressedSize > 0 ? uncompressedSize : 1);
  }
}
