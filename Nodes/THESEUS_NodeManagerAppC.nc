#include "messages.h"

configuration THESEUS_NodeManagerAppC {}
implementation {
  components MainC, THESEUS_NodeManagerC as App, LedsC;
  components new TimerMilliC() as TIMER0;
  components new TimerMilliC() as TIMER1;
  components new TimerMilliC() as TIMER2;
  components new TimerMilliC() as TIMER3;
  components new TimerMilliC() as TIMER4;
  components new TimerMilliC() as TIMER5;
  components ActiveMessageC;
  components new AMSenderC(AM_MSYNC) as AM_MSync_S;
  components new AMReceiverC(AM_MSYNC) as AM_MSync_R;
  components new AMSenderC(AM_MCOORD) as AM_MCoord_S;
  components new AMReceiverC(AM_MCOORD) as AM_MCoord_R;
  components new AMSenderC(AM_MDATA) as AM_MData_S;
  components new AMSenderC(AM_MDATA) as AM_MDataF_S;
  components new AMReceiverC(AM_MDATA) as AM_MDataF_R;
  components new AMSenderC(AM_AVRORA) as AM_Avrora_S;
  components RandomC;
  components new VoltageC() as Battery;
  
  App.Boot -> MainC.Boot;
  
  App.MSync_R -> AM_MSync_R.Receive;
  App.MSync_S -> AM_MSync_S.AMSend;
  App.MSync_P -> AM_MSync_S.Packet;
  
  App.MCoord_R -> AM_MCoord_R.Receive;
  App.MCoord_S -> AM_MCoord_S.AMSend;
  App.MCoord_P -> AM_MCoord_S.Packet;
  App.PacketAcknowledgements -> AM_MCoord_S;

  App.MData_S -> AM_MData_S.AMSend;
  App.MData_P -> AM_MData_S.Packet;
  App.PacketAcknowledgements -> AM_MData_S;
  
  App.MDataF_R -> AM_MDataF_R.Receive;
  App.MDataF_S -> AM_MDataF_S.AMSend;
  App.MDataF_P -> AM_MDataF_S.Packet;
  App.PacketAcknowledgements -> AM_MDataF_S;
  
  App.Avrora_S -> AM_Avrora_S.AMSend;
  App.Avrora_P -> AM_Avrora_S.Packet;
  
  App.AMControl -> ActiveMessageC;
  App.Leds -> LedsC;
  App.MilliTimer -> TIMER0;
  App.MilliTimerApp -> TIMER1;
  App.MilliTimerBuf -> TIMER2;
  App.MilliTimerBufE -> TIMER3;
  App.MilliTimerACK -> TIMER4;
  App.MilliTimerValidTime -> TIMER5;
  
  App.Random -> RandomC.Random;
  App.Battery -> Battery;

}