import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { LoadingModel, LoadingStatus, PageLoadModel, PageStatus } from '../main/ets/models/LoadingModel';

export default function loadingModelTest() {
  describe('LoadingModel', () => {
    let model: LoadingModel;

    beforeEach(() => {
      model = new LoadingModel();
    });

    it('initialStatus_should_be_IDLE', 0, () => {
      expect(model.status).assertEqual(LoadingStatus.IDLE);
    });

    it('startLoading_should_set_LOADING', 0, () => {
      model.startLoading();
      expect(model.status).assertEqual(LoadingStatus.LOADING);
      expect(model.isLoading).assertTrue();
    });

    it('setSuccess_should_set_SUCCESS', 0, () => {
      model.startLoading();
      model.setSuccess();
      expect(model.status).assertEqual(LoadingStatus.SUCCESS);
      expect(model.isSuccess).assertTrue();
    });

    it('setFailed_should_set_FAILED', 0, () => {
      model.setFailed('error');
      expect(model.status).assertEqual(LoadingStatus.FAILED);
      expect(model.isFailed).assertTrue();
      expect(model.errorMessage).assertEqual('error');
    });

    it('setEmpty_should_set_EMPTY', 0, () => {
      model.setEmpty();
      expect(model.status).assertEqual(LoadingStatus.EMPTY);
      expect(model.isEmpty).assertTrue();
    });

    it('reset_should_clear_to_IDLE', 0, () => {
      model.setFailed('err');
      model.reset();
      expect(model.status).assertEqual(LoadingStatus.IDLE);
      expect(model.errorMessage).assertEqual('');
    });
  });

  describe('PageLoadModel', () => {
    let model: PageLoadModel;

    beforeEach(() => {
      model = new PageLoadModel();
    });

    it('startLoading_page1_should_set_LOADING', 0, () => {
      model.startLoading(1);
      expect(model.page).assertEqual(1);
      expect(model.isLoading).assertTrue();
    });

    it('startLoading_page2_should_set_LOADING_MORE', 0, () => {
      model.startLoading(2);
      expect(model.page).assertEqual(2);
      expect(model.isLoadingMore).assertTrue();
    });

    it('setSuccess_should_update_page_info', 0, () => {
      model.setSuccess(1, 5);
      expect(model.page).assertEqual(1);
      expect(model.pages).assertEqual(5);
      expect(model.hasMore).assertTrue();
    });

    it('setNoMore_should_set_NO_MORE', 0, () => {
      model.setNoMore();
      expect(model.isNoMore).assertTrue();
      expect(model.hasMore).assertFalse();
    });

    it('setFailed_should_set_error', 0, () => {
      model.setFailed('load err');
      expect(model.isFailed).assertTrue();
      expect(model.errorMessage).assertEqual('load err');
    });
  });
}
