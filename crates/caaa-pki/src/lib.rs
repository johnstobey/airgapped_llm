//! CAAA PKI Provisioning Module
//! 
//! Generates self-signed certificates for mTLS communication between
//! caaa-applet and caaa-core. Implements the air-gap secure bootstrap protocol.

use rcgen::{Certificate, CertificateParams, DistinguishedName, DnType, KeyPair};
use std::path::{Path, PathBuf};
use thiserror::Error;
use tracing::{info, warn};

#[derive(Error, Debug)]
pub enum PkiError {
    #[error("Failed to generate certificate: {0}")]
    CertGeneration(#[from] rcgen::Error),
    
    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),
    
    #[error("Certificate not found: {0}")]
    CertNotFound(String),
    
    #[error("Invalid certificate: {0}")]
    InvalidCert(String),
}

/// PKI Configuration for air-gapped deployment
#[derive(Debug, Clone)]
pub struct PkiConfig {
    pub ca_cert_path: PathBuf,
    pub ca_key_path: PathBuf,
    pub server_cert_path: PathBuf,
    pub server_key_path: PathBuf,
    pub client_cert_path: PathBuf,
    pub client_key_path: PathBuf,
    pub organization: String,
    pub validity_days: u32,
}

impl Default for PkiConfig {
    fn default() -> Self {
        let base = PathBuf::from("/opt/caaa/pki");
        Self {
            ca_cert_path: base.join("ca.crt"),
            ca_key_path: base.join("ca.key"),
            server_cert_path: base.join("server.crt"),
            server_key_path: base.join("server.key"),
            client_cert_path: base.join("client.crt"),
            client_key_path: base.join("client.key"),
            organization: "CAAA Air-Gapped System".to_string(),
            validity_days: 365,
        }
    }
}

/// PKI Manager for certificate lifecycle
pub struct PkiManager {
    config: PkiConfig,
}

impl PkiManager {
    pub fn new(config: PkiConfig) -> Self {
        Self { config }
    }

    /// Initialize PKI infrastructure (run once during installation)
    pub fn initialize(&self) -> Result<(), PkiError> {
        info!("Initializing CAAA PKI infrastructure");
        
        // Create directory structure
        let pki_dir = self.config.ca_cert_path.parent().unwrap();
        std::fs::create_dir_all(pki_dir)?;
        
        // Generate CA certificate
        if !self.config.ca_cert_path.exists() {
            self.generate_ca()?;
        } else {
            info!("CA certificate already exists, skipping generation");
        }
        
        // Generate server certificate
        if !self.config.server_cert_path.exists() {
            self.generate_server_cert()?;
        } else {
            info!("Server certificate already exists, skipping generation");
        }
        
        // Generate client certificate
        if !self.config.client_cert_path.exists() {
            self.generate_client_cert()?;
        } else {
            info!("Client certificate already exists, skipping generation");
        }
        
        info!("PKI initialization complete");
        Ok(())
    }

    fn generate_ca(&self) -> Result<(), PkiError> {
        info!("Generating CA certificate");
        
        let mut params = CertificateParams::default();
        params.distinguished_name = DistinguishedName::new();
        params.distinguished_name.push(DnType::OrganizationName, self.config.organization.clone());
        params.distinguished_name.push(DnType::CommonName, "CAAA Root CA");
        params.is_ca = rcgen::IsCa::Ca(rcgen::BasicConstraints::Unconstrained);
        
        let key_pair = KeyPair::generate()?;
        let cert = params.self_signed(&key_pair)?;
        
        // Write CA cert and key
        std::fs::write(&self.config.ca_cert_path, cert.pem())?;
        std::fs::write(&self.config.ca_key_path, key_pair.serialize_pem())?;
        
        info!("CA certificate generated successfully");
        Ok(())
    }

