import * as Upstream from 'gaussian-splats-upstream';

export const SceneFormat = Upstream.SceneFormat;

export class Viewer extends Upstream.Viewer {
  addSplatScene(path, options = {}) {
    return super.addSplatScene(path, {
      ...options,
      format: options.format ?? Upstream.SceneFormat.Ply
    });
  }
}
