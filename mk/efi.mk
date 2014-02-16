include $(MAKEDIR)/syslinux.mk

com32 = $(topdir)/com32
core = $(topdir)/core

# Support IA32 and x86_64 platforms with one build
# Set up architecture specifics; for cross compilation, set ARCH as apt
# gnuefi sets up architecture specifics in ia32 or x86_64 sub directories
# set up the LIBDIR and EFIINC for building for the appropriate architecture
GCCOPT := $(call gcc_ok,-fno-stack-protector,)
EFIINC = $(objdir)/include/efi
LIBDIR  = $(objdir)/lib
EFIDIR = $(topdir)/gnu-efi/gnu-efi-3.0

ifeq ($(ARCH),i386)
	ARCHOPT = -m32 -march=i386
	EFI_SUBARCH = ia32
endif
ifeq ($(ARCH),x86_64)
	ARCHOPT = -m64 -march=x86-64
	EFI_SUBARCH = $(ARCH)
endif

#LIBDIR=/usr/lib
FORMAT=efi-app-$(EFI_SUBARCH)

CFLAGS = -I$(EFIINC) -I$(EFIINC)/$(EFI_SUBARCH) \
		-DEFI_FUNCTION_WRAPPER -fPIC -fshort-wchar -ffreestanding \
		-Wall -I$(com32)/include -I$(com32)/include/sys \
		-I$(core)/include -I$(core)/ $(ARCHOPT) \
		-I$(com32)/lib/ -I$(com32)/libutil/include -std=gnu99 \
		-DELF_DEBUG -DSYSLINUX_EFI -I$(objdir) \
		$(GCCWARN) -D__COM32__ -mno-red-zone \
		-DLDLINUX=\"$(LDLINUX)\" -fvisibility=hidden \
		-Wno-unused-parameter $(GCCOPT)

CRT0 := $(LIBDIR)/crt0-efi-$(EFI_SUBARCH).o
LDSCRIPT := $(LIBDIR)/elf_$(EFI_SUBARCH)_efi.lds

LDFLAGS = -T $(SRC)/$(ARCH)/syslinux.ld -Bsymbolic -pie -nostdlib -znocombreloc \
		-L$(LIBDIR) --hash-style=gnu -m elf_$(ARCH) $(CRT0) -E

SFLAGS     = $(GCCOPT) $(GCCWARN) $(ARCHOPT) \
	     -fomit-frame-pointer -D__COM32__ \
	     -nostdinc -iwithprefix include \
	     -I$(com32)/libutil/include -I$(com32)/include -I$(com32)/include/sys $(GPLINCLUDE)

LIBEFI = $(LIBDIR)/libefi.a $(LIBDIR)/libgnuefi.a
LDLIBSEFI = $(patsubst $(LIBDIR)/lib%.a,-l%,$(LIBEFI))

# The empty commands are needed in order to force make to check the files date
$(LIBEFI): gnuefi ;
$(CRT0) $(LDSCRIPT): gnuefi ;
$(EFIINC)/%.h $(EFIINC)/protocol/%.h $(EFIINC)/$(EFI_SUBARCH)/%.h: gnuefi ;

.PHONY: gnuefi
gnuefi:
	@echo Building gnu-efi for $(EFI_SUBARCH)
	cd $(topdir) && git submodule update --init
	mkdir -p "$(objdir)/gnu-efi"
	MAKEFLAGS= make SRCDIR="$(EFIDIR)" TOPDIR="$(EFIDIR)" \
		ARCH=$(EFI_SUBARCH) -f "$(EFIDIR)/Makefile"
	MAKEFLAGS= make SRCDIR="$(EFIDIR)" TOPDIR="$(EFIDIR)" \
		ARCH=$(EFI_SUBARCH) PREFIX="$(objdir)" \
		-f "$(EFIDIR)/Makefile" install

%.o: %.S	# Cancel old rule

%.o: %.c

.PRECIOUS: %.o
%.o: %.S
	$(CC) $(SFLAGS) -c -o $@ $<

# efi/*.c depends on some headers installed by gnuefi,
# so let's depend on one header, and the others will come along.
# Note: Do NOT depend on gnuefi phony target, this would force all the .c to be
# rebuilt every time.
.SECONDARY: $(EFIINC)/efi.h $(EFIINC)/efilib.h
%.o: %.c $(EFIINC)/efi.h $(EFIINC)/efilib.h
	$(CC) $(CFLAGS) -c -o $@ $<

#%.efi: %.so
#	$(OBJCOPY) -j .text -j .sdata -j .data -j .dynamic -j .dynsym -j .rel \
#		-j .rela -j .reloc --target=$(FORMAT) $*.so $@
