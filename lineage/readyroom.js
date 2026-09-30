/* Unit Ready Room: fills the #ready-room tile on a lineage page with the
   entries filed for that unit in readyroom.json, filterable by year. */
(function(){
  var tile = document.getElementById('ready-room');
  if (!tile) return;
  var key = (location.pathname.split('/').pop() || '').replace(/\.html?$/i, '');
  var unitName = (document.querySelector('h1') || {}).textContent || key;
  var body = document.getElementById('rr-body');
  var years = document.getElementById('rr-years');
  var count = document.getElementById('rr-count');
  var suggest = document.getElementById('rr-suggest');

  // The suggest link names the unit, so submissions arrive already sorted.
  suggest.href = 'mailto:execdirector@fghms.com'
    + '?subject=' + encodeURIComponent('Unit Ready Room: ' + unitName.trim())
    + '&body=' + encodeURIComponent('Unit: ' + unitName.trim() + '\nYear(s):\nWhat it is (photo, orders, article, video, story):\nLink or attachment:\nWho made it, and may the museum show it?\n');

  function el(tag, cls, text){
    var n = document.createElement(tag);
    if (cls) n.className = cls;
    if (text != null) n.textContent = text;
    return n;
  }
  function yearLabel(y){ return y == null ? 'Ongoing' : String(y); }

  function render(items){
    if (!items.length) return;
    // group by year; "Ongoing" (null) sorts last
    var groups = {}, order = [];
    items.forEach(function(it){
      var k = yearLabel(it.year);
      if (!groups[k]){ groups[k] = []; order.push(k); }
      groups[k].push(it);
    });
    order.sort(function(a, b){
      if (a === 'Ongoing') return 1;
      if (b === 'Ongoing') return -1;
      return Number(a) - Number(b);
    });

    var dated = order.filter(function(k){ return k !== 'Ongoing'; });
    count.textContent = items.length + (items.length === 1 ? ' item' : ' items')
      + (dated.length ? ' · ' + dated[0] + (dated.length > 1 ? '–' + dated[dated.length - 1] : '') : '');

    body.textContent = '';
    order.forEach(function(k){
      var sec = el('div', 'rr-year');
      sec.setAttribute('data-year', k);
      sec.appendChild(el('div', 'rr-ylabel', k));
      var list = el('div', 'rr-items');
      groups[k].forEach(function(it){
        var ext = /^https?:/i.test(it.url);
        var a = el('a', 'rr-item');
        a.href = it.url;
        if (ext){ a.target = '_blank'; a.rel = 'noopener'; }
        a.appendChild(el('span', 'rr-kind', it.kind || 'Item'));
        var main = el('span', 'rr-main');
        main.appendChild(el('span', 'rr-t', it.title + (ext ? ' ↗' : '')));
        var meta = [it.source, it.date].filter(Boolean).join(' · ');
        if (meta) main.appendChild(el('span', 'rr-m', meta));
        if (it.note) main.appendChild(el('span', 'rr-n', it.note));
        a.appendChild(main);
        list.appendChild(a);
      });
      sec.appendChild(list);
      body.appendChild(sec);
    });

    // year filter chips, only worth showing when there is more than one year
    if (order.length < 2) return;
    function chip(label, k){
      var b = el('button', 'rr-chip', label);
      b.type = 'button';
      b.setAttribute('data-filter', k);
      b.setAttribute('aria-pressed', k === '*' ? 'true' : 'false');
      return b;
    }
    years.appendChild(chip('All years', '*'));
    order.forEach(function(k){ years.appendChild(chip(k, k)); });
    years.hidden = false;
    years.addEventListener('click', function(e){
      var b = e.target.closest('.rr-chip');
      if (!b) return;
      var k = b.getAttribute('data-filter');
      years.querySelectorAll('.rr-chip').forEach(function(c){ c.setAttribute('aria-pressed', String(c === b)); });
      body.querySelectorAll('.rr-year').forEach(function(s){ s.hidden = k !== '*' && s.getAttribute('data-year') !== k; });
    });
  }

  fetch('readyroom.json', {cache: 'no-cache'})
    .then(function(r){ return r.ok ? r.json() : null; })
    .then(function(data){ render((data && data.units && data.units[key]) || []); })
    .catch(function(){ /* keep the empty-state text */ });
})();
