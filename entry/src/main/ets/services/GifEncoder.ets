import fileIo from '@ohos.file.fs';
import image from '@ohos.multimedia.image';
import { BusinessError } from '@kit.BasicServicesKit';

interface RgbTriplet {
  r: number;
  g: number;
  b: number;
}

interface ColorEntry {
  key: number;
  count: number;
}

export class GifEncoder {

  static async createGifFromFramePaths(
    framePaths: string[],
    delays: number[],
    outputPath: string,
    imgWidth: number,
    imgHeight: number,
    frameStep: number = 2,
  ): Promise<boolean> {
    if (framePaths.length === 0 || delays.length === 0) {
      return false;
    }
    const t0: number = Date.now();
    const gifWidth: number = Math.ceil(imgWidth / 2);
    const gifHeight: number = Math.ceil(imgHeight / 2);
    console.info(`[DL] GifEncoder: ${framePaths.length} frames, ${gifWidth}x${gifHeight}, frameStep=${frameStep}`);

    const palette: RgbTriplet[] = await GifEncoder.buildPalette(framePaths, gifWidth, gifHeight);
    const t1: number = Date.now();
    console.info(`[DL] buildPalette: ${palette.length} colors in ${t1 - t0}ms`);
    if (palette.length < 2) {
      return false;
    }
    const lut: number[] = GifEncoder.buildLut(palette);
    const tLut: number = Date.now();
    console.info(`[DL] buildLut: ${lut.length} entries in ${tLut - t1}ms`);
    const paletteSize: number = GifEncoder.nextPow2(palette.length);
    const minCodeSize: number = Math.ceil(Math.log2(paletteSize));
    const bitsPerPalette: number = minCodeSize;

    const file = fileIo.openSync(outputPath, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY);
    const fd: number = file.fd;
    let frameCount: number = 0;
    try {
      GifEncoder.writeHeader(fd, gifWidth, gifHeight, palette, bitsPerPalette);
      const clearCode: number = 1 << bitsPerPalette;
      const totalEncode: number = Math.ceil(framePaths.length / frameStep);

      for (let fi: number = 0; fi < framePaths.length; fi += frameStep) {
        const ft0: number = Date.now();
        const indexed: Uint8Array = await GifEncoder.frameToIndexed(framePaths[fi], lut, gifWidth, gifHeight);
        if (indexed.length === 0) {
          continue;
        }
        const delayCs: number = Math.max(1, Math.round(delays[fi] / 10)) * frameStep;
        GifEncoder.writeGraphicsControlExt(fd, delayCs);
        GifEncoder.writeImageDescriptor(fd, gifWidth, gifHeight);
        GifEncoder.writeLzwData(fd, indexed, bitsPerPalette, clearCode);
        await GifEncoder.yieldToUi();
        frameCount++;
        if (frameCount % 10 === 0 || frameCount === totalEncode) {
          console.info(`[DL] encodeFrame [${frameCount}/${totalEncode}] frameIdx=${fi} took ${Date.now() - ft0}ms`);
        }
      }
      const trailer: Uint8Array = new Uint8Array([0x3B]);
      fileIo.writeSync(fd, trailer.buffer as ArrayBuffer);
    } catch (err) {
      console.error('GifEncoder: write failed ' + String(err));
      fileIo.closeSync(file);
      try { fileIo.unlinkSync(outputPath); } catch (_) {}
      return false;
    }
    fileIo.closeSync(file);
    console.info(`[DL] GifEncoder done: ${frameCount} frames in ${Date.now() - t0}ms`);
    return true;
  }

  private static yieldToUi(): Promise<void> {
    return new Promise<void>(resolve => setTimeout(resolve, 0));
  }

  private static async buildPalette(
    framePaths: string[],
    imgWidth: number,
    imgHeight: number,
  ): Promise<RgbTriplet[]> {
    const colorCount: Map<number, number> = new Map<number, number>();
    const sampleStride: number = 4;

    const processLimit: number = framePaths.length < 5 ? framePaths.length : 5;
    for (let fi: number = 0; fi < processLimit; fi++) {
      const pt0: number = Date.now();
      const indexed: Uint8Array | null = await GifEncoder.readRgbPixels(framePaths[fi], imgWidth, imgHeight);
      if (indexed === null) {
        continue;
      }
      for (let y: number = 0; y < imgHeight; y += sampleStride) {
        for (let x: number = 0; x < imgWidth; x += sampleStride) {
          const idx: number = (y * imgWidth + x) * 3;
          const r: number = indexed[idx];
          const g: number = indexed[idx + 1];
          const b: number = indexed[idx + 2];
          const key: number = ((r << 16) | (g << 8) | b);
          const existing: number | undefined = colorCount.get(key);
          colorCount.set(key, (existing ?? 0) + 1);
        }
      }
      console.info(`[DL] paletteSample frame ${fi}: ${Date.now() - pt0}ms`);
      await GifEncoder.yieldToUi();
    }

    const sorted: ColorEntry[] = [];
    colorCount.forEach((count: number, key: number) => {
      const entry: ColorEntry = { key: key, count: count };
      sorted.push(entry);
    });
    sorted.sort((a, b) => b.count - a.count);

    const maxColors: number = 256;
    const palette: RgbTriplet[] = [];
    const limit: number = sorted.length < maxColors ? sorted.length : maxColors;
    for (let i: number = 0; i < limit; i++) {
      const key: number = sorted[i].key;
      palette.push({
        r: (key >> 16) & 0xFF,
        g: (key >> 8) & 0xFF,
        b: key & 0xFF,
      });
    }

    if (palette.length === 0) {
      palette.push({ r: 0, g: 0, b: 0 });
      palette.push({ r: 255, g: 255, b: 255 });
    }
    return palette;
  }

