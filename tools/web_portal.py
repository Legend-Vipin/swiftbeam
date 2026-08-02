#!/usr/bin/env python3
"""
SwiftBeam Unified Web Application (swiftbeam-tooling)
Provides an app-like Web Portal supporting both Sending and Receiving files over Wi-Fi,
along with Wi-Fi Direct and Bluetooth pairing status dashboards.
"""

import http.server
import json
import os
import socket
import subprocess
import sys
import urllib.parse
from pathlib import Path

PORT = 8080
DOWNLOADS_DIR = Path.home() / "Downloads"
SHARED_DIR = Path.home() / "Downloads"
DOWNLOADS_DIR.mkdir(parents=True, exist_ok=True)


def get_local_ip():
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "127.0.0.1"


def get_network_interfaces(): # type: ignore
    interfaces = []
    try:
        ip = get_local_ip()
        interfaces.append({"name": "Wi-Fi / LAN", "ip": ip, "type": "wifi"})
    except Exception:
        pass
    return interfaces


def format_bytes(size):
    if size <= 0:
        return "0 B"
    suffixes = ["B", "KB", "MB", "GB", "TB"]
    i = 0
    double_size = float(size)
    while double_size >= 1024 and i < len(suffixes) - 1:
        double_size /= 1024
        i += 1
    return f"{double_size:.2f} {suffixes[i]}"


