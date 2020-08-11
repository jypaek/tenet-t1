/**
 * Author 	Junaith Ahemed
 * Date		January 25, 2007
 */
interface UniqueSequenceID
{
	command uint32_t GetNextSequenceID ();
	command result_t ResetSequenceID ();
}
