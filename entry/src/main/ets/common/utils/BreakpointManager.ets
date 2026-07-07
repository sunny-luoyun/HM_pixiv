export const BREAKPOINT_KEY = 'currentBreakpoint';

const BP_NAMES: string[] = ['xs', 'sm', 'md', 'lg', 'xl', 'xxl'];
const BP_MINS: number[] = [0, 320, 600, 840, 1440];
const COLUMN_VALUES: number[] = [2, 2, 4, 4, 6, 6];

function indexOfBreakpoint(bp: string): number {
  for (let i = 0; i < BP_NAMES.length; i++) {
    if (BP_NAMES[i] === bp) {
      return i;
    }
  }
  return 1;
}

export function resolveBreakpoint(widthVp: number): string {
  let bp = 'xxl';
  for (let i = BP_MINS.length - 1; i >= 0; i--) {
    if (widthVp >= BP_MINS[i]) {
      bp = BP_NAMES[i];
      break;
    }
  }
  return bp;
}

export function getColumnCount(bp: string): number {
  const idx = indexOfBreakpoint(bp);
  if (idx >= 0 && idx < COLUMN_VALUES.length) {
    return COLUMN_VALUES[idx];
  }
  return 2;
}

export function getColumnsTemplate(bp: string): string {
  const count = getColumnCount(bp);
  const cols: string[] = [];
  for (let i = 0; i < count; i++) {
    cols.push('1fr');
  }
  return cols.join(' ');
}

export function getNovelColumnsTemplate(bp: string): string {
  const isWide = bp === 'lg' || bp === 'xl' || bp === 'xxl';
  return isWide ? '1fr 1fr' : '1fr';
}

export function publishBreakpoint(bp: string): void {
  AppStorage.setOrCreate(BREAKPOINT_KEY, bp);
}
