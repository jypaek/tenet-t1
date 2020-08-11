
/*
 * Authors: Sumit Rangwala, Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 */

/**
 * @author Sumit Rangwala
 * @author Jeongyeup Paek
 * @modified 10/25/2004
 */

configuration HPLVBOARDC {
	provides interface HPLUART;
}
implementation
{
	components HPLVBOARDM;

	HPLUART = HPLVBOARDM;
}

