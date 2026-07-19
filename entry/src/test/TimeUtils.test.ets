import { describe, it, expect } from '@ohos/hypium';
import { Date2UTCTimeString, toLocalISODateTime } from '../main/ets/common/utils/TimeUtils';

export default function timeUtilsTest() {
  describe('TimeUtils', () => {
    describe('Date2UTCTimeString', () => {
      it('应正确格式化 UTC 时间', 0, () => {
        const d = new Date('2025-06-20T12:30:45Z');
        expect(Date2UTCTimeString(d)).assertEqual('2025-06-20T12:30:45+00:00');
      });

      it('零值时间', 0, () => {
        const d = new Date('1970-01-01T00:00:00Z');
        expect(Date2UTCTimeString(d)).assertEqual('1970-01-01T00:00:00+00:00');
      });

      it('月份和日期补零', 0, () => {
        const d = new Date('2025-01-05T01:02:03Z');
        expect(Date2UTCTimeString(d)).assertEqual('2025-01-05T01:02:03+00:00');
      });
    });

    describe('toLocalISODateTime', () => {
      it('应包含日期和时间部分', 0, () => {
        const d = new Date(2025, 5, 20, 12, 30, 45);
        const result = toLocalISODateTime(d);
        expect(result.length).assertEqual(19);
        expect(result.charAt(10)).assertEqual('T');
      });

      it('格式为 yyyy-MM-ddTHH:mm:ss', 0, () => {
        const d = new Date(2024, 0, 1, 8, 5, 3);
        const result = toLocalISODateTime(d);
        expect(result).assertContain('2024-01-01T');
      });
    });
  });
}
