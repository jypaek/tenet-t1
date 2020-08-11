/* Blue Shell (BluSH) application (aka module) interface */

includes BluSH_types;
includes BluSH;

interface BluSH_AppI
{
  command BluSH_result_t getName( char* buff, uint8_t len );
  command BluSH_result_t callApp( char* cmdBuff, uint8_t cmdLen,
                                  char* resBuff, uint8_t resLen );
}
