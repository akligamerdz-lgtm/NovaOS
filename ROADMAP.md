# NovaOS roadmap

An operating system is built in layers. Each stage below assumes the previous
one works and is tested. Do not skip stages; debugging a GUI when your page
tables are wrong is misery.

Status of stage 0: **done** (this repository). A few Stage 4/5 items were
pulled forward because they are fun and visible: the RTC, PS/2 mouse, cursor,
draggable windows and smooth font are already working. They are checked below.

---

## Stage 0 — Foundation (done)

- [x] Bootloader handoff and higher-half linker script
- [x] C runtime basics (`memcpy`, `memset`, `strlen`, `kprintf`)
- [x] Framebuffer console + serial log
- [x] GDT/TSS, IDT, exception handlers
- [x] PIC + PIT timer + PS/2 keyboard
- [x] Physical page bitmap allocator
- [x] Kernel heap (`kmalloc`/`kfree`)
- [x] Interactive shell

---

## Stage 1 — Virtual memory (next)

Goal: stop relying on the bootloader's page tables.

- [ ] Read CR3, create your own 4-level page tables
- [ ] Map the kernel's higher-half region and the HHDM
- [ ] `vmm_map(addr, phys, flags)`, `vmm_unmap(addr)`
- [ ] Demand-zero pages and copy-on-write (later)
- [ ] Guard pages around the kernel stack
- [ ] Heap backed by newly mapped pages instead of a fixed arena
- [ ] Test: allocate 200 MiB, touch it, free it

Concepts to learn: 4-level paging, PML4/PDPT/PD/PT, page faults, `CR0.WP`,
`CR3`, TLB shootdown (`invlpg`).

---

## Stage 2 — Processes and user mode

Goal: run a program that is not the kernel.

- [ ] Load a small flat binary or ELF from a Limine module
- [ ] Build ring-3 page tables with user-accessible pages
- [ ] `iretq` into ring 3 (use the existing user segments in `gdt.c`)
- [ ] TSS `rsp0` for kernel stack switching on interrupts/syscalls
- [ ] Syscall entry via `syscall`/`sysret` or `int 0x80`
- [ ] Syscalls: `exit`, `write`, `read`, `yield`
- [ ] Scheduler: round-robin context switch
- [ ] Preemptive scheduling driven by the PIT
- [ ] `fork()` if you are brave (copy address space)

Concepts: privilege levels, IST, syscall ABI, context switching, run queues.

---

## Stage 3 — Filesystem

Goal: open and read a file.

- [ ] Load an initramfs as a Limine module (`module_path` in `limine.conf`)
- [ ] Parse a simple archive (tar or a custom format)
- [ ] VFS layer: inodes, file descriptors, `open/read/write/close`
- [ ] A real on-disk filesystem later (FAT32 is the easiest, then ext2)
- [ ] Block device abstraction
- [ ] ATA/AHCI driver for disks

Concepts: VFS design, caching, block I/O, partition tables (MBR/GPT).

---

## Stage 4 — More hardware

- [ ] PCI/PCIe enumeration (configuration space)
- [x] RTC (CMOS) for real date/time
- [x] PS/2 mouse driver (IRQ12, acceleration, polling fallback, diagnostics)
- [ ] ACPI tables (`RSDP` is already provided by Limine)
- [ ] APIC + IOAPIC, replace the PIC
- [ ] SMP: boot application processors, per-CPU data
- [ ] USB (xHCI) — hard; save for later

---

## Stage 5 — Graphical user interface

- [ ] Double-buffered framebuffer compositor
- [ ] Window manager: windows, focus, dragging, damage tracking
- [x] Mouse cursor and click routing
- [x] Smooth anti-aliased font renderer with four real sizes (generated from a Windows font)
- [ ] Terminal window running the shell
- [ ] Widgets: buttons, text boxes, lists
- [x] Wallpaper and themes (animations still to come)

This is the part that makes it *feel* like an OS. It is also the most fun.

---

## Stage 6 — Networking

- [ ] PCI network card driver (RTL8139 is easiest, e1000 is common)
- [ ] Ethernet + ARP + IPv4 + ICMP (ping)
- [ ] UDP + a tiny DNS client
- [ ] TCP (much harder: retransmission, windows, congestion)
- [ ] Sockets API
- [ ] An HTTP client and a simple web browser (huge project on its own)

---

## Stage 7 — Becoming usable

- [ ] Port a C library (musl) so normal programs compile
- [ ] Port a text editor, a shell, coreutils
- [ ] Users, permissions, login
- [ ] Package format and installer
- [ ] Real hardware testing (USB stick with Rufus / `dd`)

---

## Realistic expectations

| Milestone | Typical effort for a beginner |
|---|---|
| Stage 0 (this) | a few weekends with guidance |
| Stage 1 | 1–2 weeks |
| Stage 2 | 2–4 weeks |
| Stage 3 | 3–6 weeks |
| Stage 5 (GUI) | months |
| Something daily-drivable | years, or never — and that is fine |

The point is to learn how computers actually work. Every stage teaches
something that makes you a better programmer even if you never finish the OS.

---

## Rules that save time

1. **Test after every small change.** A kernel that triple-faults gives you
   almost no information.
2. **Log to serial.** Keep `build/serial.log` open in a second window.
3. **Keep a known-good commit.** Use git (`git init`, commit after each
   working stage). When you break everything, you can go back.
4. **Read the manual, not random code.** The Intel SDM and the Limine protocol
   are the ground truth.
5. **One feature at a time.** "Add paging and a scheduler" is two projects.
