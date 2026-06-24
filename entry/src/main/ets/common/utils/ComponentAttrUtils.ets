import { componentUtils } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';

export class RectInfoInPx {
  left: number = 0;
  top: number = 0;
  right: number = 0;
  bottom: number = 0;
  width: number = 0;
  height: number = 0;
}

export class ComponentAttrUtils {
  static getRectInfoById(context: UIContext, id: string): RectInfoInPx {
    let rstRect: RectInfoInPx = new RectInfoInPx();
    if (!context || !id) {
      return rstRect;
    }
    let componentInfo: componentUtils.ComponentInfo | undefined = undefined;
    try {
      componentInfo = context.getComponentUtils().getRectangleById(id);
    } catch (err) {
      let error = err as BusinessError;
      console.error('ComponentAttrUtils getRectInfoById failed:', error.code, error.message);
    }
    if (!componentInfo) {
      return rstRect;
    }
    const widthScaleGap = componentInfo.size.width * (1 - componentInfo.scale.x) / 2;
    const heightScaleGap = componentInfo.size.height * (1 - componentInfo.scale.y) / 2;
    rstRect.left = componentInfo.translate.x + componentInfo.screenOffset.x + widthScaleGap;
    rstRect.top = componentInfo.translate.y + componentInfo.screenOffset.y + heightScaleGap;
    rstRect.right = componentInfo.translate.x + componentInfo.screenOffset.x + componentInfo.size.width - widthScaleGap;
    rstRect.bottom = componentInfo.translate.y + componentInfo.screenOffset.y + componentInfo.size.height - heightScaleGap;
    rstRect.width = rstRect.right - rstRect.left;
    rstRect.height = rstRect.bottom - rstRect.top;
    return rstRect;
  }
}
