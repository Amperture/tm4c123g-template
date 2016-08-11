# TI TM4C Launchpad Makefile
# ############################
# Written by Amperture Engineering
# http://www.amperture.com
#
# With heavy inspiration and contribution from:
# 	-UCTools Project (http://uctools.github.io)
# 	-Iztok Starc (@iztokstarc)
# 	-TI Example Makefile
# ###########################

# ########################
# Toolchain info
# ########################
TOOLPREFIX = arm-none-eabi-
CC = $(TOOLPREFIX)gcc
AS = $(TOOLPREFIX)as
LD = $(TOOLPREFIX)ld -v
CP = $(TOOLPREFIX)objcopy
OD = $(TOOLPREFIX)objdump
SIZE = $(TOOLPREFIX)size
GDB = $(TOOLPREFIX)gdb
MKDIR = mkdir -p

# ########################
# Project Info
# ########################
# Project Name
TARGET = main
 
# Architecture/Family used, will usually be something like STM32F4XX
PART = TM4C123GH6PM
CPU = 

# OpenOCD script for flashing
OPENOCD_SCRIPT = board/ek-tm4c123gxl.cfg

# Finding Project Source Files
SOURCE_DIR = src
SOURCES_C = $(shell find -L $(SOURCE_DIR) -name '*.c')
SOURCES_S = $(shell find -L $(SOURCE_DIR) -name '*.s')

# DriverLib directories
PERIPHLIB_PATH = ../tivaware
DRIVERLIB_PATH = $(PERIPHLIB_PATH)/driverlib
GRLIB_PATH = $(PERIPHLIB_PATH)/grlib
SENSORLIB_PATH = $(PERIPHLIB_PATH)/sensorlib
USBLIB_PATH = $(PERIPHLIB_PATH)/usblib
HW_PATH = $(PERIPHLIB_PATH)/inc

# Finding Project Included Headers
INCLUDE_DIR = inc
INC_FILES=$(shell find -L . -name '*.h' -exec dirname {} \; | uniq)
INCLUDES = $(INC_FILES:%=-I%)

INCLUDES += -I$(PERIPHLIB_PATH)
INCLUDES += -I$(DRIVERLIB_PATH)
INCLUDES += -I$(SENSORLIB_PATH)
INCLUDES += -I$(HW_PATH)

INCLUDES += -I$(GRLIB_PATH)
INCLUDES += -I$(USBLIB_PATH)

SOURCES_DRIVERLIB = $(shell find -L $(DRIVERLIB_PATH) -name '*.c')
SOURCES_SENSORLIB = $(shell find -L $(SENSORLIB_PATH) -name '*.c')

SOURCES_GRLIB = $(shell find -L $(GRLIB_PATH) -name '*.c')
SOURCES_USBLIB = $(shell find -L $(USBLIB_PATH) -name '*.c')

MCU_FLAGS = -mcpu=cortex-m4 \
			-mthumb \
			-Dgcc \
			-mlittle-endian \
			-mfpu=fpv4-sp-d16 \
			-mfloat-abi=softfp \
			-DPART_${PART} \
			-MD \
			-std=c99 \
			-Wall \
			-pedantic \
			-DTARGET_IS_TM4C123_RB1 \

CFLAGS = -c $(MCU_FLAGS) $(DEFS) $(INCLUDES)

# Startup copied from Project in Tivaware
STARTUP_SCRIPT = ./startup_gcc.c

# Linker Script copied from Project in Tivaware
LD_SCRIPT = ./project.ld
LDFLAGS = -T $(LD_SCRIPT) \
		  --entry ResetISR \
		  --gc-sections

# Building Object List
BUILD_DIR = build
OBJECTS = $(SOURCES_DRIVERLIB:%.c=%.o)
OBJECTS += $(SOURCES_GRLIB:%.c=%.o)
OBJECTS += $(SOURCES_USBLIB:%.c=%.o)
OBJECTS += $(SOURCES_SENSORLIB:%.c=%.o)
OBJECTS += $(STARTUP_SCRIPT:%.c=%.o)
OBJECTS += $(SOURCES_C:%.c=%.o)
OBJECTS += $(SOURCES_S:%.s=%.o)


