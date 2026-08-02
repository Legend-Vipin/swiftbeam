import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;

class WebPortalService {
  HttpServer? _server;
  List<String> _sharedFilePaths = [];
  String? _outputDir;
  int? port;

  // Retrieve the local IP Address
  Future<String> getLocalIpAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      );
      for (var interface in interfaces) {
        if (interface.name.contains('wlan') ||
            interface.name.contains('ap') ||
            interface.name.contains('wl') ||
            interface.name.contains('en') ||
            interface.name.contains('eth')) {
          for (var addr in interface.addresses) {
            if (!addr.isLoopback) {
              return addr.address;
            }
          }
        }
      }
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (!addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (_) {}
    return '127.0.0.1';
  }

  // Start HTTP Server supporting simultaneous bidirectional transfers (Send & Receive)
  Future<int> start({
    String? sharedFilePath,
    List<String>? sharedFilePaths,
    String? outputDir,
  }) async {
    await stop();

    _sharedFilePaths = [];
    if (sharedFilePaths != null) {
      _sharedFilePaths.addAll(sharedFilePaths);
    } else if (sharedFilePath != null) {
      _sharedFilePaths.add(sharedFilePath);
    }
    _outputDir = outputDir;

    // Bind to any IPv4 on a random free port
    _server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    port = _server!.port;

    _server!.listen((HttpRequest request) async {
      try {
        final path = request.uri.path;
        if (request.method == 'GET') {
          if (path == '/' || path == '/upload' || path == '/download') {
            _serveUnifiedPortalPage(request);
          } else if (path == '/meta' || path == '/api/shared') {
            _serveMetadata(request);
          } else if (path == '/api/status') {
            _serveStatus(request);
          } else if (path == '/file') {
            await _serveFileDownload(request);
          } else if (path == '/logo.png' || path == '/assets/logo.png') {
            await _serveLogo(request);
          } else {
            request.response
              ..statusCode = HttpStatus.notFound
              ..write('Not Found')
              ..close();
          }
        } else if (request.method == 'POST' &&
            (path == '/' || path == '/upload')) {
          await _handleFileUpload(request);
        } else {
          request.response
            ..statusCode = HttpStatus.methodNotAllowed
            ..write('Method Not Allowed')
            ..close();
        }
      } catch (e) {
        try {
          request.response
            ..statusCode = HttpStatus.internalServerError
            ..write('Internal Server Error: $e')
            ..close();
        } catch (_) {}
      }
    });

    return port!;
  }

  // Stop HTTP Server
  Future<void> stop() async {
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
      port = null;
    }
  }

  void _serveUnifiedPortalPage(HttpRequest request) {
    request.response
      ..headers.contentType = ContentType.html
      ..write(_unifiedPortalHtml)
      ..close();
  }

  Future<void> _serveLogo(HttpRequest request) async {
    try {
      List<int>? bytes;
      try {
        final byteData = await rootBundle.load('assets/logo.png');
        bytes = byteData.buffer.asUint8List();
      } catch (_) {
        final candidates = [
          'assets/logo.png',
          'apps/mobile/assets/logo.png',
          '../apps/mobile/assets/logo.png',
        ];
        for (final candidate in candidates) {
          final f = File(candidate);
          if (f.existsSync()) {
            bytes = f.readAsBytesSync();
            break;
          }
        }
      }
      if (bytes != null) {
        request.response
          ..headers.contentType = ContentType('image', 'png')
          ..headers.contentLength = bytes.length
          ..add(bytes);
        await request.response.close();
        return;
      }
    } catch (_) {}
    request.response
      ..statusCode = HttpStatus.notFound
      ..write('Logo Not Found')
      ..close();
  }

  void _serveStatus(HttpRequest request) {
    request.response
      ..headers.contentType = ContentType.json
      ..write(
        jsonEncode({
          'status': 'online',
          'transport': 'wifi_direct',
          'port': port,
          'bluetooth_fallback': true,
        }),
      )
      ..close();
  }

  // Serve multi-file metadata as JSON for live download listing
  void _serveMetadata(HttpRequest request) {
    final Set<String> fileSet = {};
    for (var f in _sharedFilePaths) {
      if (File(f).existsSync()) {
        fileSet.add(f);
      }
    }

    if (_outputDir != null && Directory(_outputDir!).existsSync()) {
      try {
        final dir = Directory(_outputDir!);
        for (var entity in dir.listSync()) {
          if (entity is File) {
            fileSet.add(entity.path);
          }
        }
      } catch (_) {}
    }

    final validFiles = fileSet.toList();

    int totalBytes = 0;
    final fileListJson = [];

    for (int i = 0; i < validFiles.length; i++) {
      final filePath = validFiles[i];
      final file = File(filePath);
      final filename = p.basename(filePath);
      final size = file.lengthSync();
      totalBytes += size;

      fileListJson.add({
        'id': i,
        'filename': filename,
        'size': size,
        'size_formatted': _formatBytes(size),
      });
    }

    request.response
      ..headers.contentType = ContentType.json
      ..write(
        jsonEncode({
          'file_count': validFiles.length,
          'total_size': totalBytes,
          'total_size_formatted': _formatBytes(totalBytes),
          'files': fileListJson,
        }),
      )
      ..close();
  }

  // Stream specific file download to browser
  Future<void> _serveFileDownload(HttpRequest request) async {
    final idParam = request.uri.queryParameters['id'];
    final nameParam = request.uri.queryParameters['name'];
    int id = -1;
    if (idParam != null) {
      id = int.tryParse(idParam) ?? -1;
    }

    final Set<String> fileSet = {};
    for (var f in _sharedFilePaths) {
      if (File(f).existsSync()) fileSet.add(f);
    }
    if (_outputDir != null && Directory(_outputDir!).existsSync()) {
      try {
        for (var entity in Directory(_outputDir!).listSync()) {
          if (entity is File) fileSet.add(entity.path);
        }
      } catch (_) {}
    }

    final validFiles = fileSet.toList();

    String? targetPath;
    if (id >= 0 && id < validFiles.length) {
      targetPath = validFiles[id];
    } else if (nameParam != null && nameParam.isNotEmpty) {
      targetPath = validFiles.firstWhere(
        (f) => p.basename(f) == nameParam,
        orElse: () => '',
      );
      if (targetPath.isEmpty) targetPath = null;
    }

    if (targetPath == null || !File(targetPath).existsSync()) {
      request.response
        ..statusCode = HttpStatus.notFound
        ..write('File Not Found')
        ..close();
      return;
    }

    final file = File(targetPath);
    final filename = p.basename(targetPath);
    final size = file.lengthSync();

    request.response.headers
      ..add(
        'Content-Disposition',
        'attachment; filename="${Uri.encodeComponent(filename)}"',
      )
      ..contentType = ContentType.binary
      ..contentLength = size;

    try {
      await file.openRead().pipe(request.response);
    } catch (_) {
      // Stream interrupted
    }
  }

  // Stream file upload from browser
  Future<void> _handleFileUpload(HttpRequest request) async {
    if (_outputDir == null) {
      request.response
        ..statusCode = HttpStatus.badRequest
        ..write('Server is not configured to receive files')
        ..close();
      return;
    }

    final filename = Uri.decodeComponent(
      request.uri.queryParameters['filename'] ?? 'upload.bin',
    );
    final targetPath = p.join(_outputDir!, filename);

    Directory(_outputDir!).createSync(recursive: true);

    final targetFile = File(targetPath);
    final IOSink sink = targetFile.openWrite();

    try {
      await sink.addStream(request);
      await sink.close();

      if (!_sharedFilePaths.contains(targetPath)) {
        _sharedFilePaths.add(targetPath);
      }

      request.response
        ..statusCode = HttpStatus.ok
        ..write('Success')
        ..close();
    } catch (e) {
      request.response
        ..statusCode = HttpStatus.internalServerError
        ..write('Upload failed: $e')
        ..close();
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return "${size.toStringAsFixed(2)} ${suffixes[i]}";
  }

  // Premium Glassmorphic Simultaneous Dual-Portal HTML Template
  static const String _unifiedPortalHtml = '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>SwiftBeam — Simultaneous Bidirectional Web Portal</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@400;500;600;700;800&display=swap" rel="stylesheet">
  <style>
    :root {
      --bg-gradient: linear-gradient(135deg, #090d16 0%, #111827 50%, #1e1b4b 100%);
      --glass-bg: rgba(255, 255, 255, 0.035);
      --glass-border: rgba(255, 255, 255, 0.08);
      --accent-cyan: #00d9ff;
      --accent-purple: #818cf8;
      --accent-green: #34d399;
      --danger: #f87171;
    }

    * { box-sizing: border-box; }
    body {
      margin: 0;
      padding: 24px 16px;
      font-family: 'Outfit', -apple-system, BlinkMacSystemFont, sans-serif;
      background: var(--bg-gradient);
      color: #f8fafc;
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      align-items: center;
    }

    .header-section {
      text-align: center;
      margin-bottom: 24px;
      max-width: 800px;
    }

    .badge-bar {
      display: inline-flex;
      align-items: center;
      gap: 10px;
      padding: 6px 18px;
      background: rgba(0, 217, 255, 0.08);
      border: 1px solid rgba(0, 217, 255, 0.25);
      border-radius: 999px;
      color: var(--accent-cyan);
      font-size: 13px;
      font-weight: 600;
      margin-bottom: 12px;
    }

    .dot-pulse {
      width: 8px;
      height: 8px;
      background: var(--accent-green);
      border-radius: 50%;
      box-shadow: 0 0 10px var(--accent-green);
    }

    h1 {
      font-size: 32px;
      font-weight: 800;
      margin: 0 0 8px 0;
      background: linear-gradient(to right, #00d9ff, #818cf8, #34d399);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
    }

    .subtitle {
      color: #94a3b8;
      font-size: 15px;
      margin: 0;
    }

    .portal-grid {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 24px;
      width: 100%;
      max-width: 1100px;
    }

    @media (max-width: 840px) {
      .portal-grid { grid-template-columns: 1fr; }
    }

    .card {
      background: var(--glass-bg);
      backdrop-filter: blur(24px);
      -webkit-backdrop-filter: blur(24px);
      border: 1px solid var(--glass-border);
      border-radius: 24px;
      padding: 28px 24px;
      box-shadow: 0 20px 40px rgba(0, 0, 0, 0.4);
      display: flex;
      flex-direction: column;
    }

    .card-header {
      display: flex;
      align-items: center;
      gap: 12px;
      margin-bottom: 20px;
    }

    .card-icon {
      width: 44px;
      height: 44px;
      border-radius: 14px;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 22px;
    }

    .icon-upload {
      background: rgba(0, 217, 255, 0.15);
      border: 1px solid rgba(0, 217, 255, 0.3);
      color: var(--accent-cyan);
    }

    .icon-download {
      background: rgba(52, 211, 153, 0.15);
      border: 1px solid rgba(52, 211, 153, 0.3);
      color: var(--accent-green);
    }

    .card-title {
      font-size: 20px;
      font-weight: 700;
      margin: 0;
      color: #f1f5f9;
    }

    .card-desc {
      font-size: 13px;
      color: #64748b;
      margin-top: 2px;
    }

    .drop-zone {
      border: 2px dashed rgba(0, 217, 255, 0.3);
      border-radius: 18px;
      padding: 28px 16px;
      text-align: center;
      cursor: pointer;
      transition: all 0.3s ease;
      background: rgba(0, 217, 255, 0.02);
    }

    .drop-zone:hover, .drop-zone.dragover {
      border-color: var(--accent-cyan);
      background: rgba(0, 217, 255, 0.08);
    }

    .btn-action {
      background: linear-gradient(135deg, #00d9ff 0%, #4f46e5 100%);
      color: #030712;
      border: none;
      padding: 10px 24px;
      border-radius: 12px;
      font-weight: 700;
      font-size: 14px;
      cursor: pointer;
      margin-top: 12px;
      box-shadow: 0 4px 14px rgba(0, 217, 255, 0.3);
      transition: all 0.2s;
    }

    .btn-action:hover {
      transform: translateY(-2px);
      box-shadow: 0 6px 18px rgba(0, 217, 255, 0.45);
    }

    #file-input { display: none; }

    .stats-dashboard {
      margin-top: 18px;
      display: grid;
      grid-template-columns: repeat(4, 1fr);
      gap: 8px;
      background: rgba(255, 255, 255, 0.02);
      border: 1px solid var(--glass-border);
      border-radius: 14px;
      padding: 12px 8px;
    }

    .stat-card { text-align: center; }
    .stat-label { font-size: 10px; color: #64748b; font-weight: 600; text-transform: uppercase; }
    .stat-value { font-size: 14px; font-weight: 700; color: var(--accent-cyan); }

    .progress-track {
      margin-top: 14px;
      background: rgba(255, 255, 255, 0.08);
      height: 6px;
      border-radius: 999px;
      overflow: hidden;
    }

    .progress-bar {
      height: 100%;
      width: 0%;
      background: linear-gradient(to right, #00d9ff, #818cf8);
      border-radius: 999px;
      transition: width 0.15s ease;
    }

    .file-list {
      margin-top: 16px;
      display: flex;
      flex-direction: column;
      gap: 10px;
      max-height: 300px;
      overflow-y: auto;
      padding-right: 4px;
    }

    .file-item {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 12px;
      padding: 12px 14px;
      background: rgba(255, 255, 255, 0.03);
      border: 1px solid var(--glass-border);
      border-radius: 14px;
    }

    .file-info { flex: 1; min-width: 0; }
    .file-name {
      font-weight: 600;
      font-size: 13.5px;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
      color: #e2e8f0;
    }
    .file-sub { font-size: 11.5px; color: #64748b; margin-top: 2px; }

    .file-status-badge {
      font-size: 11px;
      font-weight: 700;
      padding: 3px 8px;
      border-radius: 999px;
      background: rgba(255, 255, 255, 0.05);
      color: #94a3b8;
    }
    .file-status-badge.uploading { background: rgba(0, 217, 255, 0.15); color: var(--accent-cyan); }
    .file-status-badge.complete { background: rgba(52, 211, 153, 0.15); color: var(--accent-green); }
    .file-status-badge.failed { background: rgba(248, 113, 113, 0.15); color: var(--danger); }

    .btn-single-dl {
      background: rgba(52, 211, 153, 0.12);
      color: var(--accent-green);
      border: 1px solid rgba(52, 211, 153, 0.3);
      padding: 6px 14px;
      border-radius: 10px;
      font-weight: 600;
      font-size: 12.5px;
      text-decoration: none;
      transition: all 0.2s;
    }
    .btn-single-dl:hover {
      background: var(--accent-green);
      color: #030712;
    }

    .btn-dl-all {
      background: linear-gradient(135deg, #10b981 0%, #059669 100%);
      color: white;
      border: none;
      padding: 8px 18px;
      border-radius: 10px;
      font-weight: 700;
      font-size: 13px;
      cursor: pointer;
      box-shadow: 0 4px 12px rgba(16, 185, 129, 0.3);
      transition: all 0.2s ease;
    }
    .btn-dl-all:hover {
      transform: translateY(-2px);
      box-shadow: 0 6px 16px rgba(16, 185, 129, 0.45);
    }
  </style>
</head>
<body>
  <div class="header-section">
    <div class="badge-bar">
      <div class="dot-pulse"></div>
      <span>⚡ SwiftBeam Wi-Fi Direct Web Portal</span>
    </div>
    <div style="display: flex; align-items: center; justify-content: center; gap: 14px; margin-bottom: 8px;">
      <img src="/logo.png" alt="SwiftBeam Logo" style="width: 48px; height: 48px; object-fit: contain; border-radius: 12px; filter: drop-shadow(0 4px 12px rgba(0, 217, 255, 0.4));">
      <h1 style="margin: 0;">Simultaneous P2P Web Portal</h1>
    </div>
    <p class="subtitle">Send files to app and receive shared files simultaneously over Wi-Fi</p>
  </div>

  <div class="portal-grid">
    <!-- LEFT CARD: SEND FILES TO APP -->
    <div class="card">
      <div class="card-header">
        <div class="card-icon icon-upload">📤</div>
        <div>
          <h2 class="card-title">Send to Device</h2>
          <div class="card-desc">Stream files from browser to mobile app</div>
        </div>
      </div>

      <div class="drop-zone" id="drop-zone">
        <div style="font-size: 28px; margin-bottom: 6px;">📁</div>
        <div style="font-size: 15px; font-weight: 600; color: #e2e8f0;">Drag & Drop files here</div>
        <div style="font-size: 12px; color: #64748b; margin-top: 2px;">or choose from local storage</div>
        <button class="btn-action" onclick="document.getElementById('file-input').click()">Select Files</button>
        <input type="file" id="file-input" multiple onchange="handleFileSelect(this.files)">
      </div>

      <div class="stats-dashboard" id="stats-dashboard" style="display: none;">
        <div class="stat-card"><div class="stat-label">Files</div><div class="stat-value" id="stat-files">0/0</div></div>
        <div class="stat-card"><div class="stat-label">Sent</div><div class="stat-value" id="stat-transferred">0 MB</div></div>
        <div class="stat-card"><div class="stat-label">Speed</div><div class="stat-value" id="stat-speed">0 MB/s</div></div>
        <div class="stat-card"><div class="stat-label">ETA</div><div class="stat-value" id="stat-eta">--:--</div></div>
      </div>

      <div class="progress-track" id="progress-track" style="display: none;">
        <div class="progress-bar" id="overall-bar"></div>
      </div>

      <div class="file-list" id="upload-file-list"></div>
    </div>

    <!-- RIGHT CARD: RECEIVE FILES FROM APP -->
    <div class="card">
      <div class="card-header" style="justify-content: space-between;">
        <div style="display: flex; align-items: center; gap: 12px;">
          <div class="card-icon icon-download">📥</div>
          <div>
            <h2 class="card-title">Receive from Device</h2>
            <div class="card-desc">Download files shared by mobile app</div>
          </div>
        </div>
        <button class="btn-dl-all" id="btn-dl-all" onclick="downloadAllFiles()">Download All</button>
      </div>

      <div style="font-size: 13px; font-weight: 600; color: #cbd5e1; margin-bottom: 12px;" id="pkg-summary">
        Loading package info...
      </div>

      <div class="file-list" id="receive-file-list"></div>
    </div>
  </div>

  <script>
    // --- UPLOAD CONTROLLER ---
    const dropZone = document.getElementById('drop-zone');
    const uploadListEl = document.getElementById('upload-file-list');
    const statsDash = document.getElementById('stats-dashboard');
    const progressTrack = document.getElementById('progress-track');
    const overallBar = document.getElementById('overall-bar');

    ['dragenter', 'dragover'].forEach(name => {
      dropZone.addEventListener(name, (e) => { e.preventDefault(); dropZone.classList.add('dragover'); });
    });
    ['dragleave', 'drop'].forEach(name => {
      dropZone.addEventListener(name, (e) => { e.preventDefault(); dropZone.classList.remove('dragover'); });
    });
    dropZone.addEventListener('drop', (e) => { handleFileSelect(e.dataTransfer.files); });

    let uploadQueue = [];
    let isUploading = false;
    let totalBytesAll = 0;
    let loadedBytesAll = 0;
    let completedCount = 0;
    let startTime = 0;
    let lastTime = 0;
    let lastLoaded = 0;

    function formatBytes(bytes) {
      if (bytes <= 0) return '0 B';
      const k = 1024, sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
      const i = Math.floor(Math.log(bytes) / Math.log(k));
      return (bytes / Math.pow(k, i)).toFixed(2) + ' ' + sizes[i];
    }

    function formatEta(seconds) {
      if (!isFinite(seconds) || seconds < 0) return '--:--';
      const m = Math.floor(seconds / 60);
      const s = Math.floor(seconds % 60);
      return (m < 10 ? '0' : '') + m + ':' + (s < 10 ? '0' : '') + s;
    }

    function handleFileSelect(files) {
      if (!files || files.length === 0) return;
      
      const newFiles = Array.from(files);
      newFiles.forEach(file => {
        uploadQueue.push({
          file: file,
          id: 'file-' + Math.random().toString(36).substr(2, 9),
          status: 'queued',
          loaded: 0
        });
        totalBytesAll += file.size;
      });

      renderUploadList();
      statsDash.style.display = 'grid';
      progressTrack.style.display = 'block';

      if (!isUploading) {
        startTime = Date.now();
        lastTime = startTime;
        lastLoaded = loadedBytesAll;
        processNextUpload();
      }
    }

    function renderUploadList() {
      uploadListEl.innerHTML = '';
      uploadQueue.forEach(item => {
        const div = document.createElement('div');
        div.className = 'file-item';
        div.id = item.id;

        let badgeClass = item.status;
        let badgeText = item.status.toUpperCase();

        div.innerHTML = `
          <div class="file-info">
            <div class="file-name">\${item.file.name}</div>
            <div class="file-sub">\${formatBytes(item.loaded)} / \${formatBytes(item.file.size)}</div>
          </div>
          <div class="file-status-badge \${badgeClass}">\${badgeText}</div>
        `;
        uploadListEl.appendChild(div);
      });
    }

    function processNextUpload() {
      const nextItem = uploadQueue.find(i => i.status === 'queued');
      if (!nextItem) {
        isUploading = false;
        document.getElementById('stat-speed').innerText = '0 MB/s';
        document.getElementById('stat-eta').innerText = 'Complete';
        fetchSharedFiles(); // Refresh receive list as uploaded files become available
        return;
      }

      isUploading = true;
      nextItem.status = 'uploading';
      renderUploadList();

      const xhr = new XMLHttpRequest();
      xhr.open('POST', '/upload?filename=' + encodeURIComponent(nextItem.file.name));

      let prevFileLoaded = 0;

      xhr.upload.onprogress = (e) => {
        if (e.lengthComputable) {
          const delta = e.loaded - prevFileLoaded;
          prevFileLoaded = e.loaded;
          nextItem.loaded = e.loaded;
          loadedBytesAll += delta;

          const pct = Math.round((loadedBytesAll / totalBytesAll) * 100);
          overallBar.style.width = pct + '%';

          const now = Date.now();
          const timeDiff = (now - lastTime) / 1000;
          if (timeDiff >= 0.5) {
            const bytesDiff = loadedBytesAll - lastLoaded;
            const speedBytesSec = bytesDiff / timeDiff;
            const remainingBytes = totalBytesAll - loadedBytesAll;
            const etaSec = speedBytesSec > 0 ? remainingBytes / speedBytesSec : 0;

            document.getElementById('stat-speed').innerText = formatBytes(speedBytesSec) + '/s';
            document.getElementById('stat-eta').innerText = formatEta(etaSec);

            lastTime = now;
            lastLoaded = loadedBytesAll;
          }

          document.getElementById('stat-transferred').innerText = formatBytes(loadedBytesAll) + ' / ' + formatBytes(totalBytesAll);
          document.getElementById('stat-files').innerText = completedCount + ' / ' + uploadQueue.length;

          renderUploadList();
        }
      };

      xhr.onload = () => {
        if (xhr.status === 200) {
          nextItem.status = 'complete';
          completedCount++;
        } else {
          nextItem.status = 'failed';
        }
        document.getElementById('stat-files').innerText = completedCount + ' / ' + uploadQueue.length;
        renderUploadList();
        processNextUpload();
      };

      xhr.onerror = () => {
        nextItem.status = 'failed';
        renderUploadList();
        processNextUpload();
      };

      xhr.send(nextItem.file);
    }

    // --- RECEIVE CONTROLLER (DOWNLOAD) ---
    let filesData = [];

    function fetchSharedFiles() {
      fetch('/meta')
        .then(res => res.json())
        .then(data => {
          filesData = data.files || [];
          document.getElementById('pkg-summary').innerText = `\${data.file_count || 0} File\${(data.file_count || 0) !== 1 ? 's' : ''} (\${data.total_size_formatted || '0 B'})`;

          const receiveListEl = document.getElementById('receive-file-list');
          if (filesData.length === 0) {
            receiveListEl.innerHTML = `
              <div style="text-align: center; color: #64748b; padding: 24px;">
                No shared files yet. Upload files above or share from app.
              </div>
            `;
            return;
          }

          receiveListEl.innerHTML = '';
          filesData.forEach(file => {
            const div = document.createElement('div');
            div.className = 'file-item';
            div.innerHTML = `
              <div class="file-info">
                <div class="file-name">\${file.filename}</div>
                <div class="file-sub">\${file.size_formatted}</div>
              </div>
              <a class="btn-single-dl" href="/file?id=\${file.id}" download>Download</a>
            `;
            receiveListEl.appendChild(div);
          });
        })
        .catch(err => {
          document.getElementById('pkg-summary').innerText = 'No shared files active';
        });
    }

    function downloadAllFiles() {
      if (!filesData || filesData.length === 0) return;
      filesData.forEach((file, index) => {
        setTimeout(() => {
          const a = document.createElement('a');
          a.href = '/file?id=' + file.id;
          a.download = file.filename;
          document.body.appendChild(a);
          a.click();
          document.body.removeChild(a);
        }, index * 500);
      });
    }

    // Initial load and auto-poll every 3 seconds for live bidirectional updates
    fetchSharedFiles();
    setInterval(fetchSharedFiles, 3000);
  </script>
</body>
</html>
''';
}
