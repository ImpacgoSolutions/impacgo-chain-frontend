{{flutter_js}}
{{flutter_build_config}}

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
