## HAProxy Menu v2.6 - grouped editable tunnel manager

This version installs locally once, creates a shortcut, and adds grouped editable tunnels.
A tunnel is now saved as one named group, with one destination IP/domain and one list of listen/destination ports.

### Safe one-time install from GitHub

Do not use `bash <(curl ...)` on VPS images where `/dev/fd` is unavailable or where `sudo` closes file descriptors.
Use this instead:

```bash
curl -4 -fsSL https://raw.githubusercontent.com/0fariid0/haproxy/main/haproxy.sh -o /tmp/haproxy.sh && sudo bash /tmp/haproxy.sh --install
```

If you are already root:

```bash
curl -4 -fsSL https://raw.githubusercontent.com/0fariid0/haproxy/main/haproxy.sh -o /tmp/haproxy.sh && bash /tmp/haproxy.sh --install
```

After the first install, open the menu with:

```bash
sudo hapmenu
```

or:

```bash
sudo haproxy-menu
```

### Manual update on the server

If you copy `haproxy.sh` manually to the server, copying it to `/root` is not enough. The shortcut runs:

```bash
/opt/haproxy-menu/haproxy.sh
```

After uploading the new file to `/tmp/haproxy.sh`, run:

```bash
install -Dm755 /tmp/haproxy.sh /opt/haproxy-menu/haproxy.sh
ln -sf /opt/haproxy-menu/haproxy.sh /usr/local/bin/hapmenu
ln -sf /opt/haproxy-menu/haproxy.sh /usr/local/bin/haproxy-menu
hash -r
hapmenu --version
```

The output must show:

```text
haproxy-menu v2.6
```

### Tunnel database

Editable tunnel groups are stored at:

```bash
/etc/haproxy/haproxy-tunnels.db
```

Format:

```text
name|listen_ports|destination_host|destination_ports|enabled
```

Example:

```text
1|31,1030,27028,39464,56855|10.20.1.2|31,1030,27028,39464,56855|1
```

That means one tunnel group named `1` with these mappings:

```text
31    -> 10.20.1.2:31
1030  -> 10.20.1.2:1030
27028 -> 10.20.1.2:27028
39464 -> 10.20.1.2:39464
56855 -> 10.20.1.2:56855
```

If `destination_ports` has one port, all listen ports go to that one destination port:

```text
1|31,1030,27028|10.20.1.2|443|1
```

### Add/edit flow

From the main menu choose:

```text
1. Manage Editable Tunnels
```

Then choose **Add tunnel group**.

Example input:

```text
Tunnel name: 1
Listen/bind port(s) on this server: 31,1030,27028,39464,56855
Destination IP/domain: 10.20.1.2
Destination port(s) [empty = same as listen ports, one port = all]:
```

Leaving destination ports empty saves the same port list automatically.

When editing, the script shows the selected tunnel like this:

```text
Name:              1
Destination IP:    10.20.1.2
Listen ports:      31,1030,27028,39464,56855
Destination ports: 31,1030,27028,39464,56855
Status:            enabled
```

Then you can change only the destination IP, only the ports, or anything else. Empty fields keep the current value. For destination ports, type `same` to make them match the listen ports.

### Applying to HAProxy

After add/edit/delete/enable/disable, the script asks whether to apply the change to:

```bash
/etc/haproxy/haproxy.cfg
```

If you answer yes, it:

1. validates the saved tunnel groups,
2. builds a temporary HAProxy config,
3. runs `haproxy -c -f <temporary-config>`,
4. backs up the old config,
5. writes `/etc/haproxy/haproxy.cfg`,
6. restarts HAProxy.

If validation fails, the main HAProxy config is not changed.

### Local paths

Installed script:

```bash
/opt/haproxy-menu/haproxy.sh
```

Shortcuts:

```bash
/usr/local/bin/hapmenu
/usr/local/bin/haproxy-menu
```

Backups:

```bash
/etc/haproxy/backups
```

### What changed in v2.6

- A multi-port tunnel is now saved as one grouped tunnel, not many separate records.
- Editing one tunnel now shows its destination IP and full port list.
- Listen ports and destination ports can be edited as comma-separated lists.
- Add/edit/delete/enable/disable now asks to immediately write the result into `/etc/haproxy/haproxy.cfg`.
- Applying to the main HAProxy config no longer asks twice when triggered after a change.
- Duplicate enabled listen ports are detected across all tunnel groups.
- Old one-port records are still valid.
- Legacy quick config remains available from the submenu.

### Repair shortcut

If the shortcut is deleted or broken:

```bash
sudo haproxy-menu --repair-shortcut
```
