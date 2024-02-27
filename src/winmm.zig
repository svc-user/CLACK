const std = @import("std");
const windows = std.os.windows;

pub const HWAVEOUT = windows.HANDLE;
const MMRESULT = usize;
pub const WAVEFORMATEX = extern struct {
    wFormatTag: windows.WORD,
    nChannels: windows.WORD,
    nSamplesPerSec: windows.DWORD,
    nAvgBytesPerSec: windows.DWORD,
    nBlockAlign: windows.WORD,
    wBitsPerSample: windows.WORD,
    cbSize: windows.WORD,
};

pub const WAVEHDR = extern struct {
    lpData: windows.LPSTR,
    dwBufferLength: windows.DWORD,
    dwBytesRecorded: windows.DWORD,
    dwUser: windows.DWORD_PTR,
    dwFlags: windows.DWORD,
    dwLoops: windows.DWORD,
    lpNext: windows.LONG_PTR,
    reserved: windows.DWORD_PTR,
};
pub const LPWAVEHDR = [*c]WAVEHDR;

const WaveOutProc = ?*const fn (hwo: HWAVEOUT, uMsg: windows.UINT, dwInst: windows.DWORD_PTR, dwParam1: windows.DWORD_PTR, dwParam2: windows.DWORD_PTR) void;

pub const MM_WAVE_MAPPER = 2;
pub const WAVE_FORMAT_PCM = 1;

pub const CALLBACK_TYPEMASK = 0x00070000; // callback type mask
pub const CALLBACK_NULL = 0x00000000; // no callback
pub const CALLBACK_WINDOW = 0x00010000; // dwCallback is a HWND
pub const CALLBACK_TASK = 0x00020000; // dwCallback is a HTASK
pub const CALLBACK_THREAD = CALLBACK_TASK; // dwCallback is a thread ID
pub const CALLBACK_FUNCTION = 0x00030000; // dwCallback is a FARPROC
pub const CALLBACK_EVENT = 0x00050000; // dwCallback is an EVENT Handler

pub const WAVE_FORMAT_QUERY = 0x0001;
pub const WAVE_ALLOWSYNC = 0x0002;
pub const WAVE_MAPPED = 0x0004;
pub const WAVE_FORMAT_DIRECT = 0x0008;
pub const WAVE_FORMAT_DIRECT_QUERY = (WAVE_FORMAT_QUERY | WAVE_FORMAT_DIRECT);

pub const MMSYSERR_BASE = 0;
pub const WAVERR_BASE = 32;
pub const MIDIERR_BASE = 64;
pub const TIMERR_BASE = 96;
pub const JOYERR_BASE = 160;
pub const MCIERR_BASE = 256;

pub const MMSYSERR_NOERROR = 0;
pub const MMSYSERR_ERROR = MMSYSERR_BASE + 1;
pub const MMSYSERR_BADDEVICEID = MMSYSERR_BASE + 2;
pub const MMSYSERR_NOTENABLED = MMSYSERR_BASE + 3;
pub const MMSYSERR_ALLOCATED = MMSYSERR_BASE + 4;
pub const MMSYSERR_INVALHANDLE = MMSYSERR_BASE + 5;
pub const MMSYSERR_NODRIVER = MMSYSERR_BASE + 6;
pub const MMSYSERR_NOMEM = MMSYSERR_BASE + 7;
pub const MMSYSERR_NOTSUPPORTED = MMSYSERR_BASE + 8;
pub const MMSYSERR_BADERRNUM = MMSYSERR_BASE + 9;
pub const MMSYSERR_INVALFLAG = MMSYSERR_BASE + 10;
pub const MMSYSERR_INVALPARAM = MMSYSERR_BASE + 11;
pub const MMSYSERR_HANDLEBUSY = MMSYSERR_BASE + 12;
pub const MMSYSERR_INVALIDALIAS = MMSYSERR_BASE + 13;
pub const MMSYSERR_BADDB = MMSYSERR_BASE + 14;
pub const MMSYSERR_KEYNOTFOUND = MMSYSERR_BASE + 15;
pub const MMSYSERR_READERROR = MMSYSERR_BASE + 16;
pub const MMSYSERR_WRITEERROR = MMSYSERR_BASE + 17;
pub const MMSYSERR_DELETEERROR = MMSYSERR_BASE + 18;
pub const MMSYSERR_VALNOTFOUND = MMSYSERR_BASE + 19;
pub const MMSYSERR_NODRIVERCB = MMSYSERR_BASE + 20;
pub const MMSYSERR_MOREDATA = MMSYSERR_BASE + 21;
pub const MMSYSERR_LASTERROR = MMSYSERR_BASE + 21;

