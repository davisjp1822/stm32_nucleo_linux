#!/bin/bash

# where the STM Cube archive is located
PDIR="/home/davisjp/STM32Cube_FW_F4_V1.16.0"

# the path of the STM example project we are going to compile
PATH="${PDIR}/Projects/STM32F401RE-Nucleo/Examples/UART/UART_Printf"

# clean up existing files
/bin/rm -rf ${PATH}/Lib ${PATH}/obj
/bin/rm -rf ${PATH}/*.hex ${PATH}/*.elf

# make the directories we are going to use to store libraries and such
/bin/mkdir -p ${PATH}/Lib ${PATH}/Obj

LIBDIR="${PATH}/Lib"
LINKER_FILE="${PDIR}/Projects/STM32F401RE-Nucleo/Templates/SW4STM32/STM32F4xx-Nucleo/STM32F401VEHx_FLASH.ld"
LD_FLAGS="-L${LIBDIR} -lstm32f4xxhal -lstm32f4xxbsp -Wl,--gc-sections"

CC="/usr/bin/arm-none-eabi-gcc"
CFLAGS="-Wall -mcpu=cortex-m4 -mlittle-endian -mthumb -Os -DSTM32F401xE -ggdb"
INCLUDES="-I${PATH}/Inc -I${PDIR}/Drivers/CMSIS/Device/ST/STM32F4xx/Include -I${PDIR}/Drivers/CMSIS/Include -I${PDIR}/Drivers/BSP/STM32F4xx-Nucleo -I${PDIR}/Drivers/STM32F4xx_HAL_Driver/Inc -I${PDIR}/Drivers/BSP/STM32F4xx-Nucleo"

OBJCOPY="/usr/bin/objcopy"
OPENOCD="/usr/bin/openocd"

# copy the correct startup code file to our directory
/bin/cp ${PDIR}/Drivers/CMSIS/Device/ST/STM32F4xx/Source/Templates/gcc/startup_stm32f401xe.s ${PATH}/Src/

# also copy the supporting files from SW4STM32/ to the Src directory
/bin/cp ${PATH}/SW4STM32/syscalls.c ${PATH}/Src/

# compile the HAL library
echo "Compiling the HAL library..."
for x in ${PDIR}/Drivers/STM32F4xx_HAL_Driver/Src/*.c; do ${CC} ${CFLAGS} ${INCLUDES} -c -o ${LIBDIR}/$(/usr/bin/basename "${x}" .c).o ${x}; done
/usr/bin/ar rcs ${LIBDIR}/libstm32f4xxhal.a ${LIBDIR}/*.o

# compile the BSP library
echo "Compiling the BSP library..."
for x in ${PDIR}/Drivers/BSP/STM32F4xx-Nucleo/*.c; do ${CC} ${CFLAGS} ${INCLUDES} -c -o ${LIBDIR}/$(/usr/bin/basename "${x}" .c).o ${x}; done
/usr/bin/ar rcs ${LIBDIR}/libstm32f4xxbsp.a ${LIBDIR}/*.o
/bin/rm ${LIBDIR}/*.o

# compile everything in Src/
for x in ${PATH}/Src/*; do ${CC} ${CFLAGS} ${INCLUDES} -c -o ${PATH}/Obj/$(/usr/bin/basename "${x}" .c).o ${x}; done 

# once compilation is done, run the linker
${CC} ${CFLAGS} -T${LINKER_FILE} ${PATH}/Obj/*.o -o ${PATH}/out.elf ${LD_FLAGS}

# now, copy to a hex file and upload to the board
${OBJCOPY} -Oihex out.elf out.hex
${OPENOCD} -f /usr/share/openocd/scripts/board/st_nucleo_f4.cfg -c "init; reset halt; flash write_image erase out.hex; reset run; exit"