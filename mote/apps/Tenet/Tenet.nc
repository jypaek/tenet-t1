/*
* "Copyright (c) 2006-2008 University of Southern California.
* All rights reserved.
*
* Permission to use, copy, modify, and distribute this software and its
* documentation for any purpose, without fee, and without written
* agreement is hereby granted, provided that the above copyright
* notice, the following two paragraphs and the author appear in all
* copies of this software.
*
* IN NO EVENT SHALL THE UNIVERSITY OF SOUTHERN CALIFORNIA BE LIABLE TO
* ANY PARTY FOR DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL
* DAMAGES ARISING OUT OF THE USE OF THIS SOFTWARE AND ITS
* DOCUMENTATION, EVEN IF THE UNIVERSITY OF SOUTHERN CALIFORNIA HAS BEEN
* ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*
* THE UNIVERSITY OF SOUTHERN CALIFORNIA SPECIFICALLY DISCLAIMS ANY
* WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
* MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.  THE SOFTWARE
* PROVIDED HEREUNDER IS ON AN "AS IS" BASIS, AND THE UNIVERSITY OF
* SOUTHERN CALIFORNIA HAS NO OBLIGATION TO PROVIDE MAINTENANCE,
* SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS."
*
*/

/**
 * This is the configuration file for Tenet mote binary
 * @author Everyone
 **/

/**
 * List of INCLUDE Tasklet definitions are in 'tasklets.h'
 **/
#include "tasklets.h"
#include "element_map.h"

