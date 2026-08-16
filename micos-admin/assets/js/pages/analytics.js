/**
 * pages/analytics.js — Full rewrite
 * Uses /api/admin/analytics endpoint
 * 4 tabs: Sales Overview / Stock Movement / Products / Reports
 */

let _analyticsData = null;
let _analyticsPeriod = 'monthly';
let _analyticsCompare = false;
let _analyticsStart = '';
let _analyticsEnd = '';

async function pageAnalytics(container) {
  container.innerHTML = `
    <div class="page-header">
      <div class="page-header-left">
        <h2>Analytics</h2>
        <p>Sales trends, stock movement, and business insights</p>
      </div>
      <div class="flex gap-8" style="display:flex;gap:8px;align-items:center">
        <select id="analytics-period" style="width:130px">
          <option value="daily">Daily (7d)</option>
          <option value="weekly">Weekly (4w)</option>
          <option value="monthly" selected>Monthly (12m)</option>
        </select>
        <input type="date" id="analytics-start" style="width:140px" />
        <span style="color:var(--muted);font-size:12px">to</span>
        <input type="date" id="analytics-end" style="width:140px" />
        <label style="display:flex;align-items:center;gap:6px;font-size:12px;color:var(--muted);white-space:nowrap">
          <input type="checkbox" id="analytics-compare" /> Compare period
        </label>
        <button class="btn btn-secondary" id="analytics-refresh">↻ Refresh</button>
      </div>
    </div>
    <div class="page-body">
      <div class="tabs-bar">
        <button class="tab-btn active" data-tab="overview">Sales Overview</button>
        <button class="tab-btn" data-tab="stock">Stock Movement</button>
        <button class="tab-btn" data-tab="products">Products</button>
        <button class="tab-btn" data-tab="reports">Reports</button>
      </div>
      <div id="analytics-tab-content">${spinner()}</div>
    </div>`;

  document.querySelectorAll('.tab-btn').forEach(btn =>
    btn.addEventListener('click', () => switchAnalyticsTab(btn.dataset.tab)));

  document.getElementById('analytics-period').addEventListener('change', e => {
    _analyticsPeriod = e.target.value;
    loadAnalytics();
  });
  document.getElementById('analytics-compare').addEventListener('change', e => {
    _analyticsCompare = e.target.checked;
    loadAnalytics();
  });
  document.getElementById('analytics-refresh').addEventListener('click', loadAnalytics);
  document.getElementById('analytics-start').addEventListener('change', e => {
    _analyticsStart = e.target.value; loadAnalytics();
  });
  document.getElementById('analytics-end').addEventListener('change', e => {
    _analyticsEnd = e.target.value; loadAnalytics();
  });

  if (!window.Chart) {
    await loadScript('https://cdnjs.cloudflare.com/ajax/libs/Chart.js/4.4.1/chart.umd.min.js');
  }

  await loadAnalytics();
}

async function loadAnalytics() {
  document.getElementById('analytics-tab-content').innerHTML = spinner();
  try {
    const params = { period: _analyticsPeriod, compare: _analyticsCompare };
    if (_analyticsStart) params.start = _analyticsStart;
    if (_analyticsEnd)   params.end   = _analyticsEnd;
    _analyticsData = await API.getAnalytics(params);
    await switchAnalyticsTab(document.querySelector('.tab-btn.active')?.dataset.tab || 'overview');
  } catch (err) {
    document.getElementById('analytics-tab-content').innerHTML =
      `<div class="alert alert-error">${err.message}</div>`;
  }
}

