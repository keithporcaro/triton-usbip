// HidInputDump.cs — read raw input reports from the synthetic Triton's vendor collection (COL03),
// i.e. exactly what the iPad feeds Steam (the 0x42 state report after BLE->USB translation).
// Synchronous blocking reads; the controller feeds continuously so they return promptly.
// Usage (PowerShell):  $src = gc -raw HidInputDump.cs; Add-Type -TypeDefinition $src; [HidInput]::Dump(24)
using System;
using System.Runtime.InteropServices;
using System.Text;

public static class HidInput
{
    const uint GENERIC_READ = 0x80000000;
    const uint GENERIC_WRITE = 0x40000000;
    const uint FILE_SHARE_READ = 1, FILE_SHARE_WRITE = 2, OPEN_EXISTING = 3;
    const uint DIGCF_PRESENT = 0x2, DIGCF_DEVICEINTERFACE = 0x10;
    static readonly Guid GUID_HID = new Guid("4D1E55B2-F16F-11CF-88CB-001111000030");
    static readonly IntPtr INVALID = new IntPtr(-1);

    [DllImport("setupapi.dll", CharSet=CharSet.Unicode, SetLastError=true)]
    static extern IntPtr SetupDiGetClassDevs(ref Guid g, IntPtr e, IntPtr h, uint f);
    [DllImport("setupapi.dll", SetLastError=true)]
    static extern bool SetupDiEnumDeviceInterfaces(IntPtr h, IntPtr d, ref Guid g, uint i, ref SP_DEVICE_INTERFACE_DATA a);
    [DllImport("setupapi.dll", CharSet=CharSet.Unicode, SetLastError=true)]
    static extern bool SetupDiGetDeviceInterfaceDetail(IntPtr h, ref SP_DEVICE_INTERFACE_DATA a, IntPtr det, uint sz, ref uint req, IntPtr dd);
    [DllImport("setupapi.dll")] static extern bool SetupDiDestroyDeviceInfoList(IntPtr h);
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
    static extern IntPtr CreateFile(string n, uint a, uint s, IntPtr sec, uint d, uint f, IntPtr t);
    [DllImport("kernel32.dll", SetLastError=true)] static extern bool CloseHandle(IntPtr h);
    [DllImport("kernel32.dll", SetLastError=true)]
    static extern bool ReadFile(IntPtr h, byte[] buf, uint n, out uint read, IntPtr ov);
    [DllImport("hid.dll", SetLastError=true)]
    static extern bool HidD_SetFeature(IntPtr h, byte[] buf, uint len);
    [DllImport("hid.dll", SetLastError=true)]
    static extern bool HidD_SetOutputReport(IntPtr h, byte[] buf, uint len);
    [DllImport("kernel32.dll", SetLastError=true)]
    static extern bool WriteFile(IntPtr h, byte[] buf, uint n, out uint written, IntPtr ov);

    [StructLayout(LayoutKind.Sequential)]
    struct SP_DEVICE_INTERFACE_DATA { public int cbSize; public Guid g; public int flags; public IntPtr res; }

    static string FindPath(string contains)
    {
        Guid g = GUID_HID;
        IntPtr h = SetupDiGetClassDevs(ref g, IntPtr.Zero, IntPtr.Zero, DIGCF_PRESENT | DIGCF_DEVICEINTERFACE);
        if (h == INVALID) return null;
        try {
            var did = new SP_DEVICE_INTERFACE_DATA(); did.cbSize = Marshal.SizeOf(did);
            uint i = 0;
            while (SetupDiEnumDeviceInterfaces(h, IntPtr.Zero, ref g, i++, ref did)) {
                uint req = 0;
                SetupDiGetDeviceInterfaceDetail(h, ref did, IntPtr.Zero, 0, ref req, IntPtr.Zero);
                if (req == 0) continue;
                IntPtr det = Marshal.AllocHGlobal((int)req);
                try {
                    Marshal.WriteInt32(det, IntPtr.Size == 8 ? 8 : 6);
                    uint r2 = 0;
                    if (SetupDiGetDeviceInterfaceDetail(h, ref did, det, req, ref r2, IntPtr.Zero)) {
                        string p = Marshal.PtrToStringUni(new IntPtr(det.ToInt64() + 4));
                        if (p != null && p.ToLower().Contains(contains)) return p;
                    }
                } finally { Marshal.FreeHGlobal(det); }
            }
        } finally { SetupDiDestroyDeviceInfoList(h); }
        return null;
    }

