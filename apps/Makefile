######################################################################
# 
#  Top-level make file.  Just build all of the apps
#
######################################################################

# default to using -s, unless VERBOSE_MAKE is set
ifeq ($(VERBOSE_MAKE)_x, _x)
MAKEFLAGS += -s
endif
export VERBOSE_MAKE

# catch-all rule - pass targets on to the lower level
all:
	echo "collect..."
	$(MAKE) $(PLATFORM) -C collect -f Makefile
	echo "coverIt..."
	$(MAKE) $(PLATFORM) -C coverIt -f Makefile
	echo "deliverytest..."
	$(MAKE) $(PLATFORM) -C deliverytest -f Makefile
	echo "example_app..."
	$(MAKE) $(PLATFORM) -C example_app -f Makefile
	echo "imaging..."
	$(MAKE) $(PLATFORM) -C imaging -f Makefile
	echo "pingtree..."
	$(MAKE) $(PLATFORM) -C pingtree -f Makefile
	echo "send_task..."
	$(MAKE) $(PLATFORM) -C send_task -f Makefile
	echo "system..."
	$(MAKE) $(PLATFORM) -C system -f Makefile
	echo "xmaxTree..."
	$(MAKE) $(PLATFORM) -C xmasTree -f Makefile

arm:
	echo "collect..."
	$(MAKE) $(PLATFORM) -C collect -f Makefile arm
	echo "coverIt..."
	$(MAKE) $(PLATFORM) -C coverIt -f Makefile arm
	echo "deliverytest..."
	$(MAKE) $(PLATFORM) -C deliverytest -f Makefile arm
	echo "example_app..."
	$(MAKE) $(PLATFORM) -C example_app -f Makefile arm
	echo "imaging..."
	$(MAKE) $(PLATFORM) -C imaging -f Makefile arm
	echo "pingtree..."
	$(MAKE) $(PLATFORM) -C pingtree -f Makefile arm
	echo "send_task..."
	$(MAKE) $(PLATFORM) -C send_task -f Makefile arm
	echo "system..."
	$(MAKE) $(PLATFORM) -C system -f Makefile arm
	echo "xmaxTree..."
	$(MAKE) $(PLATFORM) -C xmasTree -f Makefile arm
    
clean:
	$(MAKE) $(PLATFORM) -C collect -f Makefile clean
	$(MAKE) $(PLATFORM) -C coverIt -f Makefile clean
	$(MAKE) $(PLATFORM) -C deliverytest -f Makefile clean
	$(MAKE) $(PLATFORM) -C example_app -f Makefile clean
	$(MAKE) $(PLATFORM) -C imaging -f Makefile clean
	$(MAKE) $(PLATFORM) -C pingtree -f Makefile clean
	$(MAKE) $(PLATFORM) -C send_task -f Makefile clean
	$(MAKE) $(PLATFORM) -C system -f Makefile clean
	$(MAKE) $(PLATFORM) -C xmasTree -f Makefile clean

docs:
	@echo ""