configuration Tenet {
}
implementation {
  components Main
#ifdef EMSTAR_NO_KERNEL
           , EmTimerC
#else
           , TimerC
#endif
           , LedsC
           , TenetScheduler as Scheduler
           , MemoryM
           , TaskLib
#ifdef ONE_HOP_TASKING
           , TaskInstallerNoRouting as Install
           , SendTest as SendPkt
           , NewQueuedSend
#else
           , TaskInstaller as Install
           , SendPkt
           , PacketTransportC
#ifdef TASK_TESTING
           , TenetTaskTestM
#else
           , TRD_TransportC
#endif
#endif
#ifdef USE_CENTROUTE
           , RouteToAppC
           , CentTreeC as RoutingLayerC
#else
           , RoutingLayerC
#endif
           , GenericComm
           , ErrorHandler
#if defined(PLATFORM_TELOSB) || defined(PLATFORM_MICAZ) || defined(PLATFORM_IMOTE2)
           , CC2420RadioC
#elif defined(PLATFORM_MICA2) || defined(PLATFORM_MICA2DOT)
           , CC1000RadioC
#endif
#if defined(PLATFORM_TMOTE)
           , CounterMilliC
           , Counter32khzC
#else
           , LocalTimeC
#endif
#ifdef GLOBAL_TIME
           , TimeSyncC
           , GlobalAlarmC
#endif
#ifdef INCLUDE_MEMORYOP
           , MemoryOp
#endif
#ifdef INCLUDE_SENDSTR
           , SendSTR
           , StreamTransportC
#endif
#ifdef INCLUDE_SENDRCRT
           , SendRcrt
           , RcrTransportC
#endif
#ifdef INCLUDE_COUNT
           , Count
#endif
#ifdef INCLUDE_REBOOT
           , Reboot
#endif
#ifdef INCLUDE_SAMPLERSSI
           , SampleRSSI
#endif
#ifdef INCLUDE_GET
           , Get
#endif
#ifdef INCLUDE_COMPARISON
           , Comparison 
#endif
#ifdef INCLUDE_LOGICAL
           , Logical
#endif
#ifdef INCLUDE_BIT
           , Bit
#endif
#ifdef INCLUDE_ARITH
           , Arith
#endif
#ifdef INCLUDE_STATS
           , Stats
#endif
#ifdef INCLUDE_PACK
           , Pack
#endif
#ifdef INCLUDE_ATTRIBUTE
           , Attribute
#endif
#ifdef INCLUDE_DELETEATTRIBUTEIF
           , DeleteAttributeIf
#endif
#ifdef INCLUDE_DELETEACTIVETASKIF
           , DeleteActiveTaskIf
#endif
#ifdef INCLUDE_DELETETASKIF
           , DeleteTaskIf
#endif
#ifdef INCLUDE_ISSUE
           , Issue
#endif
#ifdef INCLUDE_ACTUATE
           , Actuate
#endif
#ifdef INCLUDE_STORAGE
           , Storage
#endif
#if defined(PLATFORM_MICAZ) || defined(PLATFORM_MICA2)
           , Sounder
#endif
#ifdef INCLUDE_SAMPLE
           , SampleC as Sample
#endif
#ifdef INCLUDE_VOLTAGE
           , Voltage    // tenet tasklet
           , VoltageC   // tinyos module
#endif
#ifdef INCLUDE_ONSETDETECTOR
           , OnsetDetector
#endif
#ifdef INCLUDE_FIRLPFILTER
           , FirLpFilter
#endif

// telosb-dependent tasklets
#ifdef PLATFORM_TELOSB
#ifdef INCLUDE_USERBUTTON
           , UserButton
           , UserButtonC
#endif
#ifdef INCLUDE_FASTSAMPLE
           , FastSampleC as FastSample
#endif
#endif

// micaz-dependent tasklets
#if defined(PLATFORM_MICAZ) || defined(PLATFORM_MICA2)
#ifdef INCLUDE_IMAGE
           , Image
           , hostNeuron // Image tasklet communicates to Cyclops via neuron.
#endif
#ifdef INCLUDE_SAMPLEMDA400
           , MDA400ControlC as MDA400C
           , SampleMda400
#endif
#endif

#ifdef INCLUDE_TCMP
           , TCMPC
#endif
           ;

/* Beginning of Tasklet wiring */

#ifdef INCLUDE_MEMORYOP //MemoryOP
  Install.Element_u[ELEMENT_MEMORYOP]       -> MemoryOp.Element;
  MemoryOp.TenetTask                        -> TaskLib;
  MemoryOp.Memory                           -> MemoryM;
#endif

/* SENDPKT */
  Install.Element_u[ELEMENT_SENDPKT]        -> SendPkt.Element;
  Main.StdControl                           -> SendPkt;
  SendPkt.TenetTask                         -> TaskLib;
  SendPkt.TaskError                         -> ErrorHandler;
  SendPkt.Memory                            -> MemoryM;
  SendPkt.Schedule                          -> Scheduler;
  SendPkt.List                              -> TaskLib;
#ifdef ONE_HOP_TASKING
  Main.StdControl                           -> NewQueuedSend;
  SendPkt.SendMsg                           -> NewQueuedSend.SendMsg[0x08];
#else
  Main.StdControl                           -> PacketTransportC.StdControl;
  SendPkt.SendBE                            -> PacketTransportC.NoAckSend;
  SendPkt.Send                              -> PacketTransportC.Send;
  SendPkt.RoutingTable                      -> RoutingLayerC;
#endif

#ifdef INCLUDE_SENDSTR
  Install.Element_u[ELEMENT_SENDSTR]        -> SendSTR.Element;
  Main.StdControl                           -> SendSTR;
  SendSTR.TenetTask                         -> TaskLib;
  SendSTR.TaskError                         -> ErrorHandler;
  SendSTR.Memory                            -> MemoryM;
  SendSTR.Schedule                          -> Scheduler;
  SendSTR.List                              -> TaskLib;
  Main.StdControl                           -> StreamTransportC;
  SendSTR.Send                              -> StreamTransportC;
  SendSTR.RoutingTable                      -> RoutingLayerC;
#endif

#ifdef INCLUDE_SENDRCRT
  Install.Element_u[ELEMENT_SENDRCRT]       -> SendRcrt.Element;
  Main.StdControl                           -> SendRcrt;
  SendRcrt.TenetTask                        -> TaskLib;
  SendRcrt.TaskError                        -> ErrorHandler;
  SendRcrt.Memory                           -> MemoryM;
  SendRcrt.Schedule                         -> Scheduler;
  SendRcrt.List                             -> TaskLib;
  Main.StdControl                           -> RcrTransportC.StdControl;
  SendRcrt.Send                             -> RcrTransportC;
  SendRcrt.RoutingTable                     -> RoutingLayerC;
#endif

#ifdef INCLUDE_ISSUE
  Install.Element_u[ELEMENT_ISSUE]          -> Issue.Element;
  Main.StdControl                           -> Issue;
  Issue.TenetTask                           -> TaskLib;
  Issue.TaskError                           -> ErrorHandler;
  Issue.Memory                              -> MemoryM;
  Issue.Schedule                            -> Scheduler;
  Issue.List                                -> TaskLib;
#ifdef EMSTAR_NO_KERNEL
  Issue.IssueTimer                          -> EmTimerC.EmTimerI[unique("Timer")];
#else
  Issue.IssueTimer                          -> TimerC.Timer[unique("Timer")];
#endif
#ifdef GLOBAL_TIME
  Issue.AbsoluteTimer                       -> GlobalAlarmC;
  Issue.GlobalTime                          -> TimeSyncC;
#endif
#if defined(PLATFORM_TMOTE)
  Issue.LocalTime                           -> CounterMilliC;
#else
  Issue.LocalTime                           -> LocalTimeC;
  Issue.LocalTimeInfo                       -> LocalTimeC;
#endif
#endif

#ifdef INCLUDE_ACTUATE
  Install.Element_u[ELEMENT_ACTUATE]        -> Actuate.Element;
  Actuate.TenetTask                         -> TaskLib;
  Actuate.TaskError                         -> ErrorHandler;
  Actuate.Memory                            -> MemoryM;
  Actuate.Leds                              -> LedsC;
#if defined(PLATFORM_TELOSB) || defined(PLATFORM_MICAZ) || defined(PLATFORM_IMOTE2)
  Actuate.CC2420Control                     -> CC2420RadioC;
#elif defined(PLATFORM_MICA2) || defined(PLATFORM_MICA2DOT)
  Actuate.CC1000Control                     -> CC1000RadioC;
#endif
#if defined(PLATFORM_MICAZ) || defined(PLATFORM_MICA2)
  Actuate.Sounder                           -> Sounder;
#endif
#ifndef USE_CENTROUTE
  Actuate.ParentControl                     -> RoutingLayerC;
#endif
#endif

#ifdef INCLUDE_STORAGE
  Install.Element_u[ELEMENT_STORAGE]        -> Storage.Element;
  Storage.TenetTask                         -> TaskLib;
  Storage.TaskError                         -> ErrorHandler;
  Storage.Memory                            -> MemoryM;
  Storage.List                              -> TaskLib;
#endif

#ifdef INCLUDE_COUNT
  Install.Element_u[ELEMENT_COUNT]          -> Count.Element;
  Count.TenetTask                           -> TaskLib;
  Count.Memory                              -> MemoryM;
#endif

#ifdef INCLUDE_REBOOT
  Install.Element_u[ELEMENT_REBOOT]         -> Reboot.Element;
  Reboot.TenetTask                          -> TaskLib;
  Reboot.Memory                             -> MemoryM;
#endif

#ifdef INCLUDE_SAMPLERSSI
  Install.Element_u[ELEMENT_SAMPLERSSI]     -> SampleRSSI.Element;
  SampleRSSI.TenetTask                      -> TaskLib;
  SampleRSSI.Memory                         -> MemoryM;
  SampleRSSI.Timer                          -> TimerC.Timer[unique("Timer")];
  SampleRSSI.ReceiveMsg                     -> GenericComm.ReceiveMsg[0x04];
#endif

#ifdef INCLUDE_GET
  Install.Element_u[ELEMENT_GET]            -> Get.Element;
  Get.TenetTask                             -> TaskLib;
  Get.TaskError                             -> ErrorHandler;
  Get.Memory                                -> MemoryM;
  Get.RoutingTable                          -> RoutingLayerC;
#ifndef USE_CENTROUTE
  Get.ChildrenTable                         -> RoutingLayerC;
  Get.NeighborTable                         -> RoutingLayerC;
#endif
#ifdef GLOBAL_TIME
  Get.GlobalTime                            -> TimeSyncC;
#endif
#if defined(PLATFORM_TMOTE)
  Get.LocalTime32khz                        -> Counter32khzC;
  Get.LocalTimeMS                           -> CounterMilliC;
#else
  Get.LocalTime                             -> LocalTimeC;
  Get.LocalTimeInfo                         -> LocalTimeC;
#endif
  Get.Leds                                  -> LedsC;
#if defined(PLATFORM_TELOSB) || defined(PLATFORM_MICAZ) || defined(PLATFORM_IMOTE2)
  Get.CC2420Control                         -> CC2420RadioC;
#elif defined(PLATFORM_MICA2) || defined(PLATFORM_MICA2DOT)
  Get.CC1000Control                         -> CC1000RadioC;
#endif
#endif

#ifdef INCLUDE_LOGICAL
  Install.Element_u[ELEMENT_LOGICAL]        -> Logical.Element;
  Logical.TenetTask                         -> TaskLib;
  Logical.TaskError                         -> ErrorHandler;
  Logical.Memory                            -> MemoryM;
#endif

#ifdef INCLUDE_BIT
  Install.Element_u[ELEMENT_BIT]            -> Bit.Element;
  Bit.TenetTask                             -> TaskLib;
  Bit.TaskError                             -> ErrorHandler;
  Bit.Memory                                -> MemoryM;
#endif

#ifdef INCLUDE_ARITH
  Install.Element_u[ELEMENT_ARITH]          -> Arith.Element;
  Arith.TenetTask                           -> TaskLib;
  Arith.TaskError                           -> ErrorHandler;
  Arith.Memory                              -> MemoryM;
#endif

#ifdef INCLUDE_COMPARISON
  Install.Element_u[ELEMENT_COMPARISON]     -> Comparison.Element;
  Comparison.TenetTask                      -> TaskLib;
  Comparison.TaskError                      -> ErrorHandler;
  Comparison.Memory                         -> MemoryM;
#endif

#ifdef INCLUDE_STATS
  Install.Element_u[ELEMENT_STATS]          -> Stats.Element;
  Stats.TenetTask                           -> TaskLib;
  Stats.TaskError                           -> ErrorHandler;
  Stats.Memory                              -> MemoryM;
#endif

#ifdef INCLUDE_PACK
  Install.Element_u[ELEMENT_PACK]           -> Pack.Element;
  Pack.TenetTask                            -> TaskLib;
  Pack.TaskError                            -> ErrorHandler;
  Pack.Memory                               -> MemoryM;
#endif

#ifdef INCLUDE_ATTRIBUTE
  Install.Element_u[ELEMENT_ATTRIBUTE]      -> Attribute.Element;
  Attribute.TenetTask                       -> TaskLib;
  Attribute.TaskError                       -> ErrorHandler;
  Attribute.Memory                          -> MemoryM;
#endif

#ifdef INCLUDE_DELETEATTRIBUTEIF
  Install.Element_u[ELEMENT_DELETEATTRIBUTEIF] -> DeleteAttributeIf.Element;
  DeleteAttributeIf.TenetTask               -> TaskLib;
  DeleteAttributeIf.TaskError               -> ErrorHandler;
  DeleteAttributeIf.Memory                  -> MemoryM;
#endif

#ifdef INCLUDE_DELETEACTIVETASKIF
  Install.Element_u[ELEMENT_DELETEACTIVETASKIF] -> DeleteActiveTaskIf.Element;
  DeleteActiveTaskIf.TenetTask              -> TaskLib;
  DeleteActiveTaskIf.TaskError              -> ErrorHandler;
  DeleteActiveTaskIf.Memory                 -> MemoryM;
#endif

#ifdef INCLUDE_DELETETASKIF
  Install.Element_u[ELEMENT_DELETETASKIF]   -> DeleteTaskIf.Element;
  DeleteTaskIf.TenetTask                    -> TaskLib;
  DeleteTaskIf.TaskError                    -> ErrorHandler;
  DeleteTaskIf.Memory                       -> MemoryM;
#endif

#ifdef INCLUDE_SAMPLE
  Install.Element_u[ELEMENT_SAMPLE]         -> Sample.Element;
  Main.StdControl                           -> Sample;
  Sample.TenetTask                          -> TaskLib;
  Sample.TaskError                          -> ErrorHandler;
  Sample.Memory                             -> MemoryM;
  Sample.Schedule                           -> Scheduler;
  Sample.List                               -> TaskLib;
  Sample.LocalTime                          -> LocalTimeC;
  Sample.LocalTimeInfo                      -> LocalTimeC;
#endif

#ifdef INCLUDE_VOLTAGE
  Install.Element_u[ELEMENT_VOLTAGE]        -> Voltage.Element;
  Main.StdControl                           -> Voltage;
  Voltage.TenetTask                         -> TaskLib;
  Voltage.Memory                            -> MemoryM;
  Voltage.Schedule                          -> Scheduler;
  Voltage.List                              -> TaskLib;
  Voltage.ADCControl                        -> VoltageC;
  Voltage.Voltage                           -> VoltageC;
#endif

#ifdef INCLUDE_ONSETDETECTOR
  Install.Element_u[ELEMENT_ONSETDETECTOR]  -> OnsetDetector.Element;
  OnsetDetector.TenetTask                   -> TaskLib;
  OnsetDetector.Schedule                    -> Scheduler;
  OnsetDetector.Memory                      -> MemoryM;
#endif

#ifdef INCLUDE_FIRLPFILTER
  Install.Element_u[ELEMENT_FIRLPFILTER]    -> FirLpFilter.Element;
  FirLpFilter.TenetTask                     -> TaskLib;
  FirLpFilter.Schedule                      -> Scheduler;
  FirLpFilter.Memory                        -> MemoryM;
#endif

// telosb-dependent tasklets
#ifdef PLATFORM_TELOSB
#ifdef INCLUDE_USERBUTTON
  Install.Element_u[ELEMENT_USERBUTTON]     -> UserButton.Element;
  Main.StdControl                           -> UserButtonC;
  UserButton.TenetTask                      -> TaskLib;
  UserButton.Memory                         -> MemoryM;
  UserButton.Schedule                       -> Scheduler;
  UserButton.List                           -> TaskLib;
  UserButton.UserButton                     -> UserButtonC;
#endif

#ifdef INCLUDE_FASTSAMPLE
  Install.Element_u[ELEMENT_FASTSAMPLE]     -> FastSample.Element;
  Main.StdControl                           -> FastSample;
  FastSample.TenetTask                      -> TaskLib;
  FastSample.Memory                         -> MemoryM;
  FastSample.Schedule                       -> Scheduler;
  FastSample.Leds                           -> LedsC;
#endif
#endif

// micaz-dependent tasklets
#if defined(PLATFORM_MICAZ) || defined(PLATFORM_MICA2)
#ifdef INCLUDE_IMAGE    // CYCLOPS
  Install.Element_u[ELEMENT_IMAGE]          -> Image.Element;
  Main.StdControl                           -> Image;
  Image.TenetTask                           -> TaskLib;
  Image.List                                -> TaskLib;
  Image.Schedule                            -> Scheduler;
  Image.Memory                              -> MemoryM;
  Image.TaskError                           -> ErrorHandler;
  Image.Leds                                -> LedsC;
  Image.WaitTimer                           -> TimerC.Timer[unique("Timer")];
  Image.neuronControl                       -> hostNeuron;
  Image.neuronH                             -> hostNeuron;
#endif

#ifdef INCLUDE_SAMPLEMDA400
  Install.Element_u[ELEMENT_SAMPLEMDA400]   -> SampleMda400.Element;
  Main.StdControl                           -> SampleMda400;
  SampleMda400.MDA400I                      -> MDA400C;
  SampleMda400.SubControl                   -> MDA400C;
  SampleMda400.Timer                        -> TimerC.Timer[unique("Timer")];
  SampleMda400.TenetTask                    -> TaskLib;
  SampleMda400.Schedule                     -> Scheduler;
  SampleMda400.Memory                       -> MemoryM;
#ifdef GLOBAL_TIME
  SampleMda400.GlobalTime                   -> TimeSyncC;
#else
  SampleMda400.LocalTime                    -> LocalTimeC;
#endif
#endif
#endif

/* End of Tasklet wiring */


/* Beginning of non-tasklet wirings */

  /** 
   * Task/Tasklet Error Handler
   **/
  ErrorHandler.TenetTask      -> TaskLib;
  ErrorHandler.TaskDelete     -> Install;
  ErrorHandler.Send           -> SendPkt.SneakSend;
#ifdef BACK_CHANNEL
  ErrorHandler.SendMsg        -> NewQueuedSend.SendMsg[PORT_TENET_ERROR];
#endif

  /** 
   * Tenet Task Library/Installer/Scheduler
   **/
#ifdef EMSTAR_NO_KERNEL
  Main.StdControl             -> EmTimerC;
#else
  Main.StdControl             -> TimerC;
#endif
  Main.StdControl             -> Install;
  Main.StdControl             -> Scheduler;
  Scheduler.TenetTask         -> TaskLib;
  Scheduler.TaskDelete        -> Install;
  Scheduler.List              -> TaskLib;
  Scheduler.Leds              -> LedsC;
  TaskLib.Memory              -> MemoryM;
  Install.TenetTask           -> TaskLib;
  Install.List                -> TaskLib;
  Install.Schedule            -> Scheduler;
  Install.TaskError           -> ErrorHandler;

#ifdef TASK_TESTING // receive task internally rather than over trd
  Main.StdControl             -> TenetTaskTestM;
  Install.TRD_Transport       -> TenetTaskTestM;
  TenetTaskTestM.Timer        -> TimerC.Timer[unique("Timer")];
#elif ONE_HOP_TASKING // receive task in 1-hop via GenericComm
  Main.StdControl             -> GenericComm;
  Install.ReceiveMsg          -> GenericComm.ReceiveMsg[0x07];
#else
  /** 
   * Actual Task receiver 
   * (TRD is the transport protocol used for task dissemination)
   **/
  Install.TRD_Transport       -> TRD_TransportC;
#endif

#ifdef INCLUDE_TCMP
  Main.StdControl             -> TCMPC;
#endif

}

