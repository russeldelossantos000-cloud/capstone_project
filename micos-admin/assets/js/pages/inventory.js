/**
 * pages/inventory.js — Full rewrite
 * 4 tabs: Stock Levels / Adjustment Logs / Suppliers / Demand Insights
 */

let _inv = [], _invLogs = [], _suppliers = [];
let _invPage = 1, _logPage = 1, _supPage = 1;
let _invTab = 'stock';

// ── Page entry ────────────────────────────────────────────────────────────────
async function pageInventory(container) {
  container.innerHTML = `
    <div class="page-header">
      <div class="page-header-left">
        <h2>Inventory</h2>
        <p>Stock management, adjustments, suppliers, and demand insights</p>
      </div>
    </div>
    <div class="page-body">
      <div class="tabs-bar">
        <button class="tab-btn active" data-tab="stock">Stock Levels</button>
        <button class="tab-btn" data-tab="logs">Adjustment Logs</button>
        <button class="tab-btn" data-tab="suppliers">Suppliers</button>
        <button class="tab-btn" data-tab="insights">Demand Insights</button>
      </div>
      <div id="inv-tab-content">${spinner()}</div>
    </div>`;

  document.querySelectorAll('.tab-btn').forEach(btn => {
    btn.addEventListener('click', () => switchInvTab(btn.dataset.tab));
  });

  await switchInvTab('stock');
}

