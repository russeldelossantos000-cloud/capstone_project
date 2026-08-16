/**
 * components.js — Shared UI helpers
 */

// ── Toast ─────────────────────────────────────────────────────────────────────
function toast(message, type = 'info', duration = 3000) {
  const container = document.getElementById('toast-container');
  const el = document.createElement('div');
  el.className = `toast ${type}`;
  el.innerHTML = `
    <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor" style="flex-shrink:0;color:${
      type === 'success' ? 'var(--success)' :
      type === 'error'   ? 'var(--danger)'  : 'var(--info)'
    }">
      ${type === 'success'
        ? '<path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z"/>'
        : type === 'error'
        ? '<path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-2h2v2zm0-4h-2V7h2v6z"/>'
        : '<path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-6h2v6zm0-8h-2V7h2v2z"/>'}
    </svg>
    <span>${message}</span>`;
  container.appendChild(el);
  setTimeout(() => { el.style.opacity = '0'; el.style.transition = 'opacity .3s'; setTimeout(() => el.remove(), 300); }, duration);
}

// ── Modal ─────────────────────────────────────────────────────────────────────
const Modal = (() => {
  const overlay  = document.getElementById('modal-overlay');
  const box      = document.getElementById('modal-box');
  const titleEl  = document.getElementById('modal-title');
  const bodyEl   = document.getElementById('modal-body');
  const footerEl = document.getElementById('modal-footer');
  const closeBtn = document.getElementById('modal-close');

  closeBtn.addEventListener('click', close);
  overlay.addEventListener('click', (e) => { if (e.target === overlay) close(); });

  function open({ title, body, footer = '', large = false }) {
    titleEl.textContent  = title;
    bodyEl.innerHTML     = body;
    footerEl.innerHTML   = footer;
    box.className        = large ? 'modal modal-lg' : 'modal';
    overlay.classList.remove('hidden');
  }

  function close() {
    overlay.classList.add('hidden');
    bodyEl.innerHTML   = '';
    footerEl.innerHTML = '';
  }

  return { open, close };
})();

// ── Spinner ───────────────────────────────────────────────────────────────────
function spinner() {
  return `<div class="spinner-wrap"><div class="spinner"></div><p>Loading…</p></div>`;
}

// ── Badge ─────────────────────────────────────────────────────────────────────
function badge(value) {
  if (!value) return '<span class="badge badge-default">—</span>';
  const cls = {
    pending: 'badge-pending', processing: 'badge-processing',
    shipped: 'badge-shipped', delivered: 'badge-delivered',
    cancelled: 'badge-cancelled', paid: 'badge-paid',
    unpaid: 'badge-unpaid', refunded: 'badge-refunded',
    IN: 'badge-in', OUT: 'badge-out',
  }[value] || 'badge-default';
  return `<span class="badge ${cls}">${value}</span>`;
}

// ── Confirm Dialog ────────────────────────────────────────────────────────────
function confirmDelete(message, onConfirm, options = {}) {
  const title      = options.title      || 'Confirm Delete';
  const buttonText = options.buttonText || 'Delete';

  Modal.open({
    title,
    body: `<p style="color:var(--muted)">${message}</p>`,
    footer: `
      <button class="btn btn-secondary" onclick="Modal.close()">Cancel</button>
      <button class="btn btn-danger" id="confirm-yes">${buttonText}</button>`,
  });
  setTimeout(() => {
    document.getElementById('confirm-yes')?.addEventListener('click', () => {
      Modal.close();
      onConfirm();
    });
  }, 50);
}

// ── Stock color ───────────────────────────────────────────────────────────────
function stockClass(n) {
  n = parseInt(n);
  if (n <= 5) return 'stock-low';
  if (n <= 20) return 'stock-mid';
  return 'stock-ok';
}

// ── Format date ───────────────────────────────────────────────────────────────
function fmtDate(str) {
  if (!str) return '—';
  return new Date(str).toLocaleDateString('en-PH', { year: 'numeric', month: 'short', day: 'numeric' });
}

function fmtDateTime(str) {
  if (!str) return '—';
  return new Date(str).toLocaleString('en-PH', { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' });
}

// ── Currency ──────────────────────────────────────────────────────────────────
function peso(n) {
  return '₱' + parseFloat(n || 0).toLocaleString('en-PH', { minimumFractionDigits: 2 });
}

// ── Paginate array ────────────────────────────────────────────────────────────
function paginate(arr, page, size = 15) {
  const start = (page - 1) * size;
  return { items: arr.slice(start, start + size), total: arr.length, pages: Math.ceil(arr.length / size) };
}

function renderPagination(container, current, totalPages, onChange) {
  if (totalPages <= 1) { container.innerHTML = ''; return; }
  let html = `<div class="pagination">`;
  if (current > 1) html += `<button class="page-btn" data-p="${current - 1}">‹</button>`;
  for (let i = 1; i <= totalPages; i++) {
    if (i === 1 || i === totalPages || Math.abs(i - current) <= 1)
      html += `<button class="page-btn ${i === current ? 'active' : ''}" data-p="${i}">${i}</button>`;
    else if (Math.abs(i - current) === 2) html += `<span style="color:var(--muted);padding:0 4px">…</span>`;
  }
  if (current < totalPages) html += `<button class="page-btn" data-p="${current + 1}">›</button>`;
  html += `</div>`;
  container.innerHTML = html;
  container.querySelectorAll('.page-btn').forEach(btn => {
    btn.addEventListener('click', () => onChange(parseInt(btn.dataset.p)));
  });
}
