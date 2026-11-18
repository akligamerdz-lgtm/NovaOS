# NovaOS

A small operating system for x86-64, written from scratch in C and assembly.
It boots on a real PC (or in QEMU), takes over the machine, and gives you a
Windows-style graphical desktop with a mouse, or a plain text shell.

> **Read this first, honestly:** this is *not* Windows, and it is not going to
> become Windows any time soon. Windows is tens of millions of lines of code
> and decades of work by thousands of people. What you have here is the
> foundation every OS is built on: a boot loader handoff, a 64-bit kernel, CPU
> setup, interrupts, drivers, memory management, and a shell. Everything else
> is built on top of that. See [ROADMAP.md](ROADMAP.md) for the path forward.
>
> New to low-level programming? Read **[docs/CONCEPTS.md](docs/CONCEPTS.md)**
> after your first boot. It explains every piece in plain language.

---

## What works today (version 0.1)

| Part | Status |
|---|---|
| Boots from a CD/ISO via Limine (BIOS and UEFI) | yes |
| 64-bit long mode kernel, higher-half linked | yes |
| Framebuffer text console (smooth anti-aliased font, colours, scrolling) | yes |
| Serial debug console (`build/serial.log`) | yes |
| GDT + TSS, IDT, CPU exception handlers | yes |
| 8259 PIC remap, PIT timer at 100 Hz | yes |
| PS/2 keyboard driver | yes |
| PS/2 mouse driver (IRQ12, acceleration + polling fallback) | yes |
| Graphical desktop: wallpaper, taskbar, clock, Start menu | yes |
| Draggable windows with close buttons | yes |
| Your own logo on the desktop, Start button and windows | yes |
| "Try it first" / "Install" welcome screen | yes (Install is a placeholder) |
| Media Creation Tool wizard (.exe, icon, languages, ISO/USB) | yes |
| Text console fallback (Esc, or `gui` to return) | yes |
| Physical page allocator (bitmap) | yes |
| 4 MiB kernel heap (`kmalloc` / `kfree`) | yes |
| Interactive shell with commands | yes |
| User mode / processes / filesystem | not yet |

Boot messages look roughly like this:

```
+---------------------------------------------+
|             N o v a O S   0 . 1             |
|     a small operating system for x86-64     |
|        written from scratch in C/ASM        |
+---------------------------------------------+
Booting NovaOS 0.1...

System information
  bootloader : Limine 12.10.0
  display    : 1280x800, 32 bpp
  memory     : 506 MiB usable, 129554 pages free
  interrupts : GDT + IDT loaded, PIC remapped, PIT at 100 Hz
  timer      : IRQ0 delivered, counting at 100 Hz

gfx: drawing surface ready
mouse: PS/2 mouse ready
gui: desktop ready
gui: welcome ready
```

At this point the screen shows the welcome dialog with **Try it first** and
**Install** buttons. Click *Try it first* to enter the desktop. Press **Esc** at
any time to switch to the text console; type `gui` there to come back.

---

## 1. Install the tools (one time)

All of these are free. Open **PowerShell** and run:

```powershell
winget install LLVM.LLVM
winget install MSYS2.MSYS2
winget install SoftwareFreedomConservancy.QEMU
```

Then install `xorriso` (the tool that builds the bootable ISO) inside MSYS2:

```powershell
C:\msys64\usr\bin\bash -lc "pacman -Sy --noconfirm && pacman -S --noconfirm xorriso"
```

Close and reopen PowerShell afterwards so the new tools are on your `PATH`
(the build scripts also look in the default install folders, so this is not
strictly required).

**No virtualization is needed.** QEMU will emulate the CPU in software. It is
slower than hardware virtualization, but a kernel this small runs fine.

---

## 2. Build

```powershell
cd "D:\Files floder\download\myos"
.\build.ps1
```

This compiles every `.c` and `.S` file, links `build/kernel.elf`, builds
`build/nova.iso`, and stamps Limine's BIOS boot code onto the ISO.

If PowerShell refuses to run the script ("running scripts is disabled"), use:

```powershell
powershell -ExecutionPolicy Bypass -File .\build.ps1
```

---

## 3. Run

**The easy way: double-click a file in this folder.**

| Double-click | What happens |
|---|---|
| `TEST-NOVA.bat` | Builds, boots with no window, prints PASS/FAIL, waits for a keypress |
| `RUN-NOVA.bat` | Builds, opens the QEMU window so you can type commands |

