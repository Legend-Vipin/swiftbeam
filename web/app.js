// WebRTC Configurations
const rtcConfig = {
  iceServers: [
    { urls: 'stun:stun.l.google.com:19302' },
    { urls: 'stun:stun1.l.google.com:19302' }
  ]
};

const CHUNK_SIZE = 16384; // 16KB chunk size for WebRTC DataChannel
const MAX_BUFFERED_AMOUNT = 65536; // 64KB max buffer limit

let pc = null;
let dataChannel = null;
let isSender = true;

// File state
let activeFile = null;
let receivedChunks = [];
let receivedSize = 0;
let fileMeta = null;
let startTime = null;

// UI Elements
const btnRoleSender = document.getElementById('btn-role-sender');
const btnRoleReceiver = document.getElementById('btn-role-receiver');
const senderFlow = document.getElementById('sender-flow');
const receiverFlow = document.getElementById('receiver-flow');
const connectionSection = document.getElementById('connection-section');
const transferSection = document.getElementById('transfer-section');
const sendModule = document.getElementById('send-module');
const progressModule = document.getElementById('progress-module');

// Inputs & Buttons
const btnGenOffer = document.getElementById('btn-gen-offer');
const txtOffer = document.getElementById('txt-offer');
const groupOffer = document.getElementById('group-offer');
const stepSenderAnswer = document.getElementById('step-sender-answer');
const txtAnswerPaste = document.getElementById('txt-answer-paste');
const btnConnectSender = document.getElementById('btn-connect-sender');

const txtOfferPaste = document.getElementById('txt-offer-paste');
const btnAcceptOffer = document.getElementById('btn-accept-offer');
const stepReceiverAnswer = document.getElementById('step-receiver-answer');
const txtAnswer = document.getElementById('txt-answer');

const dropZone = document.getElementById('drop-zone');
const fileInput = document.getElementById('file-input');
const statusDot = document.getElementById('status-dot');
const statusText = document.getElementById('status-text');
const btnDisconnect = document.getElementById('btn-disconnect');
const logOutput = document.getElementById('log-output');

// Progress labels
const lblFileName = document.getElementById('lbl-file-name');
const lblFileSize = document.getElementById('lbl-file-size');
const lblPercentage = document.getElementById('lbl-percentage');
const progressBar = document.getElementById('progress-bar');
const lblSpeed = document.getElementById('lbl-speed');
const lblEta = document.getElementById('lbl-eta');

// Copy Buttons
if (document.getElementById('btn-copy-offer')) document.getElementById('btn-copy-offer').addEventListener('click', () => copyToClipboard(txtOffer));
if (document.getElementById('btn-copy-answer')) document.getElementById('btn-copy-answer').addEventListener('click', () => copyToClipboard(txtAnswer));
if (document.getElementById('btn-copy-link')) document.getElementById('btn-copy-link').addEventListener('click', () => copyToClipboard(document.getElementById('txt-invite-link')));

const senderQrBox = document.getElementById('sender-qr-box');
const stepSenderInit = document.getElementById('step-sender-init');
const senderQrcode = document.getElementById('sender-qrcode');
const receiverQrcode = document.getElementById('receiver-qrcode');
const stepReceiverInit = document.getElementById('step-receiver-init');

// Toggle Roles
btnRoleSender.addEventListener('click', () => {
  isSender = true;
  btnRoleSender.classList.add('btn-primary', 'active');
  btnRoleSender.classList.remove('btn-secondary');
  btnRoleReceiver.classList.add('btn-secondary');
  btnRoleReceiver.classList.remove('btn-primary', 'active');
  senderFlow.classList.remove('hidden');
  receiverFlow.classList.add('hidden');
});

btnRoleReceiver.addEventListener('click', () => {
  isSender = false;
  btnRoleReceiver.classList.add('btn-primary', 'active');
  btnRoleReceiver.classList.remove('btn-secondary');
  btnRoleSender.classList.add('btn-secondary');
  btnRoleSender.classList.remove('btn-primary', 'active');
  receiverFlow.classList.remove('hidden');
  senderFlow.classList.add('hidden');
});

// Logs helper
function log(msg, type = 'normal') {
  const entry = document.createElement('div');
  entry.className = `log-entry ${type}`;
  entry.innerText = `[${new Date().toLocaleTimeString()}] ${msg}`;
  logOutput.appendChild(entry);
  logOutput.scrollTop = logOutput.scrollHeight;
}

