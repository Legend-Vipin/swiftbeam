import 'dart:convert';
import 'dart:io';
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

  // Start HTTP Server with multi-file support
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
            if (_sharedFilePaths.isNotEmpty) {
              _serveDownloadPage(request);
            } else {
              _serveUploadPage(request);
            }
          } else if (path == '/meta') {
            _serveMetadata(request);
          } else if (path == '/file') {
            await _serveFileDownload(request);
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

  void _serveUploadPage(HttpRequest request) {
    request.response
      ..headers.contentType = ContentType.html
      ..write(_uploadHtml)
      ..close();
  }

  void _serveDownloadPage(HttpRequest request) {
    request.response
      ..headers.contentType = ContentType.html
      ..write(_downloadHtml)
      ..close();
  }

  // Serve multi-file metadata as JSON
  void _serveMetadata(HttpRequest request) {
    final validFiles =
        _sharedFilePaths.where((f) => File(f).existsSync()).toList();
    if (validFiles.isEmpty) {
      request.response
        ..statusCode = HttpStatus.notFound
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'error': 'No files shared'}))
        ..close();
      return;
    }

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
      ..write(jsonEncode({
        'file_count': validFiles.length,
        'total_size': totalBytes,
        'total_size_formatted': _formatBytes(totalBytes),
        'files': fileListJson,
      }))
      ..close();
  }

  // Stream specific file download to browser
  Future<void> _serveFileDownload(HttpRequest request) async {
    final idParam = request.uri.queryParameters['id'];
    int id = 0;
    if (idParam != null) {
      id = int.tryParse(idParam) ?? 0;
    }

    final validFiles =
        _sharedFilePaths.where((f) => File(f).existsSync()).toList();
    if (id < 0 || id >= validFiles.length) {
      request.response
        ..statusCode = HttpStatus.notFound
        ..write('File Not Found')
        ..close();
      return;
    }

    final targetPath = validFiles[id];
    final file = File(targetPath);
    final filename = p.basename(targetPath);
    final size = file.lengthSync();

    request.response.headers
      ..add('Content-Disposition',
          'attachment; filename="${Uri.encodeComponent(filename)}"')
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
        request.uri.queryParameters['filename'] ?? 'upload.bin');
    final targetPath = p.join(_outputDir!, filename);

    Directory(_outputDir!).createSync(recursive: true);

    final targetFile = File(targetPath);
    final IOSink sink = targetFile.openWrite();

    try {
      await sink.addStream(request);
      await sink.close();
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

  // Premium Glassmorphic Multi-File HTML templates
  static const String _uploadHtml = '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>SwiftBeam Multi-File Upload Portal</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@400;500;600;700;800&display=swap" rel="stylesheet">
  <style>
    :root {
      --bg-gradient: linear-gradient(135deg, #090d16 0%, #111827 50%, #1e1b4b 100%);
      --glass-bg: rgba(255, 255, 255, 0.03);
      --glass-border: rgba(255, 255, 255, 0.08);
      --accent: #00d9ff;
      --accent-purple: #818cf8;
      --success: #34d399;
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
      align-items: center;
      justify-content: center;
    }

    .container {
      width: 100%;
      max-width: 680px;
    }

    .card {
      background: var(--glass-bg);
      backdrop-filter: blur(24px);
      -webkit-backdrop-filter: blur(24px);
      border: 1px solid var(--glass-border);
      border-radius: 28px;
      padding: 36px 32px;
      box-shadow: 0 24px 48px rgba(0, 0, 0, 0.5);
    }

    .header {
      text-align: center;
      margin-bottom: 28px;
    }

    .header .logo-badge {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      padding: 6px 16px;
      background: rgba(0, 217, 255, 0.1);
      border: 1px solid rgba(0, 217, 255, 0.25);
      border-radius: 999px;
      color: var(--accent);
      font-size: 13px;
      font-weight: 600;
      margin-bottom: 12px;
    }

    h1 {
      font-size: 32px;
      font-weight: 800;
      margin: 0 0 6px 0;
      background: linear-gradient(to right, #00d9ff, #818cf8, #c084fc);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
    }

    .subtitle {
      color: #94a3b8;
      font-size: 15px;
      margin: 0;
    }

    .drop-zone {
      border: 2px dashed rgba(0, 217, 255, 0.3);
      border-radius: 20px;
      padding: 36px 20px;
      text-align: center;
      cursor: pointer;
      transition: all 0.3s ease;
      background: rgba(0, 217, 255, 0.02);
    }

    .drop-zone:hover, .drop-zone.dragover {
      border-color: var(--accent);
      background: rgba(0, 217, 255, 0.08);
      transform: scale(1.01);
    }

    .btn-browse {
      background: linear-gradient(135deg, #00d9ff 0%, #4f46e5 100%);
      color: #030712;
      border: none;
      padding: 12px 28px;
      border-radius: 14px;
      font-weight: 700;
      font-size: 15px;
      cursor: pointer;
      margin-top: 14px;
      box-shadow: 0 4px 16px rgba(0, 217, 255, 0.3);
      transition: all 0.2s ease;
    }

    .btn-browse:hover {
      transform: translateY(-2px);
      box-shadow: 0 6px 20px rgba(0, 217, 255, 0.45);
    }

    #file-input { display: none; }

    .stats-dashboard {
      margin-top: 24px;
      display: grid;
      grid-template-columns: repeat(4, 1fr);
      gap: 12px;
      background: rgba(255, 255, 255, 0.02);
      border: 1px solid var(--glass-border);
      border-radius: 16px;
      padding: 16px;
    }

    @media (max-width: 580px) {
      .stats-dashboard { grid-template-columns: repeat(2, 1fr); }
    }

    .stat-card {
      text-align: center;
    }

    .stat-label {
      font-size: 11px;
      color: #64748b;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      font-weight: 600;
      margin-bottom: 4px;
    }

    .stat-value {
      font-size: 16px;
      font-weight: 700;
      color: var(--accent);
    }

    .overall-progress-track {
      margin-top: 20px;
      background: rgba(255, 255, 255, 0.08);
      height: 8px;
      border-radius: 999px;
      overflow: hidden;
    }

    .overall-progress-bar {
      height: 100%;
      width: 0%;
      background: linear-gradient(to right, #00d9ff, #818cf8);
      border-radius: 999px;
      transition: width 0.15s ease;
    }

    .file-list {
      margin-top: 24px;
      display: flex;
      flex-direction: column;
      gap: 10px;
      max-height: 280px;
      overflow-y: auto;
      padding-right: 4px;
    }

    .file-item {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 12px;
      padding: 14px 16px;
      background: rgba(255, 255, 255, 0.03);
      border: 1px solid var(--glass-border);
      border-radius: 14px;
    }

    .file-info {
      flex: 1;
      min-width: 0;
    }

    .file-name {
      font-weight: 600;
      font-size: 14px;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
      color: #e2e8f0;
    }

    .file-sub {
      font-size: 12px;
      color: #64748b;
      margin-top: 2px;
    }

    .file-status-badge {
      font-size: 11.5px;
      font-weight: 700;
      padding: 4px 10px;
      border-radius: 999px;
      background: rgba(255, 255, 255, 0.05);
      color: #94a3b8;
    }

    .file-status-badge.uploading {
      background: rgba(0, 217, 255, 0.15);
      color: var(--accent);
    }

    .file-status-badge.complete {
      background: rgba(52, 211, 153, 0.15);
      color: var(--success);
    }

    .file-status-badge.failed {
      background: rgba(248, 113, 113, 0.15);
      color: var(--danger);
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="card">
      <div class="header">
        <div class="logo-badge">⚡ SwiftBeam P2P Transfer</div>
        <h1>Multi-File Upload Portal</h1>
        <p class="subtitle">Send multiple files directly to this device over local Wi-Fi</p>
      </div>

      <div class="drop-zone" id="drop-zone">
        <div style="font-size: 32px; margin-bottom: 8px;">📁</div>
        <div style="font-size: 16px; font-weight: 600; color: #e2e8f0;">Drag & Drop multiple files here</div>
        <div style="font-size: 13px; color: #64748b; margin-top: 4px;">or click below to choose files</div>
        <button class="btn-browse" onclick="document.getElementById('file-input').click()">Select Files</button>
        <input type="file" id="file-input" multiple onchange="handleFileSelect(this.files)">
      </div>

      <div class="stats-dashboard" id="stats-dashboard" style="display: none;">
        <div class="stat-card">
          <div class="stat-label">Files</div>
          <div class="stat-value" id="stat-files">0 / 0</div>
        </div>
        <div class="stat-card">
          <div class="stat-label">Transferred</div>
          <div class="stat-value" id="stat-transferred">0 MB</div>
        </div>
        <div class="stat-card">
          <div class="stat-label">Speed</div>
          <div class="stat-value" id="stat-speed">0 MB/s</div>
        </div>
        <div class="stat-card">
          <div class="stat-label">ETA</div>
          <div class="stat-value" id="stat-eta">--:--</div>
        </div>
      </div>

      <div class="overall-progress-track" id="progress-track" style="display: none;">
        <div class="overall-progress-bar" id="overall-bar"></div>
      </div>

      <div class="file-list" id="file-list"></div>
    </div>
  </div>

  <script>
    const dropZone = document.getElementById('drop-zone');
    const fileListEl = document.getElementById('file-list');
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

      renderFileList();
      statsDash.style.display = 'grid';
      progressTrack.style.display = 'block';

      if (!isUploading) {
        startTime = Date.now();
        lastTime = startTime;
        lastLoaded = loadedBytesAll;
        processNextUpload();
      }
    }

    function renderFileList() {
      fileListEl.innerHTML = '';
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
        fileListEl.appendChild(div);
      });
    }

    function processNextUpload() {
      const nextItem = uploadQueue.find(i => i.status === 'queued');
      if (!nextItem) {
        isUploading = false;
        document.getElementById('stat-speed').innerText = '0 MB/s';
        document.getElementById('stat-eta').innerText = 'Complete';
        return;
      }

      isUploading = true;
      nextItem.status = 'uploading';
      renderFileList();

      const xhr = new XMLHttpRequest();
      xhr.open('POST', '/upload?filename=' + encodeURIComponent(nextItem.file.name));

      let prevFileLoaded = 0;

      xhr.upload.onprogress = (e) => {
        if (e.lengthComputable) {
          const delta = e.loaded - prevFileLoaded;
          prevFileLoaded = e.loaded;
          nextItem.loaded = e.loaded;
          loadedBytesAll += delta;

          // Update total stats
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

          renderFileList();
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
        renderFileList();
        processNextUpload();
      };

      xhr.onerror = () => {
        nextItem.status = 'failed';
        renderFileList();
        processNextUpload();
      };

      xhr.send(nextItem.file);
    }
  </script>
</body>
</html>
''';

  static const String _downloadHtml = '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>SwiftBeam Multi-File Download Portal</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@400;500;600;700;800&display=swap" rel="stylesheet">
  <style>
    :root {
      --bg-gradient: linear-gradient(135deg, #090d16 0%, #111827 50%, #1e1b4b 100%);
      --glass-bg: rgba(255, 255, 255, 0.03);
      --glass-border: rgba(255, 255, 255, 0.08);
      --accent: #34d399;
      --accent-blue: #00d9ff;
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
      align-items: center;
      justify-content: center;
    }

    .container {
      width: 100%;
      max-width: 680px;
    }

    .card {
      background: var(--glass-bg);
      backdrop-filter: blur(24px);
      -webkit-backdrop-filter: blur(24px);
      border: 1px solid var(--glass-border);
      border-radius: 28px;
      padding: 36px 32px;
      box-shadow: 0 24px 48px rgba(0, 0, 0, 0.5);
    }

    .header {
      text-align: center;
      margin-bottom: 28px;
    }

    .header .logo-badge {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      padding: 6px 16px;
      background: rgba(52, 211, 153, 0.1);
      border: 1px solid rgba(52, 211, 153, 0.25);
      border-radius: 999px;
      color: var(--accent);
      font-size: 13px;
      font-weight: 600;
      margin-bottom: 12px;
    }

    h1 {
      font-size: 32px;
      font-weight: 800;
      margin: 0 0 6px 0;
      background: linear-gradient(to right, #34d399, #00d9ff, #c084fc);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
    }

    .subtitle {
      color: #94a3b8;
      font-size: 15px;
      margin: 0;
    }

    .action-bar {
      display: flex;
      align-items: center;
      justify-content: space-between;
      margin-bottom: 20px;
      gap: 12px;
    }

    .package-summary {
      font-size: 14px;
      font-weight: 600;
      color: #cbd5e1;
    }

    .btn-download-all {
      background: linear-gradient(135deg, #10b981 0%, #059669 100%);
      color: white;
      border: none;
      padding: 10px 22px;
      border-radius: 12px;
      font-weight: 700;
      font-size: 14px;
      cursor: pointer;
      box-shadow: 0 4px 14px rgba(16, 185, 129, 0.35);
      transition: all 0.2s ease;
      text-decoration: none;
    }

    .btn-download-all:hover {
      transform: translateY(-2px);
      box-shadow: 0 6px 18px rgba(16, 185, 129, 0.5);
    }

    .file-list {
      display: flex;
      flex-direction: column;
      gap: 12px;
      max-height: 340px;
      overflow-y: auto;
    }

    .file-item {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 16px;
      padding: 16px 18px;
      background: rgba(255, 255, 255, 0.03);
      border: 1px solid var(--glass-border);
      border-radius: 16px;
      transition: border-color 0.2s;
    }

    .file-item:hover {
      border-color: rgba(52, 211, 153, 0.3);
    }

    .file-info {
      flex: 1;
      min-width: 0;
    }

    .file-name {
      font-weight: 600;
      font-size: 15px;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
      color: #f1f5f9;
    }

    .file-size {
      font-size: 12.5px;
      color: #64748b;
      margin-top: 3px;
    }

    .btn-single-dl {
      background: rgba(52, 211, 153, 0.12);
      color: var(--accent);
      border: 1px solid rgba(52, 211, 153, 0.3);
      padding: 8px 16px;
      border-radius: 10px;
      font-weight: 600;
      font-size: 13px;
      text-decoration: none;
      transition: all 0.2s;
    }

    .btn-single-dl:hover {
      background: var(--accent);
      color: #030712;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="card">
      <div class="header">
        <div class="logo-badge">📥 SwiftBeam P2P Receiver</div>
        <h1>Shared Files Package</h1>
        <p class="subtitle">Download files directly over your local Wi-Fi connection</p>
      </div>

      <div class="action-bar">
        <div class="package-summary" id="pkg-summary">Loading package info...</div>
        <button class="btn-download-all" id="btn-dl-all" onclick="downloadAllFiles()">Download All Files</button>
      </div>

      <div class="file-list" id="file-list"></div>
    </div>
  </div>

  <script>
    let filesData = [];

    fetch('/meta')
      .then(res => {
        if (!res.ok) throw new Error('No shared files available');
        return res.json();
      })
      .then(data => {
        filesData = data.files || [];
        document.getElementById('pkg-summary').innerText = `\${data.file_count} File\${data.file_count > 1 ? 's' : ''} (\${data.total_size_formatted})`;

        const fileListEl = document.getElementById('file-list');
        fileListEl.innerHTML = '';

        filesData.forEach(file => {
          const div = document.createElement('div');
          div.className = 'file-item';
          div.innerHTML = `
            <div class="file-info">
              <div class="file-name">\${file.filename}</div>
              <div class="file-size">\${file.size_formatted}</div>
            </div>
            <a class="btn-single-dl" href="/file?id=\${file.id}" download>Download</a>
          `;
          fileListEl.appendChild(div);
        });
      })
      .catch(err => {
        document.getElementById('pkg-summary').innerText = 'No shared files active';
        document.getElementById('btn-dl-all').style.opacity = 0.5;
        document.getElementById('btn-dl-all').style.pointerEvents = 'none';
        document.getElementById('file-list').innerHTML = `
          <div style="text-align: center; color: #64748b; padding: 24px;">
            Make sure the sender app is active on the local network.
          </div>
        `;
      });

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
        }, index * 600);
      });
    }
  </script>
</body>
</html>
''';
}