Both are plain Windows batch files — you can open them in Notepad and read
every line. Nothing is installed, no Administrator rights are needed, and your
PC is never rebooted. QEMU is just a program that pretends to be a computer:
it gets a fake CPU, 512 MB of fake RAM and a read-only CD, so there is no disk
it could write to.

From a PowerShell window the same two actions are:

```powershell
.\test.ps1     # no window
.\run.ps1      # window
```

QEMU opens a window and boots the ISO. Click the window to give it keyboard
focus. Close the window (or type `shutdown` inside NovaOS) to stop it.

Prefer to run QEMU yourself?

```powershell
& "C:\Program Files\qemu\qemu-system-x86_64.exe" `
    -m 512M -cdrom build\nova.iso -boot d -vga std `
    -serial file:build\serial.log -no-reboot
```

Every message printed by the kernel is also written to `build/serial.log`.

### Try it on a real USB stick (ChromeOS-style)

The same build can boot from a FAT32 USB stick. Nothing is installed on Windows,
nothing is changed on your internal disks, and no Administrator rights are
needed for the file copy:

```powershell
.\build.ps1
.\make-usb.ps1              # copies the bootloader + kernel to E:
```

`make-usb.ps1` refuses to write to anything except a removable FAT32 drive. To
use a different stick, run `.\make-usb.ps1 -Drive F`.

Then reboot and open your computer's **boot menu** (usually F12, F11, F8 or
Esc) and pick the USB entry — it may be labelled `UEFI: <USB name>`. You will
see the **Welcome to NovaOS** screen:

| Button | What happens |
|---|---|
| **Try it first** | Opens the desktop. This is a live session: NovaOS has no disk driver, so it cannot read or write *any* disk, including the one Windows lives on. |
| **Install** | Honestly explains that installation is not built yet. Nothing is changed. |

Keyboard shortcuts work too: **Enter** = Try it first, **I** = Install,
**Esc** = text console. This is exactly the ChromeOS "try before you install"
idea, minus the actual installer.

> **Safety note:** NovaOS has no disk driver at all. While it is running, it
> physically cannot modify your files or your Windows installation. The only
> write to the USB was the three-file copy above, done from Windows.

### Media Creation Tool (the Windows-installer-style way)

If you prefer a wizard instead of typing commands, double-click
**`CREATE-MEDIA.bat`**. It builds a real Windows program called
`NovaOS-MediaCreationTool.exe` (with your NovaOS logo as its icon) and opens it.
It looks and works like the Windows Media Creation Tool:

1. **Language** — English, Español, Français or Deutsch. The wizard itself
   changes language, and your choice is written to the USB as
   `nova-language.txt` for a future version of NovaOS to read.
2. **Choose media** — *ISO file* or *USB flash drive*.
3. **Details** — for ISO, pick where to save it; for USB, pick the drive and a
   **Keep files** checkbox. Leave it ticked to copy NovaOS alongside your
   existing files, or untick it to format the stick first (you get a warning).
4. **Create** — a progress bar appears while the required files are fetched
   and written, then a "All done!" page.

The tool only ever lists **removable FAT32 drives**, so your Windows disks
(disks 0 and 1) can never be chosen. It gets the files from the `NovaOSMedia`
folder next to the .exe — or, if you type a URL in the "Download source" box,
it downloads them instead. That is the same "get the files onto the media"
idea as the real Windows tool.

To rebuild the tool by hand:

```powershell
.\tools\build-media-tool.ps1        # makes the .exe, icon and NovaOSMedia folder
.\NovaOS-MediaCreationTool.exe
```

It is plain C# (`tools/MediaCreationTool.cs`) compiled with the `csc.exe` that
already ships with Windows — no C++ and no Visual Studio needed. The icon is
generated from your logo by `tools/make-icon.ps1`.

### Change the logo

Your logo is baked into the kernel as pixel data, so NovaOS does not need a
filesystem to draw it. To use a different image:

```powershell
.\tools\make-logo.ps1 -Image "D:\path\to\your-logo.png"
.\build.ps1
.\make-usb.ps1
```

`make-logo.ps1` crops the empty padding, scales the image down to 64 pixels
wide, keeps transparency, and regenerates `kernel/src/logo_data.c` and
`kernel/include/logo.h`. PNG and BMP both work. The logo then appears on the
welcome screen, the Start button, the taskbar clock, every window title bar,
the About window, and as a faint desktop watermark — the same places Windows
shows its own logo.

### Change the font