    public static void Dump(int count)
    {
        string path = FindPath("vid_28de&pid_1302&col03");
        if (path == null) { Console.WriteLine("COL03 vendor HID interface not found (is the device attached?)"); return; }
        Console.WriteLine("device: " + path);
        IntPtr dev = CreateFile(path, GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE, IntPtr.Zero, OPEN_EXISTING, 0, IntPtr.Zero);
        if (dev == INVALID) { Console.WriteLine("open failed err=" + Marshal.GetLastWin32Error()); return; }
        try {
            int got = 0;
            while (got < count) {
                byte[] buf = new byte[64];
                uint read;
                if (!ReadFile(dev, buf, (uint)buf.Length, out read, IntPtr.Zero)) {
                    Console.WriteLine("read err=" + Marshal.GetLastWin32Error()); break;
                }
                if (read == 0) continue;
                var sb = new StringBuilder();
                for (int k = 0; k < read && k < 56; k++) sb.Append(buf[k].ToString("X2")).Append(' ');
                Console.WriteLine("[" + read + "] " + sb.ToString().Trim());
                got++;
            }
            Console.WriteLine("captured " + got + " reports");
        } finally { CloseHandle(dev); }
    }

    // Watch only the IMU block (wire bytes 30..45 = u32 timestamp + 6x s16 accel/gyro) across
    // `count` frames. Verdict = did the IMU data or its timestamp ever change? Rotate the
    // controller through all axes during the capture: LIVE -> changes; FROZEN/OFF -> never moves.
    public static void ImuWatch(int count)
    {
        string path = FindPath("vid_28de&pid_1302&col03");
        if (path == null) { Console.WriteLine("COL03 not found"); return; }
        IntPtr dev = CreateFile(path, GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE, IntPtr.Zero, OPEN_EXISTING, 0, IntPtr.Zero);
        if (dev == INVALID) { Console.WriteLine("open failed err=" + Marshal.GetLastWin32Error()); return; }
        try {
            byte[] baseImu = null;
            int frames = 0, changed = 0;
            uint tsMin = uint.MaxValue, tsMax = 0;
            int sampleEvery = count / 10; if (sampleEvery < 1) sampleEvery = 1;
            while (frames < count) {
                byte[] buf = new byte[64];
                uint read;
                if (!ReadFile(dev, buf, (uint)buf.Length, out read, IntPtr.Zero)) {
                    Console.WriteLine("read err=" + Marshal.GetLastWin32Error()); break;
                }
                if (read < 46) continue;                 // need wire bytes 30..45
                byte[] imu = new byte[16];
                Array.Copy(buf, 30, imu, 0, 16);
                uint ts = (uint)(imu[0] | (imu[1] << 8) | (imu[2] << 16) | (imu[3] << 24));
                if (ts < tsMin) tsMin = ts;
                if (ts > tsMax) tsMax = ts;
                if (baseImu == null) {
                    baseImu = imu;
                    Console.WriteLine("base IMU @frame0: " + Hex(imu) + "  ts=" + ts);
                } else {
                    bool diff = false;
                    for (int k = 0; k < 16; k++) if (imu[k] != baseImu[k]) { diff = true; break; }
                    if (diff) changed++;
                }
                if (frames % sampleEvery == 0)
                    Console.WriteLine("frame " + frames + " seq=" + buf[1].ToString("X2") + " imu=" + Hex(imu) + " ts=" + ts);
                frames++;
            }
            Console.WriteLine("---");
            Console.WriteLine("frames=" + frames + " imuChangedFrames=" + changed +
                              " tsSpan=" + (tsMax - tsMin) + " (tsMin=" + tsMin + " tsMax=" + tsMax + ")");
            Console.WriteLine((changed == 0 && (tsMax - tsMin) == 0)
                ? "VERDICT: IMU FROZEN (no data change + timestamp never advanced) -> IMU is OFF / not streaming"
                : "VERDICT: IMU LIVE (data and/or timestamp changed during capture)");
        } finally { CloseHandle(dev); }
    }

