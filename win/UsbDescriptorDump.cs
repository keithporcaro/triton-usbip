// UsbDescriptorDump.cs — UsbView-style descriptor dumper for the Phase 0 bench.
//
// Retrieves a USB device's DEVICE, CONFIGURATION, STRING and (the prize) HID
// REPORT descriptors straight off the bus via the inbox USB hub driver, using
// IOCTL_USB_GET_DESCRIPTOR_FROM_NODE_CONNECTION — the same mechanism UsbView uses.
// Needs NO driver install and NO elevation (UsbView runs unelevated).
//
// Usage (PowerShell):
//   $src = Get-Content -Raw .\UsbDescriptorDump.cs
//   Add-Type -TypeDefinition $src -Language CSharp
//   [UsbView]::Dump(0x28DE, 0x1302)
using System;
using System.Runtime.InteropServices;
using System.Text;
using System.Collections.Generic;

public static class UsbView
{
    const uint GENERIC_WRITE = 0x40000000;
    const uint FILE_SHARE_READ = 1, FILE_SHARE_WRITE = 2;
    const uint OPEN_EXISTING = 3;
    const uint DIGCF_PRESENT = 0x2, DIGCF_DEVICEINTERFACE = 0x10;

    static readonly Guid GUID_DEVINTERFACE_USB_HUB =
        new Guid("f18a0e88-c30c-11d0-8815-00a0c906bed8");

    const int IOCTL_USB_GET_NODE_INFORMATION = 0x220408;
    const int IOCTL_USB_GET_NODE_CONNECTION_INFORMATION_EX = 0x220448;
    const int IOCTL_USB_GET_DESCRIPTOR_FROM_NODE_CONNECTION = 0x220410;