pub const WAVERR_BADFORMAT = WAVERR_BASE + 0; // unsupported wave format
pub const WAVERR_STILLPLAYING = WAVERR_BASE + 1; // still something playing
pub const WAVERR_UNPREPARED = WAVERR_BASE + 2; // header not prepared
pub const WAVERR_SYNC = WAVERR_BASE + 3; // device is synchronous
pub const WAVERR_LASTERROR = WAVERR_BASE + 3; // last error in range

pub const MM_WOM_OPEN = 0x3BB; // waveform output
pub const MM_WOM_CLOSE = 0x3BC;
pub const MM_WOM_DONE = 0x3BD;

pub const WOM_OPEN = MM_WOM_OPEN;
pub const WOM_CLOSE = MM_WOM_CLOSE;
pub const WOM_DONE = MM_WOM_DONE;

pub const LPCWAVEFORMATEX = [*c]WAVEFORMATEX;

pub extern "winmm" fn waveOutOpen(phwp: HWAVEOUT, uDeviceID: windows.UINT, pwfx: LPCWAVEFORMATEX, dwCallback: WaveOutProc, dwInstance: windows.DWORD_PTR, fdwOpen: windows.DWORD) callconv(windows.WINAPI) MMRESULT;
pub extern "winmm" fn waveOutPrepareHeader(hwo: HWAVEOUT, pwh: LPWAVEHDR, cbwh: windows.UINT) callconv(windows.WINAPI) MMRESULT;
pub extern "winmm" fn waveOutWrite(hwo: HWAVEOUT, pwh: LPWAVEHDR, cbwh: windows.UINT) callconv(windows.WINAPI) MMRESULT;
pub extern "winmm" fn waveOutUnprepareHeader(hwo: HWAVEOUT, pwh: LPWAVEHDR, cbwh: windows.UINT) callconv(windows.WINAPI) MMRESULT;
pub extern "winmm" fn waveOutClose(hwo: HWAVEOUT) callconv(windows.WINAPI) MMRESULT;

// MMRESULT waveOutClose(
//   HWAVEOUT hwo
// );

// MMRESULT waveOutUnprepareHeader(
//   HWAVEOUT  hwo,
//   LPWAVEHDR pwh,
//   UINT      cbwh
// );

// MMRESULT waveOutWrite(
//   HWAVEOUT  hwo,
//   LPWAVEHDR pwh,
//   UINT      cbwh
// );

// MMRESULT waveOutOpen(
//   LPHWAVEOUT      phwo,
//   UINT            uDeviceID,
//   LPCWAVEFORMATEX pwfx,
//   DWORD_PTR       dwCallback,
//   DWORD_PTR       dwInstance,
//   DWORD           fdwOpen
// );

// typedef struct tWAVEFORMATEX {
//     WORD	wFormatTag;
//     WORD	nChannels;
//     DWORD	nSamplesPerSec;
//     DWORD	nAvgBytesPerSec;
//     WORD	nBlockAlign;
//     WORD	wBitsPerSample;
//     WORD	cbSize;
// }

// MMRESULT waveOutPrepareHeader(
//   HWAVEOUT  hwo,
//   LPWAVEHDR pwh,
//   UINT      cbwh
// );
