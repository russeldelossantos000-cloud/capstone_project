/**
 * pages/categories.js
 */
let _cats = [], _catPage = 1;

async function pageCategories(container) {
  container.innerHTML = `
    <div class="page-header">
      <div class="page-header-left"><h2>Categories</h2><p></p></div>
      <button class="btn btn-primary" id="add-cat-btn">+ Add Category</button>
    </div>
    <div class="page-body">
      <div class="table-card">
        <div class="table-toolbar">
          <span class="table-title">All Categories</span>
          <input type="search" class="search-input" id="cat-search" placeholder="Search…" />
        </div>
        <div class="table-wrap"><div id="cat-table">${spinner()}</div></div>
        <div id="cat-pagination"></div>
      </div>
    </div>`;

  document.getElementById('add-cat-btn').addEventListener('click', () => openCatForm());
  document.getElementById('cat-search').addEventListener('input', renderCats);

  try {
    _cats = await API.getCategories();
    renderCats();
  } catch (err) {
    document.getElementById('cat-table').innerHTML = `<div class="alert alert-error" style="margin:16px">${err.message}</div>`;
  }
}

function renderCats() {
  const search = document.getElementById('cat-search')?.value.toLowerCase() || '';
  const filtered = _cats.filter(c => c.category_name.toLowerCase().includes(search));
  const { items, pages } = paginate(filtered, _catPage);

  document.getElementById('cat-table').innerHTML = items.length === 0
    ? `<p class="table-empty">No categories found.</p>`
    : `<table>
        <thead><tr><th>ID</th><th>Name</th><th>Created</th><th></th></tr></thead>
        <tbody>
          ${items.map(c => `
            <tr>
              <td class="mono text-muted">#${c.id}</td>
              <td class="fw-600">${c.category_name}</td>
              <td class="text-muted mono">${fmtDate(c.created_at)}</td>
              <td>
                <div class="actions-cell">
                  <button class="btn btn-ghost btn-sm" onclick="openCatForm(${c.id})">Edit</button>
                  <button class="btn btn-danger btn-sm" onclick="deleteCat(${c.id}, '${c.category_name.replace(/'/g,"\\'")}')">Del</button>
                </div>
              </td>
            </tr>`).join('')}
        </tbody>
      </table>`;

  renderPagination(document.getElementById('cat-pagination'), _catPage, pages, p => { _catPage = p; renderCats(); });
}

function openCatForm(id = null) {
  const c = id ? _cats.find(x => x.id === id) : null;
  Modal.open({
    title: id ? 'Edit Category' : 'Add Category',
    body: `
      <div class="form-group"><label>Category Name </label><input type="text" id="f-cat-name" value="${c?.category_name || ''}" /></div>
      <div id="cat-err"></div>`,
    footer: `
      <button class="btn btn-secondary" onclick="Modal.close()">Cancel</button>
      <button class="btn btn-primary" id="save-cat-btn">${id ? 'Update' : 'Create'}</button>`,
  });
  document.getElementById('save-cat-btn').addEventListener('click', async () => {
    const name = document.getElementById('f-cat-name').value.trim();
    if (!name) { document.getElementById('cat-err').innerHTML = `<div class="alert alert-error">Name is required.</div>`; return; }
    try {
      if (id) await API.updateCategory(id, { category_name: name });
      else    await API.createCategory({ category_name: name });
      toast(id ? 'Category updated!' : 'Category created!', 'success');
      Modal.close();
      _cats = await API.getCategories();
      renderCats();
    } catch (err) { document.getElementById('cat-err').innerHTML = `<div class="alert alert-error">${err.message}</div>`; }
  });
}

async function deleteCat(id, name) {
  confirmDelete(`Delete category <strong>${name}</strong>?`, async () => {
    try { await API.deleteCategory(id); toast('Category deleted.', 'success'); _cats = await API.getCategories(); renderCats(); }
    catch (err) { toast(err.message, 'error'); }
  });
}
