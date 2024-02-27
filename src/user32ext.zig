const windows = @import("std").os.windows;

const HOOKPROC = ?*const fn (code: i32, wParam: windows.WPARAM, lParam: windows.LPARAM) windows.LRESULT;

pub const struct_HHOOK__ = extern struct {
    unused: windows.INT,
};
pub const HHOOK = [*c]struct_HHOOK__;

pub const KBDLLHOOKSTRUCT = extern struct {
    vkCode: windows.DWORD,
    scanCode: windows.DWORD,
    flags: windows.DWORD,
    time: windows.DWORD,
    dwExtraInfo: windows.ULONG_PTR,
};

pub extern "user32" fn CallNextHookEx(_: HHOOK, nCode: windows.INT, wParam: windows.WPARAM, lParam: windows.LPARAM) callconv(windows.WINAPI) windows.LRESULT;
pub extern "user32" fn SetWindowsHookExW(idHook: windows.INT, hookProc: HOOKPROC, hmod: ?windows.HINSTANCE, dwThreadId: windows.DWORD) callconv(windows.WINAPI) HHOOK;
pub extern "user32" fn UnhookWindowsHookEx(hhk: HHOOK) callconv(windows.WINAPI) windows.BOOLEAN;
pub extern "user32" fn PostMessageW(hWnd: ?windows.HWND, Msg: windows.UINT, wParam: windows.WPARAM, lParam: windows.LPARAM) callconv(windows.WINAPI) windows.BOOL;

// LRESULT CallNextHookEx(
//   [in, optional] HHOOK  hhk,
//   [in]           int    nCode,
//   [in]           WPARAM wParam,
//   [in]           LPARAM lParam
// );

// HHOOK SetWindowsHookExW(
//   [in] int       idHook,
//   [in] HOOKPROC  lpfn,
//   [in] HINSTANCE hmod,
//   [in] DWORD     dwThreadId
// );

// HOOKPROC Hookproc;
// LRESULT Hookproc(
//        int code,
//   [in] WPARAM wParam,
//   [in] LPARAM lParam
// )
// {...}

// BOOL UnhookWindowsHookEx(
//   [in] HHOOK hhk
// );

// typedef struct tagCWPRETSTRUCT {
//   LRESULT lResult;
//   LPARAM  lParam;
//   WPARAM  wParam;
//   UINT    message;
//   HWND    hwnd;
// } CWPRETSTRUCT, *PCWPRETSTRUCT, *NPCWPRETSTRUCT, *LPCWPRETSTRUCT;
