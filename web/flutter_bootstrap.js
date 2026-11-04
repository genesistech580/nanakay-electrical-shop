{{flutter_js}}
{{flutter_build_config}}

let startupFallbackTimer;

function removeStartupSplash() {
  window.clearTimeout(startupFallbackTimer);
  if (typeof window.removeSplashFromWeb === 'function') {
    window.removeSplashFromWeb();
  }
}

function showStartupFailure() {
  removeStartupSplash();
  if (document.getElementById('flutter-startup-failure')) return;

  const notice = document.createElement('main');
  notice.id = 'flutter-startup-failure';
  notice.setAttribute('role', 'alert');
  notice.style.cssText = [
    'position:fixed', 'inset:0', 'display:grid', 'place-content:center',
    'gap:14px', 'padding:24px', 'text-align:center', 'font:16px system-ui',
    'color:#24352f', 'background:#f4f1e8', 'z-index:99999'
  ].join(';');

  const message = document.createElement('p');
  message.textContent = 'The shop app did not finish loading. Check your connection and try again.';
  const retry = document.createElement('button');
  retry.textContent = 'Reload app';
  retry.style.cssText = 'justify-self:center;padding:12px 20px;border:0;border-radius:8px;background:#3d6555;color:white;font:inherit';
  retry.addEventListener('click', () => window.location.reload());
  notice.append(message, retry);
  document.body.append(notice);
}

startupFallbackTimer = window.setTimeout(showStartupFailure, 45000);

_flutter.loader.load({
  onEntrypointLoaded: async function (engineInitializer) {
    try {
      const appRunner = await engineInitializer.initializeEngine();
      await appRunner.runApp();
      removeStartupSplash();
    } catch (error) {
      console.error('Flutter app startup failed:', error);
      showStartupFailure();
    }
  }
});