    // Empirically find the enable-gyro command: send WRITE_REGISTER (0x87) on feature report 0x01
    // -> [01][87][03][reg][lo][hi] padded to 64 -> then watch the IMU. If the timestamp starts
    // advancing, the gyro hardware woke up (reg 0x30 GYRO_MODE, value 0x18 = raw accel|raw gyro).
    public static void ProbeGyro(int reg, int value16, int count)
    {
        string path = FindPath("vid_28de&pid_1302&col03");
        if (path == null) { Console.WriteLine("COL03 not found"); return; }
        IntPtr dev = CreateFile(path, GENERIC_READ | GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_WRITE, IntPtr.Zero, OPEN_EXISTING, 0, IntPtr.Zero);
        if (dev == INVALID) { Console.WriteLine("open(rw) failed err=" + Marshal.GetLastWin32Error() + " (Steam may hold write access; try with Steam closed)"); return; }
        try {
            byte[] feat = new byte[64];
            feat[0] = 0x01;                            // feature report id = vendor command channel
            feat[1] = 0x87;                            // WRITE_REGISTER / SET_SETTINGS
            feat[2] = 0x03;                            // payload len: one (reg,lo,hi) triplet
            feat[3] = (byte)reg;                       // 0x30 = GYRO_MODE
            feat[4] = (byte)(value16 & 0xFF);
            feat[5] = (byte)((value16 >> 8) & 0xFF);
            bool ok = HidD_SetFeature(dev, feat, (uint)feat.Length);
            Console.WriteLine("SetFeature WRITE_REGISTER reg=0x" + reg.ToString("X2") + " val=0x" + value16.ToString("X4") +
                              " -> " + (ok ? "OK" : ("FAIL err=" + Marshal.GetLastWin32Error())));
            byte[] baseImu = null; int frames = 0, changed = 0; uint tsMin = uint.MaxValue, tsMax = 0;
            int sampleEvery = count / 10; if (sampleEvery < 1) sampleEvery = 1;
            while (frames < count) {
                byte[] buf = new byte[64]; uint read;
                if (!ReadFile(dev, buf, (uint)buf.Length, out read, IntPtr.Zero)) { Console.WriteLine("read err=" + Marshal.GetLastWin32Error()); break; }
                if (read < 46) continue;
                byte[] imu = new byte[16]; Array.Copy(buf, 30, imu, 0, 16);
                uint ts = (uint)(imu[0] | (imu[1] << 8) | (imu[2] << 16) | (imu[3] << 24));
                if (ts < tsMin) tsMin = ts;
                if (ts > tsMax) tsMax = ts;
                if (baseImu == null) { baseImu = imu; Console.WriteLine("base IMU: " + Hex(imu) + " ts=" + ts); }
                else { bool d = false; for (int k = 0; k < 16; k++) if (imu[k] != baseImu[k]) { d = true; break; } if (d) changed++; }
                if (frames % sampleEvery == 0) Console.WriteLine("frame " + frames + " imu=" + Hex(imu) + " ts=" + ts);
                frames++;
            }
            Console.WriteLine("--- frames=" + frames + " imuChangedFrames=" + changed + " tsSpan=" + (tsMax - tsMin));
            Console.WriteLine((changed == 0 && (tsMax - tsMin) == 0)
                ? "STILL FROZEN (this reg/value/channel did not enable the IMU)"
                : "IMU WOKE UP -> this enable command works!");
        } finally { CloseHandle(dev); }
    }

