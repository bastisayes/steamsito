const express = require('express');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const app = express();
const PORT = process.env.PORT || 8768;
const DATA_FILE = path.join(__dirname, 'codes.json');

// Ensure data file exists
if (!fs.existsSync(DATA_FILE)) {
    fs.writeFileSync(DATA_FILE, JSON.stringify({ codes: {}, redemptions: [] }));
}

function loadData() {
    try {
        return JSON.parse(fs.readFileSync(DATA_FILE, 'utf8'));
    } catch { return { codes: {}, redemptions: [] }; }
}

function saveData(d) {
    fs.writeFileSync(DATA_FILE, JSON.stringify(d, null, 2));
}

app.use(express.json());

// Serve admin HTML
app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'index.html'));
});

// List all codes
app.get('/api/codes', (req, res) => {
    const d = loadData();
    res.json({ ok: true, codes: d.codes });
});

// Create code
app.post('/api/create-code', (req, res) => {
    const d = loadData();
    let code = (req.body.code || '').toUpperCase().trim();
    if (!code || code.length < 8) {
        // Auto-generate
        const r = () => crypto.randomBytes(3).toString('hex').toUpperCase();
        code = `${r()}-${r()}-${r()}-${r()}`;
    }
    if (d.codes[code]) {
        return res.json({ ok: false, err: `El codigo '${code}' ya existe` });
    }
    d.codes[code] = {
        links: req.body.links || [],
        max_uses: parseInt(req.body.max_uses) || 1,
        duration: parseInt(req.body.duration) || 0,
        used_count: 0,
        redeemed_by: [],
        pinned: false
    };
    saveData(d);
    console.log(`[CREATED] ${code} (${d.codes[code].links.length} links, ${d.codes[code].max_uses} uses)`);
    res.json({ ok: true });
});

// Redeem code
app.post('/api/redeem-code', (req, res) => {
    const d = loadData();
    const code = (req.body.code || '').toUpperCase().trim();
    const cid = req.body.client_id || '';
    const info = d.codes[code];
    if (!info) {
        return res.json({ ok: false, err: 'Codigo invalido o no existe' });
    }
    if (info.used_count >= info.max_uses) {
        return res.json({ ok: false, err: `Codigo agotado (${info.used_count}/${info.max_uses} usos)` });
    }
    info.used_count++;
    if (cid && !info.redeemed_by.includes(cid)) {
        info.redeemed_by.push(cid);
    }
    saveData(d);
    console.log(`[REDEEMED] ${code} by ${cid} (${info.used_count}/${info.max_uses})`);
    res.json({ ok: true, links: info.links, duration: info.duration });
});

// Delete code
app.post('/api/delete-code', (req, res) => {
    const d = loadData();
    const code = (req.body.code || '').toUpperCase().trim();
    if (d.codes[code]) {
        delete d.codes[code];
        saveData(d);
        console.log(`[DELETED] ${code}`);
        res.json({ ok: true });
    } else {
        res.json({ ok: false, err: 'Codigo no encontrado' });
    }
});

// Toggle pin
app.post('/api/pin-code', (req, res) => {
    const d = loadData();
    const code = (req.body.code || '').toUpperCase().trim();
    const info = d.codes[code];
    if (info) {
        info.pinned = !info.pinned;
        saveData(d);
        console.log(`[${info.pinned ? 'PINNED' : 'UNPINNED'}] ${code}`);
        res.json({ ok: true, pinned: info.pinned });
    } else {
        res.json({ ok: false, err: 'Codigo no encontrado' });
    }
});

// Renew code (reset usage)
app.post('/api/renew-code', (req, res) => {
    const d = loadData();
    const code = (req.body.code || '').toUpperCase().trim();
    const info = d.codes[code];
    if (info) {
        info.used_count = 0;
        info.redeemed_by = [];
        saveData(d);
        console.log(`[RENEWED] ${code}`);
        res.json({ ok: true });
    } else {
        res.json({ ok: false, err: 'Codigo no encontrado' });
    }
});

// Remove redeemed client from code
app.post('/api/remove-redeemed', (req, res) => {
    const d = loadData();
    const code = (req.body.code || '').toUpperCase().trim();
    const cid = req.body.client_id || '';
    const info = d.codes[code];
    if (info) {
        if (info.redeemed_by.includes(cid)) {
            info.redeemed_by = info.redeemed_by.filter(id => id !== cid);
            if (info.used_count > 0) info.used_count--;
            saveData(d);
            console.log(`[REMOVED] ${cid} from ${code}`);
            res.json({ ok: true });
        } else {
            res.json({ ok: false, err: 'Esa PC no canjeo este codigo' });
        }
    } else {
        res.json({ ok: false, err: 'Codigo no encontrado' });
    }
});

app.listen(PORT, () => {
    console.log(`Server running on http://localhost:${PORT}`);
});
