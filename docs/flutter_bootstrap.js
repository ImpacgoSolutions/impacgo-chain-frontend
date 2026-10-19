(()=>{var C={blink:!0,gecko:!1,webkit:!1,unknown:!1},A=()=>navigator.vendor==="Google Inc."||navigator.userAgent.includes("Edg/")?"blink":navigator.vendor==="Apple Computer, Inc."?"webkit":navigator.vendor===""&&navigator.userAgent.includes("Firefox")?"gecko":"unknown",T=A(),x=()=>typeof ImageDecoder>"u"?!1:T==="blink",R=()=>typeof Intl.v8BreakIterator<"u"&&typeof Intl.Segmenter<"u",j=()=>typeof window.TextCluster<"u",B=()=>{let n=[0,97,115,109,1,0,0,0,1,5,1,95,1,120,0];return WebAssembly.validate(new Uint8Array(n))},K=()=>{let n=document.createElement("canvas");return n.width=1,n.height=1,n.getContext("webgl2")!=null?2:n.getContext("webgl")!=null?1:-1},$=()=>window.chrome&&chrome.runtime&&chrome.runtime.id,f={browserEngine:T,hasImageCodecs:x(),hasChromiumBreakIterators:R(),hasTextCluster:j(),supportsWasmGC:B(),crossOriginIsolated:window.crossOriginIsolated,webGLVersion:K(),isChromeExtension:$()};function m(...n){return new URL(W(...n),document.baseURI).toString()}function W(...n){return n.filter(e=>!!e).map((e,s)=>s===0?L(e):F(L(e))).filter(e=>e.length).join("/")}function F(n){let e=0;for(;e<n.length&&n.charAt(e)==="/";)e++;return n.substring(e)}function L(n){let e=n.length;for(;e>0&&n.charAt(e-1)==="/";)e--;return n.substring(0,e)}function _(n,e){return n.canvasKitBaseUrl?n.canvasKitBaseUrl:e.engineRevision&&!e.useLocalCanvasKit?W("https://www.gstatic.com/flutter-canvaskit",e.engineRevision):"canvaskit"}var g=class{constructor(){this._scriptLoaded=!1}setTrustedTypesPolicy(e){this._ttPolicy=e}async loadEntrypoint(e){let{entrypointUrl:s=m("main.dart.js"),onEntrypointLoaded:t,nonce:r}=e||{};return this._loadJSEntrypoint(s,t,r)}async load(e,s,t,r,i){i??=a=>{a.initializeEngine(t).then(l=>l.runApp())};let{entrypointBaseUrl:o}=t,{entryPointBaseUrl:c}=t;if(!o&&c&&(console.warn("[deprecated] `entryPointBaseUrl` is deprecated and will be removed in a future release. Use `entrypointBaseUrl` instead."),o=c),e.compileTarget==="dart2wasm")return this._loadWasmEntrypoint(e,s,o,i);{let a=e.mainJsPath??"main.dart.js",l=m(o,a);return this._loadJSEntrypoint(l,i,r)}}didCreateEngineInitializer(e){typeof this._didCreateEngineInitializerResolve=="function"&&(this._didCreateEngineInitializerResolve(e),this._didCreateEngineInitializerResolve=null,delete _flutter.loader.didCreateEngineInitializer),typeof this._onEntrypointLoaded=="function"&&this._onEntrypointLoaded(e)}_loadJSEntrypoint(e,s,t){let r=typeof s=="function";if(!this._scriptLoaded){this._scriptLoaded=!0;let i=this._createScriptTag(e,t);if(r)console.debug("Injecting <script> tag. Using callback."),this._onEntrypointLoaded=s,document.head.append(i);else return new Promise((o,c)=>{console.debug("Injecting <script> tag. Using Promises. Use the callback approach instead!"),this._didCreateEngineInitializerResolve=o,i.addEventListener("error",c),document.head.append(i)})}}async _loadWasmEntrypoint(e,s,t,r){if(!this._scriptLoaded){this._scriptLoaded=!0,this._onEntrypointLoaded=r;let{mainWasmPath:i,jsSupportRuntimePath:o}=e,c=m(t,i),a=m(t,o);this._ttPolicy!=null&&(a=this._ttPolicy.createScriptURL(a));let p=(await import(a)).compileStreaming(fetch(c)),d;e.renderer==="skwasm"?d=(async()=>{let u=await s.skwasm;return window._flutter_skwasmInstance=u,{skwasm:u.wasmExports,skwasmWrapper:u,ffi:{memory:u.wasmMemory}}})():d=Promise.resolve({}),await(await(await p).instantiate(await d)).invokeMain()}}_createScriptTag(e,s){let t=document.createElement("script");t.type="application/javascript",s&&(t.nonce=s);let r=e;return this._ttPolicy!=null&&(r=this._ttPolicy.createScriptURL(e)),t.src=r,t}};async function E(n,e,s){if(e<0)return n;let t,r=new Promise((i,o)=>{t=setTimeout(()=>{o(new Error(`${s} took more than ${e}ms to resolve. Moving on.`,{cause:E}))},e)});return Promise.race([n,r]).finally(()=>{clearTimeout(t)})}var v=class{setTrustedTypesPolicy(e){this._ttPolicy=e}loadServiceWorker(e){if(!e||!("serviceWorker"in navigator))return Promise.resolve();let s=()=>{console.warn(`Loading the service worker using Flutter bootstrap is deprecated and will stop working in a future release.
For more details, see: https://github.com/flutter/flutter/issues/156910`)},t=()=>{let{serviceWorkerVersion:r,serviceWorkerUrl:i=m(`flutter_service_worker.js?v=${r}`),timeoutMillis:o=4e3}=e,c=i;this._ttPolicy!=null&&(c=this._ttPolicy.createScriptURL(c));let a=navigator.serviceWorker.register(c).then(l=>this._getNewServiceWorker(l,r)).then(this._waitForServiceWorkerActivation);return E(a,o,"prepareServiceWorker")};return e.serviceWorkerUrl!=null?(s(),t()):navigator.serviceWorker.getRegistration().then(r=>r?t():Promise.resolve())}async _getNewServiceWorker(e,s){if(!e.active&&(e.installing||e.waiting))return console.debug("Installing/Activating first service worker."),e.installing||e.waiting;if(e.active.scriptURL.endsWith(s))return console.debug("Loading from existing service worker."),e.active;{let t=await e.update();return console.debug("Updating service worker."),t.installing||t.waiting||t.active}}async _waitForServiceWorkerActivation(e){if(!e||e.state==="activated")if(e){console.debug("Service worker already active.");return}else throw new Error("Cannot activate a null service worker!");return new Promise((s,t)=>{e.addEventListener("statechange",()=>{e.state==="activated"&&(console.debug("Activated new service worker."),s())})})}};var y=class{constructor(e,s="flutter-js"){let t=e||[/\.js$/,/\.mjs$/];window.trustedTypes&&(this.policy=trustedTypes.createPolicy(s,{createScriptURL:function(r){if(r.startsWith("blob:"))return r;let i=new URL(r,window.location),o=i.pathname.split("/").pop();if(t.some(a=>a.test(o)))return i.toString();console.error("URL rejected by TrustedTypes policy",s,":",r,"(download prevented)")}}))}};var b=(n,e)=>{let s=window._flutter?.buildConfig?.wasmHashes,t=s?.[e];if(!t&&e.includes("/")){let a=e.split("/").pop();t=s?.[a]}let r="crossOriginStorage"in navigator&&"requestFileHandles"in navigator.crossOriginStorage;r&&console.log("Cross-Origin Storage is supported. See https://wicg.github.io/cross-origin-storage/ for more details.");let i=async a=>{let l={algorithm:"SHA-256",value:a};try{let[p]=await navigator.crossOriginStorage.requestFileHandles([l]),d=await p.getFile();return new Response(d,{headers:{"Content-Type":"application/wasm"}})}catch(p){p.name==="NotAllowedError"?console.warn(`Not allowed to retrieve ${e} (hash: ${a}).`):p.name!=="NotFoundError"&&console.warn(`Unexpected error during retrieval of ${e} (hash: ${a}).`,p)}},o=async()=>{if(r&&t){let l=await i(t);if(l)return l}let a=await fetch(n);if(r&&t&&a.ok){let l={algorithm:"SHA-256",value:t},p=a.clone();(async()=>{try{let d=await p.blob(),[h]=await navigator.crossOriginStorage.requestFileHandles([l],{create:!0}),w=await h.createWritable();await w.write(d),await w.close()}catch(d){console.warn(`Error storing ${e} (hash: ${t}):`,d)}})()}return a},c=WebAssembly.compileStreaming(o());return(a,l)=>((async()=>{let p=await c,d=await WebAssembly.instantiate(p,a);l(d,p)})(),{})};var I=(n,e,s,t)=>(window.flutterCanvasKitLoaded=(async()=>{if(window.flutterCanvasKit)return window.flutterCanvasKit;let r=s.hasChromiumBreakIterators&&s.hasImageCodecs;if(!r&&e.canvasKitVariant=="chromium")throw"Chromium CanvasKit variant specifically requested, but unsupported in this browser";let i=r&&e.canvasKitVariant!=="full",o=i&&e.preferWebParagraph&&s.hasTextCluster,c=t;o?c=m(c,"webparagraph"):i&&(c=m(c,"chromium"));let a=m(c,"canvaskit.js");n.flutterTT.policy&&(a=n.flutterTT.policy.createScriptURL(a));let l="canvaskit.wasm";o?l="webparagraph/canvaskit.wasm":i&&(l="chromium/canvaskit.wasm");let p=b(m(c,"canvaskit.wasm"),l),d=await import(a);return window.flutterCanvasKit=await d.default({instantiateWasm:p}),window.flutterCanvasKit})(),window.flutterCanvasKitLoaded);var U=async(n,e,s,t)=>{let i=!s.hasImageCodecs||!s.hasChromiumBreakIterators?"skwasm_heavy":e.enableWimp?"wimp":"skwasm",o=m(t,`${i}.js`),c=o;n.flutterTT.policy&&(c=n.flutterTT.policy.createScriptURL(c));let a=b(m(t,`${i}.wasm`),`${i}.wasm`),l=await import(c);return!s.crossOriginIsolated&&!e.forceSingleThreadedSkwasm&&!e.suppressMultithreadingWarning&&console.warn(`Flutter Web: Skwasm uses multi-threading and web workers for better performance, but your page needs to be cross-origin isolated to support multi-threading. Skwasm will run in single-threaded mode.
To enable multithreading, serve your app with these HTTP response headers:
  Cross-Origin-Opener-Policy: same-origin
  Cross-Origin-Embedder-Policy: require-corp
See https://web.dev/articles/coop-coep for guidance.
To silence this warning, set \`suppressMultithreadingWarning: true\` in your Flutter configuration.`),await l.default({skwasmSingleThreaded:e.enableWimp||!s.crossOriginIsolated||s.isChromeExtension||e.forceSingleThreadedSkwasm,instantiateWasm:a,locateFile:(p,d)=>p.endsWith(".ww.js")?URL.createObjectURL(new Blob([`
"use strict";

let eventListener;
eventListener = (message) => {
    const pendingMessages = [];
    const data = message.data;
    data["instantiateWasm"] = (info,receiveInstance) => {
        const instance = new WebAssembly.Instance(data["wasm"], info);
        return receiveInstance(instance, data["wasm"])
    };
    import(data.js).then(async (skwasm) => {
        await skwasm.default(data);

        removeEventListener("message", eventListener);
        for (const message of pendingMessages) {
            dispatchEvent(message);
        }
    });
    removeEventListener("message", eventListener);
    eventListener = (message) => {

        pendingMessages.push(message);
    };

    addEventListener("message", eventListener);
};
addEventListener("message", eventListener);
`],{type:"application/javascript"})):m(t,p),mainScriptUrlOrBlob:o})};var P=f.supportsWasmGC,k=class{async loadEntrypoint(e){let{serviceWorker:s,...t}=e||{},r=new y,i=new v;i.setTrustedTypesPolicy(r.policy),await i.loadServiceWorker(s).catch(c=>{console.warn("Exception while loading service worker:",c)});let o=new g;return o.setTrustedTypesPolicy(r.policy),this.didCreateEngineInitializer=o.didCreateEngineInitializer.bind(o),o.loadEntrypoint(t)}async load({serviceWorkerSettings:e,onEntrypointLoaded:s,nonce:t,config:r}={}){r??={};let i=_flutter.buildConfig;if(!i)throw"FlutterLoader.load requires _flutter.buildConfig to be set";let o=r.wasmAllowList?.[f.browserEngine]??C[f.browserEngine],c=u=>{switch(u){case"skwasm":return P?f.webGLVersion>0?o?null:`Skwasm is disabled by your wasmAllowList configuration for browser engine "${f.browserEngine}".`:"Skwasm requires WebGL support; this browser does not provide it.":"Skwasm requires WasmGC support; this browser does not implement it yet.";default:return null}},a=u=>u.compileTarget==="dart2wasm"&&!P?"dart2wasm requires WasmGC support; this browser does not implement it yet.":r.renderer&&r.renderer!=u.renderer?`The application is configured to use the "${r.renderer}" renderer; this build targets "${u.renderer}".`:c(u.renderer),l,p=[];for(let u of i.builds){let S=a(u);if(S===null){l=u;break}p.push({candidate:u,reason:S})}if(r.verboseBuildSelection)for(let u of p)console.warn(`Flutter Web: build ${u.candidate.compileTarget}/${u.candidate.renderer} was skipped: ${u.reason}`);if(!l)throw console.warn("Flutter Web: no compatible build found for this browser."+(r.verboseBuildSelection?"":" Set `verboseBuildSelection: true` in your Flutter configuration to see why each candidate was rejected.")),new Error("FlutterLoader could not find a build compatible with configuration and environment.");let d={};d.flutterTT=new y,e&&(d.serviceWorkerLoader=new v,d.serviceWorkerLoader.setTrustedTypesPolicy(d.flutterTT.policy),await d.serviceWorkerLoader.loadServiceWorker(e).catch(u=>{console.warn("Exception while loading service worker:",u)}));let h=_(r,i);l.renderer==="canvaskit"?d.canvasKit=I(d,r,f,h):l.renderer==="skwasm"&&(d.skwasm=U(d,r,f,h));let w=new g;return w.setTrustedTypesPolicy(d.flutterTT.policy),this.didCreateEngineInitializer=w.didCreateEngineInitializer.bind(w),w.load(l,d,r,t,s)}};window._flutter||(window._flutter={});window._flutter.loader||(window._flutter.loader=new k);})();
//# sourceMappingURL=flutter.js.map

