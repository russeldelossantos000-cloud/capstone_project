/**
 * pages/catalog.js
 * Unified Catalog page — Products / Categories / Brands / Customizations tabs
 */
let _catalogTab = 'products';
let _catProducts = [], _catCategories = [], _catBrands = [];
let _catProductPage = 1;
let _showArchived = false;

async function pageCatalog(container) {
  container.innerHTML = `
    <div class="page-header">
      <div class="page-header-left"><h2>Catalog</h2><p>Manage products, categories, brands, and customizations</p></div>
    </div>
    <div class="page-body">
      <div class="tabs-bar">
        <button class="tab-btn active" data-tab="products">Products</button>
        <button class="tab-btn" data-tab="categories">Categories</button>
        <button class="tab-btn" data-tab="brands">Brands</button>
      </div>
      <div id="catalog-tab-content">${spinner()}</div>
    </div>`;

  document.querySelectorAll('.tab-btn').forEach(btn => {
    btn.addEventListener('click', () => switchCatalogTab(btn.dataset.tab));
  });

  await switchCatalogTab('products');
}

async function switchCatalogTab(tab) {
  _catalogTab = tab;
  document.querySelectorAll('.tab-btn').forEach(b => b.classList.toggle('active', b.dataset.tab === tab));

  const content = document.getElementById('catalog-tab-content');
  content.innerHTML = spinner();

  if (tab === 'products')       await renderCatalogProductsTab(content);
  if (tab === 'categories')     await renderCategoriesTab(content);
  if (tab === 'brands')         await renderBrandsTab(content);
}

// ══════════════════════════════════════════════════════════════════════════
// PRODUCTS TAB
// ══════════════════════════════════════════════════════════════════════════

async function renderCatalogProductsTab(content) {
  content.innerHTML = `
    <div class="table-card">
      <div class="table-toolbar">
        <span class="table-title">Products</span>
        <input type="search" class="search-input" id="cat-product-search" placeholder="Search products…" />
        <select id="cat-product-cat-filter" style="width:150px"><option value="">All Categories</option></select>
        <select id="cat-product-brand-filter" style="width:130px"><option value="">All Brands</option></select>
        <select id="cat-product-demand-filter" style="width:140px">
          <option value="">All Demand</option>
          <option value="high">High</option>
          <option value="normal">Normal</option>
          <option value="low">Low</option>
          <option value="specialty">Specialty</option>
        </select>
        <label style="display:flex;align-items:center;gap:6px;font-size:12px;color:var(--muted);white-space:nowrap">
          <input type="checkbox" id="cat-show-archived" /> Show Archived
        </label>
        <button class="btn btn-primary" id="cat-add-product-btn">+ Add Product</button>
      </div>
      <div class="table-wrap"><div id="cat-products-table">${spinner()}</div></div>
      <div id="cat-products-pagination"></div>
    </div>`;

  document.getElementById('cat-add-product-btn').addEventListener('click', () => openCatProductForm());
  document.getElementById('cat-show-archived').addEventListener('change', (e) => {
    _showArchived = e.target.checked; _catProductPage = 1; loadCatProducts();
  });

  try {
    [_catProducts, _catCategories, _catBrands] = await Promise.all([
      API.getProducts(_showArchived ? '?archived=true' : ''),
      API.getCategories(),
      API.getBrands(),
    ]);

    const catFilter   = document.getElementById('cat-product-cat-filter');
    const brandFilter = document.getElementById('cat-product-brand-filter');
    _catCategories.forEach(c => catFilter.insertAdjacentHTML('beforeend', `<option value="${c.id}">${c.category_name}</option>`));
    _catBrands.forEach(b => brandFilter.insertAdjacentHTML('beforeend', `<option value="${b.id}">${b.brand_name}</option>`));

    renderCatProducts();

    document.getElementById('cat-product-search').addEventListener('input', renderCatProducts);
    catFilter.addEventListener('change', renderCatProducts);
    brandFilter.addEventListener('change', renderCatProducts);
    document.getElementById('cat-product-demand-filter').addEventListener('change', renderCatProducts);
  } catch (err) {
    document.getElementById('cat-products-table').innerHTML = `<div class="alert alert-error" style="margin:16px">${err.message}</div>`;
  }
}

async function loadCatProducts() {
  document.getElementById('cat-products-table').innerHTML = spinner();
  try {
    _catProducts = await API.getProducts(_showArchived ? '?archived=true' : '');
    renderCatProducts();
  } catch (err) {
    document.getElementById('cat-products-table').innerHTML = `<div class="alert alert-error" style="margin:16px">${err.message}</div>`;
  }
}