    [DllImport("setupapi.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    static extern IntPtr SetupDiGetClassDevs(ref Guid g, IntPtr enumerator, IntPtr hwnd, uint flags);
    [DllImport("setupapi.dll", SetLastError = true)]
    static extern bool SetupDiEnumDeviceInterfaces(IntPtr h, IntPtr devInfo, ref Guid g, uint idx, ref SP_DEVICE_INTERFACE_DATA data);
    [DllImport("setupapi.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    static extern bool SetupDiGetDeviceInterfaceDetail(IntPtr h, ref SP_DEVICE_INTERFACE_DATA data, IntPtr detail, uint detailSize, ref uint reqSize, IntPtr devInfoData);
    [DllImport("setupapi.dll", SetLastError = true)]
    static extern bool SetupDiDestroyDeviceInfoList(IntPtr h);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    static extern IntPtr CreateFile(string name, uint access, uint share, IntPtr sec, uint disp, uint flags, IntPtr templ);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool CloseHandle(IntPtr h);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool DeviceIoControl(IntPtr h, int code, byte[] inBuf, int inSize, byte[] outBuf, int outSize, ref int ret, IntPtr ov);

    [StructLayout(LayoutKind.Sequential)]
    struct SP_DEVICE_INTERFACE_DATA { public int cbSize; public Guid g; public int flags; public IntPtr reserved; }

    static readonly IntPtr INVALID = new IntPtr(-1);

    static List<string> HubPaths()
    {
        var paths = new List<string>();
        Guid g = GUID_DEVINTERFACE_USB_HUB;
        IntPtr h = SetupDiGetClassDevs(ref g, IntPtr.Zero, IntPtr.Zero, DIGCF_PRESENT | DIGCF_DEVICEINTERFACE);
        if (h == INVALID) return paths;
        try
        {
            var did = new SP_DEVICE_INTERFACE_DATA();
            did.cbSize = Marshal.SizeOf(did);
            uint i = 0;
            while (SetupDiEnumDeviceInterfaces(h, IntPtr.Zero, ref g, i, ref did))
            {
                i++;
                uint req = 0;
                SetupDiGetDeviceInterfaceDetail(h, ref did, IntPtr.Zero, 0, ref req, IntPtr.Zero);
                if (req == 0) continue;
                IntPtr detail = Marshal.AllocHGlobal((int)req);
                try
                {
                    Marshal.WriteInt32(detail, IntPtr.Size == 8 ? 8 : 6); // cbSize
                    uint req2 = 0;
                    if (SetupDiGetDeviceInterfaceDetail(h, ref did, detail, req, ref req2, IntPtr.Zero))
                        paths.Add(Marshal.PtrToStringUni(new IntPtr(detail.ToInt64() + 4)));
                }
                finally { Marshal.FreeHGlobal(detail); }
            }
        }
        finally { SetupDiDestroyDeviceInfoList(h); }
        return paths;
    }

    // GET_DESCRIPTOR via the hub. bmRequest 0x80 = device recipient, 0x81 = interface recipient.
    static byte[] GetDescriptor(IntPtr hub, int port, byte bmRequest, byte descType, byte descIndex, ushort wIndex, int length)
    {
        int err; int ret;
        return GetDescriptorEx(hub, port, bmRequest, descType, descIndex, wIndex, length, out ret, out err);
    }

    static byte[] GetDescriptorEx(IntPtr hub, int port, byte bmRequest, byte descType, byte descIndex, ushort wIndex, int length, out int ret, out int err)
    {
        const int hdr = 12; // ULONG ConnectionIndex + 8-byte SetupPacket
        byte[] buf = new byte[hdr + length];
        BitConverter.GetBytes(port).CopyTo(buf, 0);
        buf[4] = bmRequest;
        buf[5] = 6;            // GET_DESCRIPTOR
        buf[6] = descIndex;    // wValue low
        buf[7] = descType;     // wValue high
        BitConverter.GetBytes(wIndex).CopyTo(buf, 8);
        BitConverter.GetBytes((ushort)length).CopyTo(buf, 10);
        ret = 0;
        bool ok = DeviceIoControl(hub, IOCTL_USB_GET_DESCRIPTOR_FROM_NODE_CONNECTION, buf, buf.Length, buf, buf.Length, ref ret, IntPtr.Zero);
        err = ok ? 0 : Marshal.GetLastWin32Error();
        if (!ok || ret <= hdr) return null;
        byte[] outb = new byte[ret - hdr];
        Array.Copy(buf, hdr, outb, 0, outb.Length);
        return outb;
    }

    // Diagnostic: try several ways to pull the 0x22 report descriptor, report the win32 error for each.
    public static void DiagReportDescriptor(ushort vid, ushort pid)
    {
        foreach (var path in HubPaths())
        {
            IntPtr hub = CreateFile(path, GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_WRITE, IntPtr.Zero, OPEN_EXISTING, 0, IntPtr.Zero);
            if (hub == INVALID) continue;
            try
            {
                byte[] ni = new byte[2048]; int rn = 0;
                if (!DeviceIoControl(hub, IOCTL_USB_GET_NODE_INFORMATION, ni, ni.Length, ni, ni.Length, ref rn, IntPtr.Zero)) continue;
                int ports = ni[6];
                for (int port = 1; port <= ports; port++)
                {
                    byte[] ci = new byte[600]; BitConverter.GetBytes(port).CopyTo(ci, 0); int r2 = 0;
                    if (!DeviceIoControl(hub, IOCTL_USB_GET_NODE_CONNECTION_INFORMATION_EX, ci, ci.Length, ci, ci.Length, ref r2, IntPtr.Zero)) continue;
                    if (BitConverter.ToUInt16(ci, 12) != vid || BitConverter.ToUInt16(ci, 14) != pid) continue;
                    Console.WriteLine("device on " + path + " port " + port);
                    string[] names = { "iface-recip 0x81 type0x22 len372", "dev-recip 0x80 type0x22 len372", "iface-recip 0x81 type0x21(HIDdesc) len9", "iface-recip 0x81 type0x22 len0xFFFF" };
                    var calls = new Func<Tuple<int,int,byte[]>>[] {
                        () => { int rr,ee; var b = GetDescriptorEx(hub, port, 0x81, 0x22, 0, 0, 372, out rr, out ee); return Tuple.Create(rr,ee,b); },
                        () => { int rr,ee; var b = GetDescriptorEx(hub, port, 0x80, 0x22, 0, 0, 372, out rr, out ee); return Tuple.Create(rr,ee,b); },
                        () => { int rr,ee; var b = GetDescriptorEx(hub, port, 0x81, 0x21, 0, 0, 9,   out rr, out ee); return Tuple.Create(rr,ee,b); },
                        () => { int rr,ee; var b = GetDescriptorEx(hub, port, 0x81, 0x22, 0, 0, 0xFFFF, out rr, out ee); return Tuple.Create(rr,ee,b); },
                    };
                    for (int k = 0; k < calls.Length; k++)
                    {
                        var t = calls[k]();
                        Console.WriteLine("  [" + names[k] + "] ret=" + t.Item1 + " err=" + t.Item2 + " bytes=" + (t.Item3 == null ? "null" : t.Item3.Length.ToString()));
                        if (t.Item3 != null && t.Item3.Length > 2) Console.WriteLine("    " + Hex(t.Item3));
                    }
                    return;
                }
            }
            finally { CloseHandle(hub); }
        }
    }

    public static void Dump(ushort vid, ushort pid)
    {
        foreach (var path in HubPaths())
        {
            IntPtr hub = CreateFile(path, GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_WRITE, IntPtr.Zero, OPEN_EXISTING, 0, IntPtr.Zero);
            if (hub == INVALID) continue;
            try
            {
                byte[] ni = new byte[2048];
                int ret = 0;
                if (!DeviceIoControl(hub, IOCTL_USB_GET_NODE_INFORMATION, ni, ni.Length, ni, ni.Length, ref ret, IntPtr.Zero)) continue;
                int ports = ni[6]; // NodeType(4) + USB_HUB_DESCRIPTOR.bNumberOfPorts(@+2)
                for (int port = 1; port <= ports; port++)
                {
                    byte[] ci = new byte[600];
                    BitConverter.GetBytes(port).CopyTo(ci, 0);
                    int r2 = 0;
                    if (!DeviceIoControl(hub, IOCTL_USB_GET_NODE_CONNECTION_INFORMATION_EX, ci, ci.Length, ci, ci.Length, ref r2, IntPtr.Zero)) continue;
                    ushort dvid = BitConverter.ToUInt16(ci, 12); // DeviceDescriptor@4 + idVendor@8
                    ushort dpid = BitConverter.ToUInt16(ci, 14);
                    if (dvid != vid || dpid != pid) continue;

                    Console.WriteLine("=== FOUND " + path + "  port " + port + " ===");
                    byte[] dd = new byte[18];
                    Array.Copy(ci, 4, dd, 0, 18);
                    Console.WriteLine("DEVICE_DESCRIPTOR: " + Hex(dd));
                    byte iMan = dd[14], iProd = dd[15], iSer = dd[16];
                    Console.WriteLine("  bcdUSB=0x" + BitConverter.ToUInt16(dd, 2).ToString("X4")
                        + " bMaxPacket0=" + dd[7]
                        + " bcdDevice=0x" + BitConverter.ToUInt16(dd, 12).ToString("X4")
                        + " bNumConfig=" + dd[17]);
                    DumpString(hub, port, iMan, "iManufacturer");
                    DumpString(hub, port, iProd, "iProduct");
                    DumpString(hub, port, iSer, "iSerial");

                    byte[] c9 = GetDescriptor(hub, port, 0x80, 0x02, 0, 0, 9);
                    if (c9 == null) { Console.WriteLine("config(9) FAILED"); return; }
                    ushort total = BitConverter.ToUInt16(c9, 2);
                    byte[] cfg = GetDescriptor(hub, port, 0x80, 0x02, 0, 0, total);
                    Console.WriteLine("CONFIG_DESCRIPTOR (" + total + " bytes):\n" + Hex(cfg));
                    ParseAndDumpHid(hub, port, cfg);
                    return;
                }
            }
            finally { CloseHandle(hub); }
        }
        Console.WriteLine("device " + vid.ToString("X4") + ":" + pid.ToString("X4") + " not found on any hub port");
    }

    static void DumpString(IntPtr hub, int port, byte idx, string label)
    {
        if (idx == 0) { Console.WriteLine("  " + label + " = (index 0 / none)"); return; }
        byte[] s = GetDescriptor(hub, port, 0x80, 0x03, idx, 0x0409, 255);
        if (s == null || s.Length < 2) { Console.WriteLine("  " + label + " = <fetch failed>"); return; }
        int len = s[0]; if (len > s.Length) len = s.Length;
        Console.WriteLine("  " + label + " [" + idx + "] = \"" + Encoding.Unicode.GetString(s, 2, len - 2) + "\"");
    }

    static void ParseAndDumpHid(IntPtr hub, int port, byte[] cfg)
    {
        int i = 0, curIf = -1;
        while (i + 1 < cfg.Length)
        {
            int bl = cfg[i], bt = cfg[i + 1];
            if (bl == 0) break;
            if (bt == 0x04) // INTERFACE
            {
                curIf = cfg[i + 2];
                Console.WriteLine("INTERFACE " + curIf + " class=0x" + cfg[i + 5].ToString("X2")
                    + " sub=0x" + cfg[i + 6].ToString("X2") + " proto=0x" + cfg[i + 7].ToString("X2")
                    + " nEp=" + cfg[i + 4]);
            }
            else if (bt == 0x21) // HID class descriptor
            {
                int ndesc = cfg[i + 5], j = i + 6;
                for (int d = 0; d < ndesc && j + 2 < cfg.Length; d++)
                {
                    int dtype = cfg[j], dlen = BitConverter.ToUInt16(cfg, j + 1);
                    Console.WriteLine("  HID class-descr: type=0x" + dtype.ToString("X2") + " len=" + dlen + " (iface " + curIf + ")");
                    if (dtype == 0x22)
                    {
                        byte[] rd = GetDescriptor(hub, port, 0x81, 0x22, 0, (ushort)curIf, dlen);
                        if (rd == null) Console.WriteLine("    !! REPORT_DESCRIPTOR fetch FAILED (iface " + curIf + ") — fall back to USBPcap");
                        else Console.WriteLine("    REPORT_DESCRIPTOR iface " + curIf + " (" + rd.Length + " bytes):\n" + Hex(rd));
                    }
                    j += 3;
                }
            }
            i += bl;
        }
    }

    static string Hex(byte[] b)
    {
        var sb = new StringBuilder();
        for (int i = 0; i < b.Length; i++) { sb.Append(b[i].ToString("X2")); sb.Append(i % 16 == 15 ? "\n" : " "); }
        return sb.ToString().TrimEnd();
    }
}
