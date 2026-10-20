# コードから直接確認した補足証拠

対象commit: bee01e3a12812c930109aa91242658709480bbf3。対象のMITライセンスはtarget-LICENSEに同梱。行番号は原ファイルの番号。REA出力そのものではない。

## packages/element/src/shape.ts

SHA-256: 1121578b920a03e74e713bcf5ec454faedd09b46a327a55296948e038cfe97b2

```text
83: export class ShapeCache {
84:   private static rg = new RoughGenerator();
85:   private static cache = new WeakMap<
86:     ExcalidrawElement,
87:     { shape: ElementShape; theme: AppState["theme"] }
88:   >();
89:
90:   /**
91:    * Retrieves shape from cache if available. Use this only if shape
92:    * is optional and you have a fallback in case it's not cached.
93:    */
94:   public static get = <T extends ExcalidrawElement>(
95:     element: T,
96:     theme: AppState["theme"] | null,
97:   ) => {
98:     const cached = ShapeCache.cache.get(element);
99:     if (cached && (theme === null || cached.theme === theme)) {
100:       return cached.shape as T["type"] extends keyof ElementShapes
101:         ? ElementShapes[T["type"]] | undefined
102:         : ElementShape | undefined;
103:     }
104:     return undefined;
105:   };
106:
107:   public static delete = (element: ExcalidrawElement) => {
108:     ShapeCache.cache.delete(element);
109:     elementWithCanvasCache.delete(element);
110:   };
111:
112:   public static destroy = () => {
113:     ShapeCache.cache = new WeakMap();
114:   };
115:
116:   /**
117:    * Generates & caches shape for element if not already cached, otherwise
118:    * returns cached shape.
119:    */
120:   public static generateElementShape = <
121:     T extends Exclude<ExcalidrawElement, ExcalidrawSelectionElement>,
122:   >(
123:     element: T,
124:     renderConfig: {
125:       isExporting: boolean;
126:       canvasBackgroundColor: AppState["viewBackgroundColor"];
127:       embedsValidationStatus: EmbedsValidationStatus;
128:       theme: AppState["theme"];
129:     } | null,
130:   ) => {
131:     // when exporting, always regenerated to guarantee the latest shape
132:     const cachedShape = renderConfig?.isExporting
133:       ? undefined
134:       : ShapeCache.get(element, renderConfig ? renderConfig.theme : null);
135:
136:     // `null` indicates no rc shape applicable for this element type,
137:     // but it's considered a valid cache value (= do not regenerate)
138:     if (cachedShape !== undefined) {
139:       return cachedShape;
140:     }
141:
142:     elementWithCanvasCache.delete(element);
143:
144:     const shape = _generateElementShape(
145:       element,
146:       ShapeCache.rg,
147:       renderConfig || {
148:         isExporting: false,
149:         canvasBackgroundColor: COLOR_PALETTE.white,
150:         embedsValidationStatus: null,
151:         theme: THEME.LIGHT,
152:       },
153:     ) as T["type"] extends keyof ElementShapes
154:       ? ElementShapes[T["type"]]
155:       : Drawable | null;
156:
157:     if (!renderConfig?.isExporting) {
158:       ShapeCache.cache.set(element, {
159:         shape,
160:         theme: renderConfig?.theme || THEME.LIGHT,
161:       });
162:     }
163:
164:     return shape;
165:   };
```

