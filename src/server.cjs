// src/server.cjs
// Ticimax API → Flutter Mobile App köprüsü
// Başlatmak için: node src/server.cjs

require("dotenv").config({ path: require("path").resolve(__dirname, "../.env") });

const express = require("express");
const fs = require("fs");
const path = require("path");
const multer = require("multer");

const api = require("./lib/ticimax-api.cjs");
const PORT = process.env.SERVER_PORT ?? 3099;

const app = express();
app.use(express.json());

// Multer setup for file uploads
const upload = multer({
    dest: path.resolve(__dirname, "../data/temp/"),
    limits: { fileSize: 50 * 1024 * 1024 } // 50MB limit
});

// Flutter'dan gelen isteklere CORS izni
app.use((req, res, next) => {
    res.setHeader("Access-Control-Allow-Origin", "*");
    res.setHeader("Access-Control-Allow-Headers", "Content-Type");
    res.setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
    if (req.method === "OPTIONS") return res.sendStatus(200);
    next();
});

// Bağlantı log klasörü
const PAYLOADS_DIR = path.resolve(__dirname, "../data/connect-payloads");
if (!fs.existsSync(PAYLOADS_DIR)) fs.mkdirSync(PAYLOADS_DIR, { recursive: true });

// ── LOGGER ────────────────────────────────────────────────

function log(method, path, status) {
    const ts = new Date().toISOString();
    console.log(`[${ts}] ${method.padEnd(6)} ${path} → ${status}`);
}

// ── ROUTES: Siparişler ────────────────────────────────────

// GET /orders?sayfa=1&sayfaBasina=20&durum=0
app.get("/orders", async (req, res) => {
    try {
        const data = await api.getOrders(req.query);
        log("GET", "/orders", 200);
        res.json({ ok: true, data });
    } catch (e) {
        log("GET", "/orders", 500);
        res.status(500).json({ ok: false, error: e.message });
    }
});

// GET /orders/:id
app.get("/orders/:id", async (req, res) => {
    try {
        const data = await api.getOrderDetail(req.params.id);
        log("GET", `/orders/${req.params.id}`, 200);
        res.json({ ok: true, data });
    } catch (e) {
        log("GET", `/orders/${req.params.id}`, 500);
        res.status(500).json({ ok: false, error: e.message });
    }
});

// ── ROUTES: Ürünler ───────────────────────────────────────

// GET /products?sayfa=1&sayfaBasina=20
app.get("/products", async (req, res) => {
    try {
        const data = await api.getProducts(req.query);
        log("GET", "/products", 200);
        res.json({ ok: true, data });
    } catch (e) {
        log("GET", "/products", 500);
        res.status(500).json({ ok: false, error: e.message });
    }
});

// ── ROUTES: Stok ─────────────────────────────────────────

// GET /stock/:sku
app.get("/stock/:sku", async (req, res) => {
    try {
        const data = await api.getStock(req.params.sku);
        log("GET", `/stock/${req.params.sku}`, 200);
        res.json({ ok: true, data });
    } catch (e) {
        log("GET", `/stock/${req.params.sku}`, 500);
        res.status(500).json({ ok: false, error: e.message });
    }
});

// POST /stock/:sku  { miktar: 5 }
app.post("/stock/:sku", async (req, res) => {
    try {
        const { miktar } = req.body;
        const data = await api.updateStock(req.params.sku, miktar);
        log("POST", `/stock/${req.params.sku}`, 200);
        res.json({ ok: true, data });
    } catch (e) {
        log("POST", `/stock/${req.params.sku}`, 500);
        res.status(500).json({ ok: false, error: e.message });
    }
});

// ── ROUTES: Connect Webhook ───────────────────────────────