The text used to be a blocky 8x8 "BIOS-style" bitmap. It is now smooth,
anti-aliased text generated from a real Windows font (Segoe UI by default).
The kernel has no filesystem, so it cannot load a `.ttf` at boot. Instead,
`tools/make-font.ps1` renders the letters **once on Windows** and writes their
grey pixels into a plain C array:

```powershell
.\tools\make-font.ps1 -Family "Segoe UI"   # or "Verdana", "Consolas", ...
.\build.ps1
.\make-usb.ps1
```

Four real sizes are baked in — 12 px (console), 16 px (normal UI), 24 px and
32 px. `gfx.c` blends each grey pixel onto the background, which is what makes
the letter edges soft instead of square. The same font is shared by the console
and the desktop, so both look consistent. Any font installed on your Windows
PC can be used with `-Family`.

### If the mouse will not move on a real PC

The driver had a real bug: its fallback PS/2 configuration byte (`0x67`) had
bit 5 set, which **disables the mouse clock** on actual hardware (QEMU ignored
it, which is why it worked there). It now uses `0x47`, resets the mouse properly
at boot, and adds pointer acceleration ("Enhance pointer precision") and a
polling fallback. To check a real machine, boot the USB, press **Esc** to reach
the shell, type `mouse` and press Enter:

```
PS/2 mouse
  position   : 640,400
  buttons    : left=off right=off
  config     : 0x47 (from controller)
  ack        : yes
  IRQs       : 124
  packets    : 41
  polled     : 0 bytes
```

- `config` should be `0x47` (bit 5 clear = mouse clock on).
- `packets` (or `polled`) climbing as you move the mouse means data is arriving.
- If both stay at zero, firmware may not be emulating a PS/2 mouse at all; the
  USB needs a USB host driver, which is a future feature.

### Test it without a window

```powershell
.\test.ps1
```

This builds the ISO, boots it with the screen disabled, waits 25 seconds,
then reads `build/serial.log` and checks that the kernel reached the graphical
desktop. It prints the log and a pass/fail summary — useful when you change
kernel code and want a quick "did I break the boot?" answer. Use
`.\test.ps1 -Seconds 40` if your machine is slow.

`.\test-input.ps1` goes one step further: it boots into the desktop, presses
Esc to switch to the text console, and types real commands through QEMU's
emulated keyboard.

### Shell commands

| Command | What it does |
|---|---|
| `help` | list commands |
| `about` | kernel version, bootloader, build date |
| `clear` | clear the screen |
| `mem` | physical memory + heap statistics |
| `cpu` | CPU vendor and model (CPUID) |
| `uptime` | time since boot |
| `mouse` | PS/2 mouse diagnostics (position, packets, config) |
| `echo <text>` | print text |
| `sleep <ms>` | busy-wait using the timer interrupt |
| `gui` | return to the graphical desktop |
| `crash` | trigger a CPU exception on purpose |
| `reboot` | reset the machine |
| `shutdown` | power off (QEMU) |

Try `crash` once: it shows the exception handler that prints the faulting
instruction pointer, error code, and register state.

---

## 4. How the boot works

```
BIOS/UEFI
   |
   v
Limine bootloader (boot/limine-bios-cd.bin, BOOTX64.EFI)
   |  reads limine.conf, loads the kernel ELF, sets up long mode,
   |  paging, a framebuffer, and a memory map
   v
kernel/arch/entry.S   (_start)
   |  zeroes .bss, sets up a 64 KiB stack
   v
kernel/src/main.c     (kmain)
   |  serial -> console -> GDT -> IDT -> PIC -> PIT -> keyboard
   |  -> physical memory manager -> heap -> enable interrupts
   v
gui_run()             (kernel/src/gui.c)  <- starts first
    |  welcome screen, desktop, taskbar, windows, mouse
    v
shell_run()           (kernel/src/shell.c) <- Esc from the desktop
    |  "gui" command returns to the desktop
    v  (loop forever)
```

The kernel is linked at `0xffffffff80000000` — the "higher half" of the
address space, where real kernels live. Limine maps it there for us.

### Project layout

