import { SearchCondition, DEFAULT_SEARCH_CONDITION, isSearchConditionActive, conditionLabelSummary } from '../models/SearchModels';

const AI_TYPE_VALS: number[] = [0, 1];
const WORK_LANG_VALS: string[] = ['', 'ja', 'en', 'zh-cn', 'zh-tw'];

const SORT_LABELS: string[] = ['最新发布', '最早发布', '最多收藏'];
const SORT_VALS: string[] = ['date_d', 'date', 'popular_d'];
const MODE_LABELS_ILLUST: string[] = ['标签（部分一致）', '标签（完全一致）', '标题、说明文字', '标签、标题、说明文字'];
const MODE_VALS_ILLUST: string[] = ['s_tag', 's_tag_full', 's_tc', 's_tag_tc'];
const MODE_LABELS_NOVEL: string[] = ['标签（完全一致）', '标签（部分一致）', '正文', '标签、标题、说明文字'];
const MODE_VALS_NOVEL: string[] = ['s_tag_full', 's_tag', 's_body', 's_tc'];
const MODE_LABELS_USER: string[] = ['部分一致', '完全一致'];
const MODE_VALS_USER: string[] = ['s_usr', 's_usr_full'];
const TYPE_LABELS: string[] = ['全部', '插画', '动图', '漫画'];
const TYPE_VALS: string[] = ['illust_and_ugoira', 'illust', 'ugoira', 'manga'];
const R18_LABELS: string[] = ['全部', '全年龄', 'R-18'];
const R18_VALS: string[] = ['all', 'safe', 'r18'];

const GENRE_LABELS: string[][] = [
  ['所有分类', '恋爱', '异世界奇幻', '现代奇幻'],
  ['悬疑', '恐怖', '科幻', '文学'],
  ['生活・情感', '历史・时代', 'BL', '百合'],
  ['儿童向', '散文・诗歌', '随笔・纪实', '剧本・台本'],
  ['评论・感想', '其他']
];
const GENRE_VALS: string[][] = [
  ['', '1', '2', '3'],
  ['4', '5', '6', '7'],
  ['8', '9', '10', '11'],
  ['12', '13', '14', '15'],
  ['0', '16']
];

function formatDateStr(date: Date | undefined): string {
  if (date === undefined) return '';
  const y = date.getFullYear();
  const m = (date.getMonth() + 1).toString().padStart(2, '0');
  const d = date.getDate().toString().padStart(2, '0');
  return y + '-' + m + '-' + d;
}

function parseDateStr(s: string | undefined): Date | undefined {
  if (s === undefined || s === '') return undefined;
  const d = new Date(s);
  if (isNaN(d.getTime())) return undefined;
  return d;
}

@Component
export struct AdvancedSearchDialog {
  @Link searchCondition: SearchCondition;

  @State localStartDate: Date | undefined = undefined;
  @State localEndDate: Date | undefined = undefined;
  @State localAiType: number = 0;
  @State localWorkLang: string = '';
  @State localSortOrder: string = 'date_d';
  @State localSearchMode: string = 's_tag';
  @State localContentType: string = 'illust_and_ugoira';
  @State localR18Mode: string = 'all';

  @State localIsOriginal: number = 0;
  @State localGenre: string = '';

  doClose: () => void = () => {};
  showLanguageFilter: boolean = false;
  currentTab: number = 0;

  aboutToAppear(): void {
    this.syncFromCondition();
  }

  syncFromCondition(): void {
    this.localStartDate = parseDateStr(this.searchCondition.startDate);
    this.localEndDate = parseDateStr(this.searchCondition.endDate);
    this.localAiType = this.searchCondition.aiType;
    this.localWorkLang = this.searchCondition.workLang;
    this.localSortOrder = this.searchCondition.sortOrder;
    this.localSearchMode = this.searchCondition.searchMode;
    this.localContentType = this.searchCondition.contentType;
    this.localR18Mode = this.searchCondition.r18Mode;

    this.localIsOriginal = this.searchCondition.isOriginal;
    this.localGenre = this.searchCondition.genre;
  }

