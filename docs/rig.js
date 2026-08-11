/* ==========================================================================
   uprint — landing page behaviour
   Two independent modules, no dependencies, no build step.
     1. The FIG. 1 prompt-to-paper rig.
     2. Copy-to-clipboard for command blocks.
   ========================================================================== */

/* ---------------------------------------------------------------- FIG. 1 */
(function () {
  var rig = document.getElementById('rig');
  if (!rig) { return; }

  var go = document.getElementById('go'),
      inp = document.getElementById('prompt'),
      cmd = document.getElementById('cmd'),
      env = document.getElementById('env'),
      state = document.getElementById('state'),
      doc = document.getElementById('doc'),
      rowCmd = document.getElementById('rowCmd'),
      rowEnv = document.getElementById('rowEnv'),
      rowState = document.getElementById('rowState'),
      timers = [],
      reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  /* This excerpt shows the fields that matter to the animation. The complete
     version 1 envelope appears in the agent section below the rig. */
  var ENV = '{"version":1,"command":"print","success":true,\n "data":{"engine":"SumatraPDF",\n  "status":<span class="s">"submitted_to_cloud"</span>}}';

  function commandFor(file) {
    return '.\\uprint.ps1 print "' + file + '" --json';
  }

  function fileFrom(text) {
    var s = (text || '').trim()
      .replace(/^(please\s+)?(can you\s+)?(go\s+)?print(\s+out)?\s+/i, '')
      .replace(/^(the|a|an|my|this)\s+/i, '')
      .replace(/\s+(for|to|on|at|by)\s+.*$/i, '')
      .replace(/[^A-Za-z0-9 _-]/g, '')
      .trim();
    if (!s) { s = 'document'; }
    return s.split(/\s+/).slice(0, 5).join('-').slice(0, 34) + '.pdf';
  }

  function at(ms, fn) { timers.push(setTimeout(fn, ms)); }

  function reset() {
    timers.forEach(clearTimeout);
    timers = [];
    rig.className = 'machine rig';
    rig.dataset.led = 'off';
    rowCmd.classList.remove('on');
    rowEnv.classList.remove('on');
    rowState.classList.remove('on');
    cmd.textContent = '';
    env.textContent = '';
    state.textContent = '—';
    state.className = '';
  }

  function typeInto(el, txt, speed) {
    var i = 0;
    (function step() {
      if (i <= txt.length) {
        el.textContent = txt.slice(0, i++);
        at(speed, step);
      }
    })();
  }

  function run() {
    reset();
    var file = fileFrom(inp.value);
    doc.textContent = file.replace(/\.pdf$/, '').replace(/-/g, ' ').toUpperCase();
    go.disabled = true;
    go.textContent = '• RUNNING';

    if (reduce) {
      rowCmd.classList.add('on');
      rowEnv.classList.add('on');
      rowState.classList.add('on');
      cmd.textContent = commandFor(file);
      env.innerHTML = ENV;
      state.textContent = 'SUBMITTED TO CLOUD';
      state.className = 'st-rel';
      rig.className = 'machine rig printing done';
      rig.dataset.led = 'green';
      go.disabled = false;
      go.textContent = '▶ RUN AGAIN';
      return;
    }

    at(150, function () {
      rowCmd.classList.add('on');
      typeInto(cmd, commandFor(file), 24);
    });
    at(1300, function () {
      rowEnv.classList.add('on');
      env.innerHTML = ENV;
    });
    /* Nothing inside the machine moves yet: Universal Print holds the job
       in the cloud until a badge is presented at the device. */
    at(1950, function () {
      rowState.classList.add('on');
      state.textContent = 'SUBMITTED TO CLOUD';
      state.className = 'st-held';
      rig.dataset.led = 'amber';
    });
    at(2900, function () { rig.classList.add('badged'); });
    at(3450, function () {
      rig.dataset.led = 'green';
    });
    at(3700, function () { rig.classList.add('working', 'feeding'); });
    at(4400, function () { rig.classList.add('printing'); });
    at(7100, function () {
      rig.classList.remove('working');
      rig.classList.add('done');
      go.disabled = false;
      go.textContent = '▶ RUN AGAIN';
    });
  }

  go.addEventListener('click', run);
  inp.addEventListener('keydown', function (e) {
    if (e.key === 'Enter' && !go.disabled) { run(); }
  });
  at(500, run);
})();

/* ------------------------------------------------------------------ COPY */
(function () {
  function flash(btn, label) {
    var prev = btn.textContent;
    btn.textContent = label;
    btn.classList.add('done');
    setTimeout(function () {
      btn.textContent = prev;
      btn.classList.remove('done');
    }, 1600);
  }

  document.querySelectorAll('button.copy[data-copy]').forEach(function (btn) {
    btn.addEventListener('click', function () {
      var src = document.querySelector(btn.getAttribute('data-copy'));
      if (!src) { return; }
      var text = src.textContent;

      if (navigator.clipboard && window.isSecureContext) {
        navigator.clipboard.writeText(text).then(
          function () { flash(btn, 'COPIED'); },
          function () { flash(btn, 'FAILED'); }
        );
        return;
      }

      /* file:// and plain http have no async clipboard. */
      var ta = document.createElement('textarea');
      ta.value = text;
      ta.setAttribute('readonly', '');
      ta.style.position = 'fixed';
      ta.style.opacity = '0';
      document.body.appendChild(ta);
      ta.select();
      var ok = false;
      try { ok = document.execCommand('copy'); } catch (e) { ok = false; }
      document.body.removeChild(ta);
      flash(btn, ok ? 'COPIED' : 'FAILED');
    });
  });
})();
