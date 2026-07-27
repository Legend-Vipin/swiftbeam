use crate::frb_generated::StreamSink;
use anyhow::Result;
use lazy_static::lazy_static;
use std::path::PathBuf;
use tokio::sync::mpsc;

use swiftbeam_net::mdns::MdnsDiscovery;
use swiftbeam_net::quic::TransferEvent;
use swiftbeam_net::transport::TransportManager;

lazy_static! {
    static ref RUNTIME: tokio::runtime::Runtime = tokio::runtime::Builder::new_multi_thread()
        .enable_all()
        .build()
        .expect("Failed to build tokio runtime");
    static ref MDNS: std::sync::Mutex<Option<MdnsDiscovery>> = std::sync::Mutex::new(None);
    static ref TRANSPORT_MANAGER: tokio::sync::Mutex<TransportManager> =
        tokio::sync::Mutex::new(TransportManager::new());
}

#[derive(Clone, Debug, serde::Serialize, serde::Deserialize)]
pub struct DiscoveredPeerInfo {
    pub peer_id: String,
    pub device_name: String,
    pub ip_addresses: Vec<String>,
    pub port: u16,
}

#[derive(Clone, Debug, serde::Serialize, serde::Deserialize)]
#[serde(tag = "type")]
pub enum FfiTransferEvent {
    Started {
        transfer_id: String,
        file_name: String,
        total_size: u64,
    },
    Progress {
        transfer_id: String,
        bytes_transferred: u64,
        speed_bps: u64,
        eta_seconds: u64,
    },
    Completed {
        transfer_id: String,
    },
    Failed {
        transfer_id: String,
        error: String,
    },
}

// -------------------------------------------------------------
// MDNS FLOW
// -------------------------------------------------------------
pub fn init_peer(_device_name: String) -> Result<String> {
    let peer_id = uuid::Uuid::new_v4().to_string();
    let mut mdns_lock = MDNS.lock().unwrap();
    if mdns_lock.is_none() {
        let discovery = MdnsDiscovery::new()?;
        *mdns_lock = Some(discovery);
    }
    Ok(peer_id)
}

pub fn start_discovery(sink: StreamSink<String>) -> Result<()> {
    let (tx, mut rx) = mpsc::channel(100);

    {
        let mut mdns_lock = MDNS.lock().unwrap();
        if mdns_lock.is_none() {
            let discovery = MdnsDiscovery::new()?;
            *mdns_lock = Some(discovery);
        }
        if let Some(ref mdns_ref) = *mdns_lock {
            mdns_ref.start_browsing(tx)?;
        }
    }

    RUNTIME.spawn(async move {
        while let Some(peer) = rx.recv().await {
            let info = DiscoveredPeerInfo {
                peer_id: peer.peer_id,
                device_name: peer.device_name,
                ip_addresses: peer.ip_addresses,
                port: peer.port,
            };
            if let Ok(json_str) = serde_json::to_string(&info) {
                let _ = sink.add(json_str);
            }
        }
    });

    Ok(())
}

pub fn advertise_peer(peer_id: String, device_name: String, port: u16) -> Result<()> {
    let mut mdns_lock = MDNS.lock().unwrap();
    if mdns_lock.is_none() {
        let discovery = MdnsDiscovery::new()?;
        *mdns_lock = Some(discovery);
    }
    if let Some(ref mdns_ref) = *mdns_lock {
        mdns_ref.register_service(&peer_id, &device_name, port)?;
    }
    Ok(())
}

// -------------------------------------------------------------
// NEW QR BOOTSTRAP P2P FLOW
// -------------------------------------------------------------
pub fn start_qr_receiver(
    device_name: String,
    output_dir: String,
    sink: StreamSink<String>,
) -> Result<()> {
    let (event_tx, mut event_rx) = mpsc::channel(100);
    let sink_clone = sink.clone();

    RUNTIME.spawn(async move {
        // First: start the receiver and get QR JSON
        let qr_json = {
            let mut tm = TRANSPORT_MANAGER.lock().await;
            match tm
                .start_receiver(device_name, PathBuf::from(output_dir), event_tx)
                .await
            {
                Ok(qr) => match qr.to_json() {
                    Ok(json_str) => json_str,
                    Err(e) => {
                        let _ = sink_clone.add(
                            serde_json::to_string(&FfiTransferEvent::Failed {
                                transfer_id: "receiver_init".to_string(),
                                error: format!("QR serialization failed: {}", e),
                            })
                            .unwrap_or_default(),
                        );
                        return;
                    }
                },
                Err(e) => {
                    let _ = sink_clone.add(
                        serde_json::to_string(&FfiTransferEvent::Failed {
                            transfer_id: "receiver_init".to_string(),
                            error: format!("Receiver start failed: {}", e),
                        })
                        .unwrap_or_default(),
                    );
                    return;
                }
            }
        };

        // Send QR JSON as first event
        let _ = sink_clone.add(qr_json);

        // Then: forward transfer events
        while let Some(event) = event_rx.recv().await {
            let ffi_event = match event {
                TransferEvent::Started {
                    transfer_id,
                    file_name,
                    total_size,
                } => FfiTransferEvent::Started {
                    transfer_id,
                    file_name,
                    total_size,
                },
                TransferEvent::Progress {
                    transfer_id,
                    bytes_transferred,
                    speed_bps,
                    eta_seconds,
                } => FfiTransferEvent::Progress {
                    transfer_id,
                    bytes_transferred,
                    speed_bps,
                    eta_seconds,
                },
                TransferEvent::Completed { transfer_id } => {
                    FfiTransferEvent::Completed { transfer_id }
                }
                TransferEvent::Failed { transfer_id, error } => {
                    FfiTransferEvent::Failed { transfer_id, error }
                }
            };
            if let Ok(json_str) = serde_json::to_string(&ffi_event) {
                let _ = sink_clone.add(json_str);
            }
        }
    });
    Ok(())
}

pub fn connect_to_qr(qr_json: String, file_path: String, sink: StreamSink<String>) -> Result<()> {
    let (event_tx, mut event_rx) = mpsc::channel(100);

    let sink_clone = sink.clone();
    RUNTIME.spawn(async move {
        while let Some(event) = event_rx.recv().await {
            let ffi_event = match event {
                TransferEvent::Started {
                    transfer_id,
                    file_name,
                    total_size,
                } => FfiTransferEvent::Started {
                    transfer_id,
                    file_name,
                    total_size,
                },
                TransferEvent::Progress {
                    transfer_id,
                    bytes_transferred,
                    speed_bps,
                    eta_seconds,
                } => FfiTransferEvent::Progress {
                    transfer_id,
                    bytes_transferred,
                    speed_bps,
                    eta_seconds,
                },
                TransferEvent::Completed { transfer_id } => {
                    FfiTransferEvent::Completed { transfer_id }
                }
                TransferEvent::Failed { transfer_id, error } => {
                    FfiTransferEvent::Failed { transfer_id, error }
                }
            };
            if let Ok(json_str) = serde_json::to_string(&ffi_event) {
                let _ = sink_clone.add(json_str);
            }
        }
    });

    RUNTIME.spawn(async move {
        let res = {
            let mut tm = TRANSPORT_MANAGER.lock().await;
            tm.connect_to_qr(&qr_json, PathBuf::from(file_path), event_tx.clone())
                .await
        };
        if let Err(e) = res {
            let _ = event_tx
                .send(TransferEvent::Failed {
                    transfer_id: "error".to_string(),
                    error: e.to_string(),
                })
                .await;
        }
    });

    Ok(())
}