  applyChanges(): void {
    const newCond: SearchCondition = {
      startDate: this.localStartDate !== undefined ? formatDateStr(this.localStartDate) : undefined,
      endDate: this.localEndDate !== undefined ? formatDateStr(this.localEndDate) : undefined,
      bookmarkMin: undefined,
      bookmarkMax: undefined,
      aiType: this.localAiType,
      ratio: '',
      workLang: this.localWorkLang,
      sortOrder: this.localSortOrder,
      searchMode: this.localSearchMode,
      contentType: this.localContentType,
      r18Mode: this.localR18Mode,
      isOriginal: this.localIsOriginal,
      genre: this.localGenre,
      duration: '',
    };
    console.info('[AdvancedSearch] applyChanges: ' + JSON.stringify(newCond));
    this.searchCondition = newCond;
  }

  resetAll(): void {
    console.info('[AdvancedSearch] resetAll');
    this.localStartDate = undefined;
    this.localEndDate = undefined;
    this.localAiType = 0;
    this.localWorkLang = '';
    this.localSortOrder = 'date_d';
    this.localSearchMode = 's_tag';
    this.localContentType = 'illust_and_ugoira';
    this.localR18Mode = 'all';

    this.localIsOriginal = 0;
    this.localGenre = '';
    this.applyChanges();
  }

