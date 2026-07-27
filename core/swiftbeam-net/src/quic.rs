use anyhow::Result;
use quinn::{ClientConfig, Endpoint, ServerConfig};
use rcgen::generate_simple_self_signed;
use rustls::client::danger::{HandshakeSignatureValid, ServerCertVerified, ServerCertVerifier};
use rustls::pki_types::{CertificateDer, ServerName, UnixTime};
use rustls::{DigitallySignedStruct, SignatureScheme};
use std::net::SocketAddr;
use std::path::PathBuf;
use std::sync::Arc;
use std::time::Instant;
use swiftbeam_core::chunker::{
    generate_manifest, write_chunk, TransferCheckpoint, TransferManifest, CHUNK_SIZE,
};
use swiftbeam_crypto::{
    compute_shared_secret, decrypt_chunk, derive_symmetric_key, encrypt_chunk, generate_keypair,
};
use tokio::io::AsyncWriteExt;
use tokio::sync::mpsc;
use tokio::sync::Mutex;
use x25519_dalek::{PublicKey, StaticSecret};

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub enum TransferEvent {
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

#[derive(Debug)]
struct SkipServerVerification;

impl ServerCertVerifier for SkipServerVerification {
    fn verify_server_cert(
        &self,
        _end_entity: &CertificateDer<'_>,
        _intermediates: &[CertificateDer<'_>],
        _server_name: &ServerName<'_>,
        _ocsp_response: &[u8],
        _now: UnixTime,
    ) -> Result<ServerCertVerified, rustls::Error> {
        Ok(ServerCertVerified::assertion())
    }

    fn verify_tls12_signature(
        &self,
        _message: &[u8],
        _cert: &CertificateDer<'_>,
        _dss: &DigitallySignedStruct,
    ) -> Result<HandshakeSignatureValid, rustls::Error> {
        Ok(HandshakeSignatureValid::assertion())
    }

    fn verify_tls13_signature(
        &self,
        _message: &[u8],
        _cert: &CertificateDer<'_>,
        _dss: &DigitallySignedStruct,
    ) -> Result<HandshakeSignatureValid, rustls::Error> {
        Ok(HandshakeSignatureValid::assertion())
    }

    fn supported_verify_schemes(&self) -> Vec<SignatureScheme> {
        vec![
            SignatureScheme::ECDSA_NISTP256_SHA256,
            SignatureScheme::ED25519,
            SignatureScheme::RSA_PSS_SHA256,
        ]
    }
}

/// Robust file move helper: attempts atomic rename, falling back to copy+delete for cross-filesystem (EXDEV) edge-cases.
fn finalize_received_file(temp_path: &std::path::Path, final_path: &std::path::Path) -> Result<()> {
    if let Some(parent) = final_path.parent() {
        let _ = std::fs::create_dir_all(parent);
    }
    if final_path.exists() {
        let _ = std::fs::remove_file(final_path);
    }
    if std::fs::rename(temp_path, final_path).is_err() {
        std::fs::copy(temp_path, final_path)?;
        let _ = std::fs::remove_file(temp_path);
    }
    Ok(())
}

pub fn get_quic_server_config() -> Result<ServerConfig> {
    rustls::crypto::ring::default_provider()
        .install_default()
        .ok();
    let cert = generate_simple_self_signed(vec!["localhost".to_string(), "127.0.0.1".to_string()])?;
    let cert_der = cert.cert.der().to_vec();
    let key_der = cert.key_pair.serialize_der();

    let certificate = CertificateDer::from(cert_der);
    let private_key = rustls::pki_types::PrivateKeyDer::Pkcs8(
        rustls::pki_types::PrivatePkcs8KeyDer::from(key_der),
    );

    let mut server_crypto = rustls::ServerConfig::builder()
        .with_no_client_auth()
        .with_single_cert(vec![certificate], private_key)?;
    server_crypto.alpn_protocols = vec![b"swiftbeam".to_vec()];

    let mut server_config = ServerConfig::with_crypto(Arc::new(
        quinn::crypto::rustls::QuicServerConfig::try_from(server_crypto)?,
    ));
    let mut transport_config = quinn::TransportConfig::default();
    transport_config.max_concurrent_uni_streams(100u32.into());
    transport_config.max_concurrent_bidi_streams(100u32.into());
    transport_config.max_idle_timeout(Some(std::time::Duration::from_secs(60).try_into().unwrap()));
    server_config.transport_config(Arc::new(transport_config));

    Ok(server_config)
}

pub fn get_quic_client_config() -> ClientConfig {
    rustls::crypto::ring::default_provider()
        .install_default()
        .ok();
    let mut client_crypto = rustls::ClientConfig::builder()
        .dangerous()
        .with_custom_certificate_verifier(Arc::new(SkipServerVerification))
        .with_no_client_auth();

    client_crypto.alpn_protocols = vec![b"swiftbeam".to_vec()];

    let mut config = ClientConfig::new(Arc::new(
        quinn::crypto::rustls::QuicClientConfig::try_from(client_crypto).unwrap(),
    ));
    let mut transport = quinn::TransportConfig::default();
    transport.max_concurrent_bidi_streams(100u32.into());
    transport.max_concurrent_uni_streams(100u32.into());
    transport.max_idle_timeout(Some(std::time::Duration::from_secs(60).try_into().unwrap()));
    config.transport_config(Arc::new(transport));

    config
}

// =====================================================================
// RECEIVER (SERVER)
// =====================================================================
/// Runs the Receiver server. It listens for the Sender, performs the OOB handshake,
/// receives the manifest, and requests missing chunks.
pub async fn start_receiver_server(
    bind_addr: SocketAddr,
    output_dir: PathBuf,
    my_secret: StaticSecret, // Received from TransportManager
    mut stop_rx: mpsc::Receiver<()>,
    event_tx: mpsc::Sender<TransferEvent>,
) -> Result<u16> {
    let server_config = get_quic_server_config()?;
    let endpoint = Endpoint::server(server_config, bind_addr)?;
    let local_port = endpoint.local_addr()?.port();

    let output_dir = Arc::new(output_dir);
    let secret_bytes = my_secret.to_bytes();
    let my_secret = Arc::new(tokio::sync::Mutex::new(secret_bytes));

    tokio::spawn(async move {
        tokio::select! {
            _ = async {
                while let Some(incoming) = endpoint.accept().await {
                    if let Ok(conn) = incoming.accept() {
                        let output_dir = Arc::clone(&output_dir);
                        let event_tx = event_tx.clone();
                        let secret_lock = Arc::clone(&my_secret);

                        tokio::spawn(async move {
                            // Extract the static secret for this connection
                            let secret_bytes = {
                                let s = secret_lock.lock().await;
                                *s
                            };
                            let sec = StaticSecret::from(secret_bytes);

                            if let Err(e) = handle_incoming_connection(conn, output_dir.to_path_buf(), sec, event_tx).await {
                                eprintln!("Receiver failed to handle connection: {:?}", e);
                            }
                        });
                    }
                }
            } => {}
            _ = stop_rx.recv() => {
                endpoint.close(0u32.into(), b"stopped");
            }
        }
    });

    Ok(local_port)
}

async fn handle_incoming_connection(
    conn: quinn::Connecting,
    output_dir: PathBuf,
    my_secret: StaticSecret,
    event_tx: mpsc::Sender<TransferEvent>,
) -> Result<()> {
    let connection = conn.await?;
    let transfer_id = format!("tx-{}", uuid::Uuid::new_v4());

    // 1. Accept Handshake stream
    let (mut send, mut recv) = connection.accept_bi().await?;

    // Write my public key in-band
    let my_public = PublicKey::from(&my_secret);
    send.write_all(my_public.as_bytes()).await?;
    send.flush().await?;

    // Read Sender's Public Key
    let mut sender_public_bytes = [0u8; 32];
    recv.read_exact(&mut sender_public_bytes).await?;
    let sender_public = PublicKey::from(sender_public_bytes);

    // Compute AES Session Key
    let shared = compute_shared_secret(&my_secret, &sender_public);
    let symmetric_key = derive_symmetric_key(&shared);

    // 2. Read Manifest
    let mut len_bytes = [0u8; 4];
    recv.read_exact(&mut len_bytes).await?;
    let enc_manifest_len = u32::from_be_bytes(len_bytes) as usize;

    let mut enc_manifest = vec![0u8; enc_manifest_len];
    recv.read_exact(&mut enc_manifest).await?;

    let dec_manifest_bytes = decrypt_chunk(&symmetric_key, u64::MAX, &enc_manifest)?;
    let manifest: TransferManifest = serde_json::from_slice(&dec_manifest_bytes)?;

    // 3. Setup files and checkpoint
    std::fs::create_dir_all(&output_dir)?;
    let temp_file_path = output_dir.join(format!("{}.part", manifest.file_name));
    let checkpoint_path = output_dir.join(format!("{}.swiftbeam", manifest.file_name));

    let checkpoint = if checkpoint_path.exists() {
        match TransferCheckpoint::load_from_file(&checkpoint_path) {
            Ok(cp) => cp,
            Err(_) => TransferCheckpoint::new(
                manifest.clone(),
                temp_file_path.to_str().unwrap().to_string(),
            ),
        }
    } else {
        TransferCheckpoint::new(
            manifest.clone(),
            temp_file_path.to_str().unwrap().to_string(),
        )
    };

    let checkpoint = Arc::new(Mutex::new(checkpoint));

    let _ = event_tx
        .send(TransferEvent::Started {
            transfer_id: transfer_id.clone(),
            file_name: manifest.file_name.clone(),
            total_size: manifest.file_size,
        })
        .await;

    // Prefill file size
    {
        let file = std::fs::OpenOptions::new()
            .write(true)
            .create(true)
            .truncate(false)
            .open(&temp_file_path)?;
        file.set_len(manifest.file_size)?;
    }

    let missing_chunks = checkpoint.lock().await.get_missing_chunks();
    if missing_chunks.is_empty() {
        let final_path = output_dir.join(&manifest.file_name);
        finalize_received_file(&temp_file_path, &final_path)?;
        let _ = checkpoint_path.exists() && std::fs::remove_file(&checkpoint_path).is_ok();
        let _ = event_tx
            .send(TransferEvent::Completed { transfer_id })
            .await;
        return Ok(());
    }

    let start_time = Instant::now();
    let bytes_completed = Arc::new(Mutex::new(
        (manifest.chunk_hashes.len() - missing_chunks.len()) as u64 * CHUNK_SIZE as u64,
    ));

    // 4. Request chunks in parallel
    let semaphore = Arc::new(tokio::sync::Semaphore::new(10));
    let mut tasks = vec![];

    for chunk_index in missing_chunks {
        let connection = connection.clone();
        let expected_hash = manifest.chunk_hashes[chunk_index as usize].clone();
        let temp_file_path = temp_file_path.clone();
        let checkpoint = Arc::clone(&checkpoint);
        let sem = Arc::clone(&semaphore);
        let event_tx = event_tx.clone();
        let transfer_id = transfer_id.clone();
        let bytes_completed = Arc::clone(&bytes_completed);
        let total_size = manifest.file_size;
        let checkpoint_path = checkpoint_path.clone();

        let permit = sem.acquire_owned().await?;
        tasks.push(tokio::spawn(async move {
            let _permit = permit;
            let mut retries = 3;
            let mut success = false;
            let mut last_error = String::new();

            while retries > 0 && !success {
                let res = async {
                    let (mut c_send, mut c_recv) = connection.open_bi().await?;
                    // Request the chunk
                    c_send.write_all(&chunk_index.to_be_bytes()).await?;
                    c_send.flush().await?;

                    // Read the chunk
                    let mut len_bytes = [0u8; 4];
                    c_recv.read_exact(&mut len_bytes).await?;
                    let enc_len = u32::from_be_bytes(len_bytes) as usize;

                    let mut ciphertext = vec![0u8; enc_len];
                    c_recv.read_exact(&mut ciphertext).await?;

                    let plaintext = decrypt_chunk(&symmetric_key, chunk_index, &ciphertext)?;
                    write_chunk(&temp_file_path, chunk_index, &plaintext, &expected_hash)?;

                    // Update progress
                    let mut cp = checkpoint.lock().await;
                    cp.completed_chunks.insert(chunk_index);
                    cp.save_to_file(&checkpoint_path)?;

                    let mut bc = bytes_completed.lock().await;
                    *bc = std::cmp::min(*bc + plaintext.len() as u64, total_size);

                    let elapsed = start_time.elapsed().as_secs_f64();
                    let speed = if elapsed > 0.0 {
                        (*bc as f64 / elapsed) as u64
                    } else {
                        0
                    };
                    let remaining = total_size.saturating_sub(*bc);
                    let eta = remaining.checked_div(speed).unwrap_or(0);

                    let _ = event_tx
                        .send(TransferEvent::Progress {
                            transfer_id: transfer_id.clone(),
                            bytes_transferred: *bc,
                            speed_bps: speed,
                            eta_seconds: eta,
                        })
                        .await;

                    Ok::<(), anyhow::Error>(())
                }
                .await;

                match res {
                    Ok(_) => {
                        success = true;
                    }
                    Err(e) => {
                        last_error = e.to_string();
                        retries -= 1;
                    }
                }
            }

            if !success {
                let _ = event_tx
                    .send(TransferEvent::Failed {
                        transfer_id,
                        error: format!(
                            "Chunk {} failed after retries: {}",
                            chunk_index, last_error
                        ),
                    })
                    .await;
            }
        }));
    }

    for task in tasks {
        let _ = task.await;
    }

    // Finalize
    let final_missing = checkpoint.lock().await.get_missing_chunks();
    if final_missing.is_empty() {
        let final_path = output_dir.join(&manifest.file_name);
        finalize_received_file(&temp_file_path, &final_path)?;
        let _ = std::fs::remove_file(&checkpoint_path);
        let _ = event_tx
            .send(TransferEvent::Completed { transfer_id })
            .await;
    } else {
        let _ = event_tx
            .send(TransferEvent::Failed {
                transfer_id,
                error: "Incomplete transfer".to_string(),
            })
            .await;
    }

    Ok(())
}

// =====================================================================
// SENDER (CLIENT)
// =====================================================================
/// Initiates a transfer to a Receiver. Scans QR, negotiates transport, and sends the file.
pub async fn start_sender_client(
    server_addr: SocketAddr,
    file_path: PathBuf,
    pinned_pub_key: Option<PublicKey>,
    event_tx: mpsc::Sender<TransferEvent>,
) -> Result<()> {
    let client_config = get_quic_client_config();
    let mut endpoint = Endpoint::client(SocketAddr::from(([0, 0, 0, 0], 0)))?;
    endpoint.set_default_client_config(client_config);

    let connection = endpoint.connect(server_addr, "localhost")?.await?;

    let transfer_id = format!("tx-{}", uuid::Uuid::new_v4());

    // 1. Perform Handshake
    let (mut send, mut recv) = connection.open_bi().await?;
    let (my_secret, my_public) = generate_keypair();

    // Write my public key in-band
    send.write_all(my_public.as_bytes()).await?;
    send.flush().await?;

    // Read Receiver's public key in-band
    let mut receiver_public_bytes = [0u8; 32];
    recv.read_exact(&mut receiver_public_bytes).await?;
    let receiver_public = PublicKey::from(receiver_public_bytes);

    // Pin verify if requested
    if let Some(pinned) = pinned_pub_key {
        if receiver_public != pinned {
            return Err(anyhow::anyhow!(
                "MITM detected: Receiver public key mismatch"
            ));
        }
    }

    let shared = compute_shared_secret(&my_secret, &receiver_public);
    let symmetric_key = derive_symmetric_key(&shared);

    // 2. Generate and Send Manifest
    let manifest = generate_manifest(&file_path)?;
    let manifest_bytes = serde_json::to_vec(&manifest)?;
    let encrypted_manifest = encrypt_chunk(&symmetric_key, u64::MAX, &manifest_bytes)?;

    send.write_all(&(encrypted_manifest.len() as u32).to_be_bytes())
        .await?;
    send.write_all(&encrypted_manifest).await?;
    send.flush().await?;

    let _ = event_tx
        .send(TransferEvent::Started {
            transfer_id: transfer_id.clone(),
            file_name: manifest.file_name.clone(),
            total_size: manifest.file_size,
        })
        .await;

    // 3. Keep file mapped for serving chunks
    let file = std::fs::File::open(&file_path)?;
    let mmap = unsafe { memmap2::Mmap::map(&file)? };
    let mmap = Arc::new(mmap);

    let total_size = mmap.len() as u64;
    let bytes_sent = Arc::new(Mutex::new(0u64));
    let start_time = Instant::now();

    // 4. Accept chunk requests from Receiver
    while let Ok((mut c_send, mut c_recv)) = connection.accept_bi().await {
        let mmap = Arc::clone(&mmap);
        let event_tx = event_tx.clone();
        let transfer_id = transfer_id.clone();
        let bytes_sent = Arc::clone(&bytes_sent);

        tokio::spawn(async move {
            let mut idx_bytes = [0u8; 8];
            if c_recv.read_exact(&mut idx_bytes).await.is_ok() {
                let chunk_index = u64::from_be_bytes(idx_bytes);
                let start = chunk_index as usize * CHUNK_SIZE;
                if start < mmap.len() {
                    let end = std::cmp::min(start + CHUNK_SIZE, mmap.len());
                    let plain_chunk = &mmap[start..end];

                    if let Ok(encrypted) = encrypt_chunk(&symmetric_key, chunk_index, plain_chunk) {
                        let len_bytes = (encrypted.len() as u32).to_be_bytes();
                        if c_send.write_all(&len_bytes).await.is_ok()
                            && c_send.write_all(&encrypted).await.is_ok()
                        {
                            let mut bs = bytes_sent.lock().await;
                            *bs = std::cmp::min(*bs + plain_chunk.len() as u64, total_size);

                            let elapsed = start_time.elapsed().as_secs_f64();
                            let speed = if elapsed > 0.0 {
                                (*bs as f64 / elapsed) as u64
                            } else {
                                0
                            };
                            let remaining = total_size.saturating_sub(*bs);
                            let eta = remaining.checked_div(speed).unwrap_or(0);

                            let _ = event_tx
                                .send(TransferEvent::Progress {
                                    transfer_id: transfer_id.clone(),
                                    bytes_transferred: *bs,
                                    speed_bps: speed,
                                    eta_seconds: eta,
                                })
                                .await;

                            if *bs >= total_size {
                                let _ = event_tx
                                    .send(TransferEvent::Completed { transfer_id })
                                    .await;
                            }
                        }
                    }
                }
            }
        });
    }

    Ok(())
}
