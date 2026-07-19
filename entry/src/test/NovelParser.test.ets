import { describe, it, expect } from '@ohos/hypium';
import { parsePixivBlocks, ContentBlock } from '../main/ets/common/utils/NovelParser';

export default function novelParserTest() {
  describe('NovelParser', () => {
    describe('parsePixivBlocks', () => {
      it('空字符串返回空数组', 0, () => {
        expect(parsePixivBlocks('').length).assertEqual(0);
      });

      it('普通段落解析', 0, () => {
        const blocks = parsePixivBlocks('这是一段普通文本');
        expect(blocks.length).assertEqual(1);
        expect(blocks[0].type).assertEqual('paragraph');
        expect(blocks[0].text).assertEqual('这是一段普通文本');
      });

      it('[newpage] 转换为 hr 块', 0, () => {
        const blocks = parsePixivBlocks('[newpage]');
        expect(blocks.length).assertEqual(1);
        expect(blocks[0].type).assertEqual('hr');
      });

      it('[chapter:] 解析为章节标题', 0, () => {
        const blocks = parsePixivBlocks('[chapter:第一章]');
        expect(blocks.length).assertEqual(1);
        expect(blocks[0].type).assertEqual('chapter');
        expect(blocks[0].text).assertEqual('第一章');
      });

      it('[chapter:] 中特殊字符正常', 0, () => {
        const blocks = parsePixivBlocks('[chapter:prologue - 序幕]');
        expect(blocks[0].text).assertEqual('prologue - 序幕');
      });

      it('[[rb:]] 注音标签应隐藏注音', 0, () => {
        const blocks = parsePixivBlocks('[[rb:漢字>かんじ]]');
        expect(blocks[0].text).assertEqual('漢字');
      });

      it('[b] 粗体标签应移除标记', 0, () => {
        const blocks = parsePixivBlocks('这是[b]重要[/b]内容');
        expect(blocks[0].text).assertEqual('这是重要内容');
      });

      it('[i] 斜体标签应移除标记', 0, () => {
        const blocks = parsePixivBlocks('这是[i]斜体[/i]文字');
        expect(blocks[0].text).assertEqual('这是斜体文字');
      });

      it('空行转换为 blank 块', 0, () => {
        const blocks = parsePixivBlocks('第一行\n\n第二行');
        expect(blocks.length).assertEqual(3);
        expect(blocks[0].text).assertEqual('第一行');
        expect(blocks[1].type).assertEqual('blank');
        expect(blocks[2].text).assertEqual('第二行');
      });

      it('[jump:] 标签应移除', 0, () => {
        const blocks = parsePixivBlocks('详情请参考[jump:https://example.com]');
        expect(blocks[0].text).assertEqual('详情请参考');
      });

      it('多个段落混合', 0, () => {
        const input = '[chapter:序章]\n\n这是第一段。\n\n[newpage]\n\n[b:粗体]';
        const blocks = parsePixivBlocks(input);
        expect(blocks.length >= 5).assertTrue();
        expect(blocks[0].type).assertEqual('chapter');
        expect(blocks[1].type).assertEqual('blank');
        expect(blocks[2].type).assertEqual('paragraph');
        expect(blocks[3].type).assertEqual('blank');
        expect(blocks[4].type).assertEqual('hr');
      });
    });
  });
}
