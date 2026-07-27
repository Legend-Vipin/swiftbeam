use std::fs::File;
use std::io::Write;
use swiftbeam_core::chunker::{
    generate_manifest, stream_file_chunks, write_chunk, TransferCheckpoint, CHUNK_SIZE,
};
use tempfile::tempdir;
use tokio::sync::mpsc;

#[tokio::test]
async fn test_manifest_and_chunk_streaming() {
    let dir = tempdir().unwrap();
    let file_path = dir.path().join("test_file.bin");

    // Write exactly 2.5 MB of data
    let data_len = (2.5 * CHUNK_SIZE as f64) as usize;
    let original_data: Vec<u8> = (0..data_len).map(|i| (i % 256) as u8).collect();
    {
        let mut file = File::create(&file_path).unwrap();
        file.write_all(&original_data).unwrap();
    }

    // Generate manifest
    let manifest = generate_manifest(&file_path).unwrap();
    assert_eq!(manifest.file_name, "test_file.bin");
    assert_eq!(manifest.file_size, data_len as u64);
    assert_eq!(manifest.chunk_hashes.len(), 3); // 1MB, 1MB, 0.5MB

    // Stream chunks
    let (tx, mut rx) = mpsc::channel(10);
    stream_file_chunks(file_path.clone(), vec![0, 1, 2], tx).await;

    let mut chunks = Vec::new();
    while let Some(res) = rx.recv().await {
        chunks.push(res.unwrap());
    }

    assert_eq!(chunks.len(), 3);
    assert_eq!(chunks[0].index, 0);
    assert_eq!(chunks[0].data.len(), CHUNK_SIZE);
    assert_eq!(chunks[2].index, 2);
    assert_eq!(chunks[2].data.len(), CHUNK_SIZE / 2);

    // Verify chunk hash
    let expected_hash_0 = &manifest.chunk_hashes[0];
    let computed_hash_0 = blake3::hash(&chunks[0].data).to_hex().to_string();
    assert_eq!(expected_hash_0, &computed_hash_0);
}

#[test]
fn test_checkpoint_and_resume() {
    let dir = tempdir().unwrap();
    let checkpoint_path = dir.path().join("transfer.swiftbeam");
    let temp_file_path = dir.path().join("target_file.bin.part");

    let manifest = swiftbeam_core::chunker::TransferManifest {
        file_name: "example.txt".to_string(),
        file_size: 3000000,
        chunk_hashes: vec!["h0".to_string(), "h1".to_string(), "h2".to_string()],
    };

    let mut checkpoint = TransferCheckpoint::new(
        manifest.clone(),
        temp_file_path.to_str().unwrap().to_string(),
    );
    assert_eq!(checkpoint.get_missing_chunks(), vec![0, 1, 2]);

    checkpoint.completed_chunks.insert(0);
    checkpoint.completed_chunks.insert(2);
    assert_eq!(checkpoint.get_missing_chunks(), vec![1]);

    checkpoint.save_to_file(&checkpoint_path).unwrap();

    let loaded = TransferCheckpoint::load_from_file(&checkpoint_path).unwrap();
    assert_eq!(loaded.file_name, "example.txt");
    assert_eq!(loaded.completed_chunks.len(), 2);
    assert_eq!(loaded.get_missing_chunks(), vec![1]);
}

#[test]
fn test_write_chunk_offset() {
    let dir = tempdir().unwrap();
    let temp_file_path = dir.path().join("dest_file.bin");

    let data_0 = vec![1u8; CHUNK_SIZE];
    let data_2 = vec![3u8; CHUNK_SIZE / 2];

    let hash_0 = blake3::hash(&data_0).to_hex().to_string();
    let hash_2 = blake3::hash(&data_2).to_hex().to_string();

    // Write chunk 0
    write_chunk(&temp_file_path, 0, &data_0, &hash_0).unwrap();
    // Write chunk 2 (leaves a gap where chunk 1 should be)
    write_chunk(&temp_file_path, 2, &data_2, &hash_2).unwrap();

    // Read and verify file contents
    let file_data = std::fs::read(&temp_file_path).unwrap();
    // Size should be: chunk 0 (1MB) + chunk 1 (empty 1MB) + chunk 2 (0.5MB) = 2.5MB
    assert_eq!(file_data.len(), CHUNK_SIZE * 2 + CHUNK_SIZE / 2);
    assert_eq!(file_data[0], 1);
    assert_eq!(file_data[CHUNK_SIZE], 0); // Unwritten gap should be 0s
    assert_eq!(file_data[CHUNK_SIZE * 2], 3);
}
