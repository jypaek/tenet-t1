
module CC2420RadioC
{
  provides {
    interface MacControl;
  }
}
implementation
{
  async command void MacControl.enableAck() {
	return;
  }
  async command void MacControl.disableAck() {
	return;
  }
	
}