async function switchInvTab(tab) {
  _invTab = tab;
  document.querySelectorAll('.tab-btn').forEach(b =>
    b.classList.toggle('active', b.dataset.tab === tab));
  const content = document.getElementById('inv-tab-content');
  content.innerHTML = spinner();

  if (tab === 'stock')     await renderStockTab(content);
  if (tab === 'logs')      await renderLogsTab(content);
  if (tab === 'suppliers') await renderSuppliersTab(content);
  if (tab === 'insights')  await renderInsightsTab(content);
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 1 — STOCK LEVELS
// ══════════════════════════════════════════════════════════════════════════════

async function renderStockTab(content) {
  content.innerHTML = `
    <div class="table-card">
      <div class="table-toolbar">
        <span class="table-title">Stock Levels</span>
        <input type="search" class="search-input" id="inv-search" placeholder="Search products…" />
        <select id="inv-cat-filter" style="width:150px"><option value="">All Categories</option></select>
        <select id="inv-status-filter" style="width:140px">
          <option value="">All Stock</option>
          <option value="out_of_stock">Out of Stock</option>
          <option value="low">Low Stock</option>
          <option value="ok">OK</option>
        </select>
        <select id="inv-demand-filter" style="width:140px">
          <option value="">All Demand</option>
          <option value="high">High</option>
          <option value="normal">Normal</option>
          <option value="low">Low</option>
          <option value="specialty">Specialty</option>
        </select>
        <label style="display:flex;align-items:center;gap:6px;font-size:12px;color:var(--muted);white-space:nowrap">
          <input type="checkbox" id="inv-show-archived" /> Show Archived
        </label>
        <button class="btn btn-primary" id="inv-log-btn">+ Log Adjustment</button>
      </div>
      <div class="table-wrap"><div id="inv-table">${spinner()}</div></div>
      <div id="inv-pagination"></div>
    </div>`;

  document.getElementById('inv-log-btn').addEventListener('click', openLogForm);
  document.getElementById('inv-search').addEventListener('input', renderInvTable);
  document.getElementById('inv-cat-filter').addEventListener('change', renderInvTable);
  document.getElementById('inv-status-filter').addEventListener('change', renderInvTable);
  document.getElementById('inv-demand-filter').addEventListener('change', renderInvTable);
  document.getElementById('inv-show-archived').addEventListener('change', async (e) => {
    _invPage = 1;
    _inv = await API.getInventory(e.target.checked ? '?archived=true' : '');
    renderInvTable();
  });

  try {
    const [inv, cats] = await Promise.all([API.getInventory(), API.getCategories()]);
    _inv = inv;
    const catFilter = document.getElementById('inv-cat-filter');
    cats.forEach(c => catFilter.insertAdjacentHTML('beforeend',
      `<option value="${c.id}">${c.category_name}</option>`));
    renderInvTable();
  } catch (err) {
    document.getElementById('inv-table').innerHTML =
      `<div class="alert alert-error" style="margin:16px">${err.message}</div>`;
  }
}

function renderInvTable() {
  const search = document.getElementById('inv-search')?.value.toLowerCase() || '';
  const catId  = document.getElementById('inv-cat-filter')?.value || '';
  const status = document.getElementById('inv-status-filter')?.value || '';
  const demand = document.getElementById('inv-demand-filter')?.value || '';

  const filtered = _inv.filter(p =>
    (!search || p.product_name.toLowerCase().includes(search)) &&
    (!catId  || String(p.category_id) === catId) &&
    (!status || p.stock_status === status) &&
    (!demand || p.demand_level === demand)
  );

  const { items, pages } = paginate(filtered, _invPage);

  const demandColor = { high:'badge-in', normal:'badge-default', low:'badge-pending', specialty:'badge-paid' };
  const stockIcon   = { out_of_stock:'🔴', low:'🟡', ok:'🟢' };

  document.getElementById('inv-table').innerHTML = items.length === 0
    ? `<p class="table-empty">No products found.</p>`
    : `<table>
        <thead>
          <tr>
            <th>Product</th><th>Category</th><th>Brand</th><th>Price</th>
            <th>Stock</th><th>Threshold</th><th>Demand</th>
            <th>Last Restocked</th><th>Supplier</th><th>Sold (30d)</th><th></th>
          </tr>
        </thead>
        <tbody>
          ${items.map(p => `
            <tr>
              <td class="fw-600">${p.product_name}${p.priority ? ' <span class="badge badge-out">★</span>' : ''}</td>
              <td class="text-muted">${p.category_name || '—'}</td>
              <td class="text-muted">${p.brand_name || '—'}</td>
              <td class="mono">${peso(p.price)}</td>
              <td class="mono fw-600">
                ${stockIcon[p.stock_status] || ''} 
                <span class="${p.stock_status === 'out_of_stock' ? 'stock-low' : p.stock_status === 'low' ? 'stock-mid' : 'stock-ok'}">${p.stock}</span>
              </td>
              <td class="mono text-muted">${p.stock_threshold}</td>
              <td><span class="badge ${demandColor[p.demand_level] || 'badge-default'}">${p.demand_level}</span></td>
              <td class="text-muted" style="font-size:11px">${p.last_restocked ? fmtDate(p.last_restocked) : '—'}</td>
              <td class="text-muted" style="font-size:11px">${p.last_supplier || '—'}</td>
              <td class="mono">${parseInt(p.total_sold_30days || 0)}</td>
              <td>
                <button class="btn btn-ghost btn-sm"
                  onclick="openLogFormForProduct(${p.id}, '${p.product_name.replace(/'/g,"\\'")}')">
                  Log
                </button>
              </td>
            </tr>`).join('')}
        </tbody>
      </table>`;

  renderPagination(document.getElementById('inv-pagination'), _invPage, pages,
    p => { _invPage = p; renderInvTable(); });
}

// ══════════════════════════════════════════════════════════════════════════════
// LOG ADJUSTMENT FORM — Multi-step
// ══════════════════════════════════════════════════════════════════════════════

