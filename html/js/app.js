// ═══════════════════════════════════════════════
//  KC-COINWASH - APP.JS (Player Wash UI + Overlay)
// ═══════════════════════════════════════════════

let currentWasher  = null;
let currentConfig  = {};
let selectedRisk   = 1;
let washTimer      = null;
let overlayTimer   = null;
const riskCuts     = { 1: 0, 2: 3, 3: 8 };

// ─── NUI MESSAGE HANDLER ──────────────────────────────────────────────────────
window.addEventListener('message', (e) => {
    const d = e.data;
    if (!d || !d.action) return;

    switch (d.action) {
        case 'openWash':
            openWashUI(d.washer, d.config);
            break;
        case 'openAdmin':
            openAdminUI(d.washers, d.config);
            break;
        case 'washStarted':
            startOverlay(d.data);
            break;
        case 'washComplete':
            onWashComplete(d.cleanAmt);
            break;
        case 'washCancelled':
            hideOverlay();
            break;
        case 'hideOverlay':
            hideOverlay();
            break;
        case 'escape':
            closeWash();
            closeAdmin();
            break;
    }
});

// ─── PLAYER WASH UI ───────────────────────────────────────────────────────────
function openWashUI(washer, config) {
    currentWasher = washer;
    currentConfig = config;
    selectedRisk  = config.riskLevel || 1;

    document.getElementById('wash-ui').classList.remove('hidden');
    document.getElementById('wash-location-label').textContent = washer.label || 'Washing Machine';
    document.getElementById('max-label').textContent = '$' + (config.maxWash || 50000).toLocaleString();
    document.getElementById('bd-fee-pct').textContent = config.washFee || 15;

    selectRisk(selectedRisk, true);
    updateBreakdown();
}

function closeWash() {
    document.getElementById('wash-ui').classList.add('hidden');
    fetch('https://KC-Coinwash/closeWash', { method: 'POST', body: JSON.stringify({}) });
}

function setMaxAmount() {
    const max = currentConfig.maxWash || 50000;
    document.getElementById('wash-amount').value = max;
    updateBreakdown();
}

function selectRisk(level, silent) {
    selectedRisk = level;
    document.querySelectorAll('.risk-option').forEach(el => {
        el.classList.toggle('active', parseInt(el.dataset.risk) === level);
    });
    document.getElementById('bd-risk-pct').textContent = riskCuts[level] || 0;
    if (!silent) updateBreakdown();
}

document.getElementById('wash-amount').addEventListener('input', updateBreakdown);

function updateBreakdown() {
    const dirty   = parseFloat(document.getElementById('wash-amount').value) || 0;
    const fee     = currentConfig.washFee || 15;
    const risk    = riskCuts[selectedRisk] || 0;
    const feeDed  = Math.floor(dirty * fee / 100);
    const riskDed = Math.floor(dirty * risk / 100);
    const clean   = dirty - feeDed - riskDed;

    document.getElementById('bd-dirty').textContent = dirty > 0 ? '$' + Math.floor(dirty).toLocaleString() : '—';
    document.getElementById('bd-fee').textContent   = dirty > 0 ? '-$' + feeDed.toLocaleString() : '—';
    document.getElementById('bd-risk').textContent  = dirty > 0 ? '-$' + riskDed.toLocaleString() : '—';
    document.getElementById('bd-clean').textContent = dirty > 0 ? '$' + Math.max(0, clean).toLocaleString() : '—';
}

function submitWash() {
    const amount = parseFloat(document.getElementById('wash-amount').value);
    if (!amount || amount <= 0 || !currentWasher) return;

    fetch('https://KC-Coinwash/startWash', {
        method: 'POST',
        body: JSON.stringify({
            washerId:  currentWasher.id,
            amount:    Math.floor(amount),
            riskLevel: selectedRisk,
        })
    });

    document.getElementById('wash-ui').classList.add('hidden');
}

// ─── WASH PROGRESS OVERLAY ────────────────────────────────────────────────────
function startOverlay(data) {
    clearInterval(overlayTimer);

    const { amount, cleanAmt, duration } = data;
    const startTime = Date.now();
    const endTime   = startTime + duration * 1000;

    document.getElementById('wash-overlay').classList.remove('hidden');
    document.getElementById('overlay-amount').textContent =
        '$' + amount.toLocaleString() + ' → $' + cleanAmt.toLocaleString();

    overlayTimer = setInterval(() => {
        const now     = Date.now();
        const elapsed = now - startTime;
        const total   = duration * 1000;
        const pct     = Math.min(100, Math.floor(elapsed / total * 100));
        const remSec  = Math.max(0, Math.ceil((endTime - now) / 1000));

        document.getElementById('overlay-bar').style.width = pct + '%';
        document.getElementById('overlay-pct').textContent = pct + '%';
        document.getElementById('overlay-timer').textContent = remSec + 's remaining';

        if (pct >= 100) clearInterval(overlayTimer);
    }, 200);
}

function hideOverlay() {
    clearInterval(overlayTimer);
    document.getElementById('overlay-bar').style.width = '0%';
    document.getElementById('overlay-pct').textContent = '0%';
    document.getElementById('wash-overlay').classList.add('hidden');
}

function onWashComplete(cleanAmt) {
    hideOverlay();
    showToast('$' + cleanAmt.toLocaleString() + ' clean ' + (currentConfig.payMethod === 'bank' ? 'banked' : 'in hand'));
}

// ─── TOAST ────────────────────────────────────────────────────────────────────
function showToast(msg) {
    const toast = document.getElementById('wash-toast');
    document.getElementById('toast-sub').textContent = msg;
    toast.classList.remove('hidden');
    clearTimeout(washTimer);
    washTimer = setTimeout(() => toast.classList.add('hidden'), 4000);
}
