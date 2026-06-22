/**
 * LazyForEach 通用数据源
 * 用于替代 ForEach 实现长列表懒加载
 */
export class BasicDataSource<T> implements IDataSource {
  private listeners: DataChangeListener[] = [];
  private dataArray: T[] = [];

  totalCount(): number {
    return this.dataArray.length;
  }

  getData(index: number): T {
    return this.dataArray[index];
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (!this.listeners.includes(listener)) {
      this.listeners.push(listener);
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const idx = this.listeners.indexOf(listener);
    if (idx >= 0) {
      this.listeners.splice(idx, 1);
    }
  }

  private notifyDataReload(): void {
    for (const listener of this.listeners) {
      listener.onDataReloaded();
    }
  }

  private notifyDataAdd(index: number): void {
    for (const listener of this.listeners) {
      listener.onDataAdd(index);
    }
  }

  private notifyDataChange(index: number): void {
    for (const listener of this.listeners) {
      listener.onDataChange(index);
    }
  }

  private notifyDataDelete(index: number): void {
    for (const listener of this.listeners) {
      listener.onDataDelete(index);
    }
  }

  private notifyDataMove(from: number, to: number): void {
    for (const listener of this.listeners) {
      listener.onDataMove(from, to);
    }
  }

  /** 全量替换数据 */
  reset(data: T[]): void {
    this.dataArray = data;
    this.notifyDataReload();
  }

  /** 追加数据到末尾 */
  push(...items: T[]): void {
    const start = this.dataArray.length;
    this.dataArray.push(...items);
    for (let i = 0; i < items.length; i++) {
      this.notifyDataAdd(start + i);
    }
  }

  /** 替换指定位置的数据 */
  set(index: number, item: T): void {
    this.dataArray[index] = item;
    this.notifyDataChange(index);
  }

  /** 删除指定位置的数据 */
  delete(index: number): void {
    this.dataArray.splice(index, 1);
    this.notifyDataDelete(index);
  }

  /** 获取底层数组（只读） */
  getDataArray(): T[] {
    return this.dataArray;
  }

  /** 获取数据项数量 */
  get length(): number {
    return this.dataArray.length;
  }

  /** 清空数据 */
  clear(): void {
    const count = this.dataArray.length;
    this.dataArray = [];
    for (let i = count - 1; i >= 0; i--) {
      this.notifyDataDelete(i);
    }
  }
}
