// D2-009 single-entry regression gate.
// Keep this file dependency-free so it can run anywhere Node.js is available.
await import('./share-metadata-contract.test.mjs');
await import('./share-fallback-contract.test.mjs');
await import('./native-share-metadata-contract.test.mjs');
await import('./live-viewer-smoke.mjs');

console.log('D2-009 share contracts: PASS');