function copyToClipboard(textareaEl) {
  textareaEl.select();
  document.execCommand('copy');
  log('Copied connection code to clipboard!', 'info');
}

// -------------------------------------------------------------
// UTILITIES
// -------------------------------------------------------------
function compressPayload(obj) {
  const jsonStr = JSON.stringify(obj);
  const deflated = pako.deflate(jsonStr);
  let binary = '';
  for (let i = 0; i < deflated.length; i++) {
    binary += String.fromCharCode(deflated[i]);
  }
  return btoa(binary);
}

function decompressPayload(b64) {
  const binary = atob(b64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  const inflated = pako.inflate(bytes, { to: 'string' });
  return JSON.parse(inflated);
}

// -------------------------------------------------------------
// SENDER WORKFLOW
// -------------------------------------------------------------
btnGenOffer.addEventListener('click', async () => {
  log('Initializing WebRTC Connection...', 'info');
  btnGenOffer.disabled = true;
  
  pc = new RTCPeerConnection(rtcConfig);
  dataChannel = pc.createDataChannel('file-transfer', { ordered: true });
  
  setupDataChannelHandlers(dataChannel);
  setupIceGathering(pc, txtOffer, () => {
    const b64 = txtOffer.value;
    const url = window.location.origin + window.location.pathname + '#offer=' + b64;
    document.getElementById('txt-invite-link').value = url;
    
    senderQrcode.innerHTML = '';
    new QRCode(senderQrcode, {
      text: url,
      width: 512,
      height: 512,
      colorDark : "#000000",
      colorLight : "#ffffff",
      correctLevel : QRCode.CorrectLevel.L
    });
    
    stepSenderInit.classList.add('hidden');
    senderQrBox.classList.remove('hidden');
    stepSenderAnswer.classList.remove('hidden');
    log('Invitation QR generated! Scan it with the receiver device.', 'success');
  });

  const offer = await pc.createOffer();
  await pc.setLocalDescription(offer);
});

btnConnectSender.addEventListener('click', async () => {
  const answerStr = txtAnswerPaste.value.trim();
  if (!answerStr) return log('Please scan or paste a response code first!', 'error');

  try {
    const answer = decompressPayload(answerStr);
    await pc.setRemoteDescription(new RTCSessionDescription(answer));
    log('Response accepted. Connecting...', 'info');
  } catch (e) {
    log('Invalid response code. Try copying it again.', 'error');
  }
});

let html5QrcodeScanner = null;
document.getElementById('btn-scan-answer').addEventListener('click', () => {
  if (!html5QrcodeScanner) {
    html5QrcodeScanner = new Html5QrcodeScanner(
      "scanner-container",
      { fps: 10, qrbox: {width: 250, height: 250} },
      false
    );
    html5QrcodeScanner.render((decodedText) => {
      html5QrcodeScanner.clear();
      html5QrcodeScanner = null;
      txtAnswerPaste.value = decodedText;
      btnConnectSender.click();
    }, () => {});
  }
});

// -------------------------------------------------------------
// RECEIVER WORKFLOW
// -------------------------------------------------------------
async function processOffer(offerStr) {
  if (offerStr.includes('#offer=')) {
    offerStr = offerStr.split('#offer=')[1];
  }
  
  try {
    const offer = decompressPayload(offerStr);
    log('Invitation accepted. Setting up peer connection...', 'info');
    
    pc = new RTCPeerConnection(rtcConfig);
    
    pc.ondatachannel = (event) => {
      dataChannel = event.channel;
      setupDataChannelHandlers(dataChannel);
    };

    setupIceGathering(pc, txtAnswer, () => {
      const b64 = txtAnswer.value;
      receiverQrcode.innerHTML = '';
      new QRCode(receiverQrcode, {
        text: b64,
        width: 512,
        height: 512,
        colorDark : "#000000",
        colorLight : "#ffffff",
        correctLevel : QRCode.CorrectLevel.L
      });
      
      stepReceiverInit.classList.add('hidden');
      stepReceiverAnswer.classList.remove('hidden');
      log('Response QR generated! Scan it with the sender laptop.', 'success');
    });

    await pc.setRemoteDescription(new RTCSessionDescription(offer));
    const answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);

  } catch (e) {
    log('Invalid invitation code. Try again.', 'error');
  }
}

btnAcceptOffer.addEventListener('click', () => {
  const offerStr = txtOfferPaste.value.trim();
  if (!offerStr) return log('Please paste an invitation link or code first!', 'error');
  processOffer(offerStr);
});

