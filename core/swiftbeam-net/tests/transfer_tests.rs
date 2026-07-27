use std::fs::File;
use std::io::Write;
use swiftbeam_net::quic::TransferEvent;
use swiftbeam_net::transport::TransportManager;
use tempfile::tempdir;
use tokio::sync::mpsc;

#[tokio::test]
async fn test_end_to_end_transport_manager_transfer() {
    let dir = tempdir().unwrap();
    let src_file_path = dir.path().join("source.bin");
    let dest_dir = dir.path().join("dest");
    std::fs::create_dir(&dest_dir).unwrap();

    // Create a 2.5 MB source file
    let file_size = (2.5 * 1024.0 * 1024.0) as usize;
    let data: Vec<u8> = (0..file_size).map(|i| (i % 256) as u8).collect();
    {
        let mut file = File::create(&src_file_path).unwrap();
        file.write_all(&data).unwrap();
    }

    let (event_tx, mut event_rx) = mpsc::channel(100);

    // 1. Start Receiver TransportManager
    let mut receiver_tm = TransportManager::new();
    let qr = receiver_tm
        .start_receiver("TestDevice".to_string(), dest_dir.clone(), event_tx.clone())
        .await
        .unwrap();
    let qr_json = qr.to_json().unwrap();

    // 2. Start Sender TransportManager
    let mut sender_tm = TransportManager::new();
    let transfer_handle = tokio::spawn(async move {
        sender_tm
            .connect_to_qr(&qr_json, src_file_path.clone(), event_tx)
            .await
    });

    // 3. Collect events
    let mut started = false;
    let mut completed = false;
    let mut progresses = 0;

    while let Some(event) = event_rx.recv().await {
        match event {
            TransferEvent::Started {
                file_name,
                total_size,
                ..
            } => {
                assert_eq!(file_name, "source.bin");
                assert_eq!(total_size, file_size as u64);
                started = true;
            }
            TransferEvent::Progress {
                bytes_transferred, ..
            } => {
                assert!(bytes_transferred <= file_size as u64);
                progresses += 1;
            }
            TransferEvent::Completed { .. } => {
                completed = true;
                break;
            }
            TransferEvent::Failed { error, .. } => {
                panic!("Transfer failed with error: {}", error);
            }
        }
    }

    transfer_handle.await.unwrap().unwrap();

    assert!(started, "Transfer should have started");
    assert!(completed, "Transfer should have completed");
    assert!(progresses > 0, "Should have received progress events");

    // Verify downloaded file content
    let downloaded_path = dest_dir.join("source.bin");
    assert!(downloaded_path.exists());
    let downloaded_data = std::fs::read(&downloaded_path).unwrap();
    assert_eq!(downloaded_data, data);
}
