export const SceneFormat = { Ply: 'ply' };

export class Viewer {
  constructor() { this.started = false; }
  async addSplatScene(_path, options = {}) {
    const h = window.__viewerHarness;
    h.sceneCount += 1;
    if (options.format !== SceneFormat.Ply) throw new Error('extensionless SPZ must force SceneFormat.Ply');
    if (h.scenario === 'sceneRetry' && h.sceneCount === 1) throw new Error('fixture scene failure');
  }
  start() { this.started = true; document.body.dataset.sceneStarted = 'true'; }
  stop() { document.body.dataset.viewerStopped = 'true'; }
  dispose() { document.body.dataset.viewerDisposed = 'true'; }
}