// Auto-process from URL hash
window.addEventListener('load', () => {
  if (window.location.hash.startsWith('#offer=')) {
    btnRoleReceiver.click();
    processOffer(window.location.hash);
  }
});

// -------------------------------------------------------------
// WEBRTC UTILITIES
// -------------------------------------------------------------
function setupIceGathering(peerConn, targetTextarea, onComplete) {
  let isComplete = false;
  
  const finishGathering = () => {
    if (isComplete) return;
    isComplete = true;
    
    // Attempt compression
    let b64;
    try {
      b64 = compressPayload(peerConn.localDescription);
    } catch (e) {
      console.error(e);
      // Fallback if pako fails
      b64 = btoa(JSON.stringify(peerConn.localDescription));
    }
    
    targetTextarea.value = b64;
    if (onComplete) onComplete();
  };

  peerConn.onicecandidate = (event) => {
    if (!event.candidate) {
      finishGathering();
    }
  };

  // Fallback timeout in case ICE gathering hangs or is blocked
  setTimeout(() => {
    if (peerConn.iceGatheringState !== 'complete') {
      console.log('ICE gathering timeout reached, using gathered candidates.');
      finishGathering();
    }
  }, 2000);
}

function setupDataChannelHandlers(channel) {
  channel.binaryType = 'arraybuffer';

  channel.onopen = () => {
    log('WebRTC Data Channel is open and connected!', 'success');
    statusDot.className = 'status-dot connected';
    statusText.innerText = 'Connected';
    
    connectionSection.classList.add('hidden');
    transferSection.classList.remove('hidden');

    if (isSender) {
      sendModule.classList.remove('hidden');
    }
  };

  channel.onclose = () => {
    log('Data Channel closed.', 'error');
    resetTransferState();
  };

  channel.onerror = (e) => {
    log(`Connection error: ${e.message}`, 'error');
  };

  channel.onmessage = (event) => {
    handleMessage(event.data);
  };
}

// -------------------------------------------------------------
// FILE STREAMING LOGIC (WebRTC Channels)
// -------------------------------------------------------------
function handleMessage(data) {
  if (typeof data === 'string') {
    // Received metadata
    fileMeta = JSON.parse(data);
    receivedChunks = [];
    receivedSize = 0;
    startTime = Date.now();
    
    lblFileName.innerText = fileMeta.name;
    lblFileSize.innerText = formatSize(fileMeta.size);
    progressModule.classList.remove('hidden');
    log(`Incoming file: ${fileMeta.name} (${formatSize(fileMeta.size)})`, 'info');
  } else {
    // Received chunk (ArrayBuffer)
    receivedChunks.push(data);
    receivedSize += data.byteLength;

    // Update progress bar
    const progress = fileMeta.size > 0 ? (receivedSize / fileMeta.size) : 0;
    progressBar.style.width = `${progress * 100}%`;
    lblPercentage.innerText = `${(progress * 100).toFixed(0)}%`;

    // Stats
    const elapsed = (Date.now() - startTime) / 1000;
    const speed = elapsed > 0 ? receivedSize / elapsed : 0;
    lblSpeed.innerText = `${(speed / (1024 * 1024)).toFixed(2)} MB/s`;

    const remainingBytes = fileMeta.size - receivedSize;
    const eta = speed > 0 ? Math.ceil(remainingBytes / speed) : 0;
    lblEta.innerText = formatEta(eta);

    if (receivedSize >= fileMeta.size) {
      log('File transfer completed. Assembling file...', 'success');
      assembleAndDownloadFile();
    }
  }
}

function assembleAndDownloadFile() {
  const blob = new Blob(receivedChunks);
  const url = URL.createObjectURL(blob);
  
  const a = document.createElement('a');
  a.href = url;
  a.download = fileMeta.name;
  a.click();
  
  URL.revokeObjectURL(url);
  log('File saved to Downloads folder!', 'success');
  
  resetTransferModule();
}

