
/**
 * Top-level configuration file for the binary that formats the telosb flash.
 *
 * @author Jeongyeup Paek
 * Embedded Networks Laboratory, University of Southern California
 * @modified Oct/13/2005
 **/

includes FormatTelosbFlash;

configuration Format {
}
implementation {

	components Main, LedsC, FormatStorageC, FormatM;

	Main.StdControl -> FormatM;
	FormatM.FormatStorage -> FormatStorageC;
	FormatM.Leds -> LedsC;

}