  build() {
    Column() {
      Row() {
        Text('详细搜索条件')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ top: 16, bottom: 12, left: 20 })

      Column() {
        Column() {
          // ── Search mode ──
          if (this.currentTab === 0) {
            Text('检索范围')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.user_name'))
              .width('100%')
              .padding({ left: 20, right: 20, top: 8, bottom: 4 })

            Column({ space: 6 }) {
              Row({ space: 6 }) {
                this.ModePillButton(MODE_LABELS_ILLUST[0], MODE_VALS_ILLUST[0])
                this.ModePillButton(MODE_LABELS_ILLUST[1], MODE_VALS_ILLUST[1])
              }
              Row({ space: 6 }) {
                this.ModePillButton(MODE_LABELS_ILLUST[2], MODE_VALS_ILLUST[2])
                this.ModePillButton(MODE_LABELS_ILLUST[3], MODE_VALS_ILLUST[3])
              }
            }
            .padding({ left: 20, right: 20, bottom: 12 })
          } else if (this.currentTab === 1) {
            Text('检索范围')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.user_name'))
              .width('100%')
              .padding({ left: 20, right: 20, top: 8, bottom: 4 })

            Column({ space: 6 }) {
              Row({ space: 6 }) {
                this.ModePillButton(MODE_LABELS_NOVEL[0], MODE_VALS_NOVEL[0])
                this.ModePillButton(MODE_LABELS_NOVEL[1], MODE_VALS_NOVEL[1])
              }
              Row({ space: 6 }) {
                this.ModePillButton(MODE_LABELS_NOVEL[2], MODE_VALS_NOVEL[2])
                this.ModePillButton(MODE_LABELS_NOVEL[3], MODE_VALS_NOVEL[3])
              }
            }
            .padding({ left: 20, right: 20, bottom: 12 })
          } else {
            Text('检索范围')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.user_name'))
              .width('100%')
              .padding({ left: 20, right: 20, top: 8, bottom: 4 })

            Row({ space: 6 }) {
              this.ModePillButton(MODE_LABELS_USER[0], MODE_VALS_USER[0])
              this.ModePillButton(MODE_LABELS_USER[1], MODE_VALS_USER[1])
            }
            .padding({ left: 20, right: 20, bottom: 12 })
          }

          if (this.currentTab !== 2) {
            // ── Sort order ──
            Text('排序方式')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.user_name'))
              .width('100%')
              .padding({ left: 20, right: 20, top: 8, bottom: 4 })

            Row({ space: 6 }) {
              this.SortPillButton(SORT_LABELS[0], SORT_VALS[0])
              this.SortPillButton(SORT_LABELS[1], SORT_VALS[1])
              this.SortPillButton(SORT_LABELS[2], SORT_VALS[2])
            }
            .padding({ left: 20, right: 20, bottom: 12 })

            if (this.currentTab === 0) {
              // ── Content type ──
              Text('作品类型')
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.user_name'))
                .width('100%')
                .padding({ left: 20, right: 20, top: 8, bottom: 4 })

              Row({ space: 6 }) {
                this.TypePillButton(TYPE_LABELS[0], TYPE_VALS[0])
                this.TypePillButton(TYPE_LABELS[1], TYPE_VALS[1])
                this.TypePillButton(TYPE_LABELS[2], TYPE_VALS[2])
                this.TypePillButton(TYPE_LABELS[3], TYPE_VALS[3])
              }
              .padding({ left: 20, right: 20, bottom: 12 })
            }

            // ── Age restriction ──
            Text('年龄限制')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.user_name'))
              .width('100%')
              .padding({ left: 20, right: 20, top: 8, bottom: 4 })

            Row({ space: 6 }) {
              this.R18PillButton(R18_LABELS[0], R18_VALS[0])
              this.R18PillButton(R18_LABELS[1], R18_VALS[1])
              this.R18PillButton(R18_LABELS[2], R18_VALS[2])
            }
            .padding({ left: 20, right: 20, bottom: 12 })

            // ── Date range ──
            Text('投稿时间')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.user_name'))
              .width('100%')
              .padding({ left: 20, right: 20, top: 8, bottom: 4 })

            Row({ space: 8 }) {
              Column() {
                Text(this.localStartDate !== undefined ? formatDateStr(this.localStartDate) : '开始日期')
                  .fontSize(14)
                  .fontColor(this.localStartDate !== undefined ? $r('app.color.user_name') : $r('app.color.text_secondary'))
                  .padding(12)
                  .borderRadius(8)
                  .backgroundColor($r('app.color.surface_secondary'))
                  .width('100%')
                  .textAlign(TextAlign.Center)
                  .onClick(() => {
                    this.getUIContext().showDatePickerDialog({
                      start: new Date('2000-01-01'),
                      end: new Date('2100-12-31'),
                      selected: this.localStartDate !== undefined ? this.localStartDate : new Date(),
                      onDateAccept: (value: Date) => {
                        this.localStartDate = value;
                      }
                    });
                  })
              }
              .layoutWeight(1)

              Text('~')
                .fontSize(14)
                .fontColor($r('app.color.text_secondary'))
                .margin({ top: 12 })

              Column() {
                Text(this.localEndDate !== undefined ? formatDateStr(this.localEndDate) : '结束日期')
                  .fontSize(14)
                  .fontColor(this.localEndDate !== undefined ? $r('app.color.user_name') : $r('app.color.text_secondary'))
                  .padding(12)
                  .borderRadius(8)
                  .backgroundColor($r('app.color.surface_secondary'))
                  .width('100%')
                  .textAlign(TextAlign.Center)
                  .onClick(() => {
                    this.getUIContext().showDatePickerDialog({
                      start: new Date('2000-01-01'),
                      end: new Date('2100-12-31'),
                      selected: this.localEndDate !== undefined ? this.localEndDate : new Date(),
                      onDateAccept: (value: Date) => {
                        this.localEndDate = value;
                      }
                    });
                  })
              }
              .layoutWeight(1)
            }
            .padding({ left: 20, right: 20, bottom: 4, top: 4 })

            Row({ space: 8 }) {
              Text('清除')
                .fontSize(13)
                .fontColor($r('app.color.tab_selected'))
                .onClick(() => {
                  this.localStartDate = undefined;
                })
              Text('清除')
                .fontSize(13)
                .fontColor($r('app.color.tab_selected'))
                .onClick(() => {
                  this.localEndDate = undefined;
                })
            }
            .padding({ left: 20, right: 20, bottom: 12 })
            .justifyContent(FlexAlign.SpaceBetween)

            // ── AI type ──
            Text('AI生成作品')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.user_name'))
              .width('100%')
              .padding({ left: 20, right: 20, top: 8, bottom: 4 })

            Row({ space: 6 }) {
              this.AIPillButton('显示', 0, AI_TYPE_VALS[0])
              this.AIPillButton('隐藏', 1, AI_TYPE_VALS[1])
            }
            .padding({ left: 20, right: 20, bottom: 12 })

            if (this.showLanguageFilter) {
              // ── Language ──
              Text('作品语言')
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.user_name'))
                .width('100%')
                .padding({ left: 20, right: 20, top: 8, bottom: 4 })

              Row({ space: 6 }) {
                this.LangPillButton('不指定', 0, WORK_LANG_VALS[0])
                this.LangPillButton('日语', 1, WORK_LANG_VALS[1])
                this.LangPillButton('英语', 2, WORK_LANG_VALS[2])
                this.LangPillButton('简体中文', 3, WORK_LANG_VALS[3])
                this.LangPillButton('繁体中文', 4, WORK_LANG_VALS[4])
              }
              .padding({ left: 20, right: 20, bottom: 12 })
            }

            if (this.currentTab === 1) {
              // ── Original ──
              Text('原创作品')
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.user_name'))
                .width('100%')
                .padding({ left: 20, right: 20, top: 8, bottom: 4 })

              Row({ space: 8 }) {
                Button() {
                  Text('全部')
                    .fontSize(14)
                    .fontColor(this.localIsOriginal === 0 ? Color.White : $r('app.color.user_name'))
                }
                .height(36)
                .layoutWeight(1)
                .borderRadius(18)
                .backgroundColor(this.localIsOriginal === 0 ? $r('app.color.tab_selected') : $r('app.color.surface_secondary'))
                .onClick(() => {
                  this.localIsOriginal = 0;
                  this.localGenre = '';
                })

                Button() {
                  Text('仅原创')
                    .fontSize(14)
                    .fontColor(this.localIsOriginal === 1 ? Color.White : $r('app.color.user_name'))
                }
                .height(36)
                .layoutWeight(1)
                .borderRadius(18)
                .backgroundColor(this.localIsOriginal === 1 ? $r('app.color.tab_selected') : $r('app.color.surface_secondary'))
                .onClick(() => {
                  this.localIsOriginal = 1;
                })
              }
              .padding({ left: 20, right: 20, bottom: 12 })

              if (this.localIsOriginal === 1) {
                Text('作品分类')
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.user_name'))
                  .width('100%')
                  .padding({ left: 20, right: 20, top: 4, bottom: 4 })

                Column({ space: 6 }) {
                  ForEach(GENRE_LABELS, (rowLabels: string[], ri: number) => {
                    Row({ space: 6 }) {
                      ForEach(rowLabels, (label: string, ci: number) => {
                        this.GenrePillButton(label, GENRE_VALS[ri][ci])
                      })
                    }
                    .padding({ left: 20, right: 20 })
                  })
                }
                .padding({ left: 0, right: 0, bottom: 12 })
              }
            }
          }

          Divider()
            .height(1)
            .color($r('app.color.text_secondary'))
            .opacity(0.3)
            .width('100%')
            .margin({ top: 4, bottom: 8 })

          // ── Action buttons ──
          Row({ space: 12 }) {
            Button('重置')
              .height(40)
              .borderRadius(20)
              .fontSize(14)
              .fontColor($r('app.color.user_name'))
              .backgroundColor($r('app.color.surface_secondary'))
              .layoutWeight(1)
              .onClick(() => {
                this.resetAll();
              })

            Button('应用')
              .height(40)
              .borderRadius(20)
              .fontSize(14)
              .fontColor(Color.White)
              .backgroundColor($r('app.color.tab_selected'))
              .layoutWeight(1)
              .onClick(() => {
                this.applyChanges();
                this.doClose();
              })
          }
          .padding({ left: 20, right: 20, bottom: 32 })
        }
        .width('100%')
      }
      .width('100%')
    }
    .backgroundColor($r('app.color.page_background'))
  }

  @Builder
  SortPillButton(label: string, val: string) {
    Button() {
      Text(label)
        .fontSize(13)
        .fontColor(this.localSortOrder === val ? Color.White : $r('app.color.user_name'))
    }
    .height(32)
    .layoutWeight(1)
    .borderRadius(16)
    .backgroundColor(this.localSortOrder === val ? $r('app.color.tab_selected') : $r('app.color.surface_secondary'))
    .padding({ left: 12, right: 12 })
    .onClick(() => {
      this.localSortOrder = val;
    })
  }

  @Builder
  ModePillButton(label: string, val: string) {
    Button() {
      Text(label)
        .fontSize(13)
        .fontColor(this.localSearchMode === val ? Color.White : $r('app.color.user_name'))
    }
    .height(32)
    .layoutWeight(1)
    .borderRadius(16)
    .backgroundColor(this.localSearchMode === val ? $r('app.color.tab_selected') : $r('app.color.surface_secondary'))
    .padding({ left: 12, right: 12 })
    .onClick(() => {
      this.localSearchMode = val;
    })
  }

  @Builder
  TypePillButton(label: string, val: string) {
    Button() {
      Text(label)
        .fontSize(13)
        .fontColor(this.localContentType === val ? Color.White : $r('app.color.user_name'))
    }
    .height(32)
    .layoutWeight(1)
    .borderRadius(16)
    .backgroundColor(this.localContentType === val ? $r('app.color.tab_selected') : $r('app.color.surface_secondary'))
    .padding({ left: 12, right: 12 })
    .onClick(() => {
      this.localContentType = val;
    })
  }

  @Builder
  R18PillButton(label: string, val: string) {
    Button() {
      Text(label)
        .fontSize(13)
        .fontColor(this.localR18Mode === val ? Color.White : $r('app.color.user_name'))
    }
    .height(32)
    .layoutWeight(1)
    .borderRadius(16)
    .backgroundColor(this.localR18Mode === val ? $r('app.color.tab_selected') : $r('app.color.surface_secondary'))
    .padding({ left: 12, right: 12 })
    .onClick(() => {
      this.localR18Mode = val;
    })
  }

  @Builder
  AIPillButton(label: string, index: number, val: number) {
    Button() {
      Text(label)
        .fontSize(13)
        .fontColor(this.localAiType === val ? Color.White : $r('app.color.user_name'))
    }
    .height(32)
    .layoutWeight(1)
    .borderRadius(16)
    .backgroundColor(this.localAiType === val ? $r('app.color.tab_selected') : $r('app.color.surface_secondary'))
    .padding({ left: 12, right: 12 })
    .onClick(() => {
      this.localAiType = val;
    })
  }

  @Builder
  GenrePillButton(label: string, val: string) {
    Button() {
      Text(label)
        .fontSize(12)
        .fontColor(this.localGenre === val ? Color.White : $r('app.color.user_name'))
    }
    .height(30)
    .layoutWeight(1)
    .borderRadius(15)
    .backgroundColor(this.localGenre === val ? $r('app.color.tab_selected') : $r('app.color.surface_secondary'))
    .padding({ left: 8, right: 8 })
    .onClick(() => {
      this.localGenre = val;
    })
  }

  @Builder
  LangPillButton(label: string, index: number, val: string) {
    Button() {
      Text(label)
        .fontSize(13)
        .fontColor(this.localWorkLang === val ? Color.White : $r('app.color.user_name'))
    }
    .height(32)
    .borderRadius(16)
    .backgroundColor(this.localWorkLang === val ? $r('app.color.tab_selected') : $r('app.color.surface_secondary'))
    .padding({ left: 12, right: 12 })
    .onClick(() => {
      this.localWorkLang = val;
    })
  }
}
