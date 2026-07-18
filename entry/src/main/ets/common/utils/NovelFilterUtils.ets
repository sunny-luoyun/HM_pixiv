export interface HasTags {
  tags: string[];
}

export function getSemanticTagCount(tags: string[]): number {
  let count = 0;
  for (const tag of tags) {
    const parts = tag.split('/');
    for (const p of parts) {
      if (p.length > 0) {
        count++;
      }
    }
  }
  return count;
}

export function filterByMaxTags<T extends HasTags>(items: T[], maxTags: number): T[] {
  if (maxTags <= 0) {
    return items;
  }
  const result: T[] = [];
  for (let i = 0; i < items.length; i++) {
    const item = items[i];
    if (getSemanticTagCount(item.tags) <= maxTags) {
      result.push(item);
    }
  }
  return result;
}