```text
195: export const generateRoughOptions = (
196:   element: ExcalidrawElement,
197:   continuousPath = false,
198:   isDarkMode: boolean = false,
199: ): Options => {
200:   const options: Options = {
201:     seed: element.seed,
202:     strokeLineDash:
203:       element.strokeStyle === "dashed"
204:         ? getDashArrayDashed(element.strokeWidth)
205:         : element.strokeStyle === "dotted"
206:         ? getDashArrayDotted(element.strokeWidth)
207:         : undefined,
208:     // for non-solid strokes, disable multiStroke because it tends to make
209:     // dashes/dots overlay each other
210:     disableMultiStroke: element.strokeStyle !== "solid",
211:     // for non-solid strokes, increase the width a bit to make it visually
212:     // similar to solid strokes, because we're also disabling multiStroke
213:     strokeWidth:
214:       element.strokeStyle !== "solid"
215:         ? element.strokeWidth + 0.5
216:         : element.strokeWidth,
217:     // when increasing strokeWidth, we must explicitly set fillWeight and
218:     // hachureGap because if not specified, roughjs uses strokeWidth to
219:     // calculate them (and we don't want the fills to be modified)
220:     fillWeight: element.strokeWidth / 2,
221:     hachureGap: element.strokeWidth * 4,
222:     roughness: adjustRoughness(element),
223:     stroke: applyDarkModeFilter(element.strokeColor, isDarkMode),
224:     preserveVertices:
225:       continuousPath || element.roughness < ROUGHNESS.cartoonist,
```

## packages/excalidraw/data/reconcile.ts

SHA-256: 07ee09fe90a94db2cf44e5a4c0c838a7c7005ffc3a03c9c8e227de4bdcbf4db0

```text
23: export const shouldDiscardRemoteElement = (
24:   localAppState: AppState,
25:   local: OrderedExcalidrawElement | undefined,
26:   remote: RemoteExcalidrawElement,
27: ): boolean => {
28:   if (
29:     local &&
30:     // local element is being edited
31:     (local.id === localAppState.editingTextElement?.id ||
32:       local.id === localAppState.resizingElement?.id ||
33:       local.id === localAppState.newElement?.id ||
34:       // local element is newer
35:       local.version > remote.version ||
36:       // resolve conflicting edits deterministically by taking the one with
37:       // the lowest versionNonce
38:       (local.version === remote.version &&
39:         local.versionNonce <= remote.versionNonce))
40:   ) {
41:     return true;
42:   }
43:   return false;
44: };
45:
46: const validateIndicesThrottled = throttle(
47:   (
48:     orderedElements: readonly OrderedExcalidrawElement[],
49:     localElements: readonly OrderedExcalidrawElement[],
50:     remoteElements: readonly RemoteExcalidrawElement[],
51:   ) => {
52:     if (isDevEnv() || isTestEnv() || window?.DEBUG_FRACTIONAL_INDICES) {
53:       // create new instances due to the mutation
54:       const elements = syncInvalidIndices(
55:         orderedElements.map((x) => ({ ...x })),
56:       );
57:
58:       validateFractionalIndices(elements, {
59:         // throw in dev & test only, to remain functional on `DEBUG_FRACTIONAL_INDICES`
60:         shouldThrow: isTestEnv() || isDevEnv(),
61:         includeBoundTextValidation: true,
62:         reconciliationContext: {
63:           localElements,
64:           remoteElements,
65:         },
66:       });
67:     }
68:   },
69:   1000 * 60,
70:   { leading: true, trailing: false },
71: );
72:
73: export const reconcileElements = (
74:   localElements: readonly OrderedExcalidrawElement[],
75:   remoteElements: readonly RemoteExcalidrawElement[],
76:   localAppState: AppState,
77: ): ReconciledExcalidrawElement[] => {
78:   const localElementsMap = arrayToMap(localElements);
79:   const reconciledElements: OrderedExcalidrawElement[] = [];
80:   const added = new Set<string>();
81:
82:   // process remote elements
83:   for (const remoteElement of remoteElements) {
84:     if (!added.has(remoteElement.id)) {
85:       const localElement = localElementsMap.get(remoteElement.id);
86:       const discardRemoteElement = shouldDiscardRemoteElement(
87:         localAppState,
88:         localElement,
89:         remoteElement,
90:       );
91:
92:       if (localElement && discardRemoteElement) {
93:         reconciledElements.push(localElement);
94:         added.add(localElement.id);
95:       } else {
96:         reconciledElements.push(remoteElement);
97:         added.add(remoteElement.id);
98:       }
99:     }
100:   }
101:
102:   // process remaining local elements
103:   for (const localElement of localElements) {
104:     if (!added.has(localElement.id)) {
105:       reconciledElements.push(localElement);
106:       added.add(localElement.id);
107:     }
108:   }
109:
110:   const orderedElements = orderByFractionalIndex(reconciledElements);
111:
112:   validateIndicesThrottled(orderedElements, localElements, remoteElements);
113:
114:   // de-duplicate indices
115:   syncInvalidIndices(orderedElements);
```

