import relationalStore from '@ohos.data.relationalStore';
import { DatabaseCore } from './DatabaseCore';
import { CacheStatus } from '../models/PixivModels';

export class TranslationCacheDao {
  static async saveTitleTranslation(novelId: string, translatedTitle: string): Promise<void> {
    if (!DatabaseCore.isReady()) return;
    const store = DatabaseCore.getStore()!;
    const updated = await DatabaseCore.updateCacheFields(novelId, {
      'title_translated': translatedTitle,
      'has_title_translation': 1
    });
    if (!updated) {
      try {
        await store.insert(
          DatabaseCore.TableNovels,
          {
            'id': novelId,
            'title': '',
            'title_translated': translatedTitle,
            'has_title_translation': 1,
            'cache_status': CacheStatus.NOT_CACHED
          },
          relationalStore.ConflictResolution.ON_CONFLICT_REPLACE
        );
      } catch (err) {
        console.error(`[TranslationCacheDao] saveTitleTranslation 插入失败 id=${novelId}: ${JSON.stringify(err)}`);
      }
    }
  }

  static async saveFullTextTranslation(novelId: string, translatedText: string): Promise<void> {
    if (!DatabaseCore.isReady()) return;
    const store = DatabaseCore.getStore()!;
    const updated = await DatabaseCore.updateCacheFields(novelId, {
      'full_text_translated': translatedText,
      'has_full_translation': 1,
      'translation_status': 'completed',
      'translation_progress': 100
    });
    if (!updated) {
      try {
        await store.insert(
          DatabaseCore.TableNovels,
          {
            'id': novelId,
            'title': '',
            'full_text_translated': translatedText,
            'has_full_translation': 1,
            'translation_status': 'completed',
            'translation_progress': 100,
            'cache_status': CacheStatus.NOT_CACHED
          },
          relationalStore.ConflictResolution.ON_CONFLICT_REPLACE
        );
      } catch (err) {
        console.error(`[TranslationCacheDao] saveFullTextTranslation 插入失败 id=${novelId}: ${JSON.stringify(err)}`);
      }
    }
  }

  static async updateTranslationProgress(novelId: string, progress: number, status: string): Promise<void> {
    await DatabaseCore.updateCacheFields(novelId, {
      'translation_progress': progress,
      'translation_status': status
    });
  }
}
