const std = @import("std");
const windows = std.os.windows;
const user32 = @import("user32ext.zig");
//const winmm = @import("winmm.zig");
const soundio = @import("soundio");

const State = struct {
    // wavHandl: winmm.HWAVEOUT = undefined,
    hhk: user32.HHOOK = undefined,
    canPlay: bool = false,
    currentBuffer: [1024]f32 = undefined,
};
var state: State = .{};

const allocator = std.heap.page_allocator;
var keyMap = std.AutoHashMap(Keys, []const u8).init(allocator);
var keyMapShift = std.AutoHashMap(Keys, []const u8).init(allocator);

pub fn main() !void {
    var sio = try soundio.SoundIo.init();
    defer sio.deinit();

    var outstream = try sio.createOutputStream(allocator, .{
        .channel_layout = .mono,
        .sample_rate = 22050,
        .write_callback = sndio_callback,
    });
    defer outstream.deinit();

    try outstream.start();

    try addKeyMap();
    try addKeyMapShift();
    defer keyMap.deinit();
    defer keyMapShift.deinit();

    // var hndl: windows.LONG_PTR = @as(windows.LONG_PTR, 0);
    // var pwfx: winmm.WAVEFORMATEX = .{
    //     .wFormatTag = winmm.WAVE_FORMAT_PCM,
    //     .nChannels = 1,
    //     .nSamplesPerSec = 22050,
    //     .nAvgBytesPerSec = 176000,
    //     .nBlockAlign = (1 * 8) / 8,
    //     .wBitsPerSample = 8,
    //     .cbSize = 0,
    // };
    // var lppwfx: winmm.LPCWAVEFORMATEX = &pwfx;

    // var mmr = winmm.waveOutOpen(&hndl, winmm.MM_WAVE_MAPPER, lppwfx, &waveCallback, 0, winmm.CALLBACK_FUNCTION | winmm.WAVE_FORMAT_DIRECT);
    // if (mmr != winmm.MMSYSERR_NOERROR) {
    //     std.debug.print("Unable to open audio device. err: {d}\n", .{mmr});
    //     return;
    // }

    // const uhndl: usize = @intCast(hndl);
    // state.wavHandl = @ptrFromInt(uhndl);
    defer {
        std.debug.print("Unhooking.\n", .{});
        var uhr: u8 = 0;
        while (uhr == 0) {
            uhr = user32.UnhookWindowsHookEx(state.hhk);
            std.debug.print("UnhookWindowsHookEx returned {any}.\n", .{uhr});
            std.time.sleep(0.5 * 1000 * 1000 * 1000);
        }

        // std.debug.print("Stopping audio output.\n", .{});
        // mmr = 1;
        // while (mmr != 0) {
        //     mmr = winmm.waveOutClose(state.wavHandl);
        //     std.debug.print("waveOutClose returned {any}.\n", .{mmr});
        //     std.time.sleep(0.5 * 1000 * 1000 * 1000);
        // }
    }

    const nto = windows.kernel32.CreateThread(null, 0, &messageListener, null, 0, null);
    if (nto) |nt| {
        std.debug.print("Created message listener thread with handle {any}\n", .{nt});
    } else {
        @panic("Could not create message listener thread.");
    }

    const stdIn = std.io.getStdIn();
    var bufr = std.io.bufferedReader(stdIn.reader());
    const reader = bufr.reader();
    var msg_buf: [255]u8 = undefined;

    while (true) {
        var msgo = try reader.readUntilDelimiterOrEof(&msg_buf, '\n');
        if (msgo) |msg| {
            const tmsg = std.mem.trim(u8, msg, "\r\n");
            std.debug.print("Read: {s}\n", .{tmsg});
            if (std.mem.eql(u8, "quit", tmsg)) {
                break;
            }
        }
    }
}

