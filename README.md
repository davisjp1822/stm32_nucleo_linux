# Using the STM32 Nucleo on Ubuntu Linux
## A Guide to Compiling and Uploading Code for the STM32-F401xxe Nucleo Board on Ubuntu Linux

### What's Covered
The purpose of this document is to help get the reader to the point where they are able to use the supplied shell script to compile and upload code to the STM32-F401xxe board from the Linux command line. Graphical IDEs - such as Eclipse - are not covered in the scope of this document as I believe that they are a beast unto themselves and can add quite a bit of complexity. Besides, the reader can use the information in this document to aid in not only setting-up an IDE such as Eclipse, but the same information applies to any other coding environment the reader chooses to use while at the same time being far more scriptable.

### Requirements
* Ubuntu Linux 16.04.3
* STM32-F401xxe (the board used in this example was a STM32-F401RE) Nucleo development board

The following packages:
* gcc-arm-none-eabi (GCC cross compiler for ARM Cortex-A/R/M processors)
* gdb-arm-none-eabi (GNU debugger for ARM Cortex-A/R/M processors)
* binutils-arm-none-eabi (GNU assembler, linker and binary utilities for ARM Cortex-A/R/M processors)
* openocd (Open on-chip JTAG debug solution for ARM and MIPS systems)
* screen (screen - screen manager with VT100/ANSI terminal emulation, used to connect to serial ports)

The standard versions available in Ubuntu 16.04.3 will suffice. Just make sure that your repository is up-to-date by running `sudo apt-get update; sudo apt-get full-upgrade` first to ensure your system is running the latest version of all packages.

Once updated, install each package with `sudo apt-get install <package_name>`

You will also need the *STM32CubeF4* archive. This archive contains the examples we will use as our basis for the small serial project created with this guide, as well as all of the necessary header files required to compile for the platform.