```
myos/
├── build.ps1              build script (Windows)
├── run.ps1                build + launch QEMU (with a window)
├── test.ps1               build + headless boot test (checks serial.log)
├── test-input.ps1         keyboard + shell test through QEMU
├── make-usb.ps1           copy the build to a FAT32 USB stick
├── CREATE-MEDIA.bat       double-click: build + open the media tool
├── NovaOS-MediaCreationTool.exe   the wizard (built by build-media-tool.ps1)
├── NovaOSMedia/           files the wizard copies to USB / ISO
├── limine.conf            boot menu / kernel path / screen resolution
├── boot/                  Limine binaries (bootloader)
├── tools/limine.exe       installs BIOS boot code into the ISO
├── tools/make-logo.ps1    converts a PNG/BMP into kernel logo pixel data
├── tools/make-font.ps1    renders an installed Windows font into kernel data
├── tools/make-icon.ps1    turns the logo into the .exe icon
├── tools/MediaCreationTool.cs   the wizard's C# source
├── tools/build-media-tool.ps1   compiles the wizard and stages the files
├── build/                 generated: kernel.elf, nova.iso, serial.log
└── kernel/
    ├── linker.ld          memory layout
    ├── Makefile           alternative build (Linux)
    ├── arch/
    │   ├── entry.S        first instructions of the kernel
    │   ├── isr.S          interrupt entry stubs
    │   └── gdt_flush.S    load GDT and reload segments
    ├── include/           headers
    │   ├── limine.h       bootloader protocol (from the Limine project)
    │   └── font.h         generated smooth font metadata (by tools/make-font.ps1)
    └── src/
        ├── main.c         boot sequence
        ├── bootinfo.c     Limine requests/responses
        ├── console.c      framebuffer text console
        ├── printf.c       kprintf ("%" formatting)
        ├── string.c       memcpy, memset, strlen, ...
        ├── serial.c       COM1 logging
        ├── gdt.c          segment + TSS setup
        ├── idt.c          interrupt table + exception handler
        ├── pic.c          interrupt controller
        ├── pit.c          timer
        ├── keyboard.c     PS/2 keyboard
        ├── mouse.c        PS/2 mouse (IRQ12)
        ├── rtc.c          CMOS clock for the taskbar
        ├── gfx.c          pixels, rectangles, smooth text, gradients
        ├── font_data.c    generated anti-aliased glyph pixels (make-font.ps1)
        ├── logo.c         scales the baked-in logo, respects transparency
        ├── logo_data.c    generated pixel data (by tools/make-logo.ps1)
        ├── gui.c          desktop, taskbar, Start menu, windows
        ├── pmm.c          physical page bitmap allocator
        ├── heap.c         kmalloc/kfree
        ├── shell.c        interactive shell
        └── panic.c        kernel panic / halt
```

---

## 5. Make it your own

**Change the name:** `KERNEL_NAME` in `kernel/include/kernel.h`, the banner in
`kernel/src/main.c`, and the entry title in `limine.conf`.

**Change colours:** the palette is in `kernel/include/console.h`.

**Add a shell command:** in `kernel/src/shell.c`, add a function and an
`else if (strcmp(cmd, "mycommand") == 0)` branch inside `execute()`.

**Change the resolution:** `limine.conf` (`resolution: 1280x800x32`). The
console picks the 12 px or 16 px font automatically based on width.

**See what is happening:** open `build/serial.log` after a boot.

---

## 6. Troubleshooting

| Symptom | Fix |
|---|---|
| `LLVM not found` | `winget install LLVM.LLVM`, then reopen PowerShell |
| `xorriso not found` | run the MSYS2 `pacman` command above |
| PowerShell blocks `build.ps1` | `powershell -ExecutionPolicy Bypass -File .\build.ps1` |
| QEMU window is black | check `build\serial.log`; the kernel prints everything there |
| Limine says "file not found" | make sure `limine.conf` uses `boot():/boot/kernel` |
| Keyboard does not respond | click the QEMU window first; close and rerun if needed |
| QEMU is slow | normal without hardware virtualization (TCG) |

---

## 7. Where to go next

See [ROADMAP.md](ROADMAP.md) for a realistic order of next steps, from virtual
memory and user mode up to a filesystem and a GUI. Do them one at a time — an
OS is built in layers, and skipping a layer always costs more time later.

Useful references:

- OSDev Wiki — <https://wiki.osdev.org>
- Limine protocol — <https://github.com/limine-bootloader/limine/blob/trunk/PROTOCOL.md>
- Intel Software Developer's Manual (the CPU bible)
- *The Little OS Book* — good for the first steps

---

## Credits

- Bootloader: [Limine](https://github.com/limine-bootloader/limine) (BSD-2-Clause, see `boot/LIMINE-LICENSE`)
- Font glyph data generated from an installed Windows font by `tools/make-font.ps1`
  (Segoe UI by default; use `-Family` to pick any font you are licensed to use).
- Everything else: written for this project.