function openLogForm(preProductId = null, preProductName = null) {
  Modal.open({
    title: 'Log Stock Adjustment',
    large: true,
    body: `
      <!-- Step 1: Type selection -->
      <div id="log-step-1">
        <p style="color:var(--muted);font-size:13px;margin-bottom:16px">
          What type of stock adjustment are you recording?
        </p>
        <div style="display:grid;grid-template-columns:1fr 1fr 1fr;gap:10px">
          ${[
            { type:'restock',      icon:'📦', label:'Restock', desc:'Stock received from supplier', change:'IN' },
            { type:'walk_in_sale', icon:'🛒', label:'Walk-in Sale', desc:'Customer bought in store', change:'OUT' },
            { type:'adjustment',   icon:'✏️', label:'Adjustment', desc:'Correction, damage, or loss', change:'BOTH' },
            { type:'return',       icon:'↩️', label:'Return', desc:'Item returned by customer', change:'IN' },
          ].map(t => `
            <div onclick="selectLogType('${t.type}', '${t.change}')"
                 style="border:1px solid var(--border);border-radius:10px;padding:14px;cursor:pointer;text-align:center;transition:all .15s"
                 onmouseover="this.style.borderColor='var(--accent)'"
                 onmouseout="this.style.borderColor='var(--border)'"
                 id="log-type-card-${t.type}">
              <div style="font-size:24px;margin-bottom:6px">${t.icon}</div>
              <div style="font-weight:700;font-size:13px;color:var(--text)">${t.label}</div>
              <div style="font-size:11px;color:var(--muted);margin-top:3px">${t.desc}</div>
            </div>`).join('')}
        </div>
      </div>

      <!-- Step 2: Details (hidden initially) -->
      <div id="log-step-2" style="display:none">
        <div style="display:flex;align-items:center;gap:10px;margin-bottom:16px">
          <span id="log-type-badge" class="badge badge-in"></span>
          <button onclick="resetLogForm()" style="background:none;border:none;color:var(--muted);cursor:pointer;font-size:12px">← Change type</button>
        </div>
        <div class="form-row">
          <div class="form-group">
            <label>Category</label>
            <select id="log-cat-select">
              <option value="">All Categories</option>
            </select>
          </div>
          <div class="form-group">
            <label>Product</label>
            <select id="log-product-select">
              <option value="">Select product…</option>
            </select>
          </div>
        </div>
        <div id="log-current-stock" style="font-size:12px;color:var(--muted);margin:-8px 0 12px;display:none"></div>

        <div class="form-row">
          <div class="form-group">
            <label>Change Type</label>
            <select id="log-change-type">
              <option value="IN">IN — Add to Stock</option>
              <option value="OUT">OUT — Deduct from Stock</option>
            </select>
          </div>
          <div class="form-group">
            <label>Quantity</label>
            <input type="number" id="log-quantity" min="1" placeholder="0" />
          </div>
        </div>

        <!-- Restock extras -->
        <div id="log-restock-fields" style="display:none">
          <div class="form-group">
            <label>Supplier</label>
            <select id="log-supplier-select">
              <option value="">Select supplier…</option>
            </select>
          </div>
        </div>

        <!-- Walk-in sale extras -->
        <div id="log-walkin-fields" style="display:none">
          <div class="form-row">
            <div class="form-group">
              <label>Customer Name (optional)</label>
              <input type="text" id="log-walkin-name" placeholder="Walk-in customer" />
            </div>
            <div class="form-group">
              <label>Payment Method</label>
              <select id="log-walkin-payment">
                <option value="cash">Cash</option>
                <option value="gcash">GCash</option>
              </select>
            </div>
          </div>
        </div>

        <div class="form-group">
          <label>Notes / Reason</label>
          <input type="text" id="log-reason" placeholder="Optional notes about this adjustment…" />
        </div>

        <!-- Preview -->
        <div id="log-preview" style="display:none;background:var(--surface2);border-radius:8px;padding:12px;font-size:13px;margin-top:8px"></div>
        <div id="log-err"></div>
      </div>`,
    footer: `
      <button class="btn btn-secondary" onclick="Modal.close()">Cancel</button>
      <button class="btn btn-primary" id="log-submit-btn" style="display:none">Submit Log</button>`,
  });

  // Pre-load category and product data for step 2
  _prepareLogFormData(preProductId, preProductName);
}

function openLogFormForProduct(productId, productName) {
  openLogForm(productId, productName);
}

let _logType = '', _logChange = '';

async function _prepareLogFormData(preProductId, preProductName) {
  try {
    const [cats, suppliers] = await Promise.all([
      API.getCategories(),
      API.getAdminSuppliers(),
    ]);

    const catSel = document.getElementById('log-cat-select');
    cats.forEach(c => catSel.insertAdjacentHTML('beforeend',
      `<option value="${c.id}">${c.category_name}</option>`));

    const supSel = document.getElementById('log-supplier-select');
    suppliers.filter(s => s.is_active == 1).forEach(s =>
      supSel.insertAdjacentHTML('beforeend',
        `<option value="${s.id}">${s.supplier_name}</option>`));

    catSel.addEventListener('change', () => _filterLogProducts(catSel.value));

    // If pre-selected product
    if (preProductId) {
      await _filterLogProducts('', preProductId);
    } else {
      await _filterLogProducts('');
    }

    document.getElementById('log-product-select').addEventListener('change', _onLogProductChange);
    document.getElementById('log-quantity').addEventListener('input', _updateLogPreview);
    document.getElementById('log-change-type').addEventListener('change', _updateLogPreview);
  } catch (_) {}
}

