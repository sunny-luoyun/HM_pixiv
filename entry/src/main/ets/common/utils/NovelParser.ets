export type BlockType = 'paragraph' | 'chapter' | 'hr' | 'blank';

export interface ContentBlock {
  type: BlockType;
  text: string;
  bold?: boolean;
  italic?: boolean;
}

export function parsePixivBlocks(raw: string): ContentBlock[] {
  if (!raw) return [];
  const blocks: ContentBlock[] = [];
  const lines = raw.split('\n');

  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed) {
      blocks.push({ type: 'blank', text: '', bold: false, italic: false });
      continue;
    }
    if (trimmed === '[newpage]') {
      blocks.push({ type: 'hr', text: '', bold: false, italic: false });
      continue;
    }
    const chapterMatch = trimmed.match(/^\[chapter:(.*?)\]$/);
    if (chapterMatch) {
      blocks.push({ type: 'chapter', text: chapterMatch[1], bold: false, italic: false });
      continue;
    }
    let text = trimmed
      .replace(/\[\[rb:(.*?)>(.*?)\]\]/g, '$1')
      .replace(/\[b\]([\s\S]*?)\[\/b\]/g, '$1')
      .replace(/\[i\]([\s\S]*?)\[\/i\]/g, '$1')
      .replace(/\[jump:(.*?)\]/g, '')
      .replace(/\[[^\]]*\]/g, '');
    if (!text.trim()) continue;
    const hasBold = /\[b\]/.test(line);
    const hasItalic = /\[i\]/.test(line);
    blocks.push({ type: 'paragraph', text: text, bold: hasBold, italic: hasItalic });
  }
  return blocks;
}