if (!window._flutter) {
  window._flutter = {};
}
_flutter.buildConfig = {"engineRevision":"692136cb6582dbfc5af3fb33c2515a069f2f66d0","wasmHashes":{"canvaskit.wasm":"fbed517a43e82452404446683f00f2e876d835aed84410695759e67b6bb01cd3","chromium/canvaskit.wasm":"ae8ff1d858140f7b1300ced3fa89fb8c9dce0a400a0f4f1e11f6dcfb3315fdcf","skwasm.wasm":"e540fd5e8303b7b68ec2718cb49e9c421f8ade3075b15e02a7059a62654df9a1","skwasm_heavy.wasm":"565f5cc1cca6ab120f11934b105f01fec4b58b480c82e0889dca93af8e6f8635","webparagraph/canvaskit.wasm":"0ce1b05082efdc8529550e8a01f6ff0593972d55525035010e26f5600aa9f254","wimp.wasm":"e924eaafd801d41e017d178f3fd5cf8a417f641fe35c9ed34a4e1d7582283e0c"},"builds":[{"compileTarget":"dart2js","renderer":"canvaskit","mainJsPath":"main.dart.js"},{}]};


// Start-up picks how the screen is drawn.
//
// Normally the app draws with the graphics card (WebGL), which is fast. On some computers the graphics
// driver cannot compile two of the small programs ("shaders") the engine needs, for rounded shapes and for
// text. The browser then prints "Shader compilation error", the screen blinks and the app keeps redrawing.
//
// So before starting, the exact same two shaders are test-compiled here. If the driver accepts them the
// graphics card is used as usual; if it rejects them, only that computer falls back to drawing with the
// processor (slower, but stable and without blinking).
function graphicsCardCanDraw() {
  try {
    const gl = document.createElement('canvas').getContext('webgl2');
    if (!gl) return false;
    const shaders = [
      // text (glyph atlas lookup with a texture bias)
      `#version 300 es
precision mediump float;
precision mediump sampler2D;
out mediump vec4 sk_FragColor;
uniform sampler2D uTextureSampler_0_S0;
in highp vec2 vTextureCoords_S0;
in mediump vec4 vinColor_S0;
void main() {
  mediump vec4 texColor = texture(uTextureSampler_0_S0, vTextureCoords_S0, -0.475).xxxx;
  sk_FragColor = vinColor_S0 * texColor;
}`,
      // rounded shapes (circle / rounded-corner edges)
      `#version 300 es
precision mediump float;
precision mediump sampler2D;
out mediump vec4 sk_FragColor;
in highp vec4 vinCircleEdge_S0;
in mediump vec4 vinColor_S0;
void main() {
  highp float d = length(vinCircleEdge_S0.xy);
  mediump float distanceToOuterEdge = vinCircleEdge_S0.z * (1.0 - d);
  mediump float edgeAlpha = clamp(distanceToOuterEdge, 0.0, 1.0);
  sk_FragColor = vinColor_S0 * vec4(edgeAlpha);
}`,
      // rounded shapes clipped to a rounded rectangle (cards, buttons, avatars)
      `#version 300 es
uniform highp vec2 u_skRTFlip;
precision mediump float;
precision mediump sampler2D;
out mediump vec4 sk_FragColor;
uniform highp vec4 uinnerRect_S1;
uniform mediump vec2 uradiusPlusHalf_S1;
in highp vec4 vinCircleEdge_S0;
in mediump vec4 vinColor_S0;
void main() {
  highp vec4 sk_FragCoord = vec4(gl_FragCoord.x, u_skRTFlip.x + u_skRTFlip.y * gl_FragCoord.y, gl_FragCoord.z, gl_FragCoord.w);
  highp vec4 circleEdge = vinCircleEdge_S0;
  mediump vec4 outputColor_S0 = vinColor_S0;
  highp float d = length(circleEdge.xy);
  mediump float distanceToOuterEdge = circleEdge.z * (1.0 - d);
  mediump float edgeAlpha = clamp(distanceToOuterEdge, 0.0, 1.0);
  mediump vec4 outputCoverage_S0 = vec4(edgeAlpha);
  highp vec2 _0_dxy0 = uinnerRect_S1.xy - sk_FragCoord.xy;
  highp vec2 _1_dxy1 = sk_FragCoord.xy - uinnerRect_S1.zw;
  highp vec2 _2_dxy = max(max(_0_dxy0, _1_dxy1), 0.0);
  mediump float _3_alpha = clamp(uradiusPlusHalf_S1.x - length(_2_dxy), 0.0, 1.0);
  _3_alpha = 1.0 - _3_alpha;
  mediump vec4 output_S1 = outputCoverage_S0 * _3_alpha;
  sk_FragColor = outputColor_S0 * output_S1;
}`,
    ];
    for (const src of shaders) {
      const s = gl.createShader(gl.FRAGMENT_SHADER);
      gl.shaderSource(s, src);
      gl.compileShader(s);
      const ok = gl.getShaderParameter(s, gl.COMPILE_STATUS);
      gl.deleteShader(s);
      if (!ok) return false;
    }
    return true;
  } catch (e) {
    return false;
  }
}

