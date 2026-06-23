import http from '@ohos.net.http';
import fileIo from '@ohos.file.fs';
import common from '@ohos.app.ability.common';
import photoAccessHelper from '@ohos.file.photoAccessHelper';
import { Context } from '@kit.AbilityKit';
import image from '@ohos.multimedia.image';
import { CookieManager } from './CookieManager';
import { ApiConfig } from '../common/constants/ApiConfig';
import { ProxyService } from './ProxyService';

interface DownloadTask {
  resolve: (value: boolean) => void;
  url: string;
  savePath: string;
  groupId?: string;
}

interface CacheCategoryInfo {
  size: number;
  count: number;
}

interface AllImageCacheInfo {
  illust: CacheCategoryInfo;
  novel: CacheCategoryInfo;
  avatar: CacheCategoryInfo;
}

export class ImageCacheService {
  private static maxConcurrentDownloads = 3;
  private static activeDownloads = 0;
  private static downloadQueue: Array<DownloadTask> = [];

  private static async enqueueDownload(url: string, savePath: string, groupId?: string): Promise<boolean> {
    return new Promise<boolean>((resolve) => {
      ImageCacheService.downloadQueue.push({ resolve, url, savePath, groupId });
      ImageCacheService.processQueue();
    });
  }

  private static processQueue() {
    while (ImageCacheService.activeDownloads < ImageCacheService.maxConcurrentDownloads && ImageCacheService.downloadQueue.length > 0) {
      const task = ImageCacheService.downloadQueue.shift()!;
      ImageCacheService.activeDownloads++;
      ImageCacheService.doDownload(task.url, task.savePath).then((result) => {
        task.resolve(result);
        ImageCacheService.activeDownloads--;
        ImageCacheService.processQueue();
      });
    }
  }

  private static async doDownload(imageUrl: string, savePath: string): Promise<boolean> {
    const cookie = await CookieManager.getFullCookie();
    try {
      const header: Record<string, string> = {
        'Referer': ApiConfig.REFERER,
        'User-Agent': ApiConfig.USER_AGENT,
      };
      if (cookie) header['Cookie'] = cookie;

      const proxyConfig = await ProxyService.getRequestProxyConfig();

      const httpRequest = http.createHttp();
      try {
        const resp = await httpRequest.request(imageUrl, {
          method: http.RequestMethod.GET,
          header,
          expectDataType: http.HttpDataType.ARRAY_BUFFER,
          usingProxy: proxyConfig || false,
          connectTimeout: 15000,
          readTimeout: 30000,
        });
        if (resp.responseCode !== 200) {
          console.error(`❌ 下载图片失败 HTTP ${resp.responseCode}:`, imageUrl);
          return false;
        }
        const buf = resp.result as ArrayBuffer;
        if (!buf || buf.byteLength === 0) {
          console.error('❌ 下载图片为空:', imageUrl);
          return false;
        }
        const file = fileIo.openSync(savePath, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY);
        fileIo.writeSync(file.fd, buf);
        fileIo.closeSync(file);

        const ext = ImageCacheService.detectImageExt(savePath);
        if (!ext) {
          console.error('❌ 下载的文件不是有效图片，删除:', savePath);
          try { fileIo.unlinkSync(savePath); } catch (_) {}
          return false;
        }
        if (proxyConfig) {
          console.info(`🔗 通过代理 ${proxyConfig.host}:${proxyConfig.port} 下载图片:`, savePath);
        } else {
          console.info('✅ 图片下载完成:', savePath);
        }
        return true;
      } finally {
        httpRequest.destroy();
      }
    } catch (err) {
      console.error('❌ 下载图片失败:', err);
      return false;
    }
  }

  static async downloadImage(imageUrl: string, savePath: string, groupId?: string): Promise<boolean> {
    return ImageCacheService.enqueueDownload(imageUrl, savePath, groupId);
  }

  static async downloadImageDirect(imageUrl: string, savePath: string): Promise<boolean> {
    return ImageCacheService.doDownload(imageUrl, savePath);
  }

  static async cacheImage(url: string, fileName: string, groupId?: string): Promise<string> {
    const cacheDir: string = ImageCacheService.getCacheDir();
    if (!cacheDir) return '';
    const localPath = cacheDir + '/' + fileName;

    try {
      const file = fileIo.openSync(localPath, fileIo.OpenMode.READ_ONLY);
      fileIo.closeSync(file);
      const ext = ImageCacheService.detectImageExt(localPath);
      if (ext) {
        return 'file://' + localPath;
      }
      fileIo.unlinkSync(localPath);
    } catch (_) {}

    const success = await ImageCacheService.downloadImage(url, localPath, groupId);
    if (!success) {
      try { fileIo.unlinkSync(localPath); } catch (_) {}
      return '';
    }
    return 'file://' + localPath;
  }

  static cancelDownloadGroup(groupId: string): void {
    const remaining: Array<DownloadTask> = [];
    for (const task of ImageCacheService.downloadQueue) {
      if (task.groupId === groupId) {
        task.resolve(false);
      } else {
        remaining.push(task);
      }
    }
    ImageCacheService.downloadQueue = remaining;
  }