## packages/excalidraw/data/encryption.ts

SHA-256: cf0459f24fadf50018db8d78f69c0d44333bc53fb88ec34435fa7fad37e602ed

```text
50: export const encryptData = async (
51:   key: string | CryptoKey,
52:   data: Uint8Array<ArrayBuffer> | ArrayBuffer | Blob | File | string,
53: ): Promise<{ encryptedBuffer: ArrayBuffer; iv: Uint8Array<ArrayBuffer> }> => {
54:   const importedKey =
55:     typeof key === "string" ? await getCryptoKey(key, "encrypt") : key;
56:   const iv = createIV();
57:   const buffer: ArrayBuffer | Uint8Array<ArrayBuffer> =
58:     typeof data === "string"
59:       ? new TextEncoder().encode(data)
60:       : data instanceof Uint8Array
61:       ? data
62:       : data instanceof Blob
63:       ? await blobToArrayBuffer(data)
64:       : data;
65:
66:   // We use symmetric encryption. AES-GCM is the recommended algorithm and
67:   // includes checks that the ciphertext has not been modified by an attacker.
68:   const encryptedBuffer = await window.crypto.subtle.encrypt(
69:     {
70:       name: "AES-GCM",
71:       iv,
72:     },
73:     importedKey,
74:     buffer,
75:   );
76:
77:   return { encryptedBuffer, iv };
78: };
79:
80: export const decryptData = async (
81:   iv: Uint8Array<ArrayBuffer>,
82:   encrypted: Uint8Array<ArrayBuffer> | ArrayBuffer,
83:   privateKey: string,
84: ): Promise<ArrayBuffer> => {
85:   const key = await getCryptoKey(privateKey, "decrypt");
86:   return window.crypto.subtle.decrypt(
87:     {
88:       name: "AES-GCM",
89:       iv,
90:     },
91:     key,
92:     encrypted,
93:   );
94: };
```

## excalidraw-app/collab/Portal.tsx

SHA-256: 8e954a48319fdedd9d82604a4c642a424b33e49713e30721feaa5e95b4f57fc2

```text
85:   async _broadcastSocketData(
86:     data: SocketUpdateData,
87:     volatile: boolean = false,
88:     roomId?: string,
89:   ) {
90:     if (this.isOpen()) {
91:       const json = JSON.stringify(data);
92:       const encoded = new TextEncoder().encode(json);
93:       const { encryptedBuffer, iv } = await encryptData(this.roomKey!, encoded);
94:
95:       this.socket?.emit(
96:         volatile ? WS_EVENTS.SERVER_VOLATILE : WS_EVENTS.SERVER,
97:         roomId ?? this.roomId,
98:         encryptedBuffer,
99:         iv,
100:       );
101:     }
102:   }
103:
```

## excalidraw-app/data/LocalData.ts

SHA-256: 9628f2e3f5cf0f0cb41af71c9d350ea365435664cc6181dcb7bbbb27466b5ca4

