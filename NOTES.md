# lcgamboa USB/IP server — API map (Task 2 Step 3)

Vendored from https://github.com/lcgamboa/USBIP-Virtual-USB-Device (GPLv2). Two implementations: `c/` (reused later for the iPad/Voidlink port) and `python/` (handy for fast bench iteration alongside `bleak`). The bench uses the **C** path.

## How a virtual device is defined (C)

A device example (`c/hid-keyboard.c`, our `c/hid-triton.c`) supplies these globals that `c/usbip.c` consumes (declared `extern` in `c/usbip.h:385-392`):

| Symbol | Type (`usbip.h`) | Purpose |
|---|---|---|
| `dev_dsc` | `USB_DEVICE_DESCRIPTOR` (`usbip.h:62-78`) | Device identity: `idVendor`, `idProduct`, `bcdDevice`, `bMaxPacketSize0`, string indices, `bNumConfigurations` |
| `configuration` | `const char *` → `CONFIG_HID` (`usbip.h:151-157`) | Config + Interface + HID-class + Endpoint descriptors as one packed blob |
| `interfaces[]` | `USB_INTERFACE_DESCRIPTOR *[]` | Pointers to each interface descriptor |
| `strings[]` | `unsigned char *[]` | String descriptors (empty `{}` ⇒ no strings; identity is VID/PID anyway) |
| `dev_qua` | `USB_DEVICE_QUALIFIER_DESCRIPTOR` | `{}` is fine for full-speed HID |

`CONFIG_HID` = `{ USB_CONFIGURATION_DESCRIPTOR dev_conf; USB_INTERFACE_DESCRIPTOR dev_int; USB_HID_DESCRIPTOR dev_hid; USB_ENDPOINT_DESCRIPTOR dev_ep; }`. The HID-class descriptor's `wRPDescriptorLength` must equal the report-descriptor byte count.

## Callbacks the device example MUST implement (`usbip.h:391-392`)

- `void handle_data(int sockfd, USBIP_RET_SUBMIT *usb_req, int bl)` — called to satisfy an **interrupt-IN** submit. Produce a report and call `send_usb_req(sockfd, usb_req, data, size, 0)`. One send per call. This is where we emit Triton state.
- `void handle_unknown_control(int sockfd, StandardDeviceRequest *control_req, USBIP_RET_SUBMIT *usb_req)` — every control transfer the core doesn't handle itself. Key cases (`StandardDeviceRequest` fields at `usbip.h:369-378`):
  - `bmRequestType==0x81 && bRequest==0x06 && wValue1==0x22` → **GET_DESCRIPTOR(Report)**: send the report-descriptor bytes.
  - `bmRequestType==0x21 && bRequest==0x0a` → **SET_IDLE**: ack empty.
  - `bmRequestType==0x21 && bRequest==0x09` → **SET_REPORT** (output/feature, e.g. lizard-off, IMU-enable, rumble): `recv()` `wLength` bytes; ack empty. **We log these** — they answer "what does Steam write?"
  - `bmRequestType==0xA1` → **GET_REPORT/GET_FEATURE** (device→host): **the GetFeature question.** As-shipped the core has no path for this, so our `hid-triton.c` logs it and replies zeros. Whether Steam issues any is exactly what Task 5 must observe.

`send_usb_req` signature: `void send_usb_req(int sockfd, USBIP_RET_SUBMIT *usb_req, char *data, unsigned int size, unsigned int status)`.

## Protocol facts

- Listens on **TCP 3240** (`usbip.h:44`). Op-codes handled in `usbip.c`: `OP_REQ_DEVLIST`, `OP_REQ_IMPORT`, `USBIP_CMD_SUBMIT`, `USBIP_CMD_UNLINK` (structs `usbip.h:218-365`). The device advertises a single busid.
- Build (Linux): `cd c && make` (produces `hid-keyboard`, `hid-mouse`, `cdc-acm`). `Makefile.cross` exists for cross-builds; the headers already `#ifdef LINUX … #else #include <winsock.h>`, so a **Windows/Winsock build is plausible** (the loopback-on-Windows option in the plan).
- Local attach (Linux host): `sudo modprobe vhci-hcd && usbip list -r 127.0.0.1 && sudo usbip attach -r 127.0.0.1 -b 1-1`.
- **Caveat (README):** the original HID example noted a USB/IP-driver BSOD on *de-attach* on old Windows. Test detach behavior on `usbip-win2`; this may already be fixed in the signed client.

## Our additions (Task 4)

- `c/triton_report.h` — canned 64-byte Triton state report; `sLeftStickX` walks so Steam's tester shows motion. Framing per `SDL_hidapi_steam_triton.c:525-536` (`data[0]`=`0x42`/`0x45` msg id; `TritonMTUNoQuat_t` at `&data[1]`; `sLeftStickX` → byte 10).
- `c/test_triton_report.c` — unit test for that layout.
- `c/hid-triton.c` — the synthetic Steam Controller: `28DE:1302`, vendor `0xFF00` 64-byte descriptor (old-SC template — **replace with the Task-1 hardware capture**), canned input, and full control-transfer logging.

## WSL2 note

This build host is WSL2 (`5.15…-microsoft-standard-WSL2`); its kernel lacks `vhci-hcd`, so the *local* Linux `usbip attach` sanity step (Task 2 Step 4) can't run here. The real attach happens from Windows via `usbip-win2` (Task 3/5).

The server **builds clean and runs correctly** (verified: it reaches `bind()` and the unit test passes). It could **not** bind `:3240` in this WSL instance because **a Windows-side `usbip` service already holds TCP 3240** (a connect from WSL to `127.0.0.1:3240` succeeds), and WSL2 mirrored networking shares the Windows port space. Building on a free port (`13240`) listens fine — confirming the conflict is environmental, not a code bug.

> **Bench-test implication (important):** you appear to already have a Windows `usbip` server service (`usbipd-win`'s `usbipd`) running and holding 3240. Our design needs the `usbip-win2` *client* (`usbip.exe attach`), which connects OUT and does **not** need to listen — so for the bench, the cleanest setups are: (a) run `hid-triton` on a **separate Linux box** (not mirrored WSL); (b) **stop the Windows `usbipd` service** to free 3240 for the WSL server; or (c) build `hid-triton` for **Windows/Winsock** and attach over `127.0.0.1` (the loopback-on-Windows option). The usbip *client* attaches to the server's `:3240`, so the server must own 3240 on whatever host runs it.