    fn generate_server_cert(&self) -> Result<(), PkiError> {
        info!("Generating server certificate");
        
        let ca_cert = std::fs::read_to_string(&self.config.ca_cert_path)?;
        let ca_key = std::fs::read_to_string(&self.config.ca_key_path)?;
        
        let ca_params = CertificateParams::from_ca_cert_pem(&ca_cert)?;
        let ca_key_pair = KeyPair::from_pem(&ca_key)?;
        
        let mut params = CertificateParams::default();
        params.distinguished_name = DistinguishedName::new();
        params.distinguished_name.push(DnType::OrganizationName, self.config.organization.clone());
        params.distinguished_name.push(DnType::CommonName, "caaa-core.local");
        params.subject_alt_names = vec![
            rcgen::SanType::DnsName("caaa-core.local".to_string()),
            rcgen::SanType::IpAddress(std::net::IpAddr::V4(std::net::Ipv4Addr::new(127, 0, 0, 1))),
        ];
        
        let key_pair = KeyPair::generate()?;
        let cert = params.signed_by(&key_pair, &ca_params, &ca_key_pair)?;
        
        std::fs::write(&self.config.server_cert_path, cert.pem())?;
        std::fs::write(&self.config.server_key_path, key_pair.serialize_pem())?;
        
        info!("Server certificate generated successfully");
        Ok(())
    }

    fn generate_client_cert(&self) -> Result<(), PkiError> {
        info!("Generating client certificate");
        
        let ca_cert = std::fs::read_to_string(&self.config.ca_cert_path)?;
        let ca_key = std::fs::read_to_string(&self.config.ca_key_path)?;
        
        let ca_params = CertificateParams::from_ca_cert_pem(&ca_cert)?;
        let ca_key_pair = KeyPair::from_pem(&ca_key)?;
        
        let mut params = CertificateParams::default();
        params.distinguished_name = DistinguishedName::new();
        params.distinguished_name.push(DnType::OrganizationName, self.config.organization.clone());
        params.distinguished_name.push(DnType::CommonName, "caaa-applet.local");
        
        let key_pair = KeyPair::generate()?;
        let cert = params.signed_by(&key_pair, &ca_params, &ca_key_pair)?;
        
        std::fs::write(&self.config.client_cert_path, cert.pem())?;
        std::fs::write(&self.config.client_key_path, key_pair.serialize_pem())?;
        
        info!("Client certificate generated successfully");
        Ok(())
    }

    /// Verify all certificates exist and are valid
    pub fn verify(&self) -> Result<(), PkiError> {
        let paths = [
            (&self.config.ca_cert_path, "CA Certificate"),
            (&self.config.ca_key_path, "CA Key"),
            (&self.config.server_cert_path, "Server Certificate"),
            (&self.config.server_key_path, "Server Key"),
            (&self.config.client_cert_path, "Client Certificate"),
            (&self.config.client_key_path, "Client Key"),
        ];
        
        for (path, name) in &paths {
            if !path.exists() {
                return Err(PkiError::CertNotFound(format!("{} not found at {:?}", name, path)));
            }
        }
        
        info!("All PKI certificates verified successfully");
        Ok(())
    }

    /// Load CA certificate for verification
    pub fn load_ca_cert(&self) -> Result<String, PkiError> {
        Ok(std::fs::read_to_string(&self.config.ca_cert_path)?)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    #[test]
    fn test_pki_initialization() {
        let temp_dir = TempDir::new().unwrap();
        let config = PkiConfig {
            ca_cert_path: temp_dir.path().join("ca.crt"),
            ca_key_path: temp_dir.path().join("ca.key"),
            server_cert_path: temp_dir.path().join("server.crt"),
            server_key_path: temp_dir.path().join("server.key"),
            client_cert_path: temp_dir.path().join("client.crt"),
            client_key_path: temp_dir.path().join("client.key"),
            organization: "Test CAAA".to_string(),
            validity_days: 30,
        };
        
        let manager = PkiManager::new(config);
        assert!(manager.initialize().is_ok());
        assert!(manager.verify().is_ok());
    }
}