async function _filterLogProducts(catId, preSelectId = null) {
  const prodSel = document.getElementById('log-product-select');
  if (!prodSel) return;

  const filtered = catId
    ? _inv.filter(p => String(p.category_id) === catId && !p.is_archived)
    : _inv.filter(p => !p.is_archived);

  prodSel.innerHTML = '<option value="">Select product…</option>';
  filtered.forEach(p => {
    const opt = document.createElement('option');
    opt.value = p.id;
    opt.textContent = `${p.product_name} (Stock: ${p.stock})`;
    if (preSelectId && p.id == preSelectId) opt.selected = true;
    prodSel.appendChild(opt);
  });

  if (preSelectId) _onLogProductChange();
}

function _onLogProductChange() {
  const prodId = document.getElementById('log-product-select')?.value;
  const product = _inv.find(p => p.id == prodId);
  const stockEl = document.getElementById('log-current-stock');
  if (product && stockEl) {
    stockEl.style.display = 'block';
    stockEl.innerHTML = `Current stock: <strong class="${stockClass(product.stock)}">${product.stock} units</strong>`;
  } else if (stockEl) {
    stockEl.style.display = 'none';
  }
  _updateLogPreview();
}

function _updateLogPreview() {
  const prodId   = document.getElementById('log-product-select')?.value;
  const qty      = parseInt(document.getElementById('log-quantity')?.value || '0');
  const change   = document.getElementById('log-change-type')?.value;
  const product  = _inv.find(p => p.id == prodId);
  const preview  = document.getElementById('log-preview');
  if (!preview) return;

  if (product && qty > 0) {
    const newStock = change === 'IN' ? product.stock + qty : product.stock - qty;
    const color    = newStock <= product.stock_threshold ? 'var(--danger)' : 'var(--success)';
    preview.style.display = 'block';
    preview.innerHTML = `
      <strong>${product.product_name}</strong><br>
      Current stock: <strong>${product.stock}</strong> →
      New stock: <strong style="color:${color}">${Math.max(0, newStock)}</strong>
      ${newStock < 0 ? '<span class="badge badge-cancelled">Insufficient stock</span>' : ''}`;
  } else {
    preview.style.display = 'none';
  }
}

function selectLogType(type, changeType) {
  _logType = type;
  _logChange = changeType;

  document.getElementById('log-step-1').style.display = 'none';
  document.getElementById('log-step-2').style.display = 'block';
  document.getElementById('log-submit-btn').style.display = 'inline-block';

  const labels = {
    restock: 'Restock (IN)', walk_in_sale: 'Walk-in Sale (OUT)',
    adjustment: 'Adjustment', return: 'Return (IN)',
  };
  document.getElementById('log-type-badge').textContent = labels[type] || type;

  // Set change type
  const changeSelect = document.getElementById('log-change-type');
  if (changeType === 'IN')  { changeSelect.value = 'IN';  changeSelect.disabled = true; }
  if (changeType === 'OUT') { changeSelect.value = 'OUT'; changeSelect.disabled = true; }
  if (changeType === 'BOTH') { changeSelect.disabled = false; }

  // Show type-specific fields
  document.getElementById('log-restock-fields').style.display  = type === 'restock'      ? 'block' : 'none';
  document.getElementById('log-walkin-fields').style.display   = type === 'walk_in_sale' ? 'block' : 'none';

  document.getElementById('log-submit-btn').addEventListener('click', submitLogForm, { once: true });
}

function resetLogForm() {
  _logType = ''; _logChange = '';
  document.getElementById('log-step-1').style.display = 'block';
  document.getElementById('log-step-2').style.display = 'none';
  document.getElementById('log-submit-btn').style.display = 'none';
  document.getElementById('log-preview').style.display = 'none';
}