  static detectImageExt(filePath: string): string | null {
    try {
      const file = fileIo.openSync(filePath, fileIo.OpenMode.READ_ONLY);
      const buf = new ArrayBuffer(8);
      fileIo.readSync(file.fd, buf);
      fileIo.closeSync(file);
      const arr = new Uint8Array(buf);
      if (arr[0] === 0x89 && arr[1] === 0x50 && arr[2] === 0x4E && arr[3] === 0x47) return 'png';
      if (arr[0] === 0xFF && arr[1] === 0xD8 && arr[2] === 0xFF) return 'jpg';
      if (arr[0] === 0x47 && arr[1] === 0x49 && arr[2] === 0x46) return 'gif';
      if (arr[0] === 0x52 && arr[1] === 0x49 && arr[2] === 0x46 && arr[3] === 0x46) return 'webp';
      if (arr[0] === 0x42 && arr[1] === 0x4D) return 'bmp';
      return null;
    } catch (_) {
      return null;
    }
  }

  static async saveImageToGallery(context: Context, source: string, fileName: string): Promise<boolean> {
    if (!source) {
      console.error('saveImageToGallery: 图片源为空');
      return false;
    }
    let filePath: string;
    if (source.startsWith('file://')) {
      filePath = source.slice(7);
    } else {
      const cachePath = await ImageCacheService.cacheImage(source, fileName);
      if (!cachePath) return false;
      filePath = cachePath.replace('file://', '');
    }
    try {
      const ext = ImageCacheService.detectImageExt(filePath);
      if (!ext) {
        console.error('保存到相册: 下载的文件不是可识别的图片格式');
        return false;
      }
      const helper = photoAccessHelper.getPhotoAccessHelper(context);
      const uri = await helper.createAsset(photoAccessHelper.PhotoType.IMAGE, ext);
      const dstFile = fileIo.openSync(uri, fileIo.OpenMode.WRITE_ONLY);
      const srcFile = fileIo.openSync(filePath, fileIo.OpenMode.READ_ONLY);
      fileIo.copyFileSync(srcFile.fd, dstFile.fd);
      fileIo.closeSync(srcFile);
      fileIo.closeSync(dstFile);
      console.info('✅ 图片已保存到相册:', fileName);
      return true;
    } catch (err) {
      console.error('保存到相册失败:', err);
      return false;
    }
  }

  static getCacheDir(): string {
    const appContext = AppStorage.get<common.UIAbilityContext>('appContext');
    if (!appContext) return '';
    const imageDir = appContext.filesDir + '/image_cache';
    try {
      fileIo.mkdirSync(imageDir, true);
    } catch (_) {}
    return imageDir;
  }

  static async getCategoryCacheInfo(prefix: string): Promise<CacheCategoryInfo> {
    const cacheDir = ImageCacheService.getCacheDir();
    if (!cacheDir) return { size: 0, count: 0 };

    let totalSize = 0;
    let totalCount = 0;

    try {
      const files = fileIo.listFileSync(cacheDir);
      for (const fileName of files) {
        if (fileName.startsWith(prefix)) {
          try {
            const stat = fileIo.statSync(cacheDir + '/' + fileName);
            totalSize += stat.size as number || 0;
            totalCount++;
          } catch (_) {}
        }
      }
    } catch (_) {}

    return { size: totalSize, count: totalCount };
  }

  static async clearCategoryCache(prefix: string, excludeFileName?: string): Promise<number> {
    const cacheDir = ImageCacheService.getCacheDir();
    if (!cacheDir) return 0;

    let deletedCount = 0;

    try {
      const files = fileIo.listFileSync(cacheDir);
      for (const fileName of files) {
        if (fileName.startsWith(prefix) && fileName !== excludeFileName) {
          try {
            fileIo.unlinkSync(cacheDir + '/' + fileName);
            deletedCount++;
          } catch (_) {}
        }
      }
    } catch (_) {}

    return deletedCount;
  }

  static async clearAllImageCache(excludeAvatarFile?: string): Promise<void> {
    await ImageCacheService.clearCategoryCache('illust_');
    await ImageCacheService.clearCategoryCache('novel_');
    await ImageCacheService.clearCategoryCache('user_');
    await ImageCacheService.clearCategoryCache('avatar_', excludeAvatarFile);
  }

  static async extractDominantColor(filePath: string): Promise<string> {
    try {
      const imageSource = image.createImageSource(filePath);
      const pixelMap = await imageSource.createPixelMap({
        desiredSize: { width: 8, height: 8 }
      });
      const buffer = new ArrayBuffer(8 * 8 * 4);
      await pixelMap.readPixelsToBuffer(buffer);

      const pixels = new Uint8Array(buffer);
      let r = 0, g = 0, b = 0, count = 0;
      for (let i = 0; i < pixels.length; i += 4) {
        r += pixels[i];
        g += pixels[i + 1];
        b += pixels[i + 2];
        count++;
      }
      r = Math.round(r / count);
      g = Math.round(g / count);
      b = Math.round(b / count);

      imageSource.release();
      const toHex = (n: number): string => n.toString(16).padStart(2, '0');
      return `#${toHex(r)}${toHex(g)}${toHex(b)}`;
    } catch (err) {
      console.error('提取图片主色失败:', err);
      return '';
    }
  }
}
