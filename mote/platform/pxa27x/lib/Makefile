#variable definitions
OBJS = $(call find-object-files,".")
SRCS = $(call find-source-files,".")

INCLUDE_DIRS = -I$(TOSDIR)/platform/pxa27x -I$(TOSDIR)/platform/pxa27x/lib/DSP -I$(TOSDIR)/platform/pxa27x/lib/ -I$(TOSDIR)/types

CC := xscale-elf-gcc
CPPFLAGS := $(INCLUDE_DIRS)
CFLAGS := -g -O2 -Wall

AS = xscale-elf-as
ASFLAGS = -mcpu=iwmmxt -mfpu=softfpa

AR = xscale-elf-ar 
ARFLAGS = -rvs

#function to find subdirectories that contains source
# $(find-source-dirs, base-directory-to-search)
define find-source-dirs
$(sort $(dir $(shell find $1 -name "*.[c,s]")))
endef

#function to find subdirectories that contains source
# $(find-source-dirs, base-directory-to-search)
define find-object-files
$(sort $(subst .s,.o,$(subst .c,.o,$(shell find $1 -name "*.[c,s]"))))
endef

#function to find subdirectories that contains source
# $(find-source-dirs, base-directory-to-search)
define find-source-files
$(sort $(shell find $1 -name "*.[c,s]"))
endef

#function to determin if a directory exists
# $(does-dir-exist, dir)
define does-dir-exist
$(findstring, "No such file or directory",$(shell find $1))
endef

#function to create dependency files
# $(call make-depend,source-file,object-file,depend-file)
define make-depend
	$(CC) -MM \
	-MF $3 \
	-MP \
	-MT $2 \
	$(CFLAGS) \
	$(CPPFLAGS) \
	$1
endef

source-dirs = $(call find-source-dirs,".")

#source-dirs = $(findstring, "No such file or directory",$(shell find $(INTEL_FILES))

#always make the library for debugging
libimote2.a: $(OBJS)
	$(AR) $(ARFLAGS) $@ $?

#updated implicit rule to make sure that our dependency file gets created
%.o: %.c
	$(call make-depend,$<,$@,$(subst .o,.d,$@))
	$(COMPILE.c) $(OUTPUT_OPTION) $<

-include $(subst .c,.d,$(SRCS))

clean: 
	$(foreach i,$(source-dirs),cd $(i); rm -f *.[o,a,d]; )