var phase: f32 = 0.0;
fn sndio_callback(arg: ?*anyopaque, num_frames: usize, buffer: *soundio.Buffer) void {
    // _ = arg;

    // var frame: usize = 0;
    // while (frame < num_frames) : (frame += 1) {
    //     buffer.channels[0].data[frame] = state.currentBuffer[frame];
    // }

    // state.canPlay = true;

    _ = arg;

    const freq: f32 = 261.63; // Middle C.
    const sample_rate_f: f32 = 22050;
    const amplitude: f32 = 0.4; // Not too loud.

    var frame: usize = 0;
    while (frame < num_frames) : (frame += 1) {
        const val = amplitude * (2.0 * std.math.fabs(2.0 * phase - 1.0) - 1);
        buffer.channels[0].set(frame, val);

        phase += freq / sample_rate_f;
        if (phase >= 1.0)
            phase -= 1.0;
    }
}

fn messageListener(_: windows.LPVOID) callconv(windows.WINAPI) windows.DWORD {
    std.debug.print("Setting hook.\n", .{});

    state.hhk = user32.SetWindowsHookExW(13, &hookHandler, null, 0);

    _ = user32.PostMessageW(null, 0, 0, 0);

    if (@intFromPtr(state.hhk) != 0) {
        std.debug.print("Waiting. Hook is {any}\n", .{state.hhk});
    }

    state.canPlay = true;

    while (true) {
        var msg: windows.user32.MSG = undefined;
        windows.user32.getMessageW(&msg, null, 0, 0) catch @panic("getMessageW failed.");

        std.debug.print("Msg: {any}\n", .{msg});
    }
}

pub fn hookHandler(code: windows.INT, wParam: windows.WPARAM, lParam: windows.LPARAM) windows.LRESULT {
    const ks: KeyState = if (wParam == 0x101) .Down else .Up;
    if (ks != .Up) {
        return user32.CallNextHookEx(0, code, wParam, lParam);
    }

    const ulParam: usize = @intCast(lParam);
    var cwpr: *user32.KBDLLHOOKSTRUCT = undefined;
    cwpr = @ptrFromInt(ulParam);

    // std.debug.print("Hook called with code: {d}, wParam: 0x{x}, lParam:fff 0x{x}.\n", .{ code, wParam, lParam });
    //std.debug.print("cwpr: {any}\n", .{cwpr});

    switch (cwpr.vkCode) {
        8 => playClack(.Backspace, ks),
        13 => playClack(.Enter, ks),
        32 => playClack(.Space, ks),
        48...57 => playClack(.Generic2, ks),
        96...119 => playClack(.Generic1, ks),
        else => playClack(.Generic0, ks),
    }

    // if (ks == .Up) {
    //     var keycode: Keys = @enumFromInt(cwpr.vkCode);
    //     switch (keycode) {
    //         .Enter => std.debug.print("\n", .{}),
    //         //.Space => std.debug.print(" ", .{}),
    //         .Tab => std.debug.print("\t", .{}),
    //         else => std.debug.print("{s} ", .{@tagName(keycode)}),
    //     }
    // }

    return user32.CallNextHookEx(0, code, wParam, lParam);
}

// fn waveCallback(hwo: winmm.HWAVEOUT, uMsg: windows.UINT, dwInst: windows.DWORD_PTR, dwParam1: windows.DWORD_PTR, dwParam2: windows.DWORD_PTR) void {
//     _ = hwo;
//     _ = dwInst;
//     _ = dwParam1;
//     _ = dwParam2;

//     const msg = switch (uMsg) {
//         winmm.WOM_OPEN => "WOM_OPEN",
//         winmm.WOM_CLOSE => "WOM_CLOSE",
//         winmm.WOM_DONE => "WOM_DONE",
//         else => {
//             std.debug.print("{d}\n", .{uMsg});
//             @panic("unknown msg type.");
//         },
//     };

//     switch (uMsg) {
//         winmm.WOM_OPEN => state.canPlay = true,
//         winmm.WOM_CLOSE => state.canPlay = false,
//         winmm.WOM_DONE => state.canPlay = true,
//         else => unreachable, // would've paniced before reaching this
//     }

//     std.debug.print("uMsg: {s}\n", .{msg});
// }