  private static async readRgbPixels(
    filePath: string,
    w: number,
    h: number,
  ): Promise<Uint8Array | null> {
    const t0: number = Date.now();
    try {
      const imageSource: image.ImageSource = image.createImageSource(filePath);
      const pixelMap: image.PixelMap = await imageSource.createPixelMap({
        desiredSize: { width: w, height: h },
        desiredPixelFormat: image.PixelMapFormat.RGBA_8888,
      });
      const buf: ArrayBuffer = new ArrayBuffer(w * h * 4);
      await pixelMap.readPixelsToBuffer(buf);
      imageSource.release();
      const t1: number = Date.now();
      if (w > 200) {
        console.info(`[DL] readRgb ${filePath.slice(-30)} in ${t1 - t0}ms (${w}x${h})`);
      }
      const rgba: Uint8Array = new Uint8Array(buf);
      const rgb: Uint8Array = new Uint8Array(w * h * 3);
      let dstIdx: number = 0;
      for (let i: number = 0; i < rgba.length; i += 4) {
        rgb[dstIdx] = rgba[i];
        rgb[dstIdx + 1] = rgba[i + 1];
        rgb[dstIdx + 2] = rgba[i + 2];
        dstIdx += 3;
      }
      return rgb;
    } catch (err) {
      console.error('GifEncoder: readRgbPixels failed ' + String(err));
      return null;
    }
  }

  private static findNearestColor(r: number, g: number, b: number, palette: RgbTriplet[]): number {
    let bestIdx: number = 0;
    let bestDist: number = 999999999;
    for (let i: number = 0; i < palette.length; i++) {
      const dr: number = r - palette[i].r;
      const dg: number = g - palette[i].g;
      const db: number = b - palette[i].b;
      const dist: number = dr * dr + dg * dg + db * db;
      if (dist < bestDist) {
        bestDist = dist;
        bestIdx = i;
      }
    }
    return bestIdx;
  }

  private static buildLut(palette: RgbTriplet[]): number[] {
    const lut: number[] = new Array(32768);
    for (let r5: number = 0; r5 < 32; r5++) {
      for (let g5: number = 0; g5 < 32; g5++) {
        for (let b5: number = 0; b5 < 32; b5++) {
          const cr: number = r5 * 8 + 4;
          const cg: number = g5 * 8 + 4;
          const cb: number = b5 * 8 + 4;
          lut[(r5 << 10) | (g5 << 5) | b5] = GifEncoder.findNearestColor(cr, cg, cb, palette);
        }
      }
    }
    return lut;
  }

  private static async frameToIndexed(
    filePath: string,
    lut: number[],
    w: number,
    h: number,
  ): Promise<Uint8Array> {
    const rgb: Uint8Array | null = await GifEncoder.readRgbPixels(filePath, w, h);
    if (rgb === null) {
      return new Uint8Array(0);
    }
    const indexed: Uint8Array = new Uint8Array(w * h);
    for (let i: number = 0; i < w * h; i++) {
      const idx: number = i * 3;
      const r5: number = rgb[idx] >> 3;
      const g5: number = rgb[idx + 1] >> 3;
      const b5: number = rgb[idx + 2] >> 3;
      indexed[i] = lut[(r5 << 10) | (g5 << 5) | b5];
    }
    return indexed;
  }

  private static nextPow2(n: number): number {
    let v: number = 1;
    while (v < n) {
      v <<= 1;
    }
    return v;
  }

  private static writeByte(fd: number, b: number): void {
    const arr: Uint8Array = new Uint8Array([b & 0xFF]);
    fileIo.writeSync(fd, arr.buffer as ArrayBuffer);
  }

  private static writeShort(fd: number, v: number): void {
    const arr: Uint8Array = new Uint8Array([v & 0xFF, (v >> 8) & 0xFF]);
    fileIo.writeSync(fd, arr.buffer as ArrayBuffer);
  }