    // Send a Triton HAPTIC_RUMBLE output report (report id 0x80) to the controller THROUGH the
    // synthetic, resending every ~40ms for durationMs (the motor auto-stops after ~50ms, so a
    // one-shot is imperceptible). Layout: 80 | type | intensity(2) | Lspeed(2) Lgain | Rspeed(2) Rgain.
    // Tries WriteFile (interrupt-OUT) first, falls back to HidD_SetOutputReport.
    public static void SendRumble(int durationMs)
    {
        string path = FindPath("vid_28de&pid_1302&col03");
        if (path == null) { Console.WriteLine("COL03 not found"); return; }
        IntPtr dev = CreateFile(path, GENERIC_READ | GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_WRITE, IntPtr.Zero, OPEN_EXISTING, 0, IntPtr.Zero);
        if (dev == INVALID) { Console.WriteLine("open(rw) failed err=" + Marshal.GetLastWin32Error() + " (try with Steam closed)"); return; }
        try {
            byte[] r = new byte[64];           // OutputReportByteLength (largest output 0x87/0x88/0x89 = 63+1)
            r[0] = 0x80;                        // ID_OUT_REPORT_HAPTIC_RUMBLE
            r[1] = 0x00;                        // type
            r[2] = 0xFF; r[3] = 0xFF;           // intensity
            r[4] = 0xFF; r[5] = 0xFF;           // left.speed
            r[6] = 0xFF;                        // left.gain
            r[7] = 0xFF; r[8] = 0xFF;           // right.speed
            r[9] = 0xFF;                        // right.gain
            int wf = 0, wfFail = 0, so = 0;
            var sw = System.Diagnostics.Stopwatch.StartNew();
            while (sw.ElapsedMilliseconds < durationMs) {
                uint wrote;
                if (WriteFile(dev, r, (uint)r.Length, out wrote, IntPtr.Zero)) wf++;
                else { wfFail++; if (HidD_SetOutputReport(dev, r, (uint)r.Length)) so++; }
                System.Threading.Thread.Sleep(40);
            }
            Console.WriteLine("rumble 0x80 for " + durationMs + "ms @40ms -> WriteFile ok=" + wf +
                              " fail=" + wfFail + " (lastErr=" + Marshal.GetLastWin32Error() + ") SetOutputReport ok=" + so);
        } finally { CloseHandle(dev); }
    }

    // Fire an arbitrary OUTPUT report [id][payload...] at the synthetic's interrupt-OUT. The bridge
    // routes it to characteristic 100F6C<id+0x35> (id stripped). payloadHex = space/comma-separated
    // hex bytes (the bytes AFTER the report id). durationMs>0 resends @40ms (for sustained rumble);
    // 0 = one-shot.  e.g. SendOutput(0x80,"00 ff ff ff ff ff ff ff ff",2000) grip rumble;
    //                     SendOutput(0x82,"03 01 ff",0) one-shot haptic command (ping-style);
    //                     SendOutput(0x81,"01 64 00 64 00 0a 00",800) left trackpad pulse train.
    public static void SendOutput(int id, string payloadHex, int durationMs)
    {
        string path = FindPath("vid_28de&pid_1302&col03");
        if (path == null) { Console.WriteLine("COL03 not found"); return; }
        IntPtr dev = CreateFile(path, GENERIC_READ | GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_WRITE, IntPtr.Zero, OPEN_EXISTING, 0, IntPtr.Zero);
        if (dev == INVALID) { Console.WriteLine("open(rw) failed err=" + Marshal.GetLastWin32Error() + " (try Steam closed)"); return; }
        try {
            byte[] r = new byte[64];
            r[0] = (byte)id;
            var parts = (payloadHex ?? "").Split(new[] { ' ', ',', '\t' }, StringSplitOptions.RemoveEmptyEntries);
            for (int i = 0; i < parts.Length && i + 1 < r.Length; i++) r[i + 1] = Convert.ToByte(parts[i], 16);
            int wf = 0, so = 0;
            var sw = System.Diagnostics.Stopwatch.StartNew();
            do {
                uint wrote;
                if (WriteFile(dev, r, (uint)r.Length, out wrote, IntPtr.Zero)) wf++;
                else if (HidD_SetOutputReport(dev, r, (uint)r.Length)) so++;
                if (durationMs > 0) System.Threading.Thread.Sleep(40);
            } while (sw.ElapsedMilliseconds < durationMs);
            Console.WriteLine("output id=0x" + id.ToString("X2") + " -> char=...100f6c" + (((id + 0x35) & 0xff).ToString("x2")) +
                              " payload[" + parts.Length + "] for " + durationMs + "ms -> WriteFile ok=" + wf + " SetOutputReport ok=" + so);
        } finally { CloseHandle(dev); }
    }

    static string Hex(byte[] b)
    {
        var sb = new StringBuilder();
        for (int i = 0; i < b.Length; i++) sb.Append(b[i].ToString("X2")).Append(' ');
        return sb.ToString().Trim();
    }
}
