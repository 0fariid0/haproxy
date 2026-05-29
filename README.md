## HAProxy Menu v2.3 - editable tunnel manager

This v2.3 version installs locally once, creates a shortcut, and adds an editable tunnel manager so you can add, edit, enable/disable, and delete HAProxy tunnels from the menu without rewriting everything by hand.

### Important install fix

Do **not** install with this pattern on VPS images where `/dev/fd` is unavailable or where `sudo` closes file descriptors:

```bash
sudo bash <(curl -Ls --ipv4 https://github.com/0fariid0/haproxy/raw/main/haproxy.sh) --install
```

It can fail with:

```text
bash: /dev/fd/63: No such file or directory
```

Use the safe one-time download method below instead.

### One-time install from GitHub

```bash
curl -4 -fsSL https://raw.githubusercontent.com/0fariid0/haproxy/main/haproxy.sh -o /tmp/haproxy.sh && sudo bash /tmp/haproxy.sh --install
```

If you are already logged in as root:

```bash
curl -4 -fsSL https://raw.githubusercontent.com/0fariid0/haproxy/main/haproxy.sh -o /tmp/haproxy.sh && bash /tmp/haproxy.sh --install
```

After the first install, open the menu any time with:

```bash
sudo hapmenu
```

or:

```bash
sudo haproxy-menu
```


### If your menu still shows v2.0

That means the old script is still installed locally or GitHub was not updated yet. Replace `haproxy.sh` in the repository with this v2.3 file, then run:

```bash
rm -f /opt/haproxy-menu/haproxy.sh /usr/local/bin/hapmenu /usr/local/bin/haproxy-menu
curl -4 -fsSL "https://raw.githubusercontent.com/0fariid0/haproxy/main/haproxy.sh?$(date +%s)" -o /tmp/haproxy.sh
grep -E "APP_VERSION|Manage Editable Tunnels|editable tunnels" /tmp/haproxy.sh
bash /tmp/haproxy.sh --install
```

The `grep` output must show `APP_VERSION="2.3"` before you install. If it still shows `2.0`, GitHub still has the old file.

### Manual update on the server

If you copy `haproxy.sh` to the server manually, copying it into `/root` is not enough. The shortcut runs this installed file:

```bash
/opt/haproxy-menu/haproxy.sh
```

Use this after uploading the new file to `/tmp/haproxy.sh`:

```bash
install -Dm755 /tmp/haproxy.sh /opt/haproxy-menu/haproxy.sh
ln -sf /opt/haproxy-menu/haproxy.sh /usr/local/bin/hapmenu
ln -sf /opt/haproxy-menu/haproxy.sh /usr/local/bin/haproxy-menu
hash -r
grep -E 'APP_VERSION|Manage Editable Tunnels' /opt/haproxy-menu/haproxy.sh
hapmenu --version
```


### Local paths

The script is installed locally at:

```bash
/opt/haproxy-menu/haproxy.sh
```

Shortcuts are created at:

```bash
/usr/local/bin/hapmenu
/usr/local/bin/haproxy-menu
```

Editable tunnel records are stored at:

```bash
/etc/haproxy/haproxy-tunnels.db
```

Tunnel file format:

```text
name|bind_port|destination_host|destination_port|enabled
```

Example:

```text
iran-443|443|1.2.3.4|443|1
iran-8443|8443|example.com|8443|1
backup-ipv6|2096|2001:db8::10|443|0
```

`enabled` can be `1` or `0`. Enabled tunnels are written into `/etc/haproxy/haproxy.cfg` when you choose **Apply/rebuild HAProxy config from saved tunnels**.

### Editable tunnel manager

From the main menu choose:

```text
1. Manage Editable Tunnels
```

You can then:

- list saved tunnels
- add a tunnel
- edit tunnel name, listen port, destination IP/domain, and destination port
- enable/disable a tunnel
- delete a tunnel
- rebuild HAProxy config from all enabled tunnels
- manually edit `/etc/haproxy/haproxy-tunnels.db`
- use the old legacy quick config menu if needed

Before applying changes, the script runs:

```bash
haproxy -c -f <temporary-config>
```

If validation fails, `/etc/haproxy/haproxy.cfg` is not changed.

### What changed in v2.3

- Added editable tunnel database: `/etc/haproxy/haproxy-tunnels.db`.
- Added tunnel manager menu.
- Added add/edit/delete/enable/disable tunnel actions.
- Added manual tunnel file editor from inside the script.
- Rebuilds HAProxy config from saved enabled tunnels.
- Prevents duplicate enabled listen ports.
- Keeps legacy quick tunnel config available as a submenu.
- Keeps config validation and automatic backup before replacing HAProxy config.
- Keeps local shortcut install: `hapmenu`.

### Repair shortcut

If the shortcut is deleted or broken:

```bash
sudo haproxy-menu --repair-shortcut
```

### Menu

![Menu](https://github.com/Musixal/haproxy/blob/main/menu.png)
