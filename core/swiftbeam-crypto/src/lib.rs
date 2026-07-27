use chacha20poly1305::aead::{Aead, KeyInit};
use chacha20poly1305::{ChaCha20Poly1305, Key, Nonce};
use rand::rngs::OsRng;
use thiserror::Error;
use x25519_dalek::{PublicKey, StaticSecret};

#[derive(Error, Debug)]
pub enum CryptoError {
    #[error("Encryption failed")]
    EncryptionFailed,
    #[error("Decryption failed")]
    DecryptionFailed,
}

/// Generates a static secret and its corresponding public key for X25519.
pub fn generate_keypair() -> (StaticSecret, PublicKey) {
    let secret = StaticSecret::random_from_rng(OsRng);
    let public = PublicKey::from(&secret);
    (secret, public)
}

/// Computes the shared Diffie-Hellman secret.
pub fn compute_shared_secret(my_secret: &StaticSecret, their_public: &PublicKey) -> [u8; 32] {
    let shared = my_secret.diffie_hellman(their_public);
    *shared.as_bytes()
}

/// Derives a 32-byte symmetric key from the shared secret using BLAKE3.
pub fn derive_symmetric_key(shared_secret: &[u8; 32]) -> [u8; 32] {
    blake3::derive_key("SwiftBeam Key Derivation Context v1", shared_secret)
}

/// Encrypts a 1MB chunk with ChaCha20-Poly1305, using the chunk index for the nonce.
pub fn encrypt_chunk(
    key: &[u8; 32],
    chunk_index: u64,
    plaintext: &[u8],
) -> Result<Vec<u8>, CryptoError> {
    let cipher = ChaCha20Poly1305::new(Key::from_slice(key));
    let mut nonce_bytes = [0u8; 12];
    nonce_bytes[0..8].copy_from_slice(&chunk_index.to_be_bytes());
    let nonce = Nonce::from_slice(&nonce_bytes);
    cipher
        .encrypt(nonce, plaintext)
        .map_err(|_| CryptoError::EncryptionFailed)
}

/// Decrypts a chunk with ChaCha20-Poly1305, using the chunk index for the nonce.
pub fn decrypt_chunk(
    key: &[u8; 32],
    chunk_index: u64,
    ciphertext: &[u8],
) -> Result<Vec<u8>, CryptoError> {
    let cipher = ChaCha20Poly1305::new(Key::from_slice(key));
    let mut nonce_bytes = [0u8; 12];
    nonce_bytes[0..8].copy_from_slice(&chunk_index.to_be_bytes());
    let nonce = Nonce::from_slice(&nonce_bytes);
    cipher
        .decrypt(nonce, ciphertext)
        .map_err(|_| CryptoError::DecryptionFailed)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_key_exchange_and_encryption() {
        let (alice_sec, alice_pub) = generate_keypair();
        let (bob_sec, bob_pub) = generate_keypair();

        let alice_shared = compute_shared_secret(&alice_sec, &bob_pub);
        let bob_shared = compute_shared_secret(&bob_sec, &alice_pub);

        assert_eq!(alice_shared, bob_shared);

        let key = derive_symmetric_key(&alice_shared);

        let plaintext = b"Hello, SwiftBeam P2P transfer test payload!";
        let chunk_index = 42;

        let ciphertext = encrypt_chunk(&key, chunk_index, plaintext).unwrap();
        assert_ne!(plaintext.to_vec(), ciphertext);

        let decrypted = decrypt_chunk(&key, chunk_index, &ciphertext).unwrap();
        assert_eq!(plaintext.to_vec(), decrypted);
    }
}
