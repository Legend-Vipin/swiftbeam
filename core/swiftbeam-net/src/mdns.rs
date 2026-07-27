use mdns_sd::{ServiceDaemon, ServiceEvent, ServiceInfo};
use std::collections::HashMap;
use tokio::sync::mpsc;

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct DiscoveredPeer {
    pub peer_id: String,
    pub device_name: String,
    pub ip_addresses: Vec<String>,
    pub port: u16,
}

pub struct MdnsDiscovery {
    daemon: ServiceDaemon,
}

impl MdnsDiscovery {
    pub fn new() -> Result<Self, anyhow::Error> {
        let daemon = ServiceDaemon::new()?;
        Ok(Self { daemon })
    }

    /// Registers the local peer as a service in the local network.
    pub fn register_service(
        &self,
        peer_id: &str,
        device_name: &str,
        port: u16,
    ) -> Result<(), anyhow::Error> {
        let service_type = "_swiftbeam._udp.local.";
        let instance_name = format!("sb-{}", peer_id);
        // host_name needs to end with .local.
        let host_name = format!("sb-{}.local.", peer_id);

        let mut properties = HashMap::new();
        properties.insert("device_name".to_string(), device_name.to_string());
        properties.insert("peer_id".to_string(), peer_id.to_string());

        // Note: mdns-sd auto-fills local IPv4/v6 addresses when passing empty string or 0.0.0.0
        let service_info = ServiceInfo::new(
            service_type,
            &instance_name,
            &host_name,
            "",
            port,
            properties,
        )?;

        self.daemon.register(service_info)?;
        Ok(())
    }

    /// Starts browsing for other SwiftBeam peers, pushing updates to a tokio channel.
    pub fn start_browsing(
        &self,
        sender: mpsc::Sender<DiscoveredPeer>,
    ) -> Result<(), anyhow::Error> {
        let service_type = "_swiftbeam._udp.local.";
        let receiver = self.daemon.browse(service_type)?;

        tokio::spawn(async move {
            while let Ok(event) = receiver.recv_async().await {
                if let ServiceEvent::ServiceResolved(info) = event {
                    let peer_id = info
                        .get_property_val_str("peer_id")
                        .unwrap_or("")
                        .to_string();
                    let device_name = info
                        .get_property_val_str("device_name")
                        .unwrap_or("Unknown Device")
                        .to_string();

                    let ip_addresses: Vec<String> = info
                        .get_addresses()
                        .iter()
                        .map(|ip| ip.to_string())
                        .collect();

                    if !peer_id.is_empty() && !ip_addresses.is_empty() {
                        let peer = DiscoveredPeer {
                            peer_id,
                            device_name,
                            ip_addresses,
                            port: info.get_port(),
                        };
                        let _ = sender.send(peer).await;
                    }
                }
            }
        });

        Ok(())
    }
}