// DEFAULT: automatic. The graphics card draws the screen (fast) when the start-up check passes; the safety net below
// switches a tab to processor drawing if the driver fails later. (A full disk can stop the browser from saving its graphics
// cache and cause the same errors, so keep some free space.) Remembered for localhost on every port (a cookie ignores the port):
//   open the app once with  ?render=cpu   to always draw with the processor (slower, never blinks)
//   open it once with       ?render=gpu   to always use the graphics card
//   open it once with       ?render=auto  to go back to the automatic choice (the default)
function renderMode() {
  const asked = new URLSearchParams(location.search).get('render');
  if (asked === 'cpu' || asked === 'gpu') {
    document.cookie = 'impacgo_render=' + asked + '; path=/; max-age=31536000';
    return asked;
  }
  if (asked === 'auto') {
    document.cookie = 'impacgo_render=auto; path=/; max-age=31536000';
    return 'auto';
  }
  const saved = document.cookie.match(/(?:^|; )impacgo_render=([^;]*)/);
  return saved && (saved[1] === 'cpu' || saved[1] === 'gpu' || saved[1] === 'auto') ? saved[1] : 'auto';
}
// Safety net: the start-up check can pass and the graphics driver still fail later (it then prints
// "Shader compilation error ... (unknown error)" again and again). The first time that happens, this tab
// switches to drawing with the processor and reloads once. It lasts until the tab is closed, so a
// healthy graphics card is used again next time.
function cpuForThisTab() {
  try { return sessionStorage.getItem('impacgo_cpu') === '1'; } catch (e) { return false; }
}
function watchForShaderErrors() {
  let switched = false;
  const check = (args) => {
    if (switched) return;
    const text = Array.prototype.map.call(args, (a) => String(a)).join(' ');
    if (text.indexOf('Shader compilation error') === -1 && text.indexOf('CONTEXT_LOST') === -1) return;
    switched = true;
    try { sessionStorage.setItem('impacgo_cpu', '1'); } catch (e) {}
    console.info('IMPACGO: graphics driver failed while drawing; switching this tab to processor drawing');
    setTimeout(() => location.reload(), 50);
  };
  for (const level of ['error', 'warn', 'log']) {
    const original = console[level].bind(console);
    console[level] = function () {
      check(arguments);
      return original.apply(null, arguments);
    };
  }
}

