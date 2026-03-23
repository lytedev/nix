# Tailscale Dependency

**Labels**: networking

Tailscale is somewhat of a single-point-of-failure for remote
access at the moment.

I want to either:

- Ensure LAN ssh access
  - I believe this is currently working with the router configured to allow
    SSH even without Tailscale. That in combination with DDNS means I have two
    access points. My single point of failure is gone!
- Ensure a self-hosted VPN is _also_ an option
  - Setup Headscale in addition to Tailscale?