#Output Files
BUILD_ELF = $(TARGET).elf
BUILD_HEX = $(TARGET).hex

###
# Optimizations (Taken from @iztokstark)
OPT?='O1 O2 O3 O4 O6 O7' # O5 disabled by default, because it breaks code

ifneq ($(findstring memopt,$(MAKECMDGOALS)),)
ifneq ($(filter O1,$(OPT)),)
CXXFLAGS+=-fno-exceptions # Uncomment to disable exception handling
DEFS+=-DNO_EXCEPTIONS # The source code has to comply with this rule
endif

ifneq ($(filter O2,$(OPT)),)
CFLAGS+=-Os # Optimize for size https://gcc.gnu.org/onlinedocs/gcc/Optimize-Options.html
CXXFLAGS+=-Os
LDFLAGS+=-Os # Optimize for size https://gcc.gnu.org/onlinedocs/gcc/Optimize-Options.html
endif

ifneq ($(filter O3,$(OPT)),)
CFLAGS+=-ffunction-sections -fdata-sections # Place each function or data item into its own section in the output file
CXXFLAGS+=-ffunction-sections -fdata-sections # -||-
#LDFLAGS+=-Wl,-gc-sections # Remove isolated unused sections
endif

ifneq ($(filter O4,$(OPT)),)
CFLAGS+=-fno-builtin # Disable C++ exception handling
CXXFLAGS+=-fno-builtin # Disable C++ exception handling
endif

ifneq ($(filter O5,$(OPT)),)
CFLAGS+=-flto # Enable link time optimization
CXXFLAGS+=-flto # Enable link time optimization
LDFLAGS+=-flto # Enable link time optimization
endif

ifneq ($(filter O6,$(OPT)),)
CXXFLAGS+=-fno-rtti # Disable type introspection
endif

ifneq ($(findstring O7,$(OPT)),)
#LDFLAGS+=--specs=nano.specs # Use size optimized newlib
endif
endif

###

# #########################
# Build Rules
# #########################
.PHONY: all debug clean ocd debug flash

all: release
	
release: $(BUILD_DIR)/$(BUILD_HEX)

memopt: release

debugflag: CFLAGS+=-g
debugflag: LDFLAGS+=-g
debugflag: release

$(BUILD_DIR)/$(BUILD_HEX): $(BUILD_DIR)/$(BUILD_ELF)
	@echo "[CP] $(notdir $<) --> $(notdir $@)"
	@$(CP) -O ihex $< $@
	@$(SIZE) $(BUILD_DIR)/$(BUILD_HEX)

$(BUILD_DIR)/$(BUILD_ELF): $(OBJECTS) $(BUILD_DIR)
	@echo "[LD] $(notdir $<) --> $(notdir $@)"
	$(LD) -o $@ $(OBJECTS) $(LDFLAGS)
	@$(SIZE) $(BUILD_DIR)/$(BUILD_ELF)

%.o: %.c
	@echo "[CC] $(notdir $<)"
	@$(CC) $(CFLAGS) $< -o $@

%.o: %.s
	@echo "[CC] $(notdir $<)"
	@$(CC) $(CFLAGS) $< -o $@

$(BUILD_DIR):
	$(MKDIR) $@

ocd:
	openocd -f $(OPENOCD_SCRIPT) &

debug: $(BUILD_DIR)/$(BUILD_ELF)
	$(GDB) $(BUILD_DIR)/$(BUILD_ELF) -x gdbinit

flash: $(BUILD_DIR)/$(BUILD_ELF)
	openocd -f $(OPENOCD_SCRIPT) -c "program $(BUILD_DIR)/$(BUILD_ELF) verify reset exit"

clean:
	@echo "Cleaning up all compiled files..."
	@rm -f $(OBJECTS) $(BUILD_DIR)/$(BUILD_ELF) $(BUILD_DIR)/$(BUILD_HEX)
