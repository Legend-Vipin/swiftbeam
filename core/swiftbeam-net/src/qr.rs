use rand::{distributions::Alphanumeric, Rng};
use serde::{Deserialize, Serialize};
use std::time::{SystemTime, UNIX_EPOCH};

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct QrBootstrap {
    pub device_id: String,
    pub session: String,
    pub ip: Option<String>,
    pub port: u16,
    pub token: String,
    pub pub_key: String, // Base64 encoded public key
    pub expires: u64,    // Unix timestamp
    pub version: String,
}

impl QrBootstrap {
    /// Creates a new QR bootstrap payload.
    /// `ttl_seconds` defines how long the QR code is valid.
    pub fn new(
        device_id: String,
        ip: Option<String>,
        port: u16,
        pub_key: String,
        ttl_seconds: u64,
    ) -> Self {
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs();

        // Generate a random 16-character session ID
        let session: String = rand::thread_rng()
            .sample_iter(&Alphanumeric)
            .take(16)
            .map(char::from)
            .collect();

        // Generate a random 32-character discovery token
        let token: String = rand::thread_rng()
            .sample_iter(&Alphanumeric)
            .take(32)
            .map(char::from)
            .collect();

        Self {
            device_id,
            session,
            ip,
            port,
            token,
            pub_key,
            expires: now + ttl_seconds,
            version: "1.0".to_string(),
        }
    }

    /// Serializes to a JSON string.
    pub fn to_json(&self) -> Result<String, serde_json::Error> {
        serde_json::to_string(self)
    }

    /// Parses from a JSON string and validates expiration.
    pub fn from_json(json: &str) -> Result<Self, &'static str> {
        let qr: QrBootstrap = serde_json::from_str(json).map_err(|_| "Invalid QR JSON payload")?;

        if !qr.is_valid() {
            return Err("QR Code has expired or has invalid version");
        }

        Ok(qr)
    }

    /// Checks if the QR code is still valid based on expiration and version.
    pub fn is_valid(&self) -> bool {
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs();

        self.expires >= now && self.version == "1.0"
    }
}
