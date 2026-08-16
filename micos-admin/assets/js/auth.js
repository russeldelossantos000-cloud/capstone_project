/**
 * auth.js — JWT token + session management
 */
const Auth = (() => {
  const TOKEN_KEY = 'admin_token';
  const ADMIN_KEY = 'admin_info';

  function save(token, admin) {
    localStorage.setItem(TOKEN_KEY, token);
    localStorage.setItem(ADMIN_KEY, JSON.stringify(admin));
  }

  function clear() {
    localStorage.removeItem(TOKEN_KEY);
    localStorage.removeItem(ADMIN_KEY);
  }

  function isLoggedIn() {
    const token = localStorage.getItem(TOKEN_KEY);
    if (!token) return false;
    try {
      const payload = JSON.parse(atob(token.split('.')[1]));
      return payload.exp > Math.floor(Date.now() / 1000);
    } catch {
      return false;
    }
  }

  function getAdmin() {
    try { return JSON.parse(localStorage.getItem(ADMIN_KEY)); } catch { return null; }
  }

  return { save, clear, isLoggedIn, getAdmin };
})();
