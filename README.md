English | [Русский](README.ru.md)

# CoreServerKit

Bash script for initial setup and hardening of Ubuntu/Debian servers.

## Requirements

* Ubuntu 20.04+ or Debian 11+
* Root access
* Internet connection

## Installation

**Via Git:**

```bash
git clone https://github.com/cs-eliseev/CoreServerKit.git
cd CoreServerKit
chmod +x server-init.sh
```

**Via curl:**

```bash
curl -L https://github.com/cs-eliseev/CoreServerKit/archive/refs/heads/main.tar.gz | tar -xz
cd CoreServerKit-main
chmod +x server-init.sh
```

## Usage

```bash
sudo ./server-init.sh [OPTION]
```

| Option              | Description                                    |
|---------------------|------------------------------------------------|
| `-u`, `--user`      | Create a sudo user                             |
| `-k`, `--ssh-key`   | Add or generate an SSH key                     |
| `-s`, `--security`  | Security hardening (SSH, UFW, fail2ban)        |
| `-t`, `--speedtest` | Install Ookla Speedtest CLI                    |
| `-U`, `--update`    | Update the system                              |
| `-c`, `--cert`      | Issue a Let's Encrypt SSL certificate (nginx)  |
| `-V`, `--verify`    | Verify current configuration                   |
| `-d`, `--defaults`  | Full cycle non-interactively with all defaults |

Without options runs the full cycle interactively.

In `--defaults` mode the certificate step runs only when the domain is passed via environment:

```bash
sudo CERT_DOMAIN=example.com CERT_EMAIL=admin@example.com ./server-init.sh --defaults
```

## What it does

**User** — creates a user with generated username and password, adds to sudo.

**SSH key** — adds an existing public key or generates an Ed25519 key pair.

**Security** — changes the SSH port, disables password authentication and root login, configures UFW (deny incoming, DROP ICMP), installs fail2ban (5 retries, 10 min ban).

**Update** — runs `apt update` + `apt upgrade`.

**SSL certificate** — asks for a domain and email, installs nginx and certbot, creates an nginx site (HTTP → HTTPS redirect, HTTP/2, HSTS, gzip), issues a Let's Encrypt certificate and enables auto-renewal. Opens `443/tcp` in UFW; `80/tcp` is opened only for the duration of the domain validation (including renewals) and closed afterwards.

**Verify** — checks user, SSH keys, sshd config, UFW, fail2ban, speedtest, and SSL certificates.

## Logs

```
/var/log/server-init.log         # Detailed execution log
/var/log/server-init-changes.log # Changes history per run
```

## Locked out of SSH

Connect via console and restore the config:

```bash
cp /etc/ssh/sshd_config.*.bak /etc/ssh/sshd_config
systemctl restart ssh
ufw disable
```

## License

[MIT](LICENSE)