```text
73: const saveDataStateToLocalStorage = (
74:   elements: readonly ExcalidrawElement[],
75:   appState: AppState,
76: ) => {
77:   const localStorageQuotaExceeded = appJotaiStore.get(
78:     localStorageQuotaExceededAtom,
79:   );
80:   try {
81:     const _appState = clearAppStateForLocalStorage(appState);
82:
83:     if (
84:       _appState.openSidebar?.name === DEFAULT_SIDEBAR.name &&
85:       _appState.openSidebar.tab === CANVAS_SEARCH_TAB
86:     ) {
87:       _appState.openSidebar = null;
88:     }
89:
90:     localStorage.setItem(
91:       STORAGE_KEYS.LOCAL_STORAGE_ELEMENTS,
92:       JSON.stringify(getNonDeletedElements(elements)),
93:     );
94:     localStorage.setItem(
95:       STORAGE_KEYS.LOCAL_STORAGE_APP_STATE,
96:       JSON.stringify(_appState),
97:     );
98:     updateBrowserStateVersion(STORAGE_KEYS.VERSION_DATA_STATE);
99:     if (localStorageQuotaExceeded) {
100:       appJotaiStore.set(localStorageQuotaExceededAtom, false);
101:     }
102:   } catch (error: any) {
103:     // Unable to access window.localStorage
104:     console.error(error);
105:     if (isQuotaExceededError(error) && !localStorageQuotaExceeded) {
106:       appJotaiStore.set(localStorageQuotaExceededAtom, true);
107:     }
108:   }
109: };
110:
111: const isQuotaExceededError = (error: any) => {
112:   return error instanceof DOMException && error.name === "QuotaExceededError";
113: };
114:
115: type SavingLockTypes = "collaboration";
116:
117: export class LocalData {
118:   private static _save = debounce(
119:     async (
120:       elements: readonly ExcalidrawElement[],
121:       appState: AppState,
122:       files: BinaryFiles,
123:       onFilesSaved: () => void,
124:     ) => {
125:       saveDataStateToLocalStorage(elements, appState);
126:
127:       await this.fileStorage.saveFiles({
128:         elements,
129:         files,
130:       });
131:       onFilesSaved();
132:     },
133:     SAVE_TO_LOCAL_STORAGE_TIMEOUT,
134:   );
135:
136:   /** Saves DataState, including files. Bails if saving is paused */
137:   static save = (
138:     elements: readonly ExcalidrawElement[],
139:     appState: AppState,
140:     files: BinaryFiles,
141:     onFilesSaved: () => void,
142:   ) => {
143:     // we need to make the `isSavePaused` check synchronously (undebounced)
144:     if (!this.isSavePaused()) {
145:       this._save(elements, appState, files, onFilesSaved);
146:     }
147:   };
148:
149:   static flushSave = () => {
150:     this._save.flush();
```

## packages/excalidraw/data/json.ts

SHA-256: d38e58836b569507a40f6f3a745d600c589202a43627762ee7a578331a3d514d

```text
52: export const serializeAsJSON = (
53:   elements: readonly ExcalidrawElement[],
54:   appState: Partial<AppState>,
55:   files: BinaryFiles,
56:   type: "local" | "database",
57: ): string => {
58:   const data: ExportedDataState = {
59:     type: EXPORT_DATA_TYPES.excalidraw,
60:     version: VERSIONS.excalidraw,
61:     source: getExportSource(),
62:     elements,
63:     appState:
64:       type === "local"
65:         ? cleanAppStateForExport(appState)
66:         : clearAppStateForDatabase(appState),
67:     files:
68:       type === "local"
69:         ? filterOutDeletedFiles(elements, files)
70:         : // will be stripped from JSON
71:           undefined,
72:   };
73:
74:   return JSON.stringify(data, null, 2);
75: };
76:
77: export const saveAsJSON = async ({
78:   data,
```

## packages/excalidraw/scene/export.ts

SHA-256: 9b981fc80524fd0bc5b6cc0816045150a7d85957113c97ac1d346123bb42fb63

```text
1038:         metadataElement,
1039:         // when embedding scene, we want to embed the (restored) supplied
1040:         // elements which don't contain the temp frame labels. Restoring
1041:         // keeps the ids stable. But it also requires that the exportToSvg is
1042:         // being supplied with only the elements that we're exporting, and
1043:         // no extra.
1044:         payload: serializeAsJSON(elements, appState, data.files || {}, "local"),
1045:       });
1046:     } catch (error: any) {
1047:       console.error(error);
1048:     }
1049:   }
1050:
```
