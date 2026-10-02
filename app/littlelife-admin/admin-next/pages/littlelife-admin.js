const tagName = window.__GRAV_PAGE_TAG || 'grav-littlelife-admin--page';

class LittleLifeAdminPage extends HTMLElement {
  constructor() {
    super();
    this.attachShadow({ mode: 'open' });
    this.entries = [];
    this.current = null;
  }

  connectedCallback() {
    this.render();
    this.bind();
    this.loadEntries();
  }

  apiUrl(path) {
    const server = (window.__GRAV_API_SERVER_URL || '').replace(/\/$/, '');
    const prefix = window.__GRAV_API_PREFIX || '/api/v1';
    return `${server}${prefix}${path}`;
  }

  async api(path, options = {}) {
    const headers = new Headers(options.headers || {});
    const token = window.__GRAV_API_TOKEN;
    if (token) headers.set('X-API-Token', token);
    headers.set('X-Requested-With', 'XMLHttpRequest');
    if (options.body && !(options.body instanceof FormData)) headers.set('Content-Type', 'application/json');
    const response = await fetch(this.apiUrl(path), { ...options, headers, credentials: 'same-origin' });
    const type = response.headers.get('content-type') || '';
    const payload = type.includes('json') ? await response.json() : await response.text();
    if (!response.ok) {
      throw new Error(payload?.error?.detail || payload?.error?.message || payload?.message || `HTTP ${response.status}`);
    }
    return payload?.data ?? payload;
  }

  render() {
    this.shadowRoot.innerHTML = `
      <style>
        :host{display:block;color:var(--foreground,#202124);font:14px/1.5 system-ui,sans-serif}.wrap{display:grid;grid-template-columns:minmax(230px,320px) minmax(0,1fr);gap:18px;padding:20px}.card{background:var(--card,#fff);border:1px solid var(--border,#ddd);border-radius:12px;overflow:hidden}.side{min-height:650px}.head{display:flex;align-items:center;justify-content:space-between;padding:16px;border-bottom:1px solid var(--border,#ddd)}h2{font-size:16px;margin:0}.list{max-height:590px;overflow:auto}.item{display:block;width:100%;border:0;border-bottom:1px solid var(--border,#eee);background:transparent;text-align:left;padding:12px 16px;color:inherit;cursor:pointer}.item:hover,.item.active{background:var(--accent,#f2f4f7)}.item strong,.item small{display:block}.item small{opacity:.65;margin-top:3px}.form{padding:20px}.grid{display:grid;grid-template-columns:2fr 1fr 1fr;gap:14px}label{display:block;font-weight:650;margin-bottom:12px}input,select,textarea{box-sizing:border-box;width:100%;margin-top:6px;padding:9px 10px;border:1px solid var(--border,#cbd0d6);border-radius:7px;background:var(--background,#fff);color:inherit;font:inherit}textarea{min-height:260px;resize:vertical}.actions{display:flex;gap:9px;flex-wrap:wrap;margin-top:16px}.btn{border:1px solid var(--border,#cbd0d6);border-radius:7px;padding:9px 14px;background:var(--secondary,#f4f5f6);color:inherit;font-weight:650;cursor:pointer}.btn.primary{background:var(--primary,#2563eb);color:#fff;border-color:transparent}.btn:disabled{opacity:.55;cursor:wait}.status{margin:12px 0 0;padding:10px 12px;border-radius:7px;display:none}.status.show{display:block}.status.ok{background:#dcfce7;color:#166534}.status.err{background:#fee2e2;color:#991b1b}.media{display:flex;flex-wrap:wrap;gap:8px;margin:8px 0 14px}.chip{font-size:12px;border:1px solid var(--border,#ddd);border-radius:999px;padding:4px 9px;text-decoration:none;color:inherit}.muted{opacity:.65}.empty{padding:24px;text-align:center;opacity:.65}@media(max-width:850px){.wrap{grid-template-columns:1fr}.side{min-height:0}.list{max-height:260px}.grid{grid-template-columns:1fr}}
      </style>
      <div class="wrap">
        <section class="card side"><div class="head"><h2>成长记录</h2><button class="btn" id="new">新建</button></div><div class="list" id="list"><div class="empty">正在读取…</div></div></section>
        <section class="card form">
          <div class="grid">
            <label>标题<input id="title" maxlength="200" required></label>
            <label>日期时间<input id="date" type="datetime-local" required></label>
            <label>类型<select id="type"><option value="story">成长故事</option><option value="milestone">里程碑</option><option value="note">备注</option></select></label>
          </div>
          <label>标签（逗号分隔）<input id="tags" placeholder="第一次, 家庭"></label>
          <label>正文（Markdown）<textarea id="content" placeholder="写下今天发生的故事……"></textarea></label>
          <label>添加原始照片、视频或音频<input id="files" type="file" accept="image/*,video/*,audio/*" multiple></label>
          <div class="media" id="media"></div>
          <div class="actions"><button class="btn primary" id="save">保存记录并上传</button><button class="btn" id="verify">完整性检查</button><button class="btn" id="rebuild">重建网站</button><button class="btn" id="export">导出开放格式 ZIP</button></div>
          <div class="status" id="status"></div>
          <p class="muted">原始媒体只追加、不覆盖；每次编辑自动保存旧版本快照并记录审计日志。</p>
        </section>
      </div>`;
  }

