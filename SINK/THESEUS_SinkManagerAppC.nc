#include "messages.h"

configuration THESEUS_SinkManagerAppC {}
implementation {
  components MainC, THESEUS_SinkManagerC as App, LedsC;
  components new TimerMilliC();
  components new TimerMilliC() as TIMER1;
  components ActiveMessageC;
  components new AMSenderC(AM_MSYNC) as AM_MSync_S;

  components new AMReceiverC(AM_MDATA) as AM_MData_R;
  App.Boot -> MainC.Boot;

  App.MSync_S -> AM_MSync_S.AMSend;
  App.MSync_P -> AM_MSync_S.Packet;

  App.MData_R -> AM_MData_R.Receive;

  App.AMControl -> ActiveMessageC;
  App.Leds -> LedsC;
  App.MilliTimer -> TimerMilliC;
  App.MilliTimerstart -> TIMER1;
}