  private static writeBytes(fd: number, data: Uint8Array): void {
    fileIo.writeSync(fd, data.buffer as ArrayBuffer);
  }

  private static writeHeader(
    fd: number,
    width: number,
    height: number,
    palette: RgbTriplet[],
    bitsPerPalette: number,
  ): void {
    GifEncoder.writeBytes(fd, new Uint8Array([0x47, 0x49, 0x46, 0x38, 0x39, 0x61]));
    GifEncoder.writeShort(fd, width);
    GifEncoder.writeShort(fd, height);
    const colorTableSize: number = palette.length;
    const sizeField: number = bitsPerPalette - 1;
    const packed: number = 0x80 | (0x70 & (bitsPerPalette << 4)) | sizeField;
    GifEncoder.writeByte(fd, packed);
    GifEncoder.writeByte(fd, 0);
    GifEncoder.writeByte(fd, 0);
    for (let i: number = 0; i < colorTableSize; i++) {
      GifEncoder.writeByte(fd, palette[i].r);
      GifEncoder.writeByte(fd, palette[i].g);
      GifEncoder.writeByte(fd, palette[i].b);
    }
    for (let i: number = colorTableSize; i < (1 << bitsPerPalette); i++) {
      GifEncoder.writeByte(fd, 0);
      GifEncoder.writeByte(fd, 0);
      GifEncoder.writeByte(fd, 0);
    }
  }

  private static writeGraphicsControlExt(fd: number, delayCs: number): void {
    GifEncoder.writeBytes(fd, new Uint8Array([
      0x21, 0xF9, 0x04, 0x00,
      delayCs & 0xFF, (delayCs >> 8) & 0xFF,
      0x00, 0x00,
    ]));
  }

  private static writeImageDescriptor(fd: number, width: number, height: number): void {
    GifEncoder.writeByte(fd, 0x2C);
    GifEncoder.writeShort(fd, 0);
    GifEncoder.writeShort(fd, 0);
    GifEncoder.writeShort(fd, width);
    GifEncoder.writeShort(fd, height);
    GifEncoder.writeByte(fd, 0);
  }

  private static writeLzwData(
    fd: number,
    indexed: Uint8Array,
    bitsPerPalette: number,
    clearCode: number,
  ): void {
    const compressed: Uint8Array = GifEncoder.lzwEncode(indexed, bitsPerPalette, clearCode);
    GifEncoder.writeByte(fd, bitsPerPalette);
    let pos: number = 0;
    while (pos < compressed.length) {
      const blockSize: number = (compressed.length - pos) < 255 ? (compressed.length - pos) : 255;
      GifEncoder.writeByte(fd, blockSize);
      const block: Uint8Array = compressed.slice(pos, pos + blockSize);
      GifEncoder.writeBytes(fd, block);
      pos += blockSize;
    }
    GifEncoder.writeByte(fd, 0);
  }

  private static lzwEncode(
    indexed: Uint8Array,
    bitsPerPalette: number,
    clearCode: number,
  ): Uint8Array {
    const eoiCode: number = clearCode + 1;
    let nextCode: number = clearCode + 2;
    let bitWidth: number = bitsPerPalette + 1;
    const initTableSize: number = 1 << bitsPerPalette;

    const table: Map<number, number> = new Map<number, number>();

    const bits: number[] = [];
    let buffer: number = 0;
    let bufBits: number = 0;

    const writeCode = (code: number, nBits: number): void => {
      buffer |= (code << bufBits);
      bufBits += nBits;
      while (bufBits >= 8) {
        bits.push(buffer & 0xFF);
        buffer >>>= 8;
        bufBits -= 8;
      }
    };

    const resetTable = (): void => {
      table.clear();
      nextCode = clearCode + 2;
      bitWidth = bitsPerPalette + 1;
    };

    const flushBits = (): void => {
      if (bufBits > 0) {
        bits.push(buffer & 0xFF);
        buffer = 0;
        bufBits = 0;
      }
    };

    writeCode(clearCode, bitWidth);

    let prev: number = indexed[0];
    for (let i: number = 1; i < indexed.length; i++) {
      const pixel: number = indexed[i];
      const key: number = (prev << 8) | pixel;
      const existing: number | undefined = table.get(key);
      if (existing !== undefined) {
        prev = existing;
      } else {
        writeCode(prev, bitWidth);
        if (nextCode <= 4095) {
          table.set(key, nextCode);
          nextCode++;
          if (nextCode > (1 << bitWidth) && bitWidth < 12) {
            bitWidth++;
          }
          if (nextCode > 4095) {
            writeCode(clearCode, bitWidth);
            resetTable();
          }
        } else {
          writeCode(clearCode, bitWidth);
          resetTable();
        }
        prev = pixel;
      }
    }
    writeCode(prev, bitWidth);
    writeCode(eoiCode, bitWidth);
    flushBits();

    return new Uint8Array(bits);
  }
}