function renderCatProducts() {
  const search   = document.getElementById('cat-product-search')?.value.toLowerCase() || '';
  const catId    = document.getElementById('cat-product-cat-filter')?.value || '';
  const brandId  = document.getElementById('cat-product-brand-filter')?.value || '';
  const demand   = document.getElementById('cat-product-demand-filter')?.value || '';

  let filtered = _catProducts.filter(p =>
    (!search  || p.product_name.toLowerCase().includes(search)) &&
    (!catId   || String(p.category_id) === catId) &&
    (!brandId || String(p.brand_id)    === brandId) &&
    (!demand  || p.demand_level === demand)
  );

  const { items, pages } = paginate(filtered, _catProductPage);

  if (items.length === 0) {
    document.getElementById('cat-products-table').innerHTML = `<p class="table-empty">No products found.</p>`;
    document.getElementById('cat-products-pagination').innerHTML = '';
    return;
  }

  const demandBadge = (lvl) => {
    const map = { high: 'badge-in', normal: 'badge-default', low: 'badge-pending', specialty: 'badge-paid' };
    return `<span class="badge ${map[lvl] || 'badge-default'}">${lvl}</span>`;
  };

  document.getElementById('cat-products-table').innerHTML = `
    <table>
      <thead><tr>
        <th>Image</th><th>Product</th><th>Category</th><th>Price</th><th>Stock</th>
        <th>Demand</th><th>AR</th><th></th>
      </tr></thead>
      <tbody>
        ${items.map(p => `
          <tr style="${p.is_archived ? 'opacity:.5' : ''}">
            <td>${p.image ? `<img class="thumb" src="${API.imgUrl(p.image)}" onerror="this.style.display='none'">` : `<div class="thumb"></div>`}</td>
            <td class="fw-600">${p.product_name}${p.priority ? ' <span class="badge badge-out">★</span>' : ''}</td>
            <td class="text-muted">${p.category_name || '—'}</td>
            <td class="mono">${peso(p.price)}</td>
            <td class="${stockClass(p.stock)} mono fw-600">${p.stock}</td>
            <td>${demandBadge(p.demand_level)}</td>
            <td>${p.ar_model ? '<span class="badge badge-in">Yes</span>' : '<span class="badge badge-default">No</span>'}</td>
            <td>
              <div class="actions-cell">
                ${p.is_archived
                  ? `<button class="btn btn-ghost btn-sm" onclick="restoreCatProduct(${p.id})">Restore</button>`
                  : `<button class="btn btn-ghost btn-sm" onclick="openCatProductForm(${p.id})">Edit</button>
                     <button class="btn btn-ghost btn-sm" onclick="openArModal(${p.id}, '${p.product_name.replace(/'/g,"\\'")}')">AR</button>
                     <button class="btn btn-danger btn-sm" onclick="archiveCatProduct(${p.id}, '${p.product_name.replace(/'/g,"\\'")}')">Archive</button>`}
              </div>
            </td>
          </tr>`).join('')}
      </tbody>
    </table>`;

  renderPagination(document.getElementById('cat-products-pagination'), _catProductPage, pages, p => { _catProductPage = p; renderCatProducts(); });
}

async function archiveCatProduct(id, name) {
  confirmDelete(
    `Archive <strong>${name}</strong>? It will be hidden from customers but can be restored anytime.`,
    async () => {
      try {
        await API.deleteProduct(id);
        toast('Product archived.', 'success');
        await loadCatProducts();
      } catch (err) { toast(err.message, 'error'); }
    },
    { title: 'Archive Product', buttonText: 'Archive' }
  );
}

async function restoreCatProduct(id) {
  try {
    await API.unarchiveProduct(id);
    toast('Product restored.', 'success');
    await loadCatProducts();
  } catch (err) { toast(err.message, 'error'); }
}

// ══════════════════════════════════════════════════════════════════════════
// PRODUCT ADD/EDIT MODAL
// ══════════════════════════════════════════════════════════════════════════

