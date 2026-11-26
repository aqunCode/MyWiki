/* ============================================================
 * MyWiki 数学公式渲染脚本
 * 文件：docs/javascripts/mathjax.js
 * 对应 mkdocs.yml 中的 extra_javascript 与
 * markdown_extensions.pymdownx.arithmatex (generic: true)
 *
 * 加载策略：优先本地离线副本，失败时回退到 CDN。
 * 完全离线/内网环境请把 MathJax 3 的 es5 包放到：
 *   docs/javascripts/mathjax/es5/tex-mml-chtml.js
 * 若本地副本不存在且无外网，页面上会保留原始 TeX 文本，
 * 但不会影响其余内容渲染，也不会阻塞页面加载。
 * ============================================================ */

(function () {
  "use strict";

  /* MathJax 3 全局配置 */
  window.MathJax = {
    tex: {
      inlineMath: [["\\(", "\\)"]],
      displayMath: [["$$", "$$"], ["\\[", "\\]"]],
      processEscapes: true,
      processEnvironments: true
    },
    options: {
      /* arithmatex generic 模式输出的容器类名 */
      processHtmlClass: "arithmatex",
      ignoreHtmlClass: ".*|"
    },
    startup: {
      typeset: true
    }
  };

  var LOCAL_SRC = "javascripts/mathjax/es5/tex-mml-chtml.js";
  var CDN_SRC = "https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js";

  function loadScript(src, onError) {
    var script = document.createElement("script");
    script.src = src;
    script.async = true;
    script.onerror = onError;
    document.head.appendChild(script);
  }

  loadScript(LOCAL_SRC, function () {
    /* 本地副本缺失时尝试 CDN；无网络时静默降级 */
    loadScript(CDN_SRC, function () {
      if (window.console && console.warn) {
        console.warn("[MyWiki] MathJax 未加载：请放置本地副本或连接网络。公式将以 TeX 原文显示。");
      }
    });
  });
})();
