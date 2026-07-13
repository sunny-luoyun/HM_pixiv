import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import {
  UgoiraFrame,
  UgoiraMetaBody,
  UgoiraMetaResponse,
  ILLUST_TYPE_UGOIRA,
} from '../main/ets/models/PixivModels';

export default function ugoiraModelsTest() {
  describe('UgoiraModels', () => {

    describe('ILLUST_TYPE_UGOIRA 常量', () => {
      it('illarustType 值应为 2', 0, () => {
        expect(ILLUST_TYPE_UGOIRA).assertEqual(2);
      });
    });

    describe('UgoiraFrame 接口', () => {
      it('应能构造帧对象并读取字段', 0, () => {
        const frame: UgoiraFrame = { file: '000000.jpg', delay: 125 };
        expect(frame.file).assertEqual('000000.jpg');
        expect(frame.delay).assertEqual(125);
      });

      it('应支持不同的延时值', 0, () => {
        const frame: UgoiraFrame = { file: '000001.jpg', delay: 200 };
        expect(frame.delay).assertEqual(200);
      });
    });

    describe('UgoiraMetaBody 接口', () => {
      it('应包含完整字段', 0, () => {
        const frames: UgoiraFrame[] = [
          { file: '000000.jpg', delay: 125 },
          { file: '000001.jpg', delay: 125 },
        ];
        const body: UgoiraMetaBody = {
          src: 'https://i.pximg.net/img-zip-ugoira/1.zip',
          originalSrc: 'https://i.pximg.net/img-zip-ugoira/1_original.zip',
          mimeType: 'image/jpeg',
          frames: frames,
        };
        expect(body.src).assertEqual('https://i.pximg.net/img-zip-ugoira/1.zip');
        expect(body.originalSrc).assertEqual('https://i.pximg.net/img-zip-ugoira/1_original.zip');
        expect(body.mimeType).assertEqual('image/jpeg');
        expect(body.frames.length).assertEqual(2);
        expect(body.frames[0].file).assertEqual('000000.jpg');
      });

      it('应支持 mimeType 为 png', 0, () => {
        const body: UgoiraMetaBody = {
          src: 'https://i.pximg.net/img-zip-ugoira/2.zip',
          originalSrc: 'https://i.pximg.net/img-zip-ugoira/2_original.zip',
          mimeType: 'image/png',
          frames: [{ file: '000000.png', delay: 150 }],
        };
        expect(body.mimeType).assertEqual('image/png');
        expect(body.frames[0].file).assertEqual('000000.png');
      });

      it('空帧数组', 0, () => {
        const body: UgoiraMetaBody = {
          src: '',
          originalSrc: '',
          mimeType: '',
          frames: [],
        };
        expect(body.frames.length).assertEqual(0);
      });
    });

    describe('UgoiraMetaResponse 接口', () => {
      it('成功响应', 0, () => {
        const res: UgoiraMetaResponse = {
          error: false,
          body: {
            src: 'https://i.pximg.net/img-zip-ugoira/1.zip',
            originalSrc: '',
            mimeType: 'image/jpeg',
            frames: [{ file: '000000.jpg', delay: 125 }],
          },
        };
        expect(res.error).assertFalse();
        expect(res.body.frames[0].file).assertEqual('000000.jpg');
      });

      it('错误响应包含 message', 0, () => {
        const res: UgoiraMetaResponse = {
          error: true,
          message: 'not found',
          body: {
            src: '',
            originalSrc: '',
            mimeType: '',
            frames: [],
          },
        };
        expect(res.error).assertTrue();
        expect(res.message).assertEqual('not found');
      });
    });
  });
}