async function switchAnalyticsTab(tab) {
  document.querySelectorAll('.tab-btn').forEach(b =>
    b.classList.toggle('active', b.dataset.tab === tab));
  const content = document.getElementById('analytics-tab-content');
  if (!_analyticsData) { content.innerHTML = spinner(); return; }
  content.innerHTML = '';
  if (tab === 'overview')  renderOverviewTab(content);
  if (tab === 'stock')     renderAnalyticsStockTab(content);
  if (tab === 'products')  renderAnalyticsProductsTab(content);
  if (tab === 'reports')   renderReportsTab(content);
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 1 — SALES OVERVIEW
// ══════════════════════════════════════════════════════════════════════════════

function renderOverviewTab(content) {
  const d   = _analyticsData;
  const sum = d.summary || {};
  const cmp = d.comparison;

  const kpiChange = (current, prev) => {
    if (!prev || prev == 0) return '';
    const pct = ((current - prev) / prev * 100).toFixed(1);
    const up  = current >= prev;
    return `<div style="font-size:11px;color:${up ? 'var(--success)' : 'var(--danger)'};margin-top:4px">
      ${up ? '↑' : '↓'} ${Math.abs(pct)}% vs previous period
    </div>`;
  };

  content.innerHTML = `
    <!-- KPI Row -->
    <div class="stat-grid" style="margin-bottom:20px">
      <div class="stat-card">
        <div class="stat-label">Total Items Sold</div>
        <div class="stat-value">${sum.total_items_sold || 0}</div>
        ${cmp ? kpiChange(sum.total_items_sold, cmp.total_items_sold) : ''}
      </div>
      <div class="stat-card">
        <div class="stat-label">Online Orders</div>
        <div class="stat-value">${d.online?.order_count || 0}</div>
        ${cmp ? kpiChange(d.online?.order_count, cmp.order_count) : ''}
      </div>
      <div class="stat-card">
        <div class="stat-label">Walk-in Sales</div>
        <div class="stat-value">${d.walkin?.walkin_count || 0}</div>
      </div>
      <div class="stat-card">
        <div class="stat-label">Total Revenue</div>
        <div class="stat-value accent">${peso(sum.total_revenue || 0)}</div>
        ${cmp ? kpiChange(sum.total_revenue, cmp.revenue) : ''}
      </div>
      <div class="stat-card">
        <div class="stat-label">New Customers</div>
        <div class="stat-value">${d.customers?.new_customers || 0}</div>
      </div>
      <div class="stat-card">
        <div class="stat-label">Avg Order Value</div>
        <div class="stat-value">${d.online?.order_count > 0 ? peso((d.online?.revenue || 0) / d.online?.order_count) : '—'}</div>
      </div>
    </div>

    <!-- Charts Row -->
    <div style="display:grid;grid-template-columns:1fr 1fr;gap:16px;margin-bottom:20px">
      <div class="chart-card">
        <h3>Sales Volume Over Time</h3>
        <canvas id="trend-chart" height="180"></canvas>
      </div>
      <div style="display:grid;grid-template-columns:1fr 1fr;gap:16px">
        <div class="chart-card">
          <h3>Sales Channel</h3>
          <canvas id="channel-chart" height="160"></canvas>
        </div>
        <div class="chart-card">
          <h3>Payment Methods</h3>
          <canvas id="payment-chart" height="160"></canvas>
        </div>
        <div class="chart-card">
          <h3>Delivery vs Pickup</h3>
          <canvas id="delivery-chart" height="160"></canvas>
        </div>
        <div class="chart-card">
          <h3>Order Status</h3>
          <canvas id="status-chart" height="160"></canvas>
        </div>
      </div>
    </div>`;

  // Render charts after DOM is ready
  setTimeout(() => {
    renderTrendChart(d.trend || []);
    renderDoughnut('channel-chart', ['Online Orders', 'Walk-in Sales'],
      [d.online?.order_count || 0, d.walkin?.walkin_count || 0],
      ['#f97316', '#3b82f6']);
    renderDoughnut('payment-chart', ['Cash', 'GCash'],
      [d.online?.cash_count || 0, d.online?.gcash_count || 0],
      ['#22c55e', '#3b82f6']);
    renderDoughnut('delivery-chart', ['Delivery', 'Pickup'],
      [d.online?.delivery_count || 0, d.online?.pickup_count || 0],
      ['#f97316', '#a78bfa']);
    renderOrderStatusChart(d);
  }, 50);
}

function renderTrendChart(trend) {
  const ctx = document.getElementById('trend-chart');
  if (!ctx) return;
  if (ctx._chartInstance) ctx._chartInstance.destroy();

  ctx._chartInstance = new Chart(ctx, {
    type: 'line',
    data: {
      labels: trend.map(t => t.period_label),
      datasets: [{
        label: 'Orders',
        data: trend.map(t => t.order_count),
        borderColor: '#f97316',
        backgroundColor: 'rgba(249,115,22,.08)',
        borderWidth: 2,
        pointRadius: 3,
        fill: true,
        tension: 0.4,
      }],
    },
    options: {
      responsive: true,
      plugins: { legend: { display: false } },
      scales: {
        x: { grid: { color: '#252d3d' }, ticks: { color: '#64748b', font: { size: 10 }, maxTicksLimit: 8 } },
        y: { grid: { color: '#252d3d' }, ticks: { color: '#64748b', font: { size: 10 } } },
      },
    },
  });
}

function renderDoughnut(canvasId, labels, data, colors) {
  const ctx = document.getElementById(canvasId);
  if (!ctx) return;
  if (ctx._chartInstance) ctx._chartInstance.destroy();
  ctx._chartInstance = new Chart(ctx, {
    type: 'doughnut',
    data: {
      labels,
      datasets: [{ data, backgroundColor: colors, borderWidth: 2, borderColor: '#161b27' }],
    },
    options: {
      responsive: true, cutout: '60%',
      plugins: { legend: { position: 'bottom', labels: { color: '#94a3b8', font: { size: 10 }, padding: 8, boxWidth: 10 } } },
    },
  });
}

function renderOrderStatusChart(d) {
  const online = d.online || {};
  renderDoughnut('status-chart',
    ['Pending', 'Processing', 'Shipped', 'Delivered', 'Cancelled'],
    [0, 0, 0, 0, 0], // placeholder — computed from full orders data
    ['#eab308', '#3b82f6', '#a78bfa', '#22c55e', '#ef4444']
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 2 — STOCK MOVEMENT
// ══════════════════════════════════════════════════════════════════════════════

function renderAnalyticsStockTab(content) {
  const d     = _analyticsData;
  const stock = d.stock || {};

  content.innerHTML = `
    <!-- Stock In vs Out KPIs -->
    <div class="stat-grid" style="margin-bottom:20px">
      <div class="stat-card">
        <div class="stat-label">Total Stock In</div>
        <div class="stat-value ok">+${stock.total_in || 0}</div>
      </div>
      <div class="stat-card">
        <div class="stat-label">Total Stock Out</div>
        <div class="stat-value danger">-${stock.total_out || 0}</div>
      </div>
      <div class="stat-card">
        <div class="stat-label">Net Movement</div>
        <div class="stat-value ${(stock.total_in - stock.total_out) >= 0 ? 'ok' : 'danger'}">
          ${(stock.total_in || 0) - (stock.total_out || 0) >= 0 ? '+' : ''}${(stock.total_in || 0) - (stock.total_out || 0)}
        </div>
      </div>
      <div class="stat-card">
        <div class="stat-label">Online Sold</div>
        <div class="stat-value">${d.items?.items_sold || 0} units</div>
      </div>
      <div class="stat-card">
        <div class="stat-label">Walk-in Sold</div>
        <div class="stat-value">${d.walkin?.walkin_count || 0} transactions</div>
      </div>
      <div class="stat-card">
        <div class="stat-label">Delivery Revenue</div>
        <div class="stat-value accent">${peso(d.online?.delivery_revenue || 0)}</div>
      </div>
    </div>

    <!-- Stock movement by product -->
    <div class="table-card">
      <div class="table-toolbar">
        <span class="table-title">Product Stock Movement</span>
      </div>
      <div class="table-wrap">
        <table>
          <thead>
            <tr>
              <th>Product</th><th>Category</th><th>Opening</th>
              <th>Stock In</th><th>Sold Online</th><th>Sold Walk-in</th>
              <th>Total Out</th><th>Current Stock</th><th>Movement</th>
            </tr>
          </thead>
          <tbody>
            ${(_inv || []).slice(0, 20).map(p => {
              const totalOut = (parseInt(p.online_sold_30days || 0) + parseInt(p.walkin_sold_30days || 0));
              const movement = totalOut > (parseInt(p.stock || 0) * 0.5) ? 'Fast' :
                               totalOut > (parseInt(p.stock || 0) * 0.2) ? 'Normal' : 'Slow';
              const mColor   = { Fast: 'badge-in', Normal: 'badge-processing', Slow: 'badge-pending' };
              return `
                <tr>
                  <td class="fw-600">${p.product_name}</td>
                  <td class="text-muted">${p.category_name || '—'}</td>
                  <td class="mono">—</td>
                  <td class="mono text-success">—</td>
                  <td class="mono">${p.online_sold_30days || 0}</td>
                  <td class="mono">${p.walkin_sold_30days || 0}</td>
                  <td class="mono fw-600">${totalOut}</td>
                  <td class="mono ${stockClass(p.stock)}">${p.stock}</td>
                  <td><span class="badge ${mColor[movement]}">${movement}</span></td>
                </tr>`;
            }).join('')}
          </tbody>
        </table>
      </div>
    </div>`;
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 3 — PRODUCTS
// ══════════════════════════════════════════════════════════════════════════════

function renderAnalyticsProductsTab(content) {
  const d = _analyticsData;
  const best = d.best_sellers || [];
  const slow = d.slow_movers  || [];

  content.innerHTML = `
    <div style="display:grid;grid-template-columns:1fr 1fr;gap:16px;margin-bottom:16px">
      <!-- Best Sellers -->
      <div class="table-card">
        <div class="table-toolbar"><span class="table-title">🔥 Best Sellers</span></div>
        <div style="padding:12px 16px">
          ${best.length === 0
            ? `<p class="table-empty">No sales data yet.</p>`
            : best.map((p, i) => {
                const maxRev = parseFloat(best[0]?.revenue || 1);
                const trend  = parseInt(p.units_sold) > 5 ? '↑' : parseInt(p.units_sold) > 2 ? '→' : '↓';
                const tColor = trend === '↑' ? 'var(--success)' : trend === '→' ? 'var(--muted)' : 'var(--danger)';
                return `
                  <div style="margin-bottom:14px">
                    <div style="display:flex;align-items:center;gap:8px;margin-bottom:4px">
                      <span style="font-size:12px;font-weight:700;color:var(--muted);min-width:22px">#${i+1}</span>
                      <span style="font-size:13px;font-weight:600;flex:1;overflow:hidden;text-overflow:ellipsis;white-space:nowrap">${p.product_name}</span>
                      <span style="color:${tColor};font-weight:700">${trend}</span>
                      <span style="font-size:11px;color:var(--muted)">${p.units_sold} sold</span>
                      <span style="font-size:12px;font-weight:700;color:var(--accent)">${peso(p.revenue)}</span>
                    </div>
                    <div style="display:flex;gap:8px;align-items:center">
                      <span style="min-width:22px"></span>
                      <div style="flex:1;height:4px;background:var(--border);border-radius:2px;overflow:hidden">
                        <div style="height:100%;width:${Math.round((parseFloat(p.revenue)/maxRev)*100)}%;background:var(--accent);border-radius:2px"></div>
                      </div>
                    </div>
                  </div>`;
              }).join('')}
        </div>
      </div>

      <!-- Slow Movers -->
      <div class="table-card">
        <div class="table-toolbar"><span class="table-title">🐢 Slow Movers</span></div>
        ${slow.length === 0
          ? `<p class="table-empty" style="color:var(--success)">✓ All products have recent sales.</p>`
          : `<table>
              <thead><tr><th>Product</th><th>Category</th><th>Stock</th></tr></thead>
              <tbody>
                ${slow.map(p => `
                  <tr>
                    <td class="fw-600">${p.product_name}</td>
                    <td class="text-muted">${p.category_name || '—'}</td>
                    <td class="mono ${stockClass(p.stock)}">${p.stock}</td>
                  </tr>`).join('')}
              </tbody>
            </table>`}
      </div>
    </div>

    <!-- Revenue by category -->
    <div class="chart-card">
      <h3>Revenue by Category</h3>
      <canvas id="category-chart" height="120"></canvas>
    </div>`;

  setTimeout(() => renderCategoryChart(best), 50);
}

function renderCategoryChart(sellers) {
  const ctx = document.getElementById('category-chart');
  if (!ctx || !sellers.length) return;
  if (ctx._chartInstance) ctx._chartInstance.destroy();

  const byCategory = {};
  sellers.forEach(p => {
    const cat = p.category_name || 'Other';
    byCategory[cat] = (byCategory[cat] || 0) + parseFloat(p.revenue || 0);
  });

  const colors = ['#f97316','#3b82f6','#22c55e','#a78bfa','#eab308','#ef4444'];
  ctx._chartInstance = new Chart(ctx, {
    type: 'bar',
    data: {
      labels: Object.keys(byCategory),
      datasets: [{
        label: 'Revenue',
        data: Object.values(byCategory),
        backgroundColor: colors.slice(0, Object.keys(byCategory).length),
        borderRadius: 6,
      }],
    },
    options: {
      responsive: true,
      plugins: { legend: { display: false } },
      scales: {
        x: { grid: { color: '#252d3d' }, ticks: { color: '#64748b' } },
        y: { grid: { color: '#252d3d' }, ticks: { color: '#64748b', callback: v => '₱' + v.toLocaleString() } },
      },
    },
  });
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 4 — REPORTS
// ══════════════════════════════════════════════════════════════════════════════

function renderReportsTab(content) {
  const d   = _analyticsData;
  const sum = d.summary || {};

  content.innerHTML = `
    <div class="table-card" style="max-width:640px;margin:0 auto">
      <div class="table-toolbar"><span class="table-title">Generate Report</span></div>
      <div style="padding:20px;display:flex;flex-direction:column;gap:12px">

        <p style="font-size:13px;color:var(--muted)">
          Period: <strong style="color:var(--text)">${d.period?.start} to ${d.period?.end}</strong>
        </p>

        ${[
          { label: 'Daily Sales Summary', desc: 'All transactions for the selected period', id: 'rpt-sales' },
          { label: 'Inventory Movement Report', desc: 'Stock changes — IN, OUT, walk-in sales, restocks', id: 'rpt-inv' },
          { label: 'Top Products Report', desc: 'Best sellers ranked by revenue and units sold', id: 'rpt-products' },
          { label: 'Customer Orders Report', desc: 'Orders per customer with totals and status', id: 'rpt-customers' },
        ].map(r => `
          <div style="display:flex;align-items:center;justify-content:space-between;
               padding:14px;border:1px solid var(--border);border-radius:10px">
            <div>
              <div style="font-size:13px;font-weight:600;color:var(--text)">${r.label}</div>
              <div style="font-size:11px;color:var(--muted);margin-top:2px">${r.desc}</div>
            </div>
            <button class="btn btn-ghost btn-sm" onclick="generateReport('${r.id}')">
              Generate
            </button>
          </div>`).join('')}

        <div id="report-output" style="display:none;margin-top:16px">
          <div class="table-toolbar" style="margin-bottom:8px">
            <span class="table-title" id="report-output-title"></span>
            <button class="btn btn-ghost btn-sm" onclick="window.print()">🖨 Print</button>
            <button class="btn btn-secondary btn-sm" onclick="document.getElementById('report-output').style.display='none'">Close</button>
          </div>
          <div id="report-output-body"></div>
        </div>
      </div>
    </div>`;
}

async function generateReport(reportId) {
  const outputEl    = document.getElementById('report-output');
  const titleEl     = document.getElementById('report-output-title');
  const bodyEl      = document.getElementById('report-output-body');
  outputEl.style.display = 'block';
  bodyEl.innerHTML  = spinner();

  const d   = _analyticsData;
  const best = d.best_sellers || [];

  if (reportId === 'rpt-sales') {
    titleEl.textContent = 'Sales Summary Report';
    const sum = d.summary || {};
    bodyEl.innerHTML = `
      <table>
        <thead><tr><th>Metric</th><th>Value</th></tr></thead>
        <tbody>
          <tr><td>Period</td><td>${d.period?.start} to ${d.period?.end}</td></tr>
          <tr><td>Total Online Orders</td><td>${d.online?.order_count || 0}</td></tr>
          <tr><td>Walk-in Sales</td><td>${d.walkin?.walkin_count || 0}</td></tr>
          <tr><td>Total Items Sold</td><td>${sum.total_items_sold || 0}</td></tr>
          <tr><td>Online Revenue</td><td>${peso(d.online?.revenue || 0)}</td></tr>
          <tr><td>Walk-in Revenue</td><td>${peso(d.walkin?.walkin_revenue || 0)}</td></tr>
          <tr><td>Total Revenue</td><td class="fw-600 text-accent">${peso(sum.total_revenue || 0)}</td></tr>
          <tr><td>New Customers</td><td>${d.customers?.new_customers || 0}</td></tr>
          <tr><td>GCash Payments</td><td>${d.online?.gcash_count || 0}</td></tr>
          <tr><td>Cash Payments</td><td>${d.online?.cash_count || 0}</td></tr>
          <tr><td>Delivery Orders</td><td>${d.online?.delivery_count || 0}</td></tr>
          <tr><td>Pickup Orders</td><td>${d.online?.pickup_count || 0}</td></tr>
        </tbody>
      </table>`;
  }

  if (reportId === 'rpt-products') {
    titleEl.textContent = 'Top Products Report';
    bodyEl.innerHTML = best.length === 0 ? `<p class="table-empty">No sales data.</p>` : `
      <table>
        <thead><tr><th>Rank</th><th>Product</th><th>Category</th><th>Units Sold</th><th>Revenue</th></tr></thead>
        <tbody>
          ${best.map((p, i) => `
            <tr>
              <td class="mono">#${i+1}</td>
              <td class="fw-600">${p.product_name}</td>
              <td class="text-muted">${p.category_name || '—'}</td>
              <td class="mono">${p.units_sold}</td>
              <td class="mono text-accent">${peso(p.revenue)}</td>
            </tr>`).join('')}
        </tbody>
      </table>`;
  }

  if (reportId === 'rpt-inv') {
    titleEl.textContent = 'Inventory Movement Report';
    try {
      const logs = await API.getInventoryLogs({
        start: d.period?.start,
        end:   d.period?.end,
      });
      bodyEl.innerHTML = logs.length === 0 ? `<p class="table-empty">No logs in this period.</p>` : `
        <table>
          <thead><tr><th>Date</th><th>Product</th><th>Type</th><th>Change</th><th>Qty</th><th>Reference</th></tr></thead>
          <tbody>
            ${logs.slice(0, 50).map(l => `
              <tr>
                <td class="mono text-muted" style="font-size:11px">${fmtDate(l.created_at)}</td>
                <td class="fw-600">${l.product_name}</td>
                <td class="text-muted">${l.transaction_type}</td>
                <td>${badge(l.change_type)}</td>
                <td class="mono">${l.quantity}</td>
                <td class="text-muted" style="font-size:11px">${l.reference || '—'}</td>
              </tr>`).join('')}
          </tbody>
        </table>`;
    } catch (err) {
      bodyEl.innerHTML = `<div class="alert alert-error">${err.message}</div>`;
    }
  }

  if (reportId === 'rpt-customers') {
    titleEl.textContent = 'Customer Orders Report';
    try {
      const orders = await API.getAdminOrders();
      const byCustomer = {};
      orders.forEach(o => {
        if (!byCustomer[o.customer_name]) {
          byCustomer[o.customer_name] = { name: o.customer_name, email: o.customer_email, orders: 0, spent: 0 };
        }
        byCustomer[o.customer_name].orders++;
        if (o.payment_status === 'paid') byCustomer[o.customer_name].spent += parseFloat(o.total_amount || 0);
      });
      const rows = Object.values(byCustomer).sort((a, b) => b.spent - a.spent);
      bodyEl.innerHTML = `
        <table>
          <thead><tr><th>Customer</th><th>Email</th><th>Orders</th><th>Total Spent</th></tr></thead>
          <tbody>
            ${rows.map(r => `
              <tr>
                <td class="fw-600">${r.name}</td>
                <td class="text-muted">${r.email}</td>
                <td class="mono">${r.orders}</td>
                <td class="mono text-accent">${peso(r.spent)}</td>
              </tr>`).join('')}
          </tbody>
        </table>`;
    } catch (err) {
      bodyEl.innerHTML = `<div class="alert alert-error">${err.message}</div>`;
    }
  }
}

// ── helpers ───────────────────────────────────────────────────────────────────
function loadScript(src) {
  return new Promise((resolve, reject) => {
    if (document.querySelector(`script[src="${src}"]`)) { resolve(); return; }
    const s = document.createElement('script');
    s.src = src; s.onload = resolve; s.onerror = reject;
    document.head.appendChild(s);
  });
}