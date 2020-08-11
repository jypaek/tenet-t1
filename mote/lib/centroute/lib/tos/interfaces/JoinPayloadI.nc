includes Joiner;


interface JoinPayloadI
{
    command int8_t init(int8_t type, int8_t length, char *value);
}