  bind() {
    this.$('#new').addEventListener('click', () => this.resetForm());
    this.$('#save').addEventListener('click', () => this.save());
    this.$('#verify').addEventListener('click', () => this.verify());
    this.$('#rebuild').addEventListener('click', () => this.rebuild());
    this.$('#export').addEventListener('click', () => this.exportArchive());
  }

  $(selector) { return this.shadowRoot.querySelector(selector); }
  value(selector) { return this.$(selector).value; }
  busy(on) { this.shadowRoot.querySelectorAll('button').forEach(button => { button.disabled = on; }); }
  message(text, ok = true) { const box=this.$('#status'); box.textContent=text; box.className=`status show ${ok?'ok':'err'}`; }
  localDate(date = new Date()) { const shifted=new Date(date.getTime()-date.getTimezoneOffset()*60000); return shifted.toISOString().slice(0,16); }

  async loadEntries(selectId = null) {
    try {
      const data = await this.api('/littlelife/entries');
      this.entries = data.entries;
      this.$('#list').innerHTML = this.entries.length ? this.entries.map(entry => `<button class="item ${entry.id===selectId?'active':''}" data-id="${this.escape(entry.id)}"><strong>${this.escape(entry.title)}</strong><small>${this.escape(entry.date.slice(0,10))} · ${entry.media_count} 个媒体</small></button>`).join('') : '<div class="empty">还没有记录</div>';
      this.shadowRoot.querySelectorAll('.item').forEach(button => button.addEventListener('click', () => this.loadEntry(button.dataset.id)));
    } catch (error) { this.message(`读取失败：${error.message}`, false); }
  }

  async loadEntry(id) {
    this.busy(true);
    try {
      this.current = await this.api(`/littlelife/entries/${encodeURIComponent(id)}`);
      this.$('#title').value = this.current.title;
      this.$('#date').value = this.current.date.slice(0,16);
      this.$('#date').disabled = true;
      this.$('#type').value = this.current.type;
      this.$('#tags').value = (this.current.tags || []).join(', ');
      this.$('#content').value = this.current.content;
      this.$('#files').value = '';
      this.$('#media').innerHTML = this.current.media.map(item => `<a class="chip" href="${this.escape(item.url)}" target="_blank" rel="noopener">${this.escape(item.name)}</a>`).join('');
      await this.loadEntries(id);
    } catch (error) { this.message(`读取失败：${error.message}`, false); }
    finally { this.busy(false); }
  }

  resetForm() {
    this.current = null;
    this.$('#title').value=''; this.$('#date').value=this.localDate(); this.$('#date').disabled=false;
    this.$('#type').value='story'; this.$('#tags').value=''; this.$('#content').value=''; this.$('#files').value=''; this.$('#media').innerHTML='';
    this.$('#status').className='status'; this.loadEntries();
  }

  async save() {
    const title=this.value('#title').trim(); if(!title){this.message('请填写标题。',false);return;}
    this.busy(true);
    try {
      const rawDate=this.value('#date');
      const date=this.current ? this.current.date : new Date(rawDate).toISOString();
      const saved=await this.api('/littlelife/entries',{method:'POST',body:JSON.stringify({id:this.current?.id||null,title,date,type:this.value('#type'),tags:this.value('#tags'),content:this.value('#content')})});
      const files=Array.from(this.$('#files').files||[]);
      if(files.length){const form=new FormData(); files.forEach(file=>form.append('files[]',file,file.name)); await this.api(`/littlelife/entries/${encodeURIComponent(saved.id)}/media`,{method:'POST',body:form});}
      this.message(files.length?`记录已保存，并归档 ${files.length} 个原始媒体。`:'记录已保存。');
      await this.loadEntry(saved.id);
    } catch(error){this.message(`保存失败：${error.message}`,false);}
    finally{this.busy(false);}
  }

  async verify(){this.busy(true);try{const data=await this.api('/littlelife/integrity');this.message(`校验通过：${data.records} 条记录，${data.media_checked} 个原始媒体。`);}catch(error){this.message(`校验失败：${error.message}`,false);}finally{this.busy(false);}}
  async rebuild(){this.busy(true);try{const data=await this.api('/littlelife/rebuild',{method:'POST',body:'{}'});this.message(`网站已重建：${data.records} 条记录，${data.media_copies} 个媒体副本。`);}catch(error){this.message(`重建失败：${error.message}`,false);}finally{this.busy(false);}}
  async exportArchive(){this.busy(true);try{const data=await this.api('/littlelife/export',{method:'POST',body:'{}'});const url=this.apiUrl(data.download_url);const token=window.__GRAV_API_TOKEN;const response=await fetch(url,{headers:{'X-API-Token':token,'X-Requested-With':'XMLHttpRequest'}});if(!response.ok)throw new Error(`HTTP ${response.status}`);const blob=await response.blob();const link=document.createElement('a');link.href=URL.createObjectURL(blob);link.download=data.filename;link.click();setTimeout(()=>URL.revokeObjectURL(link.href),1000);this.message(`开放格式导出已生成：${data.filename}`);}catch(error){this.message(`导出失败：${error.message}`,false);}finally{this.busy(false);}}
  escape(value){return String(value??'').replace(/[&<>"']/g,char=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[char]));}
}

if (!customElements.get(tagName)) customElements.define(tagName, LittleLifeAdminPage);
