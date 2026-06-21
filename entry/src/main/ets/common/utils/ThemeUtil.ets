export interface ReaderColors {
  pageBg: string;
  headerBg: string;
  primaryText: string;
  secondaryText: string;
  accentText: string;
  divider: string;
  iconBtnBg: string;
  iconBtnText: string;
  chapterColor: string;
  hrColor: string;
  translateBtnText: string;
  translatedTextColor: string;
  translationProgressBg: string;
  translationProgressFill: string;
  dangerText: string;
  menuBg: string;
  menuItemActive: string;
}

export function getReaderColors(isDark: boolean): ReaderColors {
  return {
    pageBg: isDark ? '#0D0D0D' : '#F9F7F2',
    headerBg: isDark ? '#141414' : '#FFFFFF',
    primaryText: isDark ? '#E6E6E6' : '#1A1A1A',
    secondaryText: isDark ? '#888888' : '#666666',
    accentText: isDark ? '#0A84FF' : '#007DFF',
    divider: isDark ? '#2A2A2A' : '#E5E5E5',
    iconBtnBg: isDark ? '#2A2A2A' : '#F0F0F0',
    iconBtnText: isDark ? '#CCCCCC' : '#444444',
    chapterColor: isDark ? '#AADDFF' : '#0055AA',
    hrColor: isDark ? '#333333' : '#DDDDDD',
    translateBtnText: '#007DFF',
    translatedTextColor: isDark ? '#CCE5FF' : '#0055AA',
    translationProgressBg: isDark ? '#333333' : '#E5E5E5',
    translationProgressFill: '#007DFF',
    dangerText: '#FF4D4F',
    menuBg: isDark ? '#CC1C1C1E' : '#E8F2F2F7',
    menuItemActive: isDark ? '#3A3A3C' : '#DDDDDD'
  };
}
