#include <inttypes.h>
// Command line tools.

// Get rid of extra whitespace.
void killWhiteSpace( char* str );

void killWhiteSpace( char* str )
{
  uint16_t i, j;
  uint16_t startIdx;
  
  // Find first character or line end.
  for( i = 0; str[i] != '\0'; i++ )
    {
      if( str[i] != ' ' )
        {
          break;
        }
    }

  // Check for end of line.
  if( str[i] == '\0' )
    {
      // Empty string.
      str[0] = '\0';
      return;
    }


  startIdx = 0;
  while( 1 )
    {
      // i is the first character of the next word.
      // startIdx is where it needs to be copied to.

      // Copy line back.
      j = startIdx;
      while( str[i] != '\0' )
        {
          str[j] = str[i];
          i++;
          j++;
        }
      // Append '\0';
      str[j] = '\0';

      // Move startIdx to end of word.          
      for( ; str[startIdx] != ' ' && str[startIdx] != '\0'; startIdx++ )
        {}

      // See if next word exists;
      // Looking for a isalpha.
      for( j = startIdx; str[j] != '\0'; j++ )
        {
          if( str[j] != ' ' )
            {
              break;
            }
        }

      // See if we fell off the end.
      if( str[j] == '\0' )
        {
          // We're done.
          // Copy the \0.
          str[startIdx] = '\0';
          return;
        }

      // Copy a space.
      str[startIdx] = ' ';
      startIdx++;

      // j is the start of the next word.
      i = j;
    }
}


uint16_t firstSpace( char* str, uint16_t start )
{
  uint16_t i;
  for( i = start; str[i] != '\0'; i++ )
    {
      if( str[i] == ' ' )
        {
          return i;
        }
    }
  return start;
}

uint16_t cntArgs( char* str, uint16_t start )
{
  uint16_t count, i;
  count = i = 0;

  // Rollover of i is intentional.
  i--;
  
  do
    {
      i++;
      if( str[i] == ' ' || str[i] == '\0' )
        {
          count++;
        }
    }
  while( str[i] != '\0' );

  return count;
}
