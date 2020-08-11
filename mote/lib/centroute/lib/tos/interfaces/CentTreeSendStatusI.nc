includes CentTree;

interface CentTreeSendStatusI
{
    event int8_t send_complete_status(char *data, uint8_t type, uint8_t length,
	send_originator_type_t orig, result_t status);

}