Read through the package information [here](http://www.st.com/content/st_com/en/products/embedded-software/mcus-embedded-software/stm32-embedded-software/stm32cube-embedded-software/stm32cubef4.html) while [downloading the software](http://www.st.com/content/st_com/en/products/embedded-software/mcus-embedded-software/stm32-embedded-software/stm32cube-embedded-software/stm32cubef4.html).

### Step 1 - Connecting the Nucleo and Getting the Serial Port Handle
In Linux, everything is a file, which means that you will be able to access the serial connection provided by the Nucleo as a standard device file in `/dev`. To do this though, you need to know what to look for, as there are many files in `/dev`.

To find the Nucleo, plug the board into your computer's USB port, and then immediately run `dmesg` from a terminal. You are looking for something like this:

```
[18951.296067] scsi 33:0:0:0: Direct-Access     MBED     microcontroller  1.0  PQ: 0 ANSI: 2
[18951.296785] sd 33:0:0:0: Attached scsi generic sg2 type 0
[18951.302771] sd 33:0:0:0: [sdb] 1056 512-byte logical blocks: (541 kB/528 KiB)
[18951.306151] sd 33:0:0:0: [sdb] Write Protect is off
[18951.306152] sd 33:0:0:0: [sdb] Mode Sense: 03 00 00 00
[18951.309093] sd 33:0:0:0: [sdb] No Caching mode page found
[18951.309096] sd 33:0:0:0: [sdb] Assuming drive cache: write through
[18951.369407] sd 33:0:0:0: [sdb] Attached SCSI removable disk
[19869.503543] usb 2-2.1: reset full-speed USB device number 8 using uhci_hcd
>>>>>>>>>>>>>>>>>>[19870.202890] cdc_acm 2-2.1:1.2: ttyACM0: USB ACM device
[19870.205825] usb 2-2.1: USB disconnect, device number 8
[19872.439441] usb 2-2.1: new full-speed USB device number 9 using uhci_hcd
[19872.752000] usb 2-2.1: New USB device found, idVendor=0483, idProduct=374b
[19872.752001] usb 2-2.1: New USB device strings: Mfr=1, Product=2, SerialNumber=3
[19872.752002] usb 2-2.1: Product: STM32 STLink
[19872.752003] usb 2-2.1: Manufacturer: STMicroelectronics
[19872.752003] usb 2-2.1: SerialNumber: 066FFF525750877267102835
```

The line I emphasized with the >>>>> is the important part - *ttyACM0* indicates that whatever just connected over USB has an available serial port. Accordingly, the serial path that will be used to connect to this particular board is `/dev/ttyACM0`. Keep this in mind for later.

Coincidentally, it looks like the board also provides a USB Mass Storage device, located at `/dev/sdb`. One could run `fdisk` on this device to see what partitions are available, and then `mount` the filesystems if there was a need to copy files onto the device's flash.

### Step 2 - Compiling, Installing, and Connecting to the UART Demo Program from *STM32CubeF4*
First thing's first - unzip the *STM32CubeF4* archive in your user's home directory:

```
$ unzip en.stm32cubef4.zip
```

Before proceeding any further, let's take a high-level look at how this entire process works. I will explain each step in detail as we compile our first program, but it does help to understand where we will start and where we will end.

Basically, the build process goes as so:
1. Collect and organize the miscellaneous source, startup, and other files required to make a sane build environment
2. Compile the STM32 HAL and STM32 BSP codebase into static libraries that can be used in linking phase (step 4)
3. Compile the code using the *gcc-arm-none-eabi* cross compiler
4. Link the code to the libraries compiled in step 2
5. Convert the *.elf* file that was output from the linker to a *.hex* file and upload it to the Nucleo using `openocd`
6. Rejoice

Much of that is done by the `compile.sh` script contained in this repository. For the purpose of this document, copy that script into the `STM32Cube_FW_F4_V1.16.0/Projects/STM32F401RE-Nucleo/Examples/UART/UART_Printf` directory (which should be unzipped in your home directory).

Now that it is copied, let's take a look at `compile.sh`:

These paths should be altered to fit your environment. Speficially, `PDIR`. If you are using the standard UART example provided by *STM32CubeF4*, `PATH` should be fine for now.

```bash
#!/bin/bash

# where the STM Cube archive is located
PDIR="/home/davisjp/STM32Cube_FW_F4_V1.16.0"

# the path of the STM example project we are going to compile
PATH="${PDIR}/Projects/STM32F401RE-Nucleo/Examples/UART/UART_Printf"
```

This next block is just cleaning-up the build environment. 

```bash
# clean up existing files
/bin/rm -rf ${PATH}/Lib ${PATH}/obj
/bin/rm -rf ${PATH}/*.hex ${PATH}/*.elf

# make the directories we are going to use to store libraries and such
/bin/mkdir -p ${PATH}/Lib ${PATH}/Obj
```

The `STM32F401VEHx_FLASH.ld` file is a linker script explaining how to link the libraries and the binary together. I am using the one from the *SW4STM32* template as it is the same one used by System Workbench for STM32/ Eclipse on both Windows and Linux.

`LD_FLAGS` is creating the search path for the libraries with `-L` and then telling the linker to use (`-l`) the libraries - `libstm32f4xxhal` and `libstm32f4xxbsp` that the script will create. `-Wl` tells *gcc* to use the linker, and `--gc-sections` instructs the linker to garbage collect - basically, throwing away unused code blocks to save memory.

```bash
LIBDIR="${PATH}/Lib"
LINKER_FILE="${PDIR}/Projects/STM32F401RE-Nucleo/Templates/SW4STM32/STM32F4xx-Nucleo/STM32F401VEHx_FLASH.ld"
LD_FLAGS="-L${LIBDIR} -lstm32f4xxhal -lstm32f4xxbsp -Wl,--gc-sections"

Similar to the block above, this next block configures *gcc*. `INCLUDES` tells *gcc* where to find all of the header files required for a successful compilation, and `CFLAGS` provides some standard ARM compilation flags. The most important part of `CFLAGS` is `-DSTM32F401xE` - this is equivalent to `#define STM32F401xE`, which is required by the STM32 codebase so that the proper header files and compile options are used. The flag `-ggdb` is also important if you want to use the `GDB` debugger.

```bash
CC="/usr/bin/arm-none-eabi-gcc"
CFLAGS="-Wall -mcpu=cortex-m4 -mlittle-endian -mthumb -Os -DSTM32F401xE -ggdb"
INCLUDES="-I${PATH}/Inc -I${PDIR}/Drivers/CMSIS/Device/ST/STM32F4xx/Include -I${PDIR}/Drivers/CMSIS/Include -I${PDIR}/Drivers/BSP/STM32F4xx-Nucleo -I${PDIR}/Drivers/STM32F4xx_HAL_Driver/Inc -I${PDIR}/Drivers/BSP/STM32F4xx-Nucleo"
```

Sets the correct path for `objcopy` (converts `.elf` to `.hex`) and `openocd`.

```bash
OBJCOPY="/usr/bin/objcopy"
OPENOCD="/usr/bin/openocd"
```

The following just organizes code into the *Src/* directory for easier compilation. `startup_stm32f401xe.s` contains the assembly code required for program start and entry, and `syscalls.c` helps GNU libc resolve system calls during compilation time.

```bash
# copy the correct startup code file to our directory
/bin/cp ${PDIR}/Drivers/CMSIS/Device/ST/STM32F4xx/Source/Templates/gcc/startup_stm32f401xe.s ${PATH}/Src/

# also copy the supporting files from SW4STM32/ to the Src directory
/bin/cp ${PATH}/SW4STM32/syscalls.c ${PATH}/Src/
```

Compile the libaries and use `ar` to create static libraries that can be used by the linker.

```bash
# compile the HAL library
echo "Compiling the HAL library..."
for x in ${PDIR}/Drivers/STM32F4xx_HAL_Driver/Src/*.c; do ${CC} ${CFLAGS} ${INCLUDES} -c -o ${LIBDIR}/$(/usr/bin/basename "${x}" .c).o ${x}; done
/usr/bin/ar rcs ${LIBDIR}/libstm32f4xxhal.a ${LIBDIR}/*.o

# compile the BSP library
echo "Compiling the BSP library..."
for x in ${PDIR}/Drivers/BSP/STM32F4xx-Nucleo/*.c; do ${CC} ${CFLAGS} ${INCLUDES} -c -o ${LIBDIR}/$(/usr/bin/basename "${x}" .c).o ${x}; done
/usr/bin/ar rcs ${LIBDIR}/libstm32f4xxbsp.a ${LIBDIR}/*.o
/bin/rm ${LIBDIR}/*.o
```

Compile the program files for the example (including `main.c`).

```bash
# compile everything in Src/
for x in ${PATH}/Src/*; do ${CC} ${CFLAGS} ${INCLUDES} -c -o ${PATH}/Obj/$(/usr/bin/basename "${x}" .c).o ${x}; done 
```

Link the example code with the libraries created earlier, and then convert the resulting `.elf` file to a `.hex` file.

```bash
# once compilation is done, run the linker
${CC} ${CFLAGS} -T${LINKER_FILE} ${PATH}/Obj/*.o -o ${PATH}/out.elf ${LD_FLAGS}
```

Upload the binary to the board and tell the board to run!

```bash
# now, copy to a hex file and upload to the board
${OBJCOPY} -Oihex out.elf out.hex
${OPENOCD} -f /usr/share/openocd/scripts/board/st_nucleo_f4.cfg -c "init; reset halt; flash write_image erase out.hex; reset run; exit"
```

With the idea of how the script works, let's try using it and see what happens. You should have `compile.sh` in the *UART_Printf* directory. Assuming you remembered to edit the file and set `PATH`, you should be able to simply run the script and see a successful compilation and upload:

```bash
$ sh compile.sh
```

Ignore the warnings regarding `TIM6`. Those have no bearing on this particular project.

A successful upload should look like this (and the Nucleo board should blink like crazy while the program is being uploaded):

```bash

...

<gcc compilation output>

Compiling the BSP library...
Open On-Chip Debugger 0.9.0 (2015-09-02-10:42)
Licensed under GNU GPL v2
For bug reports, read
	http://openocd.org/doc/doxygen/bugs.html
Info : The selected transport took over low-level target control. The results might differ compared to plain JTAG/SWD
adapter speed: 2000 kHz
adapter_nsrst_delay: 100
none separate
srst_only separate srst_nogate srst_open_drain connect_deassert_srst
Info : Unable to match requested speed 2000 kHz, using 1800 kHz
Info : Unable to match requested speed 2000 kHz, using 1800 kHz
Info : clock speed 1800 kHz
Info : STLINK v2 JTAG v28 API v2 SWIM v17 VID 0x0483 PID 0x374B
Info : using stlink api v2
Info : Target voltage: 3.262673
Info : stm32f4x.cpu: hardware has 6 breakpoints, 4 watchpoints
target state: halted
target halted due to debug-request, current mode: Thread
xPSR: 0x01000000 pc: 0x0800552c msp: 0x20018000
auto erase enabled
Info : device id = 0x10016433
Info : flash size = 512kbytes
Info : Padding image section 0 with 4 bytes
Info : Padding image section 1 with 4 bytes
target state: halted
target halted due to breakpoint, current mode: Thread
xPSR: 0x61000000 pc: 0x20000042 msp: 0x20018000
wrote 49152 bytes from file out.hex in 2.396237s (20.031 KiB/s)
```

Now, let's connect to the serial port to see if it worked. To connect to the serial port, we will be using the venerable `screen` application. `screen` not only allows for virtualization of terminals (look for examples on Google - very cool stuff), but it also allows for connection to serial consoles/ports.

To connect, issue the following from the terminal:

```bash
# remember step 1? this is where you use /dev/ttyACM0
# sudo is required as root privs are needed to read this device

# 9600:		baud rate
# cs7:		7 bits per byte - the code example is an 8 Byte word, but uses 1 bit as a Stop Bit
# ixoff:	disables software flow-control for receiving data

$ sudo screen /dev/ttyACM0 9600,cs7,ixoff
```

You should see the following:

```bash
UART Printf Example: retarget the C library printf function to the UART
```

To exit `screen`, execute `ctrl-a ctrl-\` which will raise a prompt at the bottom of the screen asking if you want to quit all screen sessions. Select *y*. Terminals are a bit funny - if this doesn't work after repeated entries, open a new terminal and execute `sudo killall screen`.

Rejoice!

A note on this section - I know I could've done a Makefile instead of writing the `compile.sh` script. Yes, that would have been more standard, but for the Linux beginner, Makefiles are obtuse and `autotools` has a bit of a steep learning curve (to say the least).

### Step 3 - Modifying the UART Demo with Tx and Rx Functionality

The included `main.c` file modifies the file that comes with the example to show how **blocking** serial read and write work. It should be emphasized that the code is really for *example only*. The serial calls are blocking (in production, one should either use the DMA or interrupt-driven UART APIs), there is no buffer checking, and the error handling is minimal at best.

That said, it does work to illustrate the point. All you have to do is copy the `main.c` in this repository to the `Src/` directory of the `UART_Printf` example, and then execute `compile.sh`.

Upon connecting with `screen` using the same command as in Step 2, you will be greeted by the following:

```bash
Shall we play a game (Y/N)?: Y # input characters do not show, just type Y

A strange game. The only winning move is not to play.
```

### Step 4 - Debugging

Since the program was compiled with the `-ggdb` flag (compiling debug symbols), it is possible to connect and debug using `GDB`. The debug process between `GDB` and `openocd` is well documented, so I will leave that to the reader's Google-fu. 
