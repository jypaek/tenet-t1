all:
	$(MAKE) $(PLATFORM) -C tasklib -f Makefile
	$(MAKE) $(PLATFORM) -C router -f Makefile
	$(MAKE) $(PLATFORM) -C transport -f Makefile
	#$(MAKE) $(PLATFORM) -C pylib -f Makefile

arm:
	$(MAKE) arm -C tasklib -f Makefile
	$(MAKE) arm -C router -f Makefile
	$(MAKE) arm -C transport -f Makefile

clean:
	$(MAKE) -C tasklib -f Makefile clean
	$(MAKE) -C router -f Makefile clean
	$(MAKE) -C transport -f Makefile clean
	#$(MAKE) -C pylib -f Makefile clean
