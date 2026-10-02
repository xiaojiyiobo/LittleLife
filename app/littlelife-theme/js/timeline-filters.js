(() => {
  const controls = document.querySelector('[data-timeline-filters]');
  const timeline = document.querySelector('[data-timeline]');
  if (!controls || !timeline) return;

  const year = controls.querySelector('[data-filter-year]');
  const month = controls.querySelector('[data-filter-month]');
  const tag = controls.querySelector('[data-filter-tag]');
  const milestone = controls.querySelector('[data-filter-milestone]');
  const reset = controls.querySelector('[data-filter-reset]');
  const summary = controls.querySelector('[data-filter-summary]');
  const empty = timeline.querySelector('[data-timeline-empty]');
  const entries = [...timeline.querySelectorAll('[data-timeline-entry]')];

  const normalize = (value) => value.trim().toLocaleLowerCase('zh-Hans');
  const entryTags = (entry) => {
    try {
      const value = JSON.parse(entry.dataset.tags || '[]');
      return Array.isArray(value) ? value.map((item) => normalize(String(item))) : [];
    } catch {
      return [];
    }
  };

  const apply = () => {
    const wantedTag = normalize(tag.value);
    let visible = 0;
    for (const entry of entries) {
      const matches = (!year.value || entry.dataset.year === year.value)
        && (!month.value || entry.dataset.month === month.value)
        && (!wantedTag || entryTags(entry).some((item) => item.includes(wantedTag)))
        && (!milestone.checked || entry.dataset.milestone === 'true');
      entry.hidden = !matches;
      if (matches) visible += 1;
    }
    for (const group of timeline.querySelectorAll('[data-timeline-year]')) {
      group.hidden = !group.querySelector('[data-timeline-entry]:not([hidden])');
    }
    empty.hidden = visible !== 0;
    summary.textContent = `显示 ${visible} / ${entries.length} 条记录`;
  };

  controls.addEventListener('input', apply);
  controls.addEventListener('change', apply);
  reset.addEventListener('click', () => {
    year.value = '';
    month.value = '';
    tag.value = '';
    milestone.checked = false;
    apply();
    year.focus();
  });
  apply();
})();
