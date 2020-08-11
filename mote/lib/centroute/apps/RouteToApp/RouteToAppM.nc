////////////////////////////////////////////////////////////////////////////
//
// CENS
//
// Copyright (c) 2006 The Regents of the University of California.  All
// rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions
// are met:
//
// - Redistributions of source code must retain the above copyright
//   notice, this list of conditions and the following disclaimer.
//
// - Neither the name of the University nor the names of its
//   contributors may be used to endorse or promote products derived
//   from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS''
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
// THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
// PARTICULAR  PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE REGENTS OR
// CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
// EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
// PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
// PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
// OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
////////////////////////////////////////////////////////////////////////////

includes AM;
includes MultihopTypes;
includes QueryTypes;
includes ConfigConst;
includes eeprom_logger;
includes mDTN;

module RouteToAppM
{
  provides
  {
    interface StdControl;
    interface ApplicationI;
    
    //interface mDTNSendRawI;
    //interface mDTNRecvRawI;
  }
  uses
  {
    interface RoutingI; 
    
  }
}
implementation
{

  command result_t StdControl.init( ){
    dbg(DBG_ERROR, "Starting RouteToApp!\n");	

    return SUCCESS;
  }

  command result_t StdControl.start( ){
    dbg(DBG_ERROR, "Starting RouteToApp!\n");	
    
    return SUCCESS;
  }

  command result_t StdControl.stop( ){
    return SUCCESS;
  }

  command result_t ApplicationI.SendFromApplication(uint8_t* data, uint8_t datasize, uint16_t addr, uint8_t cst, uint8_t rel, uint8_t id){
    call RoutingI.SendToRouting(data, datasize, addr, cst, rel, id);
    return SUCCESS;
  }

  default event result_t ApplicationI.RecvToApplication(uint8_t* data,uint8_t datasize,uint16_t to_address,uint16_t from_address, uint8_t type){

	return FAIL;
  }

  command result_t ApplicationI.CheckRouteAvailable()
  {
    call RoutingI.CheckRouteAvailable();
    return SUCCESS;

  }

  event result_t RoutingI.CheckRouteAvailableDone(result_t success)
  {
    if (success != SUCCESS)
    {
      dbg(DBG_USR3,"Route to sink not available!\n");
    }

    signal ApplicationI.CheckRouteAvailableDone(success);

    return SUCCESS;
  }

  default event result_t ApplicationI.CheckRouteAvailableDone(result_t success)
  {
    return FAIL;
  }

  // a packet has been received 
  event result_t RoutingI.RecvFromRouting(uint8_t *data, uint8_t datasize,uint16_t to_address, uint16_t from_address, uint8_t type)
    {
	dbg(DBG_USR3, "Got a packet of type %d\n", type);

        signal ApplicationI.RecvToApplication(data, datasize, to_address,
	from_address, type);

    return SUCCESS;
  }


  event result_t RoutingI.SendToRoutingDone(uint8_t *data, uint8_t datasize,
	result_t success, uint8_t type){
      signal ApplicationI.SendFromApplicationDone(success);
      return SUCCESS;
  }

  event result_t RoutingI.RouteForwardFailed(uint8_t *data, uint8_t datasize)
  {

      signal ApplicationI.RouteForwardFailed(data, datasize);

      return SUCCESS;
  }

  default event result_t ApplicationI.SendFromApplicationDone(result_t success){
      return FAIL;
  }

}