function sendFile(file) {
  activeFile = file;
  log(`Starting upload of ${file.name} (${formatSize(file.size)})`, 'info');
  
  // 1. Send metadata header
  const header = {
    name: file.name,
    size: file.size,
    type: file.type
  };
  dataChannel.send(JSON.stringify(header));

  // Initialize progress UI
  lblFileName.innerText = file.name;
  lblFileSize.innerText = formatSize(file.size);
  progressModule.classList.remove('hidden');
  sendModule.classList.add('hidden');
  
  let offset = 0;
  startTime = Date.now();

  const fileReader = new FileReader();

  fileReader.onload = (e) => {
    dataChannel.send(e.target.result);
    offset += e.target.result.byteLength;
    
    // Update progress bar
    const progress = file.size > 0 ? (offset / file.size) : 0;
    progressBar.style.width = `${progress * 100}%`;
    lblPercentage.innerText = `${(progress * 100).toFixed(0)}%`;

    // Stats
    const elapsed = (Date.now() - startTime) / 1000;
    const speed = elapsed > 0 ? offset / elapsed : 0;
    lblSpeed.innerText = `${(speed / (1024 * 1024)).toFixed(2)} MB/s`;

    const remainingBytes = file.size - offset;
    const eta = speed > 0 ? Math.ceil(remainingBytes / speed) : 0;
    lblEta.innerText = formatEta(eta);

    if (offset < file.size) {
      readNextChunk();
    } else {
      log('File sent successfully!', 'success');
      resetTransferModule();
    }
  };

  function readNextChunk() {
    // Flow control: WebRTC has a buffer limit. If we exceed it, pause and wait for buffer empty.
    if (dataChannel.bufferedAmount > MAX_BUFFERED_AMOUNT) {
      dataChannel.onbufferedamountlow = () => {
        dataChannel.onbufferedamountlow = null;
        readNextChunk();
      };
      return;
    }

    const slice = file.slice(offset, offset + CHUNK_SIZE);
    fileReader.readAsArrayBuffer(slice);
  }

  readNextChunk();
}

// -------------------------------------------------------------
// EVENT LISTENERS & UI HELPERS
// -------------------------------------------------------------
btnDisconnect.addEventListener('click', () => {
  if (pc) pc.close();
  resetTransferState();
  log('Disconnected.', 'error');
});

// File Drag & Drop Handlers
dropZone.addEventListener('click', () => fileInput.click());

fileInput.addEventListener('change', (e) => {
  if (e.target.files.length > 0) {
    sendFile(e.target.files[0]);
  }
});

dropZone.addEventListener('dragover', (e) => {
  e.preventDefault();
  dropZone.classList.add('dragover');
});

dropZone.addEventListener('dragleave', () => {
  dropZone.classList.remove('dragover');
});

dropZone.addEventListener('drop', (e) => {
  e.preventDefault();
  dropZone.classList.remove('dragover');
  if (e.dataTransfer.files.length > 0) {
    sendFile(e.dataTransfer.files[0]);
  }
});

function formatSize(bytes) {
  const mbs = bytes / (1024 * 1024);
  return `${mbs.toFixed(2)} MB`;
}

function formatEta(seconds) {
  if (seconds <= 0 || seconds >= 3600) return '--:--';
  const m = Math.floor(seconds / 60).toString().padLeft(2, '0');
  const s = (seconds % 60).toString().padLeft(2, '0');
  return `${m}:${s}`;
}

// polyfill
if (!String.prototype.padLeft) {
  String.prototype.padLeft = function(length, padChar) {
    let str = this;
    while (str.length < length) str = padChar + str;
    return str;
  };
}

function resetTransferModule() {
  setTimeout(() => {
    progressModule.classList.add('hidden');
    progressBar.style.width = '0%';
    lblPercentage.innerText = '0%';
    lblSpeed.innerText = '-- MB/s';
    lblEta.innerText = '--:--';
    if (isSender) {
      sendModule.classList.remove('hidden');
    }
  }, 3000);
}

function resetTransferState() {
  if (pc) {
    pc.close();
    pc = null;
  }
  dataChannel = null;
  activeFile = null;
  receivedChunks = [];
  receivedSize = 0;
  fileMeta = null;

  statusDot.className = 'status-dot';
  statusText.innerText = 'Disconnected';
  connectionSection.classList.remove('hidden');
  transferSection.classList.add('hidden');
  progressModule.classList.add('hidden');
  sendModule.classList.add('hidden');
  
  btnGenOffer.disabled = false;
  txtOffer.value = '';
  txtAnswerPaste.value = '';
  txtOfferPaste.value = '';
  txtAnswer.value = '';
  
  stepSenderInit.classList.remove('hidden');
  senderQrBox.classList.add('hidden');
  stepSenderAnswer.classList.add('hidden');
  
  stepReceiverInit.classList.remove('hidden');
  stepReceiverAnswer.classList.add('hidden');
  
  if (html5QrcodeScanner) {
    html5QrcodeScanner.clear();
    html5QrcodeScanner = null;
  }
  
  window.history.replaceState(null, null, ' ');
}
