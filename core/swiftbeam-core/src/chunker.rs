use memmap2::Mmap;
use serde::{Deserialize, Serialize};
use std::collections::HashSet;
use std::fs::File;
use std::io::{Seek, SeekFrom, Write};
use std::path::{Path, PathBuf};
use thiserror::Error;
use tokio::sync::mpsc;

pub const CHUNK_SIZE: usize = 1024 * 1024; // 1MB

#[derive(Error, Debug)]
pub enum ChunkerError {
    #[error("I/O error: {0}")]
    Io(#[from] std::io::Error),
    #[error("Serialization error: {0}")]
    Serialization(String),
    #[error("Invalid chunk index: {0}")]
    InvalidChunkIndex(u64),
    #[error("Hash mismatch for chunk {index}: expected {expected}, actual {actual}")]
    HashMismatch {
        index: u64,
        expected: String,
        actual: String,
    },
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct TransferManifest {
    pub file_name: String,
    pub file_size: u64,
    pub chunk_hashes: Vec<String>, // Hex-encoded BLAKE3 hashes
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TransferCheckpoint {
    pub file_name: String,
    pub file_size: u64,
    pub chunk_hashes: Vec<String>,
    pub completed_chunks: HashSet<u64>,
    pub temp_file_path: String,
}

pub struct Chunk {
    pub index: u64,
    pub data: Vec<u8>,
    pub hash: String,
}

/// Generates a manifest for a file, memory-mapping it and hashing in parallel.
pub fn generate_manifest(file_path: &Path) -> Result<TransferManifest, ChunkerError> {
    let file = File::open(file_path)?;
    let metadata = file.metadata()?;
    let file_size = metadata.len();

    let file_name = file_path
        .file_name()
        .and_then(|n| n.to_str())
        .unwrap_or("unknown")
        .to_string();

    if file_size == 0 {
        return Ok(TransferManifest {
            file_name,
            file_size,
            chunk_hashes: Vec::new(),
        });
    }

    let mmap = unsafe { Mmap::map(&file)? };
    let num_chunks = file_size.div_ceil(CHUNK_SIZE as u64) as usize;

    use rayon::prelude::*;
    let chunk_hashes: Vec<String> = (0..num_chunks)
        .into_par_iter()
        .map(|i| {
            let start = i * CHUNK_SIZE;
            let end = std::cmp::min(start + CHUNK_SIZE, file_size as usize);
            let chunk_slice = &mmap[start..end];
            let hash = blake3::hash(chunk_slice);
            hash.to_hex().to_string()
        })
        .collect();

    Ok(TransferManifest {
        file_name,
        file_size,
        chunk_hashes,
    })
}

/// Reads requested chunks from a file asynchronously and sends them via an mpsc channel.
pub async fn stream_file_chunks(
    file_path: PathBuf,
    chunk_indices: Vec<u64>,
    sender: mpsc::Sender<Result<Chunk, ChunkerError>>,
) {
    tokio::task::spawn_blocking(move || {
        let file = match File::open(&file_path) {
            Ok(f) => f,
            Err(e) => {
                let _ = sender.blocking_send(Err(ChunkerError::Io(e)));
                return;
            }
        };
        let mmap = match unsafe { Mmap::map(&file) } {
            Ok(m) => m,
            Err(e) => {
                let _ = sender.blocking_send(Err(ChunkerError::Io(e)));
                return;
            }
        };
        let file_size = mmap.len() as u64;

        for idx in chunk_indices {
            let start = idx as usize * CHUNK_SIZE;
            if start >= file_size as usize {
                let _ = sender.blocking_send(Err(ChunkerError::InvalidChunkIndex(idx)));
                return;
            }
            let end = std::cmp::min(start + CHUNK_SIZE, file_size as usize);
            let chunk_data = mmap[start..end].to_vec();
            let hash = blake3::hash(&chunk_data).to_hex().to_string();

            if sender
                .blocking_send(Ok(Chunk {
                    index: idx,
                    data: chunk_data,
                    hash,
                }))
                .is_err()
            {
                break;
            }
        }
    });
}

impl TransferCheckpoint {
    pub fn new(manifest: TransferManifest, temp_file_path: String) -> Self {
        Self {
            file_name: manifest.file_name,
            file_size: manifest.file_size,
            chunk_hashes: manifest.chunk_hashes,
            completed_chunks: HashSet::new(),
            temp_file_path,
        }
    }

    pub fn save_to_file(&self, checkpoint_path: &Path) -> Result<(), ChunkerError> {
        let file = File::create(checkpoint_path)?;
        serde_json::to_writer_pretty(file, self)
            .map_err(|e| ChunkerError::Serialization(e.to_string()))?;
        Ok(())
    }

    pub fn load_from_file(checkpoint_path: &Path) -> Result<Self, ChunkerError> {
        let file = File::open(checkpoint_path)?;
        let checkpoint = serde_json::from_reader(file)
            .map_err(|e| ChunkerError::Serialization(e.to_string()))?;
        Ok(checkpoint)
    }

    pub fn get_missing_chunks(&self) -> Vec<u64> {
        let mut missing = Vec::new();
        for i in 0..self.chunk_hashes.len() {
            let idx = i as u64;
            if !self.completed_chunks.contains(&idx) {
                missing.push(idx);
            }
        }
        missing
    }
}

/// Writes a chunk of data to the target file at the correct offset, verifying its hash first.
pub fn write_chunk(
    temp_file_path: &Path,
    chunk_index: u64,
    data: &[u8],
    expected_hash: &str,
) -> Result<(), ChunkerError> {
    let hash = blake3::hash(data).to_hex().to_string();
    if hash != expected_hash {
        return Err(ChunkerError::HashMismatch {
            index: chunk_index,
            expected: expected_hash.to_string(),
            actual: hash,
        });
    }

    if let Some(parent) = temp_file_path.parent() {
        let _ = std::fs::create_dir_all(parent);
    }

    let mut file = std::fs::OpenOptions::new()
        .write(true)
        .create(true)
        .truncate(false)
        .open(temp_file_path)?;

    let offset = chunk_index * CHUNK_SIZE as u64;
    file.seek(SeekFrom::Start(offset))?;
    file.write_all(data)?;
    Ok(())
}
