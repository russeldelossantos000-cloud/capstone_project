/**
 * pages/brands.js
 */
let _brands2 = [], _brandPage = 1;

async function pageBrands(container) {
  container.innerHTML = `
    <div class="page-header">
      <div class="page-header-left"><h2>Brands</h2><p></p></div>
      <button class="btn btn-primary" id="add-brand-btn">+ Add Brand</button>
    </div>
    <div class="page-body">
      <div class="table-card">
        <div class="table-toolbar">
          <span class="table-title">All Brands</span>
          <input type="search" class="search-input" id="brand-search" placeholder="Search…" />
        </div>
        <div class="table-wrap"><div id="brand-table">${spinner()}</div></div>
        <div id="brand-pagination"></div>
      </div>
    </div>`;

  document.getElementById('add-brand-btn').addEventListener('click', () => openBrandForm());
  document.getElementById('brand-search').addEventListener('input', renderBrands);

  try {
    _brands2 = await API.getBrands();
    renderBrands();
  } catch (err) {
    document.getElementById('brand-table').innerHTML = `<div class="alert alert-error" style="margin:16px">${err.message}</div>`;
  }
}

function renderBrands() {
  const search = document.getElementById('brand-search')?.value.toLowerCase() || '';
  const filtered = _brands2.filter(b => b.brand_name.toLowerCase().includes(search));
  const { items, pages } = paginate(filtered, _brandPage);

  document.getElementById('brand-table').innerHTML = items.length === 0
    ? `<p class="table-empty">No brands found.</p>`
    : `<table>
        <thead><tr><th>ID</th><th>Brand Name</th><th>Created</th><th></th></tr></thead>
        <tbody>
          ${items.map(b => `
            <tr>
              <td class="mono text-muted">#${b.id}</td>
            
              <td class="fw-600">${b.brand_name}</td>
              <td class="text-muted mono">${fmtDate(b.created_at)}</td>
              <td>
                <div class="actions-cell">
                  <button class="btn btn-ghost btn-sm" onclick="openBrandForm(${b.id})">Edit</button>
                  <button class="btn btn-danger btn-sm" onclick="deleteBrand(${b.id}, '${b.brand_name.replace(/'/g,"\\'")}')">Del</button>
                </div>
              </td>
            </tr>`).join('')}
        </tbody>
      </table>`;

  renderPagination(document.getElementById('brand-pagination'), _brandPage, pages, p => { _brandPage = p; renderBrands(); });
}

function openBrandForm(id = null) {
  const b = id ? _brands2.find(x => x.id === id) : null;
  Modal.open({
    title: id ? 'Edit Brand' : 'Add Brand',
    body: `
      <div class="form-group"><label>Brand Name </label><input type="text" id="f-brand-name" value="${b?.brand_name || ''}" /></div>
      <div></div>`,
    footer: `
      <button class="btn btn-secondary" onclick="Modal.close()">Cancel</button>
      <button class="btn btn-primary" id="save-brand-btn">${id ? 'Update' : 'Create'}</button>`,
  });
  document.getElementById('save-brand-btn').addEventListener('click', async () => {
    const name = document.getElementById('f-brand-name').value.trim();
    if (!name) { document.getElementById('brand-err').innerHTML = `<div class="alert alert-error">Name is required.</div>`; return; }
    try {
      const body = { brand_name: name };
      if (id) await API.updateBrand(id, body); else await API.createBrand(body);
      toast(id ? 'Brand updated!' : 'Brand created!', 'success');
      Modal.close();
      _brands2 = await API.getBrands();
      renderBrands();
    } catch (err) { document.getElementById('brand-err').innerHTML = `<div class="alert alert-error">${err.message}</div>`; }
  });
}

async function deleteBrand(id, name) {
  confirmDelete(`Delete brand <strong>${name}</strong>?`, async () => {
    try { await API.deleteBrand(id); toast('Brand deleted.', 'success'); _brands2 = await API.getBrands(); renderBrands(); }
    catch (err) { toast(err.message, 'error'); }
  });
}
