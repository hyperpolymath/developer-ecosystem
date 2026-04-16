# Network System Roadmap

Ideas for expanding the network simulation toward Packet Tracer-level sophistication.

## Current Implementation
- Star topology with central router/gateway
- Layer 3 logical connectivity
- DNS resolution via configurable DNS servers
- Traceroute showing hop paths
- SSH between devices
- Zone-based layout (LAN, VLAN, External)

## Future Ideas

### Layer 2 Enhancements
- **MAC address tables** - Switches learn which MAC is on which port
- **ARP protocol** - Devices resolve IP to MAC before communication
- **ARP spoofing** - Hacking mechanic to intercept traffic (MITM attacks)
- **VLAN tagging (802.1Q)** - Proper VLAN isolation, trunk ports between switches

### Routing & Multiple Networks
- **Multiple routers** - More complex topologies
- **Routing tables** - Static routes, maybe simplified OSPF/RIP
- **NAT** - Internal IPs translated to external, port forwarding
- **Default gateway configuration** - Per-device gateway settings

### Security Features
- **Firewall rules** - Block/allow by IP, port, protocol
- **ACLs (Access Control Lists)** - On routers/switches
- **Firewall bypass** - Hacking mechanic to find gaps in rules
- **Port scanning** - nmap-style discovery of open services
- **IDS/IPS** - Intrusion detection that can catch the player

### Packet-Level Simulation
- **Packet capture tool** - Wireshark-style traffic inspection
- **Packet injection** - Craft malicious packets
- **Traffic visualization** - See packets flow through the network
- **Protocol analysis** - TCP handshakes, DNS queries visible

### Services & Protocols
- **DHCP server** - Dynamic IP assignment (already have toggle, make functional)
- **HTTP/HTTPS** - Web servers with actual request/response
- **FTP/SFTP** - File transfer between machines
- **SMB shares** - Windows-style network drives
- **Email (SMTP/IMAP)** - Actual mail flow between servers

### Hacking Mechanics Using Network Features
- **ARP poisoning** - Redirect traffic through attacker machine
- **DNS spoofing** - Return fake IPs for domains
- **Man-in-the-middle** - Intercept and modify traffic
- **Port knocking** - Hidden services revealed by knock sequence
- **Firewall rule exploitation** - Find misconfigured rules
- **VLAN hopping** - Escape from one VLAN to another

### Quality of Life
- **Network diagram export** - Save topology as image
- **Configuration save/load** - Persist network state
- **Scenario system** - Pre-built network puzzles to solve
- **Hints system** - For stuck players

## Priority Notes
The current abstraction level works well for a hacking game - realistic enough to feel authentic, simple enough to be fun. Add complexity only where it creates interesting gameplay mechanics.
