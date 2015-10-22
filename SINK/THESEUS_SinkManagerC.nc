#include "Timer.h"
#include "messages.h"
#define CycleTime 0xF000 // cycle timer set to 61440 milliseconds (60 seconds) and it will make new cycle every 3 times of this time (means each 3 minutes like PROC)
#define	MCycle 0x00000003 //Cycle time in minutes
// Values of app parameter should be set here:
#define f_appparam_MDTC 0x2800 // 10 seconds
#define f_appparam_MDTE 0x0400 // 1 second
#define f_appparam_a 0x0001
#define f_appparam_b 0x0001
#define f_appparam_c 0x0001
#define f_appparam_d 0x0001
#define f_appparam_SPpMTI_1 0x0002
#define f_appparam_SPpMTI_2 0x0001
#define f_appparam_SPpMTI_3 0
#define f_appparam_SPpMTI_4 0
#define f_appparam_mSPpMTI 0x0002

module THESEUS_SinkManagerC {
  uses {
    interface Leds;
    interface Boot;
    interface Timer<TMilli> as MilliTimer;
	interface Timer<TMilli> as MilliTimerstart;
    interface SplitControl as AMControl;
    interface Packet;
	interface AMSend as MSync_S;
	interface Packet as MSync_P;
	interface Receive as MData_R;
	interface Packet as MData_P;
  }
}
implementation {

  message_t packet;
  uint8_t cyclecounter = 0x0000;
  bool locked;
  uint16_t nextCycle = 0x0001;
  uint16_t flags = 0;
  uint16_t source_add;
  uint16_t destination_add = 0;
  uint16_t app_data1 = 0;
  uint16_t app_data2 = 0;
  uint16_t app_data3 = 0;
  uint16_t app_data4 = 0;
  uint16_t app_data5 = 0;
  uint16_t app_data6 = 0;
  uint16_t app_data7 = 0;
  uint16_t app_data8 = 0;
  uint16_t app_data9 = 0;
  uint16_t app_data10 = 0;
  uint16_t app_data11 = 0;
  uint16_t appparam_MDTC;
  uint16_t appparam_MDTE;
  uint8_t appparam_a;
  uint8_t appparam_b;
  uint8_t appparam_c;
  uint8_t appparam_d;
  uint8_t SinkID;
  uint8_t appparam_SPpMTI_1;
  uint8_t appparam_SPpMTI_2;
  uint8_t appparam_SPpMTI_3;
  uint8_t appparam_SPpMTI_4;
  uint8_t appparam_mSPpMTI;
  
  
  task void MSync_broad_task(){ //Task of broad-casting MSync message
	if (!locked) {
		MSync_t* rcm = (MSync_t*)call MSync_P.getPayload(&packet, sizeof(MSync_t));
		if (rcm == NULL) {return;}
		rcm->Node_ID = TOS_NODE_ID;
		rcm->cycle = nextCycle;
		rcm->hops = 0;
		rcm->coord = 0x0001;
		rcm->energy = 0xFFFF; //energy of sink node is always full
		rcm->appparam_MDTC = f_appparam_MDTC;
		rcm->appparam_MDTE = f_appparam_MDTE;
		rcm->appparam_a = f_appparam_a;
		rcm->appparam_b = f_appparam_b;
		rcm->appparam_c = f_appparam_c;
		rcm->appparam_d = f_appparam_d;
		rcm->SinkID = TOS_NODE_ID;
		rcm->appparam_SPpMTI_1 = f_appparam_SPpMTI_1;
		rcm->appparam_SPpMTI_2 = f_appparam_SPpMTI_2;
		rcm->appparam_SPpMTI_3 = f_appparam_SPpMTI_3;
		rcm->appparam_SPpMTI_4 = f_appparam_SPpMTI_4;
		rcm->appparam_mSPpMTI = f_appparam_mSPpMTI;
		rcm->Parent_ID = 0xFFFF; // sink does not have parent
		rcm->Valid_Time = MCycle; //cycle time in minutes
		if (call MSync_S.send(AM_BROADCAST_ADDR, &packet, sizeof(MSync_t)) == SUCCESS) {
			locked = TRUE;
	  }
	}
	else{post MSync_broad_task();}
  }
  
  event void Boot.booted() {
    call AMControl.start();
  }

  event void AMControl.startDone(error_t err) {//Sink Node start to work and startPeriodic(CycleTime)
    if (err == SUCCESS) {
		call Leds.led1Toggle();
		call MilliTimerstart.startOneShot(5120); //start first cycle after 5 second, because use of stagger option last node will start a little later than sink 
    }
    else {
      call AMControl.start();
    }
  }

  event void AMControl.stopDone(error_t err) {//Sink Node doesn't start to work
    // do nothing
  }

  event void MilliTimerstart.fired() { // For first cycle
	call MilliTimer.startPeriodic(CycleTime);
	//The First cycle MSync message
	post MSync_broad_task();
  }
  
  event void MilliTimer.fired() { // For each cycle broad-cast new MSync message
    cyclecounter++;
	if (cyclecounter == MCycle){
		cyclecounter = 0;
		// for test the invalid sink (remove and add sink in middle of working)
		//if (((nextCycle == 3) || (nextCycle == 4) || (nextCycle == 5))&&((uint16_t)(TOS_NODE_ID) == 0)){nextCycle++;}else{post MSync_broad_task();}
		post MSync_broad_task();
	}
  }

 event message_t* MData_R.receive(message_t* bufPtrD, //Receive data
				   void* payload, uint8_t len) {
	//application should decide to what to do with data
    return bufPtrD;
  }

  event void MSync_S.sendDone(message_t* bufPtrS, error_t error) { //call new cycle
    if (&packet == bufPtrS) {
      locked = FALSE;
	  nextCycle++;
	  call Leds.led0Toggle();
    }
  }

}