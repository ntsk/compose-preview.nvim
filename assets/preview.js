(function () {
  var current = window.__composePreviewToken;
  if (!current) return;
  var key = 'compose-preview-scroll';
  var saved = sessionStorage.getItem(key);
  if (saved) window.scrollTo(0, parseInt(saved, 10) || 0);
  window.addEventListener('scroll', function () {
    sessionStorage.setItem(key, String(window.scrollY));
  });
  setInterval(function () {
    var probe = document.createElement('script');
    probe.src = 'token.js?t=' + Date.now();
    probe.onload = function () {
      if (window.__composePreviewLatest && window.__composePreviewLatest !== current) {
        location.reload();
      }
      probe.remove();
    };
    probe.onerror = function () { probe.remove(); };
    document.head.appendChild(probe);
  }, 1500);
})();
