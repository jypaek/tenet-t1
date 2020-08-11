    
    
    void glowLeds(uint8_t a, uint8_t b) {
        int  j, k;
        for (j = 1536; j > 0; j -= 4) {
            call Leds.set(a);
            for (k = j; k; k--);
            call Leds.set(b);
            for (k = 1536-j; k; k--);
        }
    }

    void startupLeds() {
        uint8_t a = 0x7;
        int  i;
        for (i = 3; i; i--, a >>= 1 ) {
            glowLeds(a, a >> 1);
        }
    }
  
    void flashLeds(uint8_t a) {
        int i, j, k;
        for (i = 3; i; i--) {
            call Leds.set(a);
            for (j = 4; j; j--)
                for (k = 0xffff; k; k--);
            call Leds.set(0);
            for (j = 4; j; j--)
                for (k = 0xffff; k; k--);
        }
    }