async function submitLogForm() {
  const prodId   = document.getElementById('log-product-select')?.value;
  const qty      = document.getElementById('log-quantity')?.value;
  const change   = document.getElementById('log-change-type')?.value;
  const reason   = document.getElementById('log-reason')?.value.trim();
  const suppId   = document.getElementById('log-supplier-select')?.value || null;
  const errEl    = document.getElementById('log-err');

  if (!prodId || !qty || parseInt(qty) < 1) {
    errEl.innerHTML = `<div class="alert alert-error">Product and quantity are required.</div>`;
    return;
  }

  // Build reference string
  let reference = null;
  if (_logType === 'walk_in_sale') {
    const name    = document.getElementById('log-walkin-name')?.value.trim();
    const payment = document.getElementById('log-walkin-payment')?.value;
    reference = `Walk-in${name ? ` — ${name}` : ''} (${payment})`;
  }

  const btn = document.getElementById('log-submit-btn');
  btn.disabled = true; btn.textContent = 'Submitting…';

  try {
    await API.logInventory({
      product_id:       prodId,
      change_type:      change,
      transaction_type: _logType,
      quantity:         qty,
      reason:           reason || null,
      reference:        reference,
      supplier_id:      suppId || null,
    });
    toast('Stock adjustment recorded!', 'success');
    Modal.close();
    _inv = await API.getInventory();
    renderInvTable();
  } catch (err) {
    errEl.innerHTML = `<div class="alert alert-error">${err.message}</div>`;
    btn.disabled = false; btn.textContent = 'Submit Log';
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 2 — ADJUSTMENT LOGS
// ══════════════════════════════════════════════════════════════════════════════

async function renderLogsTab(content) {
  content.innerHTML = `
    <div class="table-card">
      <div class="table-toolbar">
        <span class="table-title">Adjustment Logs</span>
        <select id="log-type-filter" style="width:160px">
          <option value="">All Types</option>
          <option value="online_order">Online Order</option>
          <option value="walk_in_sale">Walk-in Sale</option>
          <option value="restock">Restock</option>
          <option value="adjustment">Adjustment</option>
          <option value="return">Return</option>
          <option value="cancelled_order">Cancelled Order</option>
        </select>
        <select id="log-change-filter" style="width:120px">
          <option value="">All</option>
          <option value="IN">IN</option>
          <option value="OUT">OUT</option>
        </select>
        <input type="date" id="log-start-date" style="width:140px" />
        <input type="date" id="log-end-date" style="width:140px" />
      </div>
      <div class="table-wrap"><div id="log-table">${spinner()}</div></div>
      <div id="log-pagination"></div>
    </div>`;

  document.getElementById('log-type-filter').addEventListener('change', loadAndRenderLogs);
  document.getElementById('log-change-filter').addEventListener('change', loadAndRenderLogs);
  document.getElementById('log-start-date').addEventListener('change', loadAndRenderLogs);
  document.getElementById('log-end-date').addEventListener('change', loadAndRenderLogs);

  await loadAndRenderLogs();
}

async function loadAndRenderLogs() {
  document.getElementById('log-table').innerHTML = spinner();
  try {
    const params = {};
    const type   = document.getElementById('log-type-filter')?.value;
    const change = document.getElementById('log-change-filter')?.value;
    const start  = document.getElementById('log-start-date')?.value;
    const end    = document.getElementById('log-end-date')?.value;
    if (type)   params.transaction_type = type;
    if (change) params.change_type      = change;
    if (start)  params.start            = start;
    if (end)    params.end              = end;

    _invLogs = await API.getInventoryLogs(params);
    renderLogsTable();
  } catch (err) {
    document.getElementById('log-table').innerHTML =
      `<div class="alert alert-error" style="margin:16px">${err.message}</div>`;
  }
}

function renderLogsTable() {
  const { items, pages } = paginate(_invLogs, _logPage, 20);

  const typeBadge = {
    online_order:    'badge-processing',
    walk_in_sale:    'badge-shipped',
    restock:         'badge-in',
    adjustment:      'badge-default',
    return:          'badge-paid',
    cancelled_order: 'badge-cancelled',
  };
  const typeLabel = {
    online_order: 'Online Order', walk_in_sale: 'Walk-in Sale',
    restock: 'Restock', adjustment: 'Adjustment',
    return: 'Return', cancelled_order: 'Cancelled Order',
  };

  document.getElementById('log-table').innerHTML = items.length === 0
    ? `<p class="table-empty">No logs found.</p>`
    : `<table>
        <thead>
          <tr>
            <th>Date</th><th>Product</th><th>Category</th><th>Type</th>
            <th>Change</th><th>Qty</th><th>Reference</th><th>Supplier</th><th>Logged By</th>
          </tr>
        </thead>
        <tbody>
          ${items.map(l => `
            <tr>
              <td class="mono text-muted" style="font-size:11px">${fmtDateTime(l.created_at)}</td>
              <td class="fw-600">${l.product_name}</td>
              <td class="text-muted" style="font-size:11px">${l.category_name || '—'}</td>
              <td><span class="badge ${typeBadge[l.transaction_type] || 'badge-default'}">${typeLabel[l.transaction_type] || l.transaction_type}</span></td>
              <td>${badge(l.change_type)}</td>
              <td class="mono fw-600">${l.quantity}</td>
              <td class="text-muted" style="font-size:11px">${l.reference || '—'}</td>
              <td class="text-muted" style="font-size:11px">${l.supplier_name || '—'}</td>
              <td class="text-muted" style="font-size:11px">${l.logged_by || '—'}</td>
            </tr>`).join('')}
        </tbody>
      </table>`;

  renderPagination(document.getElementById('log-pagination'), _logPage, pages,
    p => { _logPage = p; renderLogsTable(); });
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 3 — SUPPLIERS
// ══════════════════════════════════════════════════════════════════════════════

async function renderSuppliersTab(content) {
  content.innerHTML = `
    <div class="table-card">
      <div class="table-toolbar">
        <span class="table-title">Suppliers</span>
        <input type="search" class="search-input" id="sup-search" placeholder="Search suppliers…" />
        <button class="btn btn-primary" id="add-sup-btn">+ Add Supplier</button>
      </div>
      <div class="table-wrap"><div id="sup-table">${spinner()}</div></div>
      <div id="sup-pagination"></div>
    </div>`;

  document.getElementById('add-sup-btn').addEventListener('click', () => openSupplierForm());
  document.getElementById('sup-search').addEventListener('input', renderSuppliersTable);

  try {
    _suppliers = await API.getAdminSuppliers();
    renderSuppliersTable();
  } catch (err) {
    document.getElementById('sup-table').innerHTML =
      `<div class="alert alert-error" style="margin:16px">${err.message}</div>`;
  }
}

function renderSuppliersTable() {
  const search   = document.getElementById('sup-search')?.value.toLowerCase() || '';
  const filtered = _suppliers.filter(s =>
    s.supplier_name.toLowerCase().includes(search));
  const { items, pages } = paginate(filtered, _supPage);

  document.getElementById('sup-table').innerHTML = items.length === 0
    ? `<p class="table-empty">No suppliers found.</p>`
    : `<table>
        <thead>
          <tr>
            <th>Supplier Name</th><th>Contact Person</th><th>Phone</th>
            <th>Email</th><th>Deliveries</th><th>Last Delivery</th><th>Status</th><th></th>
          </tr>
        </thead>
        <tbody>
          ${items.map(s => `
            <tr style="${!s.is_active ? 'opacity:.5' : ''}">
              <td class="fw-600">${s.supplier_name}</td>
              <td class="text-muted">${s.contact_person || '—'}</td>
              <td class="mono text-muted">${s.phone || '—'}</td>
              <td class="text-muted" style="font-size:11px">${s.email || '—'}</td>
              <td class="mono">${s.total_deliveries || 0}</td>
              <td class="text-muted" style="font-size:11px">${s.last_delivery ? fmtDate(s.last_delivery) : '—'}</td>
              <td>${s.is_active ? '<span class="badge badge-in">Active</span>' : '<span class="badge badge-default">Inactive</span>'}</td>
              <td>
                <div class="actions-cell">
                  <button class="btn btn-ghost btn-sm" onclick="openSupplierForm(${s.id})">Edit</button>
                  ${s.is_active
                    ? `<button class="btn btn-danger btn-sm" onclick="deactivateSupplier(${s.id}, '${s.supplier_name.replace(/'/g,"\\'")}')">Deactivate</button>`
                    : `<button class="btn btn-ghost btn-sm" onclick="restoreSupplier(${s.id})">Restore</button>`}
                </div>
              </td>
            </tr>`).join('')}
        </tbody>
      </table>`;

  renderPagination(document.getElementById('sup-pagination'), _supPage, pages,
    p => { _supPage = p; renderSuppliersTable(); });
}

function openSupplierForm(id = null) {
  const s = id ? _suppliers.find(x => x.id === id) : null;
  Modal.open({
    title: id ? 'Edit Supplier' : 'Add Supplier',
    body: `
      <div class="form-group"><label>Supplier Name</label><input type="text" id="f-sup-name" value="${s?.supplier_name || ''}" /></div>
      <div class="form-row">
        <div class="form-group"><label>Contact Person</label><input type="text" id="f-sup-contact" value="${s?.contact_person || ''}" /></div>
        <div class="form-group"><label>Phone</label><input type="text" id="f-sup-phone" value="${s?.phone || ''}" /></div>
      </div>
      <div class="form-row">
        <div class="form-group"><label>Email</label><input type="email" id="f-sup-email" value="${s?.email || ''}" /></div>
        <div class="form-group"><label>Address</label><input type="text" id="f-sup-address" value="${s?.address || ''}" /></div>
      </div>
      <div class="form-group"><label>Notes</label><textarea id="f-sup-notes">${s?.notes || ''}</textarea></div>
      <div id="sup-form-err"></div>`,
    footer: `
      <button class="btn btn-secondary" onclick="Modal.close()">Cancel</button>
      <button class="btn btn-primary" id="save-sup-btn">${id ? 'Update' : 'Create'}</button>`,
  });

  document.getElementById('save-sup-btn').addEventListener('click', async () => {
    const name = document.getElementById('f-sup-name').value.trim();
    if (!name) { document.getElementById('sup-form-err').innerHTML = `<div class="alert alert-error">Supplier name is required.</div>`; return; }
    const body = {
      supplier_name:  name,
      contact_person: document.getElementById('f-sup-contact').value.trim() || null,
      phone:          document.getElementById('f-sup-phone').value.trim() || null,
      email:          document.getElementById('f-sup-email').value.trim() || null,
      address:        document.getElementById('f-sup-address').value.trim() || null,
      notes:          document.getElementById('f-sup-notes').value.trim() || null,
    };
    try {
      if (id) await API.updateSupplier(id, body); else await API.createSupplier(body);
      toast(id ? 'Supplier updated!' : 'Supplier created!', 'success');
      Modal.close();
      _suppliers = await API.getAdminSuppliers();
      renderSuppliersTable();
    } catch (err) { document.getElementById('sup-form-err').innerHTML = `<div class="alert alert-error">${err.message}</div>`; }
  });
}

async function deactivateSupplier(id, name) {
  confirmDelete(`Deactivate supplier <strong>${name}</strong>?`,
    async () => {
      try { await API.deleteSupplier(id); toast('Supplier deactivated.', 'success'); _suppliers = await API.getAdminSuppliers(); renderSuppliersTable(); }
      catch (err) { toast(err.message, 'error'); }
    },
    { title: 'Deactivate Supplier', buttonText: 'Deactivate' }
  );
}

async function restoreSupplier(id) {
  try { await API.restoreSupplier(id); toast('Supplier restored.', 'success'); _suppliers = await API.getAdminSuppliers(); renderSuppliersTable(); }
  catch (err) { toast(err.message, 'error'); }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 4 — DEMAND INSIGHTS
// ══════════════════════════════════════════════════════════════════════════════

async function renderInsightsTab(content) {
  content.innerHTML = `
    <div style="display:grid;grid-template-columns:1fr 1fr;gap:16px">
      <div class="table-card">
        <div class="table-toolbar"><span class="table-title">🔥 Best Sellers (Last 30 days)</span></div>
        <div id="best-sellers-table">${spinner()}</div>
      </div>
      <div class="table-card">
        <div class="table-toolbar"><span class="table-title">🐢 Slow Movers (Last 30 days)</span></div>
        <div id="slow-movers-table">${spinner()}</div>
      </div>
    </div>
    <div class="table-card" style="margin-top:16px">
      <div class="table-toolbar"><span class="table-title">📊 Demand Classification Overview</span></div>
      <div id="demand-overview-table">${spinner()}</div>
    </div>`;

  try {
    const analytics = await API.getAnalytics();
    renderBestSellers(analytics.best_sellers || []);
    renderSlowMovers(analytics.slow_movers || []);
    renderDemandOverview();
  } catch (err) {
    document.getElementById('best-sellers-table').innerHTML =
      `<div class="alert alert-error" style="margin:16px">${err.message}</div>`;
  }
}

function renderBestSellers(sellers) {
  if (!sellers.length) {
    document.getElementById('best-sellers-table').innerHTML = `<p class="table-empty">No sales data yet.</p>`;
    return;
  }
  const max = parseFloat(sellers[0]?.revenue || 1);
  document.getElementById('best-sellers-table').innerHTML = `
    <div style="padding:12px 16px">
      ${sellers.map((p, i) => `
        <div style="margin-bottom:14px">
          <div style="display:flex;align-items:center;gap:8px;margin-bottom:4px">
            <span style="font-size:11px;color:var(--muted);min-width:20px;font-weight:700">#${i+1}</span>
            <span style="font-size:13px;font-weight:600;flex:1;overflow:hidden;text-overflow:ellipsis;white-space:nowrap">${p.product_name}</span>
            <span style="font-size:11px;color:var(--muted)">${p.units_sold} sold</span>
            <span style="font-size:12px;font-weight:700;color:var(--accent)">${peso(p.revenue)}</span>
          </div>
          <div style="display:flex;gap:8px;align-items:center">
            <span style="min-width:20px"></span>
            <div style="flex:1;height:4px;background:var(--border);border-radius:2px;overflow:hidden">
              <div style="height:100%;width:${Math.round((parseFloat(p.revenue)/max)*100)}%;background:var(--accent);border-radius:2px;transition:width .6s ease"></div>
            </div>
          </div>
        </div>`).join('')}
    </div>`;
}

function renderSlowMovers(movers) {
  if (!movers.length) {
    document.getElementById('slow-movers-table').innerHTML = `<p class="table-empty" style="color:var(--success)">✓ All products have recent sales.</p>`;
    return;
  }
  document.getElementById('slow-movers-table').innerHTML = `
    <table>
      <thead><tr><th>Product</th><th>Category</th><th>Stock</th><th>Units Sold</th></tr></thead>
      <tbody>
        ${movers.map(p => `
          <tr>
            <td class="fw-600">${p.product_name}</td>
            <td class="text-muted">${p.category_name || '—'}</td>
            <td class="mono ${stockClass(p.stock)}">${p.stock}</td>
            <td class="mono text-muted">${p.units_sold}</td>
          </tr>`).join('')}
      </tbody>
    </table>`;
}

function renderDemandOverview() {
  const groups = { high: [], normal: [], low: [], specialty: [] };
  _inv.forEach(p => { if (groups[p.demand_level]) groups[p.demand_level].push(p); });

  const labels = { high: '🔥 High Demand', normal: '⚡ Normal', low: '🐢 Low Demand', specialty: '💎 Specialty' };
  const colors = { high: 'var(--success)', normal: 'var(--accent)', low: 'var(--warning)', specialty: 'var(--info)' };

  document.getElementById('demand-overview-table').innerHTML = `
    <div style="display:grid;grid-template-columns:repeat(4,1fr);gap:16px;padding:16px">
      ${Object.entries(groups).map(([level, products]) => `
        <div style="border:1px solid var(--border);border-radius:10px;padding:14px">
          <div style="font-size:13px;font-weight:700;color:${colors[level]};margin-bottom:10px">${labels[level]}</div>
          <div style="font-size:24px;font-weight:900;color:${colors[level]};margin-bottom:8px">${products.length}</div>
          <div style="font-size:11px;color:var(--muted)">products</div>
          ${products.slice(0, 3).map(p => `
            <div style="font-size:11px;color:var(--muted);margin-top:6px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap">
              • ${p.product_name}
            </div>`).join('')}
          ${products.length > 3 ? `<div style="font-size:11px;color:var(--muted);margin-top:4px">+${products.length - 3} more</div>` : ''}
        </div>`).join('')}
    </div>`;
}