// POST /connect-webhook
// Ticimax Connect → bu endpoint'e payload gönderir → JSON olarak kaydeder
app.post("/connect-webhook", (req, res) => {
    const payload = req.body;
    const ts = Date.now();
    const action = String(payload?.action ?? payload?.eylem ?? "unknown")
        .replace(/[^a-zA-Z0-9_-]/g, "_");
    const fname = `${action}_${ts}.json`;
    const fpath = path.join(PAYLOADS_DIR, fname);

    fs.writeFileSync(fpath, JSON.stringify(payload, null, 2), "utf8");
    log("POST", "/connect-webhook", 200);
    console.log(`   💾 Payload kaydedildi: ${fname}`);
    res.json({ ok: true, saved: fname });
});

// GET /connect-payloads  → kaydedilen payload listesi
app.get("/connect-payloads", (req, res) => {
    try {
        const files = fs.readdirSync(PAYLOADS_DIR)
            .filter(f => f.endsWith(".json"))
            .sort()
            .reverse()
            .slice(0, 100)
            .map(f => {
                const content = JSON.parse(
                    fs.readFileSync(path.join(PAYLOADS_DIR, f), "utf8")
                );
                return { file: f, payload: content };
            });
        log("GET", "/connect-payloads", 200);
        res.json({ ok: true, count: files.length, data: files });
    } catch (e) {
        res.status(500).json({ ok: false, error: e.message });
    }
});

// ── ROUTES: Scripts ──────────────────────────────────────

// POST /upload-excel → Excel dosyasını yükle
app.post("/upload-excel", upload.single("file"), (req, res) => {
    try {
        if (!req.file) {
            return res.status(400).json({ ok: false, error: "Dosya bulunamadı" });
        }

        const tempPath = req.file.path;
        const originalName = req.file.originalname || "file.xlsx";
        const ext = path.extname(originalName).toLowerCase();

        // .xls veya .xlsx kabul et
        if (ext !== ".xls" && ext !== ".xlsx") {
            fs.unlinkSync(tempPath);
            return res.status(400).json({ ok: false, error: "Sadece .xls veya .xlsx dosyaları kabul edilir" });
        }

        const targetPath = path.resolve(__dirname, "../data/site_products.xlsx");

        // Mevcut dosya varsa yedekle
        if (fs.existsSync(targetPath)) {
            const timestamp = new Date().toISOString().replace(/[:.]/g, "-");
            const backupPath = path.resolve(__dirname, `../data/backups/site_products_${timestamp}.xlsx`);

            const backupDir = path.dirname(backupPath);
            if (!fs.existsSync(backupDir)) {
                fs.mkdirSync(backupDir, { recursive: true });
            }

            fs.copyFileSync(targetPath, backupPath);
            console.log(`💾 Eski dosya yedeklendi: ${path.basename(backupPath)}`);
        }

        // Temp dosyayı hedef konuma taşı (her zaman .xlsx olarak kaydet)
        fs.renameSync(tempPath, targetPath);

        log("POST", "/upload-excel", 200);
        console.log(`📤 Excel yüklendi: site_products.xlsx (orijinal: ${originalName})`);

        res.json({ ok: true, message: "Dosya başarıyla yüklendi" });
    } catch (e) {
        log("POST", "/upload-excel", 500);
        console.error(`❌ Upload hatası: ${e.message}`);
        res.status(500).json({ ok: false, error: e.message });
    }
});

// GET /scripts  → mevcut scriptleri listele
app.get("/scripts", (req, res) => {
    try {
        const scriptsDir = path.resolve(__dirname, ".");
        const scripts = fs.readdirSync(scriptsDir)
            .filter(f => f.endsWith(".cjs") && f !== "server.cjs")
            .map(f => ({
                name: f.replace(".cjs", ""),
                file: f,
                path: path.join(scriptsDir, f)
            }))
            .sort((a, b) => a.name.localeCompare(b.name));

        log("GET", "/scripts", 200);
        res.json({ ok: true, scripts });
    } catch (e) {
        log("GET", "/scripts", 500);
        res.status(500).json({ ok: false, error: e.message });
    }
});