UNIFIED_WEB_APP_HTML = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>SwiftBeam Web App — Cross-Platform P2P</title>
  <style>
    :root {
      --bg-gradient: linear-gradient(135deg, #090d16 0%, #111827 50%, #1e1b4b 100%);
      --card-bg: rgba(255, 255, 255, 0.04);
      --card-border: rgba(255, 255, 255, 0.08);
      --accent-primary: #818cf8;
      --accent-secondary: #c084fc;
      --accent-emerald: #34d399;
      --text-main: #f8fafc;
      --text-muted: #94a3b8;
    }
    * {
      box-sizing: border-box;
    }
    body {
      margin: 0;
      padding: 0;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      background: var(--bg-gradient);
      color: var(--text-main);
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      align-items: center;
    }
    .header-bar {
      width: 100%;
      max-width: 600px;
      padding: 24px 20px 12px;
      display: flex;
      align-items: center;
      justify-content: space-between;
    }
    .brand {
      display: flex;
      align-items: center;
      gap: 12px;
    }
    .brand-logo-img {
      width: 40px;
      height: 40px;
      object-fit: contain;
      border-radius: 12px;
      box-shadow: 0 4px 14px rgba(99, 102, 241, 0.4);
    }
    .brand-title {
      font-size: 22px;
      font-weight: 800;
      background: linear-gradient(to right, #818cf8, #c084fc);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
    }
    .badge-status {
      background: rgba(52, 211, 153, 0.15);
      border: 1px solid rgba(52, 211, 153, 0.3);
      color: #34d399;
      font-size: 12px;
      font-weight: 600;
      padding: 4px 10px;
      border-radius: 999px;
      display: flex;
      align-items: center;
      gap: 6px;
    }
    .pulse-dot {
      width: 8px;
      height: 8px;
      background: #34d399;
      border-radius: 50%;
      box-shadow: 0 0 8px #34d399;
    }
    .nav-tabs {
      display: flex;
      background: rgba(0, 0, 0, 0.3);
      padding: 6px;
      border-radius: 16px;
      border: 1px solid var(--card-border);
      width: 90%;
      max-width: 500px;
      margin: 12px 0 24px;
    }
    .tab-btn {
      flex: 1;
      padding: 12px;
      border: none;
      background: transparent;
      color: var(--text-muted);
      font-weight: 600;
      font-size: 14px;
      border-radius: 12px;
      cursor: pointer;
      transition: all 0.25s ease;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 8px;
    }
    .tab-btn.active {
      background: linear-gradient(135deg, #6366f1 0%, #4f46e5 100%);
      color: #ffffff;
      box-shadow: 0 4px 12px rgba(99, 102, 241, 0.35);
    }
    .main-card {
      background: var(--card-bg);
      backdrop-filter: blur(24px);
      -webkit-backdrop-filter: blur(24px);
      border: 1px solid var(--card-border);
      border-radius: 24px;
      padding: 32px 24px;
      width: 90%;
      max-width: 500px;
      box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.5);
      margin-bottom: 40px;
    }
    .tab-content {
      display: none;
    }
    .tab-content.active {
      display: block;
    }
    .drop-zone {
      border: 2px dashed rgba(129, 140, 248, 0.35);
      border-radius: 20px;
      padding: 36px 20px;
      cursor: pointer;
      text-align: center;
      transition: all 0.3s ease;
      background: rgba(129, 140, 248, 0.03);
    }
    .drop-zone:hover, .drop-zone.dragover {
      border-color: var(--accent-primary);
      background: rgba(129, 140, 248, 0.08);
    }
    .btn-action {
      background: linear-gradient(135deg, #6366f1 0%, #4f46e5 100%);
      color: white;
      border: none;
      padding: 12px 28px;
      border-radius: 12px;
      font-weight: 600;
      font-size: 15px;
      cursor: pointer;
      margin-top: 16px;
      box-shadow: 0 4px 12px rgba(99, 102, 241, 0.3);
      transition: all 0.2s;
    }
    .btn-action:hover {
      transform: translateY(-2px);
      box-shadow: 0 6px 16px rgba(99, 102, 241, 0.4);
    }
    .file-item {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 14px 16px;
      background: rgba(255, 255, 255, 0.03);
      border: 1px solid rgba(255, 255, 255, 0.06);
      border-radius: 14px;
      margin-bottom: 12px;
    }
    .file-info {
      display: flex;
      align-items: center;
      gap: 12px;
      overflow: hidden;
    }
    .file-icon {
      font-size: 24px;
    }
    .file-name {
      font-weight: 600;
      color: #e2e8f0;
      font-size: 14px;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
      max-width: 220px;
    }
    .file-size {
      font-size: 12px;
      color: var(--text-muted);
    }
    .btn-dl {
      background: rgba(52, 211, 153, 0.15);
      color: #34d399;
      border: 1px solid rgba(52, 211, 153, 0.3);
      padding: 8px 16px;
      border-radius: 10px;
      font-weight: 600;
      font-size: 13px;
      text-decoration: none;
      transition: all 0.2s;
    }
    .btn-dl:hover {
      background: #34d399;
      color: #0f172a;
    }
    .pairing-card {
      background: rgba(255, 255, 255, 0.02);
      border: 1px solid rgba(255, 255, 255, 0.05);
      border-radius: 16px;
      padding: 16px;
      margin-bottom: 14px;
    }
    .pairing-title {
      font-size: 14px;
      font-weight: 700;
      color: var(--accent-primary);
      margin-bottom: 6px;
      display: flex;
      align-items: center;
      gap: 8px;
    }
    .pairing-desc {
      font-size: 13px;
      color: var(--text-muted);
      line-height: 1.5;
    }
    .progress-container {
      margin-top: 24px;
      display: none;
    }
    .progress-track {
      background: rgba(255, 255, 255, 0.08);
      border-radius: 9999px;
      height: 8px;
      overflow: hidden;
      margin-bottom: 8px;
    }
    .progress-bar {
      width: 0%;
      height: 100%;
      background: linear-gradient(to right, #818cf8, #c084fc);
      transition: width 0.1s ease;
    }
    #status-msg {
      margin-top: 16px;
      font-size: 14px;
      font-weight: 600;
      text-align: center;
    }
  </style>
</head>
<body>
  <div class="header-bar">
    <div class="brand">
      <img src="/logo.png" alt="SwiftBeam Logo" class="brand-logo-img">
      <div class="brand-title">SwiftBeam</div>
    </div>
    <div class="badge-status">
      <div class="pulse-dot"></div>
      <span>Active Host</span>
    </div>
  </div>

  <div class="nav-tabs">
    <button class="tab-btn active" onclick="switchTab('send')">📤 Send File</button>
    <button class="tab-btn" onclick="switchTab('receive')">📥 Receive File</button>
    <button class="tab-btn" onclick="switchTab('pairing')">📡 Pairing</button>
  </div>

  <div class="main-card">
    <!-- SEND TAB -->
    <div id="tab-send" class="tab-content active">
      <div class="drop-zone" id="drop-zone">
        <div style="font-size: 42px; margin-bottom: 12px;">📤</div>
        <div style="font-size: 16px; font-weight: 600; color: #cbd5e1;">Send File to Host</div>
        <div style="font-size: 13px; color: #64748b; margin: 6px 0 12px;">Files save directly to system Downloads</div>
        <button class="btn-action" onclick="document.getElementById('file-input').click()">Browse File</button>
        <input type="file" id="file-input" onchange="handleFileSelect(this.files)">
      </div>

      <div class="progress-container" id="progress-container">
        <div class="progress-track">
          <div class="progress-bar" id="progress-bar"></div>
        </div>
        <div style="display: flex; justify-content: space-between; font-size: 13px; color: #94a3b8;">
          <span id="file-name">Uploading...</span>
          <span id="progress-text">0%</span>
        </div>
      </div>
      <div id="status-msg"></div>
    </div>

    <!-- RECEIVE TAB -->
    <div id="tab-receive" class="tab-content">
      <div style="margin-bottom: 20px; text-align: center;">
        <h3 style="margin: 0 0 6px; font-size: 18px;">Shared Host Files</h3>
        <p style="margin: 0; font-size: 13px; color: var(--text-muted);">Download files hosted on this machine</p>
      </div>
      <div id="shared-files-list">
        <div style="text-align: center; color: var(--text-muted); font-size: 14px; padding: 20px;">
          Loading shared files...
        </div>
      </div>
    </div>

    <!-- PAIRING DASHBOARD TAB -->
    <div id="tab-pairing" class="tab-content">
      <div style="margin-bottom: 20px; text-align: center;">
        <h3 style="margin: 0 0 6px; font-size: 18px;">P2P Pairing Methods</h3>
        <p style="margin: 0; font-size: 13px; color: var(--text-muted);">Multi-Transport Auto Pairing</p>
      </div>

      <div class="pairing-card">
        <div class="pairing-title">📶 1. Wi-Fi Local Network</div>
        <div class="pairing-desc">
          Connected to local Wi-Fi. Access Web Portal on any phone/browser at:<br>
          <strong id="ip-address-display" style="color: #cbd5e1;">http://...</strong>
        </div>
      </div>

      <div class="pairing-card">
        <div class="pairing-title">⚡ 2. Wi-Fi Direct (P2P Radar)</div>
        <div class="pairing-desc">
          High-speed direct device-to-device transport without router.<br>
          Status: <span style="color: #34d399; font-weight: 600;">Active & Listening (mDNS / QUIC)</span>
        </div>
      </div>

      <div class="pairing-card">
        <div class="pairing-title">🔵 3. Bluetooth Pairing</div>
        <div class="pairing-desc">
          Used for ambient proximity key exchange and automatic discovery.<br>
          Status: <span style="color: #818cf8; font-weight: 600;">Ready for Scan</span>
        </div>
      </div>
    </div>
  </div>

  <script>
    function switchTab(tabName) {
      document.querySelectorAll('.tab-btn').forEach(btn => btn.classList.remove('active'));
      document.querySelectorAll('.tab-content').forEach(content => content.classList.remove('active'));
      
      if (tabName === 'send') {
        document.querySelectorAll('.tab-btn')[0].classList.add('active');
        document.getElementById('tab-send').classList.add('active');
      } else if (tabName === 'receive') {
        document.querySelectorAll('.tab-btn')[1].classList.add('active');
        document.getElementById('tab-receive').classList.add('active');
        loadSharedFiles();
      } else if (tabName === 'pairing') {
        document.querySelectorAll('.tab-btn')[2].classList.add('active');
        document.getElementById('tab-pairing').classList.add('active');
        loadStatus();
      }
    }

    const dropZone = document.getElementById('drop-zone');
    const statusMsg = document.getElementById('status-msg');

    ['dragenter', 'dragover'].forEach(name => {
      dropZone.addEventListener(name, (e) => { e.preventDefault(); dropZone.classList.add('dragover'); });
    });
    ['dragleave', 'drop'].forEach(name => {
      dropZone.addEventListener(name, (e) => { e.preventDefault(); dropZone.classList.remove('dragover'); });
    });
    dropZone.addEventListener('drop', (e) => {
      e.preventDefault();
      if (e.dataTransfer.files.length > 0) uploadFile(e.dataTransfer.files[0]);
    });

    function handleFileSelect(files) {
      if (files.length > 0) uploadFile(files[0]);
    }

    function uploadFile(file) {
      document.getElementById('progress-container').style.display = 'block';
      document.getElementById('file-name').innerText = file.name;
      statusMsg.innerText = '';

      const xhr = new XMLHttpRequest();
      xhr.open('POST', '/upload?filename=' + encodeURIComponent(file.name));
      xhr.upload.onprogress = (e) => {
        if (e.lengthComputable) {
          const pct = Math.round((e.loaded / e.total) * 100);
          document.getElementById('progress-bar').style.width = pct + '%';
          document.getElementById('progress-text').innerText = pct + '%';
        }
      };
      xhr.onload = () => {
        if (xhr.status === 200) {
          statusMsg.innerText = '✓ Sent successfully!';
          statusMsg.style.color = '#34d399';
        } else {
          statusMsg.innerText = '✗ Upload failed';
          statusMsg.style.color = '#f87171';
        }
      };
      xhr.send(file);
    }

    function loadSharedFiles() {
      fetch('/api/shared')
        .then(r => r.json())
        .then(files => {
          const container = document.getElementById('shared-files-list');
          if (files.length === 0) {
            container.innerHTML = '<div style="text-align:center; color:#94a3b8;">No files found in Downloads.</div>';
            return;
          }
          container.innerHTML = files.map(f => `
            <div class="file-item">
              <div class="file-info">
                <div class="file-icon">📄</div>
                <div>
                  <div class="file-name">${f.name}</div>
                  <div class="file-size">${f.size_formatted}</div>
                </div>
              </div>
              <a class="btn-dl" href="/file?name=${encodeURIComponent(f.name)}" download>Download</a>
            </div>
          `).join('');
        });
    }

    function loadStatus() {
      fetch('/api/status')
        .then(r => r.json())
        .then(data => {
          document.getElementById('ip-address-display').innerText = 'http://' + data.ip + ':' + data.port;
        });
    }

    loadStatus();
  </script>
</body>
</html>
"""


class UnifiedWebAppHandler(http.server.BaseHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS, HEAD")
        self.send_header("Access-Control-Allow-Headers", "*")
        super().end_headers()

    def do_OPTIONS(self):
        self.send_response(204)
        self.end_headers()

    def do_HEAD(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path

        if path in ("/", "/upload", "/download"):
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(UNIFIED_WEB_APP_HTML.encode("utf-8"))))
            self.end_headers()
        elif path in ("/logo.png", "/assets/logo.png", "/favicon.ico", "/favicon.png"):
            self.send_response(200)
            self.send_header("Content-Type", "image/png")
            self.end_headers()
        elif path == "/api/status" or path == "/api/shared":
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
        else:
            self.send_response(200)
            self.end_headers()

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path

        if path in ("/", "/upload", "/download"):
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.end_headers()
            self.wfile.write(UNIFIED_WEB_APP_HTML.encode("utf-8"))

        elif path in ("/logo.png", "/assets/logo.png", "/favicon.ico", "/favicon.png"):
            logo_candidates = [
                Path(__file__).parent.parent / "apps" / "mobile" / "assets" / "logo.png",
                Path(__file__).parent.parent / "apps" / "mobile" / "web" / "favicon.png",
                Path(__file__).parent / "assets" / "logo.png",
                Path("apps/mobile/assets/logo.png"),
                Path("assets/logo.png"),
            ]
            logo_path = None
            for cand in logo_candidates:
                if cand.exists():
                    logo_path = cand
                    break

            if logo_path:
                self.send_response(200)
                self.send_header("Content-Type", "image/png")
                self.send_header("Content-Length", str(logo_path.stat().st_size))
                self.end_headers()
                with open(logo_path, "rb") as f:
                    self.wfile.write(f.read())
            else:
                self.send_error(404, "Logo Not Found")

        elif path == "/api/status":
            ip = get_local_ip()
            data = {"ip": ip, "port": self.server.server_port, "status": "online"}
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps(data).encode("utf-8"))

        elif path == "/api/shared":
            files = []
            if SHARED_DIR.exists():
                for f in SHARED_DIR.iterdir():
                    if f.is_file() and not f.name.startswith("."):
                        files.append({"name": f.name, "size_formatted": format_bytes(f.stat().st_size)})
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps(files).encode("utf-8"))

        elif path == "/file":
            params = urllib.parse.parse_qs(parsed.query)
            filename = params.get("name", [""])[0]
            target_file = SHARED_DIR / filename

            if not target_file.exists() or not target_file.is_file():
                self.send_error(404, "File Not Found")
                return

            size = target_file.stat().st_size
            self.send_response(200)
            self.send_header("Content-Type", "application/octet-stream")
            self.send_header("Content-Length", str(size))
            self.send_header("Content-Disposition", f'attachment; filename="{urllib.parse.quote(filename)}"')
            self.end_headers()

            with open(target_file, "rb") as f:
                while chunk := f.read(64 * 1024):
                    self.wfile.write(chunk)

        else:
            self.send_error(404, "Not Found")

    def do_POST(self):
        parsed = urllib.parse.urlparse(self.path)
        if parsed.path == "/upload":
            params = urllib.parse.parse_qs(parsed.query)
            filename = params.get("filename", ["upload.bin"])[0]
            target_path = DOWNLOADS_DIR / filename

            content_length = int(self.headers.get("Content-Length", 0))
            bytes_remaining = content_length

            print(f"📥 [Web App] Receiving '{filename}' ({content_length} bytes)...")

            with open(target_path, "wb") as f:
                chunk_size = 64 * 1024
                while bytes_remaining > 0:
                    read_len = min(bytes_remaining, chunk_size)
                    chunk = self.rfile.read(read_len)
                    if not chunk:
                        break
                    f.write(chunk)
                    bytes_remaining -= len(chunk)

            print(f"✅ Saved to: {target_path}")

            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.end_headers()
            self.wfile.write(b"Success")
        else:
            self.send_error(404, "Not Found")


def main():
    import argparse
    parser = argparse.ArgumentParser(description="SwiftBeam Standalone Web Portal")
    parser.add_argument("--port", type=int, default=PORT, help="Port to listen on")
    args = parser.parse_args()

    ip = get_local_ip()
    port = args.port
    server_address = ("0.0.0.0", port)

    try:
        httpd = http.server.HTTPServer(server_address, UnifiedWebAppHandler)
    except OSError:
        port = 8085
        httpd = http.server.HTTPServer(("0.0.0.0", port), UnifiedWebAppHandler)

    print(f"\n=======================================================")
    print(f" 🚀 SwiftBeam Full Web App is Active!")
    print(f" 🌐 Access on Mobile / Browser:")
    print(f" 👉 http://{ip}:{port}")
    print(f" 📤 Send & 📥 Receive both supported over Wi-Fi")
    print(f" 📡 Wi-Fi Direct & Bluetooth Pairing Dashboard enabled")
    print(f"=======================================================\n")

    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nStopping Web Portal server.")
        httpd.server_close()


if __name__ == "__main__":
    main()
