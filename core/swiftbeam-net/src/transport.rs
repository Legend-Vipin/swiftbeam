use anyhow::Result;
use std::net::SocketAddr;
use std::path::PathBuf;
use tokio::sync::mpsc;
use tracing::{info, warn};

use crate::qr::QrBootstrap;
use crate::quic::{start_receiver_server, start_sender_client, TransferEvent};
use base64::{engine::general_purpose::STANDARD as b64, Engine as _};
use swiftbeam_crypto::generate_keypair;
use x25519_dalek::PublicKey;

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum TransportType {
    BleAndWifiLan,
    SameWifi,
    WifiDirect,
    Hotspot,
}

pub struct TransportManager {
    pub transport_type: Option<TransportType>,
    pub listen_port: Option<u16>,
    _stop_tx: Option<mpsc::Sender<()>>,
}

impl Default for TransportManager {
    fn default() -> Self {
        Self::new()
    }
}

impl TransportManager {
    pub fn new() -> Self {
        Self {
            transport_type: None,
            listen_port: None,
            _stop_tx: None,
        }
    }

    /// Starts the Receiver flow.
    /// 1. Generates local ECDH Keypair.
    /// 2. Starts QUIC Server to listen for sender.
    /// 3. Generates QR Bootstrap data with the Public Key.
    pub async fn start_receiver(
        &mut self,
        device_id: String,
        output_dir: PathBuf,
        event_tx: mpsc::Sender<TransferEvent>,
    ) -> Result<QrBootstrap> {
        info!("Starting Receiver transport layer...");

        // 1. Generate local ECDH Keypair
        let (my_secret, my_public) = generate_keypair();
        let pub_key_b64 = b64.encode(my_public.as_bytes());

        // 2. Start QUIC Server on random port
        let bind_addr = SocketAddr::from(([0, 0, 0, 0], 0));
        let (stop_tx, stop_rx) = mpsc::channel(1);

        let port =
            start_receiver_server(bind_addr, output_dir, my_secret, stop_rx, event_tx).await?;

        self.listen_port = Some(port);
        self._stop_tx = Some(stop_tx);

        // 3. Get actual LAN IP Address (resolving interface instead of loopback)
        let local_ip = Some(resolve_local_ip());

        // 4. Generate QR Code payload
        let qr = QrBootstrap::new(
            device_id,
            local_ip,
            port,
            pub_key_b64,
            600, // 10 minutes expiry
        );

        info!("Receiver ready. QR generated: session {}", qr.session);

        // TODO: Start BLE Advertising with `qr.token` and `qr.session`

        Ok(qr)
    }

    /// Starts the Sender flow after scanning a QR code.
    pub async fn connect_to_qr(
        &mut self,
        qr_json: &str,
        file_path: PathBuf,
        event_tx: mpsc::Sender<TransferEvent>,
    ) -> Result<()> {
        info!("Parsing QR payload...");
        let qr = QrBootstrap::from_json(qr_json).map_err(|e| anyhow::anyhow!(e))?;

        info!(
            "Connecting to session {} on device {}",
            qr.session, qr.device_id
        );

        // Decode Receiver Public Key (optional - skip pinning if empty)
        let pinned_pub = if !qr.pub_key.is_empty() {
            match b64.decode(&qr.pub_key) {
                Ok(bytes) if bytes.len() == 32 => {
                    let mut pub_bytes = [0u8; 32];
                    pub_bytes.copy_from_slice(&bytes);
                    Some(PublicKey::from(pub_bytes))
                }
                _ => {
                    info!("No valid pinned public key in QR, relying on in-band key exchange");
                    None
                }
            }
        } else {
            info!("Empty pub_key in QR payload, skipping pin verification");
            None
        };

        // Transport Negotiation (Priority Queue)

        // Priority 1: Same Wi-Fi (Direct QUIC)
        if let Some(ip) = qr.ip {
            info!("Attempting Priority 1: Same Wi-Fi (IP: {}:{})", ip, qr.port);
            let server_addr: SocketAddr = format!("{}:{}", ip, qr.port).parse()?;

            // Initiate the sender client over QUIC
            start_sender_client(server_addr, file_path, pinned_pub, event_tx).await?;

            self.transport_type = Some(TransportType::SameWifi);
            info!("Transfer completed via Same Wi-Fi.");
            return Ok(());
        }

        // Priority 2: BLE (TODO)
        warn!("Same Wi-Fi failed or IP unavailable. Falling back to BLE discovery...");

        Err(anyhow::anyhow!("All transports failed"))
    }
}

fn resolve_local_ip() -> String {
    // Strategy 1: UDP connect trick (works when any gateway is reachable)
    let targets = ["1.1.1.1:80", "192.168.1.1:80", "10.0.0.1:80", "8.8.8.8:80"];
    for target in targets {
        if let Ok(socket) = std::net::UdpSocket::bind("0.0.0.0:0") {
            if socket.connect(target).is_ok() {
                if let Ok(addr) = socket.local_addr() {
                    let ip = addr.ip();
                    if !ip.is_loopback() && !ip.is_unspecified() {
                        return ip.to_string();
                    }
                }
            }
        }
    }

    // Strategy 2: Enumerate network interfaces directly (offline networks)
    if let Ok(interfaces) = if_addrs::get_if_addrs() {
        for iface in interfaces {
            if iface.is_loopback() {
                continue;
            }
            if let std::net::IpAddr::V4(v4) = iface.ip() {
                if !v4.is_loopback() && !v4.is_link_local() && !v4.is_unspecified() {
                    return v4.to_string();
                }
            }
        }
    }

    "127.0.0.1".to_string()
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;

    #[tokio::test]
    async fn test_transport_manager_qr_generation_and_parsing() {
        let mut tm = TransportManager::new();
        let (tx, _rx) = mpsc::channel(100);
        let output_dir = tempdir().unwrap().path().to_path_buf();

        let qr = tm
            .start_receiver("TestDevice".to_string(), output_dir, tx)
            .await
            .unwrap();

        assert_eq!(qr.device_id, "TestDevice");
        assert_eq!(qr.session.len(), 16);
        assert_eq!(qr.token.len(), 32);
        assert!(qr.port > 0);
        assert_eq!(qr.version, "1.0");

        let json = qr.to_json().unwrap();
        assert!(json.contains("TestDevice"));

        let parsed_qr = QrBootstrap::from_json(&json).unwrap();
        assert_eq!(parsed_qr.session, qr.session);
    }
}