// POST /scripts/:name/run  → script'i çalıştır
app.post("/scripts/:name/run", async (req, res) => {
    const { name } = req.params;
    const { spawn } = require("child_process");
    let proc = null;
    let timeoutHandle = null;
    let responseSent = false;

    const sendResponse = (statusCode, body) => {
        if (responseSent) return;
        responseSent = true;

        if (statusCode === 200) {
            res.json(body);
        } else {
            res.status(statusCode).json(body);
        }
    };

    try {
        const scriptPath = path.resolve(__dirname, `${name}.cjs`);

        // Güvenlik: sadece src/ klasöründe olan scriptleri çalıştır
        if (!scriptPath.startsWith(path.resolve(__dirname))) {
            throw new Error("Invalid script path");
        }

        if (!fs.existsSync(scriptPath)) {
            throw new Error(`Script not found: ${name}`);
        }

        let output = "";
        let error = "";
        const startTime = Date.now();

        console.log(`\n▶️  Script başlatıldı: ${name}`);

        proc = spawn("node", [scriptPath], {
            cwd: path.resolve(__dirname, ".."),
            env: { ...process.env },
            stdio: ["ignore", "pipe", "pipe"]
        });

        proc.stdout.on("data", (data) => {
            const chunk = data.toString();
            output += chunk;
            process.stdout.write(chunk);
        });

        proc.stderr.on("data", (data) => {
            const chunk = data.toString();
            error += chunk;
            process.stderr.write(chunk);
        });

        proc.on("close", (code) => {
            clearTimeout(timeoutHandle);
            const duration = ((Date.now() - startTime) / 1000).toFixed(2);

            if (code === 0) {
                log("POST", `/scripts/${name}/run`, 200);
                console.log(`✅ Script tamamlandı: ${name} (${duration}s)\n`);
            } else {
                log("POST", `/scripts/${name}/run`, 500);
                console.log(`❌ Script hata ile sonlandı: ${name} (code: ${code}, ${duration}s)\n`);
            }

            sendResponse(code === 0 ? 200 : 500, {
                ok: code === 0,
                code,
                output: output.trim(),
                error: error.trim() || null,
                duration: parseFloat(duration)
            });
        });

        proc.on("error", (err) => {
            clearTimeout(timeoutHandle);
            log("POST", `/scripts/${name}/run`, 500);
            console.error(`❌ Script process error: ${err.message}\n`);

            sendResponse(500, {
                ok: false,
                error: err.message,
                code: -1
            });
        });

        // Timeout: 5 dakika
        timeoutHandle = setTimeout(() => {
            if (proc && !proc.killed) {
                proc.kill("SIGTERM");
                setTimeout(() => {
                    if (proc && !proc.killed) {
                        proc.kill("SIGKILL");
                    }
                }, 2000);
            }

            log("POST", `/scripts/${name}/run`, 408);
            console.error(`⏱️  Script timeout: ${name}\n`);

            sendResponse(408, {
                ok: false,
                error: "Script execution timeout (5 minutes)",
                code: -1,
                output: output.trim(),
                partialError: error.trim() || null
            });
        }, 5 * 60 * 1000);

    } catch (e) {
        clearTimeout(timeoutHandle);
        if (proc && !proc.killed) {
            proc.kill();
        }

        log("POST", `/scripts/${name}/run`, 500);
        console.error(`❌ Script error: ${e.message}\n`);

        sendResponse(500, {
            ok: false,
            error: e.message,
            code: -1
        });
    }
});

// ── HEALTH ────────────────────────────────────────────────

app.get("/health", (req, res) => {
    res.json({ ok: true, ts: new Date().toISOString() });
});

// ── START ─────────────────────────────────────────────────

app.listen(PORT, () => {
    console.log("─────────────────────────────────────");
    console.log(`🚀 Ticimax API Server başladı: http://localhost:${PORT}`);
    console.log("─────────────────────────────────────");
    console.log(`📦 GET  /products`);
    console.log(`📦 GET  /orders`);
    console.log(`📦 GET  /stock/:sku`);
    console.log(`📦 POST /stock/:sku`);
    console.log(`🔗 POST /connect-webhook   ← Ticimax Connect endpoint`);
    console.log(`🔗 GET  /connect-payloads  ← Flutter payload görüntüleyici`);
    console.log("─────────────────────────────────────");
});