fn playClack(sType: Sound, _: KeyState) void {
    if (!state.canPlay) return;

    //std.debug.print("CLACK! {s} {s}\n", .{ @tagName(sType), @tagName(keyState) });

    var soundFile: []const u8 = switch (sType) {
        //.Backspace => @embedFile("sounds/Dell_allSpeakers_mono.wav"),
        .Backspace => @embedFile("sounds/backspace.wav"),
        .Enter => @embedFile("sounds/enter.wav"),
        .Space => @embedFile("sounds/space.wav"),
        .Generic0 => @embedFile("sounds/generic0.wav"),
        .Generic1 => @embedFile("sounds/generic1.wav"),
        .Generic2 => @embedFile("sounds/generic2.wav"),
        .Generic3 => @embedFile("sounds/generic3.wav"),
        .Generic4 => @embedFile("sounds/generic4.wav"),
    };
    state.canPlay = false;

    var bi: usize = 0;
    var i: usize = 0;
    while (i < soundFile.len) : (i += 4) {
        const b1: u32 = if (i + 0 < soundFile.len) @shlExact(@as(u32, soundFile[i + 0]), 24) else 0;
        const b2: u32 = if (i + 1 < soundFile.len) @shlExact(@as(u32, soundFile[i + 1]), 16) else 0;
        const b3: u32 = if (i + 2 < soundFile.len) @shlExact(@as(u32, soundFile[i + 2]), 8) else 0;
        const b4: u32 = if (i + 3 < soundFile.len) @shlExact(@as(u32, soundFile[i + 3]), 0) else 0;

        const f: f32 = @bitCast(b1 | b2 | b3 | b4);
        state.currentBuffer[bi] = f;
        bi += 1;
    }
    while (bi < state.currentBuffer.len) : (bi += 1) {
        state.currentBuffer[bi] = 0;
    }

    // var wh: winmm.WAVEHDR = .{
    //     .lpData = @ptrCast(@constCast(soundFile)),
    //     .dwBufferLength = @intCast(soundFile.len),
    //     .dwBytesRecorded = 0,
    //     .dwUser = 0,
    //     .dwFlags = 0,
    //     .dwLoops = 0,
    //     .lpNext = 0,
    //     .reserved = 0,
    // };

    // var pwh: winmm.LPWAVEHDR = &wh;
    // var mmr = winmm.waveOutPrepareHeader(state.wavHandl, pwh, @sizeOf(winmm.WAVEHDR));
    // if (mmr != winmm.MMSYSERR_NOERROR) return;

    // std.debug.print("waveOutPrepareHeader.dwFlags: {b:08}\n", .{wh.dwFlags});

    // mmr = winmm.waveOutWrite(state.wavHandl, pwh, @sizeOf(winmm.WAVEHDR));
    // if (mmr != winmm.MMSYSERR_NOERROR) return;

    // std.debug.print("waveOutWrite.dwFlags:         {b:08}\n", .{wh.dwFlags});

    //std.time.sleep(1 * 1000 * 1000 * 1000);

    // mmr = winmm.waveOutUnprepareHeader(wavHandl, pwh, @sizeOf(winmm.WAVEHDR));
    // if (mmr != 0) return;
}

const KeyState = enum { Down, Up };
const Sound = enum { Generic0, Generic1, Generic2, Generic3, Generic4, Space, Enter, Backspace };

