#ifndef RESETCOUNT_H
#define RESETCOUNT_H

/*
 * A simple one byte "key" to determine if the flash is valid or not.
 */
#define UNIQUE_KEY 0x3a

/*
 * Represents a count entry in flash.
 */
typedef struct _reset_entry {
  uint8_t key;
  uint8_t reset_count;
} __attribute__ ((packed)) reset_entry_t;

#endif // RESETCOUNT_H
