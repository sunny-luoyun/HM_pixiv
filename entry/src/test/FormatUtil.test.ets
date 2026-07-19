import { describe, it, expect } from '@ohos/hypium';
import { formatFileSize } from '../main/ets/common/utils/FormatUtil';

export default function formatUtilTest() {
  describe('FormatUtil', () => {
    describe('formatFileSize', () => {
      it('0 字节应返回 "0 B"', 0, () => {
        expect(formatFileSize(0)).assertEqual('0 B');
      });

      it('负数应返回 "0 B"', 0, () => {
        expect(formatFileSize(-1)).assertEqual('0 B');
      });

      it('1023 字节应返回 "1023 B"', 0, () => {
        expect(formatFileSize(1023)).assertEqual('1023 B');
      });

      it('1024 字节应返回 "1.0 KB"', 0, () => {
        expect(formatFileSize(1024)).assertEqual('1.0 KB');
      });

      it('1536 字节应返回 "1.5 KB"', 0, () => {
        expect(formatFileSize(1536)).assertEqual('1.5 KB');
      });

      it('1048575 字节应返回 "1024.0 KB"', 0, () => {
        expect(formatFileSize(1048575)).assertEqual('1024.0 KB');
      });

      it('1 MB 应返回 "1.00 MB"', 0, () => {
        expect(formatFileSize(1048576)).assertEqual('1.00 MB');
      });

      it('1.5 MB 应返回 "1.50 MB"', 0, () => {
        expect(formatFileSize(1572864)).assertEqual('1.50 MB');
      });

      it('大量 MB 应正确格式化', 0, () => {
        expect(formatFileSize(10485760)).assertEqual('10.00 MB');
      });
    });
  });
}
