// ═══════════════════════════════════════════════
//  KC-COINWASH - ADMIN.JS (Admin Tablet)
// ═══════════════════════════════════════════════

let adminWashers   = [];
let adminConfig    = {};
let adminRiskLevel = 1;

// ─── OPEN ADMIN TABLET ────────────────────────────────────────────────────────
function openAdminUI(washers, config) {
    adminWashers   = washers || [];
    adminConfig    = config  || {};
    adminRiskLevel = config.riskLevel || 1;

    document.getElementById('admin-ui').classList.remove('hidden');

    // Set sliders
    setSlider('cfg-fee', 'cfg-fee-val', config.washFee || 15, v => v + '%');
    setSlider('cfg-dur', 'cfg-dur-val', config.washDuration || 30, v => v + 's');
    setSlider('cfg-max', 'cfg-max-val', config.maxWash || 50000, v => '$' + parseInt(v).toLocaleString());

    setAdminRisk(adminRiskLevel);
    renderWasherList();
    updateAdminStats();

    // Bind slider events
    bindSlider('cfg-fee', 'cfg-fee-val', v => v + '%');
    bindSlider('cfg-dur', 'cfg-dur-val', v => v + 's');
    bindSlider('cfg-max', 'cfg-max-val', v => '$' + parseInt(v).toLocaleString());
}

function closeAdmin() {
    document.getElementById('admin-ui').classList.add('hidden');
    fetch('https://KC-Coinwash/closeAdmin', { method: 'POST', body: JSON.stringify({}) });
}

// ─── SLIDERS ─────────────────────────────────────────────────────────────────
function setSlider(id, valId, value, fmt) {
    const el = document.getElementById(id);
    if (el) el.value = value;
    const vEl = document.getElementById(valId);
    if (vEl) vEl.textContent = fmt(value);
}

function bindSlider(id, valId, fmt) {
    const el = document.getElementById(id);
    const vEl = document.getElementById(valId);
    if (!el || !vEl) return;
    el.addEventListener('input', () => { vEl.textContent = fmt(el.value); });
}

// ─── RISK ─────────────────────────────────────────────────────────────────────
function setRisk(level) {
    adminRiskLevel = level;
    document.querySelectorAll('.risk-btn').forEach(b => {
        b.classList.toggle('active', parseInt(b.dataset.risk) === level);
    });
}

function setAdminRisk(level) {
    adminRiskLevel = level;
    document.querySelectorAll('.risk-btn').forEach(b => {
        b.classList.toggle('active', parseInt(b.dataset.risk) === level);
    });
}

// ─── PUSH CONFIG ──────────────────────────────────────────────────────────────
function pushConfig() {
    const payload = {
        washFee:      parseInt(document.getElementById('cfg-fee').value),
        washDuration: parseInt(document.getElementById('cfg-dur').value),
        maxWash:      parseInt(document.getElementById('cfg-max').value),
        riskLevel:    adminRiskLevel,
    };
    fetch('https://KC-Coinwash/updateConfig', { method: 'POST', body: JSON.stringify(payload) });
    document.getElementById('stat-fee').textContent = payload.washFee + '%';
}

// ─── PLACE WASHER ─────────────────────────────────────────────────────────────
function placeWasher() {
    const label = document.getElementById('new-washer-label').value.trim() || 'Washing Machine';
    fetch('https://KC-Coinwash/placeWasher', { method: 'POST', body: JSON.stringify({ label }) });
    document.getElementById('new-washer-label').value = '';
    // Server will sync back; refresh list after delay
    setTimeout(() => {
        closeAdmin();
    }, 500);
}

// ─── REMOVE WASHER ────────────────────────────────────────────────────────────
function removeWasher(id) {
    fetch('https://KC-Coinwash/removeWasher', { method: 'POST', body: JSON.stringify({ id }) });
    adminWashers = adminWashers.filter(w => w.id !== id);
    renderWasherList();
    updateAdminStats();
}

// ─── TP TO WASHER ─────────────────────────────────────────────────────────────
function tpToWasher(coords) {
    fetch('https://KC-Coinwash/tpToWasher', { method: 'POST', body: JSON.stringify({ coords }) });
}

// ─── RENDER WASHER LIST ───────────────────────────────────────────────────────
function renderWasherList() {
    const list = document.getElementById('washer-list');
    if (!adminWashers.length) {
        list.innerHTML = '<div class="empty-state">No washers deployed. Place one at your position.</div>';
        return;
    }

    list.innerHTML = adminWashers.map(w => {
        const c = w.coords;
        const coordStr = c
            ? `${c.x.toFixed(1)}, ${c.y.toFixed(1)}, ${c.z.toFixed(1)}`
            : 'Unknown';
        return `
        <div class="washer-card">
            <div class="washer-dot"></div>
            <div class="washer-info">
                <div class="washer-name">${escHtml(w.label || 'Washer')}</div>
                <div class="washer-coords">${coordStr} · hdg: ${(w.heading || 0).toFixed(0)}°</div>
            </div>
            <span class="washer-id-badge">#${w.id}</span>
            <div class="washer-actions">
                <button class="wbtn" onclick='tpToWasher(${JSON.stringify(w.coords)})'>TP</button>
                <button class="wbtn red" onclick="removeWasher(${w.id})">DEL</button>
            </div>
        </div>`;
    }).join('');
}

function updateAdminStats() {
    document.getElementById('stat-spots').textContent = adminWashers.length;
    const fee = parseInt(document.getElementById('cfg-fee')?.value || adminConfig.washFee || 15);
    document.getElementById('stat-fee').textContent = fee + '%';
}

function escHtml(str) {
    return String(str)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;');
}

// ─── SYNC UPDATE (server pushes new washer list after place/remove) ───────────
window.addEventListener('message', (e) => {
    const d = e.data;
    if (!d) return;
    if (d.action === 'syncWashers' && document.getElementById('admin-ui') &&
        !document.getElementById('admin-ui').classList.contains('hidden')) {
        adminWashers = d.washers || [];
        renderWasherList();
        updateAdminStats();
    }
});
