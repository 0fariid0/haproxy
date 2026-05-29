## HAProxy Menu - updated local shortcut version

This version has been updated so you do **not** need to download the script from GitHub every time.

### One-time install

If you already have the files on your server:

```bash
sudo bash haproxy.sh --install
```

If you are installing from GitHub for the first time:

```bash
sudo bash <(curl -Ls --ipv4 https://github.com/0fariid0/haproxy/raw/main/haproxy.sh) --install
```

After the first install, open the menu any time with:

```bash
sudo hapmenu
```

or:

```bash
sudo haproxy-menu
```

The script is installed locally at:

```bash
/opt/haproxy-menu/haproxy.sh
```

Shortcuts are created at:

```bash
/usr/local/bin/hapmenu
/usr/local/bin/haproxy-menu
```

### What changed

- Added one-time local installation.
- Added short command: `hapmenu`.
- No need to download from GitHub after installation.
- Automatically installs missing dependencies: `haproxy`, `curl`, `jq`.
- Fixes server info detection.
- Adds config validation with `haproxy -c` before applying changes.
- Creates backups before replacing/removing `/etc/haproxy/haproxy.cfg`.
- Adds safer port/IP/domain validation.
- Adds IPv6 destination formatting support.
- Adds current config viewer.
- Adds log fallback to `journalctl -u haproxy -f` if `/var/log/haproxy.log` does not exist.
- Removes invalid TCP URI load-balancing option.

### Repair shortcut

If the shortcut is deleted or broken:

```bash
sudo haproxy-menu --repair-shortcut
```

### Menu

![Menu](https://github.com/Musixal/haproxy/blob/main/menu.png)
