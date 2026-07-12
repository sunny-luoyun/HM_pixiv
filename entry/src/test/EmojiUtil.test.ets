import { describe, it, expect } from '@ohos/hypium';
import { convertPixivEmojis } from '../main/ets/common/utils/EmojiUtil';

export default function emojiUtilTest() {
  describe('EmojiUtil', () => {
    describe('convertPixivEmojis', () => {
      it('(heart) 转为 ❤️', 0, () => {
        const result: string = convertPixivEmojis('(heart)');
        expect(result).assertEqual('❤️');
      });

      it('(laugh) 转为 😄', 0, () => {
        const result: string = convertPixivEmojis('(laugh)');
        expect(result).assertEqual('😄');
      });

      it('(love2) 转为 🥰', 0, () => {
        const result: string = convertPixivEmojis('(love2)');
        expect(result).assertEqual('🥰');
      });

      it('(heart_eyes) 转为 😍', 0, () => {
        const result: string = convertPixivEmojis('(heart_eyes)');
        expect(result).assertEqual('😍');
      });

      it('(ok) 转为 👌', 0, () => {
        const result: string = convertPixivEmojis('(ok)');
        expect(result).assertEqual('👌');
      });

      it('连续多表情转换', 0, () => {
        const result: string = convertPixivEmojis('Hello (heart) (laugh) (good)');
        expect(result).assertEqual('Hello ❤️ 😄 👍');
      });

      it('含数字变体 love2 正常转换', 0, () => {
        const result: string = convertPixivEmojis('(love2) (heart2) (cry2)');
        expect(result).assertEqual('🥰 ❤️ 😢');
      });

      it('混合常规和变体表情', 0, () => {
        const result: string = convertPixivEmojis('Great! (love) (love2) (heart_eyes)');
        expect(result).assertEqual('Great! 🥰 🥰 😍');
      });

      it('未定义关键词保持原样', 0, () => {
        const result: string = convertPixivEmojis('(unknown_xyz)');
        expect(result).assertEqual('(unknown_xyz)');
      });

      it('空字符串返回空', 0, () => {
        const result: string = convertPixivEmojis('');
        expect(result).assertEqual('');
      });

      it('无表情文本保持不变', 0, () => {
        const text: string = 'This is a normal comment without emoji';
        const result: string = convertPixivEmojis(text);
        expect(result).assertEqual(text);
      });

      it('混合文本表情转换', 0, () => {
        const result: string = convertPixivEmojis('Great work! (heart) (good) (smile)');
        expect(result).assertEqual('Great work! ❤️ 👍 😊');
      });
    });
  });
}