const mode = renderMode();
const gpuOk = mode === 'cpu' || cpuForThisTab() ? false : mode === 'gpu' ? true : graphicsCardCanDraw();
// (mode is 'cpu' unless someone asked for 'gpu' or 'auto', so gpuOk is false by default)
if (gpuOk && mode === 'auto') watchForShaderErrors();
console.info('IMPACGO drawing mode: ' + (gpuOk ? 'graphics card' : 'processor') + ' (' + (mode === 'auto' ? 'automatic check' : (/(?:^|; )impacgo_render=/.test(document.cookie) || new URLSearchParams(location.search).has('render')) ? 'chosen by you with ?render=' + mode : 'default') + ')');
// the app reads this to skip costly blurred shadows when the processor does the drawing
document.documentElement.setAttribute('data-impacgo-cpu', String(!gpuOk));
// Drawing with the processor is the chosen, safe mode on this setup, so Flutter's own notice about it is not an error:
// that one message is left out of the console (every other warning still shows).
if (!gpuOk) {
  const warn = console.warn.bind(console);
  console.warn = (...args) => {
    if (args.length && String(args[0]).includes('canvasKitForceCpuOnly')) return;
    warn(...args);
  };
}
// A debug build (plain "flutter run") is many times slower than a release build. If the fast release copy is being served
// on localhost:8099 (double-click serve_release.cmd), a debug page hops to it by itself, however it was started.
// Add ?stay to the address to stay on the debug build (hot reload while developing).
async function hopToFastCopy() {
  try {
    const debugBuild = ((_flutter.buildConfig && _flutter.buildConfig.builds) || []).some((b) => b && b.compileTarget === 'dartdevc');
    const stay = new URLSearchParams(location.search).has('stay');
    if (!debugBuild || stay || location.hostname !== 'localhost' || location.port === '8099') return false;
    const ctl = new AbortController();
    const timer = setTimeout(() => ctl.abort(), 900);
    await fetch('http://localhost:8099/flutter_bootstrap.js', { mode: 'no-cors', cache: 'no-store', signal: ctl.signal });
    clearTimeout(timer);
    console.info('IMPACGO: this is the slow debug build; opening the fast release copy on localhost:8099');
    location.replace('http://localhost:8099/' + location.search);
    return true;
  } catch (e) {
    return false; // nothing on 8099: stay on this page (it shows the "Debug build" note)
  }
}
hopToFastCopy().then((hopped) => {
  if (hopped) return;
  _flutter.loader.load({
    config: { canvasKitForceCpuOnly: !gpuOk },
  });
});
