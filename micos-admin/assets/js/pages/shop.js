/**
 * pages/shop.js
 */
async function pageShop(container) {
  container.innerHTML = `
    <div class="page-header">
      <div class="page-header-left"><h2>Shop Info</h2><p>Your store's public details</p></div>
    </div>
    <div class="page-body">
      <div class="table-card" style="max-width:560px;padding:28px">
        <div id="shop-form">${spinner()}</div>
      </div>
    </div>`;

  try {
    const shop = await API.getShop();
    document.getElementById('shop-form').innerHTML = `
      <div class="form-group"><label>Shop Name</label><input type="text" id="s-name" value="${shop.name || ''}" /></div>
      <div class="form-group"><label>Address</label><textarea id="s-address">${shop.address || ''}</textarea></div>
      <div class="form-row">
        <div class="form-group"><label>Contact Number</label><input type="text" id="s-phone" value="${shop.contact_number || ''}" /></div>
        <div class="form-group"><label>Email</label><input type="email" id="s-email" value="${shop.email || ''}" /></div>
      </div>
      <div id="shop-err"></div>
      <button class="btn btn-primary" id="save-shop-btn" style="margin-top:8px">Save Changes</button>`;

    document.getElementById('save-shop-btn').addEventListener('click', async () => {
      const body = {
        name:           document.getElementById('s-name').value.trim(),
        address:        document.getElementById('s-address').value.trim(),
        contact_number: document.getElementById('s-phone').value.trim(),
        email:          document.getElementById('s-email').value.trim(),
      };
      try {
        await API.updateShop(body);
        toast('Shop info saved!', 'success');
      } catch (err) {
        document.getElementById('shop-err').innerHTML = `<div class="alert alert-error">${err.message}</div>`;
      }
    });
  } catch (err) {
    document.getElementById('shop-form').innerHTML = `<div class="alert alert-error">${err.message}</div>`;
  }
}