function openCatProductForm(id = null) {
  const p = id ? _catProducts.find(x => x.id === id) : null;

  const catOptions   = _catCategories.map(c => `<option value="${c.id}" ${p?.category_id == c.id ? 'selected' : ''}>${c.category_name}</option>`).join('');
  const brandOptions = _catBrands.map(b    => `<option value="${b.id}" ${p?.brand_id    == b.id ? 'selected' : ''}>${b.brand_name}</option>`).join('');

  Modal.open({
    title: id ? 'Edit Product' : 'Add Product',
    large: true,
    body: `
      <p class="form-section-label">BASIC INFO</p>
      <div class="form-row">
        <div class="form-group">
          <label>Product Name</label>
          <input type="text" id="f-name" value="${p?.product_name || ''}" />
        </div>
        <div class="form-group">
          <label>Price</label>
          <input type="number" id="f-price" step="0.01" value="${p?.price || ''}" />
        </div>
      </div>
      <div class="form-row">
        <div class="form-group">
          <label>Category</label>
          <select id="f-category"><option value="">Select…</option>${catOptions}</select>
        </div>
        <div class="form-group">
          <label>Brand</label>
          <select id="f-brand"><option value="">None</option>${brandOptions}</select>
        </div>
      </div>

      <hr style="border-color:var(--border);margin:16px 0" />
      <p class="form-section-label">CLASSIFICATION</p>
      <div class="form-row">
        <div class="form-group">
          <label>Stock ${id ? '<span class="text-muted" style="font-weight:400">(read-only — use Inventory to adjust)</span>' : ''}</label>
          <input type="number" id="f-stock" value="${p?.stock ?? ''}" ${id ? 'readonly style="opacity:.6;cursor:not-allowed"' : ''} />
        </div>
        <div class="form-group">
          <label>Stock Threshold</label>
          <input type="number" id="f-threshold" value="${p?.stock_threshold ?? 5}" />
        </div>
      </div>
        <div class="form-group">
          <label style="display:flex;align-items:center;gap:8px">
            <input type="checkbox" id="f-priority" ${p?.priority ? 'checked' : ''} style="width:auto" />
            Priority Item
          </label>
        </div>
      </div>

      <hr style="border-color:var(--border);margin:16px 0" />
      <p class="form-section-label">IMAGE</p>
      <div class="form-group">
        <div id="upload-zone" style="border:2px dashed var(--border);border-radius:10px;padding:20px;text-align:center;cursor:pointer;position:relative"
             onclick="document.getElementById('f-image-file').click()"
             ondragover="event.preventDefault();this.style.borderColor='var(--accent)'"
             ondragleave="this.style.borderColor='var(--border)'"
             ondrop="handleCatImageDrop(event)">
          <input type="file" id="f-image-file" accept="image/jpeg,image/png,image/webp,image/gif" style="display:none" onchange="handleCatImageSelect(this)" />
          <div id="upload-placeholder">
            <p style="color:var(--muted);font-size:13px;margin:0"><strong style="color:var(--text)">Click to upload</strong> or drag & drop</p>
          </div>
          <div id="upload-preview" style="display:none">
            <img id="preview-img" style="max-height:140px;max-width:100%;border-radius:8px;object-fit:contain" />
          </div>
        </div>
        ${p?.image ? `
          <div style="margin-top:10px;display:flex;align-items:center;gap:10px">
            <img src="${API.imgUrl(p.image)}" style="width:48px;height:48px;border-radius:6px;object-fit:cover;border:1px solid var(--border)" onerror="this.style.display='none'" />
            <label style="display:flex;align-items:center;gap:6px;font-size:12px;color:var(--muted);cursor:pointer">
              <input type="checkbox" id="f-keep-image" checked /> Keep current image if no new file selected
            </label>
          </div>` : ''}
        <input type="hidden" id="f-image-url" value="${p?.image || ''}" />
        ${id ? `<button type="button" class="btn btn-ghost btn-sm" style="margin-top:10px" onclick="manageProductImages(${id}, '${(p?.product_name || '').replace(/'/g,"\\'")}')">🖼 Manage Additional Images</button>`
     : `<p class="text-muted" style="font-size:12px;margin-top:10px">Save this product first to add a photo gallery.</p>`}
      </div>

      <div class="form-group">
  <label>Description</label>
  <textarea id="f-desc">${p?.description || ''}</textarea>
    </div>

   ${id ? `
   <hr style="border-color:var(--border);margin:16px 0" />
   <p class="form-section-label">VARIANTS</p>
   <div id="variant-list-wrap">${spinner()}</div>
   <button type="button" class="btn btn-ghost btn-sm" id="add-variant-row-btn" style="margin-top:8px">+ Add Variant</button>
   ` : `
   <hr style="border-color:var(--border);margin:16px 0" />
   <p class="text-muted" style="font-size:12px">Save this product first, then variants can be added.</p>
   `}

   <div id="form-err"></div>`,
    footer: `
      <button class="btn btn-secondary" onclick="Modal.close()">Cancel</button>
      <button class="btn btn-primary" id="save-cat-product-btn">${id ? 'Update' : 'Create'}</button>`,
  });

   if (id) {
  loadVariantsForProduct(id);
  document.getElementById('add-variant-row-btn')?.addEventListener('click', () => openVariantForm(id));
   }

  document.getElementById('save-cat-product-btn').addEventListener('click', async () => {
    const btn   = document.getElementById('save-cat-product-btn');
    const errEl = document.getElementById('form-err');
    const name  = document.getElementById('f-name').value.trim();
    const price = document.getElementById('f-price').value;
    const catId = document.getElementById('f-category').value;
    const stock = document.getElementById('f-stock').value;

    if (!name || !price || !catId || (!id && !stock)) {
      errEl.innerHTML = `<div class="alert alert-error">Please fill all required fields.</div>`;
      return;
    }

    btn.disabled = true; btn.textContent = 'Saving…';

    try {
      let imageUrl = document.getElementById('f-image-url').value;
      const fileInput = document.getElementById('f-image-file');
      if (fileInput?.files?.length > 0) {
        imageUrl = await uploadProductImage(fileInput.files[0]);
      } else if (id && document.getElementById('f-keep-image')?.checked === false) {
        imageUrl = null;
      }

      const body = {
        product_name:     name,
        price,
        category_id:      catId,
        brand_id:          document.getElementById('f-brand').value || null,
        stock_threshold:   document.getElementById('f-threshold').value || 5,
        priority:          document.getElementById('f-priority').checked ? 1 : 0,
        image:             imageUrl || null,
        description:       document.getElementById('f-desc').value.trim() || null,
      };

      // Stock only sent on creation — read-only after
      if (!id) body.stock = stock;

      if (id) await API.updateProduct(id, body);
      else    await API.createProduct(body);

      toast(id ? 'Product updated!' : 'Product created!', 'success');
      Modal.close();
      await loadCatProducts();
    } catch (err) {
      errEl.innerHTML = `<div class="alert alert-error">${err.message}</div>`;
    } finally {
      btn.disabled = false; btn.textContent = id ? 'Update' : 'Create';
    }
  });
}

function handleCatImageSelect(input) {
  const file = input.files[0];
  if (!file) return;
  showCatImagePreview(file);
}

function handleCatImageDrop(event) {
  event.preventDefault();
  document.getElementById('upload-zone').style.borderColor = 'var(--border)';
  const file = event.dataTransfer.files[0];
  if (!file || !file.type.startsWith('image/')) { toast('Please drop an image file.', 'error'); return; }
  document.getElementById('f-image-file').files = event.dataTransfer.files;
  showCatImagePreview(file);
}

function showCatImagePreview(file) {
  const reader = new FileReader();
  reader.onload = e => {
    document.getElementById('upload-placeholder').style.display = 'none';
    document.getElementById('upload-preview').style.display     = 'block';
    document.getElementById('preview-img').src = e.target.result;
  };
  reader.readAsDataURL(file);
}

async function uploadProductImage(file) {
  const formData = new FormData();
  formData.append('image', file);
  const token = localStorage.getItem('admin_token');

  return new Promise((resolve, reject) => {
    const xhr = new XMLHttpRequest();
    xhr.open('POST', API.BASE_URL + '/upload/product-image');
    xhr.setRequestHeader('Authorization', `Bearer ${token}`);
    xhr.onload = () => {
      try {
        const res = JSON.parse(xhr.responseText);
        if (xhr.status >= 200 && xhr.status < 300) resolve(res.image_url);
        else reject(new Error(res.error || 'Upload failed'));
      } catch { reject(new Error('Upload failed')); }
    };
    xhr.onerror = () => reject(new Error('Network error during upload'));
    xhr.send(formData);
  });
}

async function manageProductImages(productId, productName) {
  Modal.open({ title: `Images — ${productName}`, large: true, body: spinner() });
  await refreshImageManager(productId, productName);
}

async function refreshImageManager(productId, productName) {
  try {
    const images = await API.getProductImages(productId);
    document.getElementById('modal-body').innerHTML = `
      <p style="font-size:11px;font-weight:700;color:var(--muted);letter-spacing:1.5px;margin-bottom:10px">
        CURRENT IMAGES (${images.length})
      </p>
      ${images.length === 0
        ? `<p style="color:var(--muted);font-size:13px;margin-bottom:16px">No additional images yet.</p>`
        : `<div style="display:flex;flex-wrap:wrap;gap:10px;margin-bottom:20px">
            ${images.map(img => `
              <div style="position:relative;display:inline-block">
                <img src="${API.imgUrl(img.image_url)}" style="width:90px;height:90px;object-fit:cover;border-radius:8px;
                     border:2px solid ${img.is_primary ? 'var(--accent)' : 'var(--border)'}"
                     onerror="this.src=''" />
                ${img.is_primary
                  ? `<span style="position:absolute;top:4px;left:4px;background:var(--accent);color:#000;
                       font-size:9px;font-weight:800;padding:2px 5px;border-radius:4px">PRIMARY</span>`
                  : `<button onclick="setProductImagePrimary(${img.id}, ${productId}, '${productName.replace(/'/g, "\\'")}')"
                       style="position:absolute;top:4px;left:4px;background:rgba(0,0,0,.6);color:#fff;
                              border:none;font-size:9px;cursor:pointer;padding:2px 5px;border-radius:4px">
                       Set primary</button>`}
                <button onclick="deleteProductImageFromGallery(${img.id}, ${productId}, '${productName.replace(/'/g, "\\'")}')"
                    style="position:absolute;top:4px;right:4px;background:var(--danger);color:#fff;
                           border:none;cursor:pointer;width:20px;height:20px;border-radius:50%;
                           font-size:13px;line-height:1;display:flex;align-items:center;justify-content:center">×</button>
              </div>`).join('')}
          </div>`}

      <hr style="border-color:var(--border);margin:0 0 16px" />

      <p style="font-size:11px;font-weight:700;color:var(--muted);letter-spacing:1.5px;margin-bottom:10px">
        ADD NEW IMAGES
      </p>
      <div id="multi-upload-zone"
           style="border:2px dashed var(--border);border-radius:10px;padding:20px;text-align:center;cursor:pointer"
           onclick="document.getElementById('multi-img-input').click()"
           ondragover="event.preventDefault();this.style.borderColor='var(--accent)'"
           ondragleave="this.style.borderColor='var(--border)'"
           ondrop="handleMultiDrop(event, ${productId}, '${productName.replace(/'/g, "\\'")}')">
        <input type="file" id="multi-img-input" multiple accept="image/*"
               style="display:none"
               onchange="handleMultiSelect(this, ${productId}, '${productName.replace(/'/g, "\\'")}')"/>
        <p style="color:var(--muted);font-size:13px;margin:0">
          <strong style="color:var(--text)">Click or drag</strong> to add images (multiple allowed)
        </p>
      </div>
      <div id="multi-upload-list" style="margin-top:10px;display:flex;flex-direction:column;gap:6px"></div>
      <div id="img-mgr-err" style="margin-top:8px"></div>`;

    document.getElementById('modal-footer').innerHTML = `
      <button class="btn btn-secondary" onclick="openCatProductForm(${productId})">Back</button>
      <button class="btn btn-primary" id="upload-all-btn" style="display:none"
              onclick="uploadAllPendingImages(${productId}, '${productName.replace(/'/g, "\\'")}')">
        Upload Selected
      </button>`;
  } catch (err) {
    document.getElementById('modal-body').innerHTML =
      `<div class="alert alert-error">${err.message}</div>`;
  }
}

let _pendingFiles = [];

function handleMultiSelect(input) {
  _pendingFiles = Array.from(input.files);
  renderPendingList();
  document.getElementById('upload-all-btn').style.display = _pendingFiles.length > 0 ? '' : 'none';
}

function handleMultiDrop(event) {
  event.preventDefault();
  document.getElementById('multi-upload-zone').style.borderColor = 'var(--border)';
  _pendingFiles = Array.from(event.dataTransfer.files).filter(f => f.type.startsWith('image/'));
  renderPendingList();
  document.getElementById('upload-all-btn').style.display = _pendingFiles.length > 0 ? '' : 'none';
}

function renderPendingList() {
  document.getElementById('multi-upload-list').innerHTML = _pendingFiles.map(f => `
    <div style="display:flex;align-items:center;gap:10px;padding:8px 12px;background:var(--surface2);border-radius:8px">
      <span style="font-size:13px;color:var(--text);flex:1">${f.name}</span>
      <span style="font-size:11px;color:var(--muted)">${(f.size/1024).toFixed(0)} KB</span>
    </div>`).join('');
}

async function uploadAllPendingImages(productId, productName) {
  if (_pendingFiles.length === 0) return;
  const btn = document.getElementById('upload-all-btn');
  btn.disabled = true; btn.textContent = 'Uploading…';

  let successCount = 0;
  for (const file of _pendingFiles) {
    try {
      const url = await uploadProductImage(file);
      await API.addProductImage(productId, url);
      successCount++;
    } catch (err) {
      document.getElementById('img-mgr-err').innerHTML =
        `<div class="alert alert-error">Failed to upload ${file.name}: ${err.message}</div>`;
    }
  }

  _pendingFiles = [];
  toast(`${successCount} image(s) uploaded!`, 'success');
  await refreshImageManager(productId, productName);
}

async function setProductImagePrimary(imageId, productId, productName) {
  try {
    await API.setProductImagePrimary(imageId);
    await refreshImageManager(productId, productName);
  } catch (err) { toast(err.message, 'error'); }
}

async function deleteProductImageFromGallery(imageId, productId, productName) {
  try {
    await API.deleteProductImage(imageId);
    toast('Image deleted.', 'success');
    await refreshImageManager(productId, productName);
  } catch (err) { toast(err.message, 'error'); }
}

// ══════════════════════════════════════════════════════════════════════════
// CATEGORIES TAB
// ══════════════════════════════════════════════════════════════════════════

let _catCatPage = 1;

async function renderCategoriesTab(content) {
  content.innerHTML = `
    <div class="table-card">
      <div class="table-toolbar">
        <span class="table-title">Categories</span>
        <input type="search" class="search-input" id="cat-cat-search" placeholder="Search…" />
        <button class="btn btn-primary" id="cat-add-cat-btn">+ Add Category</button>
      </div>
      <div class="table-wrap"><div id="cat-categories-table">${spinner()}</div></div>
      <div id="cat-categories-pagination"></div>
    </div>`;

  document.getElementById('cat-add-cat-btn').addEventListener('click', () => openCategoryFormModal());
  document.getElementById('cat-cat-search').addEventListener('input', renderCatCategories);

  try {
    _catCategories = await API.getCategories();
    renderCatCategories();
  } catch (err) {
    document.getElementById('cat-categories-table').innerHTML = `<div class="alert alert-error" style="margin:16px">${err.message}</div>`;
  }
}

function renderCatCategories() {
  const search = document.getElementById('cat-cat-search')?.value.toLowerCase() || '';
  const filtered = _catCategories.filter(c => c.category_name.toLowerCase().includes(search));
  const { items, pages } = paginate(filtered, _catCatPage);

  document.getElementById('cat-categories-table').innerHTML = items.length === 0
    ? `<p class="table-empty">No categories found.</p>`
    : `<table>
        <thead><tr><th>ID</th><th>Name</th><th>Products</th><th>Created</th><th></th></tr></thead>
        <tbody>
          ${items.map(c => `
            <tr>
              <td class="mono text-muted">#${c.id}</td>
              <td class="fw-600">${c.category_name}</td>
              <td class="text-muted">${c.product_count ?? '—'}</td>
              <td class="text-muted mono">${fmtDate(c.created_at)}</td>
              <td>
                <div class="actions-cell">
                  <button class="btn btn-ghost btn-sm" onclick="openCategoryFormModal(${c.id})">Edit</button>
                  <button class="btn btn-danger btn-sm" onclick="deleteCategoryModal(${c.id}, '${c.category_name.replace(/'/g,"\\'")}')">Delete</button>
                </div>
              </td>
            </tr>`).join('')}
        </tbody>
      </table>`;

  renderPagination(document.getElementById('cat-categories-pagination'), _catCatPage, pages, p => { _catCatPage = p; renderCatCategories(); });
}

function openCategoryFormModal(id = null) {
  const c = id ? _catCategories.find(x => x.id === id) : null;
  Modal.open({
    title: id ? 'Edit Category' : 'Add Category',
    body: `
      <div class="form-group"><label>Category Name</label><input type="text" id="f-cat-name" value="${c?.category_name || ''}" /></div>
      <div id="cat-form-err"></div>`,
    footer: `
      <button class="btn btn-secondary" onclick="Modal.close()">Cancel</button>
      <button class="btn btn-primary" id="save-cat-cat-btn">${id ? 'Update' : 'Create'}</button>`,
  });
  document.getElementById('save-cat-cat-btn').addEventListener('click', async () => {
    const name = document.getElementById('f-cat-name').value.trim();
    if (!name) { document.getElementById('cat-form-err').innerHTML = `<div class="alert alert-error">Name is required.</div>`; return; }
    try {
      if (id) await API.updateCategory(id, { category_name: name });
      else    await API.createCategory({ category_name: name });
      toast(id ? 'Category updated!' : 'Category created!', 'success');
      Modal.close();
      _catCategories = await API.getCategories();
      renderCatCategories();
    } catch (err) { document.getElementById('cat-form-err').innerHTML = `<div class="alert alert-error">${err.message}</div>`; }
  });
}

async function deleteCategoryModal(id, name) {
  confirmDelete(`Delete category <strong>${name}</strong>?`, async () => {
    try {
      await API.deleteCategory(id);
      toast('Category deleted.', 'success');
      _catCategories = await API.getCategories();
      renderCatCategories();
    } catch (err) { toast(err.message, 'error'); }
  });
}

// ══════════════════════════════════════════════════════════════════════════
// BRANDS TAB
// ══════════════════════════════════════════════════════════════════════════

let _catBrandPage = 1;

async function renderBrandsTab(content) {
  content.innerHTML = `
    <div class="table-card">
      <div class="table-toolbar">
        <span class="table-title">Brands</span>
        <input type="search" class="search-input" id="cat-brand-search" placeholder="Search…" />
        <button class="btn btn-primary" id="cat-add-brand-btn">+ Add Brand</button>
      </div>
      <div class="table-wrap"><div id="cat-brands-table">${spinner()}</div></div>
      <div id="cat-brands-pagination"></div>
    </div>`;

  document.getElementById('cat-add-brand-btn').addEventListener('click', () => openBrandFormModal());
  document.getElementById('cat-brand-search').addEventListener('input', renderCatBrands);

  try {
    _catBrands = await API.getBrands();
    renderCatBrands();
  } catch (err) {
    document.getElementById('cat-brands-table').innerHTML = `<div class="alert alert-error" style="margin:16px">${err.message}</div>`;
  }
}

function renderCatBrands() {
  const search = document.getElementById('cat-brand-search')?.value.toLowerCase() || '';
  const filtered = _catBrands.filter(b => b.brand_name.toLowerCase().includes(search));
  const { items, pages } = paginate(filtered, _catBrandPage);

  document.getElementById('cat-brands-table').innerHTML = items.length === 0
    ? `<p class="table-empty">No brands found.</p>`
    : `<table>
        <thead><tr><th>ID</th><th>Brand Name</th><th>Products</th><th>Created</th><th></th></tr></thead>
        <tbody>
          ${items.map(b => `
            <tr>
              <td class="mono text-muted">#${b.id}</td>
              <td class="fw-600">${b.brand_name}</td>
              <td class="text-muted">${b.product_count ?? '—'}</td>
              <td class="text-muted mono">${fmtDate(b.created_at)}</td>
              <td>
                <div class="actions-cell">
                  <button class="btn btn-ghost btn-sm" onclick="openBrandFormModal(${b.id})">Edit</button>
                  <button class="btn btn-danger btn-sm" onclick="deleteBrandModal(${b.id}, '${b.brand_name.replace(/'/g,"\\'")}')">Delete</button>
                </div>
              </td>
            </tr>`).join('')}
        </tbody>
      </table>`;

  renderPagination(document.getElementById('cat-brands-pagination'), _catBrandPage, pages, p => { _catBrandPage = p; renderCatBrands(); });
}

function openBrandFormModal(id = null) {
  const b = id ? _catBrands.find(x => x.id === id) : null;
  Modal.open({
    title: id ? 'Edit Brand' : 'Add Brand',
    body: `
      <div class="form-group"><label>Brand Name</label><input type="text" id="f-brand-name" value="${b?.brand_name || ''}" /></div>
      <div id="brand-form-err"></div>`,
    footer: `
      <button class="btn btn-secondary" onclick="Modal.close()">Cancel</button>
      <button class="btn btn-primary" id="save-cat-brand-btn">${id ? 'Update' : 'Create'}</button>`,
  });
  document.getElementById('save-cat-brand-btn').addEventListener('click', async () => {
    const name = document.getElementById('f-brand-name').value.trim();
    if (!name) { document.getElementById('brand-form-err').innerHTML = `<div class="alert alert-error">Name is required.</div>`; return; }
    try {
      if (id) await API.updateBrand(id, { brand_name: name });
      else    await API.createBrand({ brand_name: name });
      toast(id ? 'Brand updated!' : 'Brand created!', 'success');
      Modal.close();
      _catBrands = await API.getBrands();
      renderCatBrands();
    } catch (err) { document.getElementById('brand-form-err').innerHTML = `<div class="alert alert-error">${err.message}</div>`; }
  });
}

async function deleteBrandModal(id, name) {
  confirmDelete(`Delete brand <strong>${name}</strong>?`, async () => {
    try {
      await API.deleteBrand(id);
      toast('Brand deleted.', 'success');
      _catBrands = await API.getBrands();
      renderCatBrands();
    } catch (err) { toast(err.message, 'error'); }
  });
}


// ══════════════════════════════════════════════════════════════════════════
// PRODUCT VARIANTS
// ══════════════════════════════════════════════════════════════════════════

async function loadVariantsForProduct(productId) {
  const wrap = document.getElementById('variant-list-wrap');
  if (!wrap) return;
  wrap.innerHTML = spinner();

  try {
    const variants = await API.getVariants(productId);
    renderVariantList(productId, variants);
  } catch (err) {
    wrap.innerHTML = `<div class="alert alert-error">${err.message}</div>`;
  }
}

function renderVariantList(productId, variants) {
  const wrap = document.getElementById('variant-list-wrap');
  if (!wrap) return;

  if (variants.length === 0) {
    wrap.innerHTML = `<p class="table-empty" style="padding:12px 0">No variants yet. This product is sold as a single item.</p>`;
    return;
  }

  wrap.innerHTML = `
    <table>
      <thead><tr><th>Image</th><th>Type</th><th>Value</th><th>Price +/-</th><th>Stock</th><th>AR</th><th></th></tr></thead>
      <tbody>
        ${variants.map(v => `
          <tr style="${v.is_archived ? 'opacity:.5' : ''}">
            <td>${v.image ? `<img class="thumb" src="${API.imgUrl(v.image)}" onerror="this.style.display='none'">` : `<div class="thumb"></div>`}</td>
            <td class="fw-600">${v.variant_type}</td>
            <td>${v.variant_value}</td>
            <td class="mono">${v.price_adjustment > 0 ? '+' : ''}${peso(v.price_adjustment)}</td>
            <td class="mono ${stockClass(v.stock)}">${v.stock}</td>
            <td>${v.ar_model ? '<span class="badge badge-in">Yes</span>' : '<span class="badge badge-default">No</span>'}</td>
            <td>
              <div class="actions-cell">
                ${v.is_archived
                  ? `<button class="btn btn-ghost btn-sm" onclick="restoreVariant(${productId}, ${v.id})">Restore</button>`
                  : `<button class="btn btn-ghost btn-sm" onclick="openVariantForm(${productId}, ${v.id})">Edit</button>
                     <button class="btn btn-ghost btn-sm" onclick="openArModal(${productId}, '${(v.variant_type + ' - ' + v.variant_value).replace(/'/g,"\\'")}', ${v.id})">AR</button>
                     <button class="btn btn-danger btn-sm" onclick="archiveVariant(${productId}, ${v.id})">Archive</button>`}
              </div>
            </td>
          </tr>`).join('')}
      </tbody>
    </table>`;
}

function openVariantForm(productId, variantId = null) {
  Modal.open({
    title: variantId ? 'Edit Variant' : 'Add Variant',
    body: `
      <div class="form-row">
        <div class="form-group">
          <label>Variant Type</label>
          <input type="text" id="v-type" placeholder="e.g. Color, Frame Size, Model Year" />
        </div>
        <div class="form-group">
          <label>Variant Value</label>
          <input type="text" id="v-value" placeholder="e.g. Red, Large, 2026" />
        </div>
      </div>
      <div class="form-row">
        <div class="form-group">
          <label>Price Adjustment (₱)</label>
          <input type="number" id="v-price" step="0.01" value="0" />
        </div>
        <div class="form-group">
          <label>Stock</label>
          <input type="number" id="v-stock" value="0" />
        </div>
      </div>

      <hr style="border-color:var(--border);margin:16px 0" />
      <p class="form-section-label">VARIANT IMAGE</p>
      <div class="form-group">
        <div id="v-upload-zone" style="border:2px dashed var(--border);border-radius:10px;padding:20px;text-align:center;cursor:pointer;position:relative"
             onclick="document.getElementById('v-image-file').click()"
             ondragover="event.preventDefault();this.style.borderColor='var(--accent)'"
             ondragleave="this.style.borderColor='var(--border)'"
             ondrop="handleVariantImageDrop(event)">
          <input type="file" id="v-image-file" accept="image/jpeg,image/png,image/webp,image/gif" style="display:none" onchange="handleVariantImageSelect(this)" />
          <div id="v-upload-placeholder">
            <p style="color:var(--muted);font-size:13px;margin:0"><strong style="color:var(--text)">Click to upload</strong> or drag & drop</p>
          </div>
          <div id="v-upload-preview" style="display:none">
            <img id="v-preview-img" style="max-height:120px;max-width:100%;border-radius:8px;object-fit:contain" />
          </div>
        </div>
        <input type="hidden" id="v-image-url" value="" />
      </div>

      <div id="variant-form-err"></div>`,
    footer: `
      <button class="btn btn-secondary" onclick="openCatProductForm(${productId})">Cancel</button>
      <button class="btn btn-primary" id="save-variant-btn">${variantId ? 'Update' : 'Add'} Variant</button>`,
  });

  if (variantId) {
    API.getVariant(variantId).then(v => {
      document.getElementById('v-type').value  = v.variant_type;
      document.getElementById('v-value').value = v.variant_value;
      document.getElementById('v-price').value = v.price_adjustment;
      document.getElementById('v-stock').value = v.stock;
      document.getElementById('v-image-url').value = v.image || '';
      if (v.image) {
        document.getElementById('v-upload-placeholder').style.display = 'none';
        document.getElementById('v-upload-preview').style.display = 'block';
        document.getElementById('v-preview-img').src = API.imgUrl(v.image);
      }
    }).catch(() => {});
  }

  document.getElementById('save-variant-btn').addEventListener('click', async () => {
    const btn   = document.getElementById('save-variant-btn');
    const errEl = document.getElementById('variant-form-err');

    const body = {
      variant_type:     document.getElementById('v-type').value.trim(),
      variant_value:    document.getElementById('v-value').value.trim(),
      price_adjustment: document.getElementById('v-price').value || 0,
      stock:             document.getElementById('v-stock').value || 0,
    };
    if (!body.variant_type || !body.variant_value) {
      errEl.innerHTML = `<div class="alert alert-error">Type and value are required.</div>`;
      return;
    }

    btn.disabled = true; btn.textContent = 'Saving…';

    try {
      let imageUrl = document.getElementById('v-image-url').value;
      const fileInput = document.getElementById('v-image-file');
      if (fileInput?.files?.length > 0) {
        imageUrl = await uploadProductImage(fileInput.files[0]);
      }
      body.image = imageUrl || null;

      if (variantId) await API.updateVariant(variantId, body);
      else            await API.createVariant(productId, body);
      toast(variantId ? 'Variant updated!' : 'Variant added!', 'success');
      openCatProductForm(productId);
    } catch (err) {
      errEl.innerHTML = `<div class="alert alert-error">${err.message}</div>`;
    } finally {
      btn.disabled = false; btn.textContent = `${variantId ? 'Update' : 'Add'} Variant`;
    }
  });
}

function handleVariantImageSelect(input) {
  const file = input.files[0];
  if (!file) return;
  showVariantImagePreview(file);
}

function handleVariantImageDrop(event) {
  event.preventDefault();
  document.getElementById('v-upload-zone').style.borderColor = 'var(--border)';
  const file = event.dataTransfer.files[0];
  if (!file || !file.type.startsWith('image/')) { toast('Please drop an image file.', 'error'); return; }
  document.getElementById('v-image-file').files = event.dataTransfer.files;
  showVariantImagePreview(file);
}

function showVariantImagePreview(file) {
  const reader = new FileReader();
  reader.onload = e => {
    document.getElementById('v-upload-placeholder').style.display = 'none';
    document.getElementById('v-upload-preview').style.display     = 'block';
    document.getElementById('v-preview-img').src = e.target.result;
  };
  reader.readAsDataURL(file);
}

async function archiveVariant(productId, variantId) {
  confirmDelete(`Archive this variant? It will be hidden from customers but can be restored anytime.`, async () => {
    try {
      await API.deleteVariant(variantId);
      toast('Variant archived.', 'success');
      loadVariantsForProduct(productId);
    } catch (err) { toast(err.message, 'error'); }
  }, { title: 'Archive Variant', buttonText: 'Archive' });
}

async function restoreVariant(productId, variantId) {
  try {
    await API.restoreVariant(variantId);
    toast('Variant restored.', 'success');
    loadVariantsForProduct(productId);
  } catch (err) { toast(err.message, 'error'); }
}

// ══════════════════════════════════════════════════════════════════════════
// AR MODEL MODAL — shared by products and variants
// ══════════════════════════════════════════════════════════════════════════

async function openArModal(productId, label, variantId = null) {
  const goBack = () => {
    if (variantId && productId) openCatProductForm(productId);
    else Modal.close();
  };

  Modal.open({ title: `AR Model — ${label}`, body: spinner() });

  try {
    const model = variantId
      ? await API.getVariantARModel(variantId).catch(() => null)
      : await API.getARModel(productId).catch(() => null);

    document.getElementById('modal-body').innerHTML = `
      <p class="text-muted" style="font-size:12px;margin-bottom:14px">
        Paste the hosted .glb file URL or path for this ${variantId ? 'variant' : 'product'}.
        Use real-world scale (1.0 = true size) for accurate AR placement.
      </p>
      <div class="form-group">
        <label>.glb Model URL / Path</label>
        <input type="text" id="ar-model-file" placeholder="uploads/models/bike.glb" value="${model?.model_file || ''}" />
      </div>
      <div class="form-group">
        <label>Scale</label>
        <input type="number" id="ar-model-scale" step="0.01" value="${model?.scale ?? 1.0}" />
      </div>
      ${model ? `<p class="text-muted" style="font-size:11px">A model is already assigned — saving will replace it.</p>` : ''}
      <div id="ar-modal-err"></div>`;

    document.getElementById('modal-footer').innerHTML = `
      <button class="btn btn-secondary" id="ar-cancel-btn">${variantId && productId ? 'Back' : 'Cancel'}</button>
      ${model ? `<button class="btn btn-danger" id="ar-delete-btn">Remove</button>` : ''}
      <button class="btn btn-primary" id="ar-save-btn">${model ? 'Update' : 'Save'}</button>`;

    document.getElementById('ar-cancel-btn').addEventListener('click', goBack);

    document.getElementById('ar-save-btn').addEventListener('click', async () => {
      const modelFile = document.getElementById('ar-model-file').value.trim();
      const scale     = document.getElementById('ar-model-scale').value || 1.0;
      const errEl     = document.getElementById('ar-modal-err');

      if (!modelFile) {
        errEl.innerHTML = `<div class="alert alert-error">Model URL/path is required.</div>`;
        return;
      }

      try {
        if (variantId) await API.saveVariantARModel(variantId, { model_file: modelFile, scale });
        else            await API.saveARModel(productId, { model_file: modelFile, scale });
        toast('AR model saved!', 'success');
        goBack();
      } catch (err) {
        errEl.innerHTML = `<div class="alert alert-error">${err.message}</div>`;
      }
    });

    document.getElementById('ar-delete-btn')?.addEventListener('click', () => {
      confirmDelete(`Remove the AR model for this ${variantId ? 'variant' : 'product'}?`, async () => {
        try {
          await API.deleteARModel(model.id);
          toast('AR model removed.', 'success');
        } catch (err) { toast(err.message, 'error'); }
      }, { title: 'Remove AR Model', buttonText: 'Remove' });
    });
  } catch (err) {
    document.getElementById('modal-body').innerHTML = `<div class="alert alert-error">${err.message}</div>`;
  }
}