// keyMap
fn addKeyMap() !void {
    try keyMap.put(Keys.Attn, "[Attn]");
    try keyMap.put(Keys.Clear, "[Clear]");
    try keyMap.put(Keys.Down, "[Down]");
    try keyMap.put(Keys.Up, "[Up]");
    try keyMap.put(Keys.Left, "[Left]");
    try keyMap.put(Keys.Right, "[Right]");
    try keyMap.put(Keys.Escape, "[Escape]");
    try keyMap.put(Keys.Tab, "[Tab]");
    try keyMap.put(Keys.LWin, "[LeftWin]");
    try keyMap.put(Keys.RWin, "[RightWin]");
    try keyMap.put(Keys.PrintScreen, "[PrintScreen]");
    try keyMap.put(Keys.D0, "0");
    try keyMap.put(Keys.D1, "1");
    try keyMap.put(Keys.D2, "2");
    try keyMap.put(Keys.D3, "3");
    try keyMap.put(Keys.D4, "4");
    try keyMap.put(Keys.D5, "5");
    try keyMap.put(Keys.D6, "6");
    try keyMap.put(Keys.D7, "7");
    try keyMap.put(Keys.D8, "8");
    try keyMap.put(Keys.D9, "9");
    try keyMap.put(Keys.Space, " ");
    try keyMap.put(Keys.NumLock, "[NumLock]");
    try keyMap.put(Keys.Alt, "[Alt]");
    try keyMap.put(Keys.LControlKey, "[LeftControl]");
    try keyMap.put(Keys.RControlKey, "[RightControl]");
    try keyMap.put(Keys.Delete, "[Delete]");
    try keyMap.put(Keys.Enter, "[Enter]");
    try keyMap.put(Keys.Divide, "/");
    try keyMap.put(Keys.Multiply, "*");
    try keyMap.put(Keys.Add, "+");
    try keyMap.put(Keys.Subtract, "-");
    try keyMap.put(Keys.PageDown, "[PageDown]");
    try keyMap.put(Keys.PageUp, "[PageUp]");
    try keyMap.put(Keys.End, "[End]");
    try keyMap.put(Keys.Insert, "[Insert]");
    try keyMap.put(Keys.Decimal, ".");
    try keyMap.put(Keys.OemSemicolon, ";");
    try keyMap.put(Keys.Oemtilde, "`");
    try keyMap.put(Keys.Oemplus, "=");
    try keyMap.put(Keys.OemMinus, "-");
    try keyMap.put(Keys.Oemcomma, ",");
    try keyMap.put(Keys.OemPeriod, ".");
    try keyMap.put(Keys.OemPipe, "\\");
    try keyMap.put(Keys.OemQuotes, "\"");
    try keyMap.put(Keys.OemCloseBrackets, "]");
    try keyMap.put(Keys.OemOpenBrackets, "[");
    try keyMap.put(Keys.Home, "[Home]");
    try keyMap.put(Keys.Back, "[Backspace]");
    try keyMap.put(Keys.NumPad0, "0");
    try keyMap.put(Keys.NumPad1, "1");
    try keyMap.put(Keys.NumPad2, "2");
    try keyMap.put(Keys.NumPad3, "3");
    try keyMap.put(Keys.NumPad4, "4");
    try keyMap.put(Keys.NumPad5, "5");
    try keyMap.put(Keys.NumPad6, "6");
    try keyMap.put(Keys.NumPad7, "7");
    try keyMap.put(Keys.NumPad8, "8");
    try keyMap.put(Keys.NumPad9, "9");
}

// keyMapShift
fn addKeyMapShift() !void {
    try keyMapShift.put(Keys.D0, ")");
    try keyMapShift.put(Keys.D1, "!");
    try keyMapShift.put(Keys.D2, "@");
    try keyMapShift.put(Keys.D3, "#");
    try keyMapShift.put(Keys.D4, "$");
    try keyMapShift.put(Keys.D5, "%");
    try keyMapShift.put(Keys.D6, "^");
    try keyMapShift.put(Keys.D7, "&");
    try keyMapShift.put(Keys.D8, "*");
    try keyMapShift.put(Keys.D9, "(");
    try keyMapShift.put(Keys.OemSemicolon, ":");
    try keyMapShift.put(Keys.Oemtilde, "~");
    try keyMapShift.put(Keys.Oemplus, "+");
    try keyMapShift.put(Keys.OemMinus, "_");
    try keyMapShift.put(Keys.Oemcomma, "<");
    try keyMapShift.put(Keys.OemPeriod, ">");
    try keyMapShift.put(Keys.OemPipe, "|");
    try keyMapShift.put(Keys.OemQuotes, "'");
    try keyMapShift.put(Keys.OemCloseBrackets, "");
    try keyMapShift.put(Keys.OemOpenBrackets, "");
}

const Keys = enum(u32) {
    //Modifiers = -65536,
    None = 0,
    LButton = 1,
    RButton = 2,
    Cancel = 3,
    MButton = 4,
    XButton1 = 5,
    XButton2 = 6,
    Back = 8,
    Tab = 9,
    LineFeed = 10,
    Clear = 12,
    //Return = 13,
    Enter = 13,
    ShiftKey = 16,
    ControlKey = 17,
    Menu = 18,
    Pause = 19,
    Capital = 20,
    //CapsLock = 20,
    KanaMode = 21,
    //HanguelMode = 21,
    //HangulMode = 21,
    JunjaMode = 23,
    FinalMode = 24,
    //HanjaMode = 25,
    KanjiMode = 25,
    Escape = 27,
    IMEConvert = 28,
    IMENonconvert = 29,
    IMEAccept = 30,
    //IMEAceept = 30,
    IMEModeChange = 31,
    Space = 32,
    //Prior = 33,
    PageUp = 33,
    //Next = 34,
    PageDown = 34,
    End = 35,
    Home = 36,
    Left = 37,
    Up = 38,
    Right = 39,
    Down = 40,
    Select = 41,
    Print = 42,
    Execute = 43,
    //Snapshot = 44,
    PrintScreen = 44,
    Insert = 45,
    Delete = 46,
    Help = 47,
    D0 = 48,
    D1 = 49,
    D2 = 50,
    D3 = 51,
    D4 = 52,
    D5 = 53,
    D6 = 54,
    D7 = 55,
    D8 = 56,
    D9 = 57,
    A = 65,
    B = 66,
    C = 67,
    D = 68,
    E = 69,
    F = 70,
    G = 71,
    H = 72,
    I = 73,
    J = 74,
    K = 75,
    L = 76,
    M = 77,
    N = 78,
    O = 79,
    P = 80,
    Q = 81,
    R = 82,
    S = 83,
    T = 84,
    U = 85,
    V = 86,
    W = 87,
    X = 88,
    Y = 89,
    Z = 90,
    LWin = 91,
    RWin = 92,
    Apps = 93,
    Sleep = 95,
    NumPad0 = 96,
    NumPad1 = 97,
    NumPad2 = 98,
    NumPad3 = 99,
    NumPad4 = 100,
    NumPad5 = 101,
    NumPad6 = 102,
    NumPad7 = 103,
    NumPad8 = 104,
    NumPad9 = 105,
    Multiply = 106,
    Add = 107,
    Separator = 108,
    Subtract = 109,
    Decimal = 110,
    Divide = 111,
    F1 = 112,
    F2 = 113,
    F3 = 114,
    F4 = 115,
    F5 = 116,
    F6 = 117,
    F7 = 118,
    F8 = 119,
    F9 = 120,
    F10 = 121,
    F11 = 122,
    F12 = 123,
    F13 = 124,
    F14 = 125,
    F15 = 126,
    F16 = 127,
    F17 = 128,
    F18 = 129,
    F19 = 130,
    F20 = 131,
    F21 = 132,
    F22 = 133,
    F23 = 134,
    F24 = 135,
    NumLock = 144,
    Scroll = 145,
    LShiftKey = 160,
    RShiftKey = 161,
    LControlKey = 162,
    RControlKey = 163,
    LMenu = 164,
    RMenu = 165,
    BrowserBack = 166,
    BrowserForward = 167,
    BrowserRefresh = 168,
    BrowserStop = 169,
    BrowserSearch = 170,
    BrowserFavorites = 171,
    BrowserHome = 172,
    VolumeMute = 173,
    VolumeDown = 174,
    VolumeUp = 175,
    MediaNextTrack = 176,
    MediaPreviousTrack = 177,
    MediaStop = 178,
    MediaPlayPause = 179,
    LaunchMail = 180,
    SelectMedia = 181,
    LaunchApplication1 = 182,
    LaunchApplication2 = 183,
    OemSemicolon = 186,
    //Oem1 = 186,
    Oemplus = 187,
    Oemcomma = 188,
    OemMinus = 189,
    OemPeriod = 190,
    OemQuestion = 191,
    //Oem2 = 191,
    Oemtilde = 192,
    //Oem3 = 192,
    OemOpenBrackets = 219,
    //Oem4 = 219,
    OemPipe = 220,
    //Oem5 = 220,
    OemCloseBrackets = 221,
    //Oem6 = 221,
    OemQuotes = 222,
    //Oem7 = 222,
    Oem8 = 223,
    OemBackslash = 226,
    //Oem102 = 226,
    ProcessKey = 229,
    Packet = 231,
    Attn = 246,
    Crsel = 247,
    Exsel = 248,
    EraseEof = 249,
    Play = 250,
    Zoom = 251,
    NoName = 252,
    Pa1 = 253,
    OemClear = 254,
    KeyCode = 65535,
    Shift = 65536,
    Control = 131072,
    Alt = 262144,
};
