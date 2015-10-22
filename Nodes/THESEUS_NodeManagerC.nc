#include "Timer.h"
#include "messages.h"
#define NeighborsLen 0x0014 //Maximum number of neighbours on the list is 20
#define SinknodesLen 0x000A //Maximum number of sink nodes on the list is 10
#define MAX_RANDOM_THRESHOLD 0x0200 //Maximum back off time 512ms
#define MIN_RANDOM_THRESHOLD 0x0078 //Minimum back off time 120ms
//Set bits for changing flags
#define B01_16 0x8000
#define B02_16 0x4000

module THESEUS_NodeManagerC { //interfaces
  uses {
    interface Leds;
    interface Boot;
	
    interface Timer<TMilli> as MilliTimer;
	interface Timer<TMilli> as MilliTimerApp;
	interface Timer<TMilli> as MilliTimerBuf;
	interface Timer<TMilli> as MilliTimerBufE;
	interface Timer<TMilli> as MilliTimerACK;
	interface Timer<TMilli> as MilliTimerValidTime;
	
    interface SplitControl as AMControl;

	interface Receive as MSync_R;
	interface AMSend as MSync_S;
	interface Packet as MSync_P;
  
	interface Receive as MCoord_R;
	interface AMSend as MCoord_S;
	interface Packet as MCoord_P;
  
	interface AMSend as MData_S;
	interface Packet as MData_P;
	
	interface Receive as MDataF_R;
	interface AMSend as MDataF_S;
	interface Packet as MDataF_P;
	
	interface AMSend as Avrora_S;
	interface Packet as Avrora_P;
	
	interface PacketAcknowledgements;
	interface Random;
	
	interface Read<uint16_t> as Battery;
  }
}

implementation {
  //start: defining variables
  
  //Messages variables
  message_t packet;
  bool locked;
  
  //The nodes choose areas based on ID
  uint8_t node_area = 0x0000;
  uint8_t node_area1_start = 0x0002; //Node_ID 2 to 51 is area 1
  uint8_t node_area1_end = 0x0033;
  uint8_t node_area2_start = 0x0034; //Node_ID 52 to 200 is area 2
  uint8_t node_area2_end = 0x00C8;
  uint16_t node_area3_start = 0x00C9; //Node_ID 201 to 300 is area 3
  uint16_t node_area3_end = 0x012C;
  uint16_t node_area4_start = 0x012D; //Node_ID 301 to 400 is area 4
  uint16_t node_area4_end = 0x0190;

  //ACK variables
  int trycoord = 0;
  int trydata = 0;
  int trydataF = 0;
  uint8_t rep_mode = 0;
  
  //battery variables
  uint16_t counter_send = 0;
  
  //Arrays
  SinkCycle_t SinkCycle[SinknodesLen];//Array of Sinks Cycles
  Neighbors_t neighbors[NeighborsLen]; //Array of neighbours
  int ID = -1;
  uint8_t i;
  
  //process control variables
  uint16_t Valid_Time;
  bool coord = FALSE;
  bool cont_sync_task = FALSE;
  int parent_add = -2;
  int SinkID = -1;
  uint8_t parent_hops;
  bool parent_coord;  
  bool find;
  float randBackoffPeriod=0.0F;
  int Sinks_n;

  //App function variables
  float F1;
  float F2;
  float F3;
  float F4;
  float prob;
  float tmp_rnd;
  uint8_t Neighbors_n = 0; //0 to NeighborsLen, count the number of neighbours in each cycle
  uint16_t AppCycleTime = 0x3800; // 14 seconds 
  uint16_t currEnergy = 0x2800; // first cycle will not read energy, this is default startup energy just for first cycle
  uint8_t Appcounter = 0x0000;
  uint8_t appparam_a;
  uint8_t appparam_b;
  uint8_t appparam_c;
  uint8_t appparam_d;
  uint8_t appparam_SPpMTI_1;
  uint8_t appparam_SPpMTI_2;
  uint8_t appparam_SPpMTI_3;
  uint8_t appparam_SPpMTI_4;
  uint8_t appparam_mSPpMTI;
  uint8_t last_cycle_coord = 0x0000;
  uint8_t count_coord = 0x0000;
  
  //DATA MANAGER VARIABLES
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
  
  uint16_t buff_data1 = 0;
  uint16_t buff_data2 = 0;
  uint16_t buff_data3 = 0;
  uint16_t buff_data4 = 0;
  uint16_t buff_data5 = 0;
  uint16_t buff_data6 = 0;
  uint16_t buff_data7 = 0;
  uint16_t buff_data8 = 0;
  uint16_t buff_data9 = 0;
  uint16_t buff_data10 = 0;
  uint16_t buff_data11 = 0;
  uint16_t buff_source_add;
  uint16_t appparam_MDTC = 0x0001; // 1ms default
  uint16_t flags_buff = 0;
  
  uint16_t buffE_data1 = 0;
  uint16_t buffE_data2 = 0;
  uint16_t buffE_data3 = 0;
  uint16_t buffE_data4 = 0;
  uint16_t buffE_data5 = 0;
  uint16_t buffE_data6 = 0;
  uint16_t buffE_data7 = 0;
  uint16_t buffE_data8 = 0;
  uint16_t buffE_data9 = 0;
  uint16_t buffE_data10 = 0;
  uint16_t buffE_data11 = 0;
  uint16_t buffE_source_add;
  uint16_t appparam_MDTE = 0x0001; // 1ms default
  uint16_t flags_buffE = 0;
  
  uint16_t rndDATA = 0;
  
  //finish: defining variables

  void count_neighbors(){ //count number of neighbours in the array
    Neighbors_n = 0;
    for (i=0;i<NeighborsLen;i++){ //number of neighbours related to selected sink
		if ((neighbors[i].cycle > 0)){//&&(neighbors[i].sink_id == SinkID)) {
			Neighbors_n = Neighbors_n + 1;
		}
	}
  }
  
  void count_sinks(){ //count number of neighbours in the array
    Sinks_n = 0;
    for (i=0;i<SinknodesLen;i++){ //number of neighbours related to selected sink
		if (SinkCycle[i].scycle > 0) {
			Sinks_n = Sinks_n + 1;
		}
	}
  }
  
  void App_Function(){ //App Function
	count_neighbors();
	F1 = 100.0F-(((float)(last_cycle_coord) * 50.0F)+(((float)(count_coord)/(float)(SinkCycle[SinkID].scycle))*50.0F));
	F2 = 100.0F-(((float)(Neighbors_n)/(float)(NeighborsLen+1))*100.0F);
	F3 = 100.0F / (((float)(parent_hops) + 1.0F));
	if (node_area == 0x0001){F4 = 100.0F * ((float)(appparam_SPpMTI_1) / (float)(appparam_mSPpMTI+1));} //this is for a node in area 1
	if (node_area == 0x0002){F4 = 100.0F * ((float)(appparam_SPpMTI_2) / (float)(appparam_mSPpMTI+1));} //this is for a node in area 2
	if (node_area == 0x0003){F4 = 100.0F * ((float)(appparam_SPpMTI_3) / (float)(appparam_mSPpMTI+1));} //this is for a node in area 3
	if (node_area == 0x0004){F4 = 100.0F * ((float)(appparam_SPpMTI_4) / (float)(appparam_mSPpMTI+1));} //this is for a node in area 4
	prob = ((float)(appparam_a))*((float)(F1));
	prob += ((float)(appparam_b))*((float)(F2));
	prob += ((float)(appparam_c))*((float)(F3));
	prob += ((float)(appparam_d))*((float)(F4));
	prob = prob / ((float)(appparam_a + appparam_b + appparam_c + appparam_d));
  }
    
  task void msync_broad_task(){ //Task of broad-casting MSync message with updated fields from this node
	if (!locked) {
	  MSync_t* rcm = (MSync_t*)call MSync_P.getPayload(&packet, sizeof(MSync_t));
	  rcm->Node_ID = TOS_NODE_ID;
	  rcm->cycle = SinkCycle[SinkID].scycle;
	  rcm->hops = parent_hops + 1;
	  if (coord == TRUE){rcm->coord = 1;}else if(coord == FALSE){rcm->coord = 0;};
	  rcm->energy = 0xFFFF - counter_send; //currEnergy;//get energy;
	  rcm->appparam_MDTC = appparam_MDTC;
	  rcm->appparam_MDTE = appparam_MDTE;
	  rcm->appparam_a = appparam_a;
	  rcm->appparam_b = appparam_b;
	  rcm->appparam_c = appparam_c;
	  rcm->appparam_d = appparam_d;
	  rcm->SinkID = SinkID;
	  rcm->appparam_SPpMTI_1 = appparam_SPpMTI_1;
	  rcm->appparam_SPpMTI_2 = appparam_SPpMTI_2;
	  rcm->appparam_SPpMTI_3 = appparam_SPpMTI_3;
	  rcm->appparam_SPpMTI_4 = appparam_SPpMTI_4;
	  rcm->appparam_mSPpMTI = appparam_mSPpMTI;
	  rcm->Parent_ID = parent_add;
	  rcm->Valid_Time = Valid_Time; //valid cycle time
	  if (call MSync_S.send(AM_BROADCAST_ADDR, &packet, sizeof(MSync_t)) == SUCCESS) {
		locked = TRUE;
		counter_send++;
	  }
	}
	else{post msync_broad_task();}
  }
  
  void Election_Manager(){ //Election Manager
	coord = FALSE;
	App_Function();
	
	// coordinator or not, random limited to prob
	tmp_rnd = (float)(call Random.rand16());
	tmp_rnd = 100.0F * (tmp_rnd/65535.0F);
	if (tmp_rnd < prob) {coord = TRUE; call Leds.led1On();} else {coord = FALSE; call Leds.led1Off();}
	last_cycle_coord = 0;
	if (coord == TRUE) {count_coord++;last_cycle_coord = 1;}
	
	cont_sync_task = TRUE;
	post msync_broad_task();
  }

  void Parent_Selector_Manager(){ //select parent within neighbours list
	if (coord == 1){
		//priority: 1)minimum hops, 2)being coordinator, 3)maximum energy
		uint8_t min_hop = 255;
		uint16_t max_energy = 0;
		for (i=0;i<NeighborsLen;i++){
			if (neighbors[i].hops < min_hop && (!neighbors[i].energy == 0) && (neighbors[i].energy > 0) && (SinkID == neighbors[i].sink_id)) {
				min_hop = neighbors[i].hops;
			}
		}
		for (i=0;i<NeighborsLen;i++){
			if ((neighbors[i].hops == min_hop && neighbors[i].coord == 1) && (neighbors[i].energy > 0)&& (SinkID == neighbors[i].sink_id)) {
				if (max_energy < neighbors[i].energy) {max_energy = neighbors[i].energy; parent_add = neighbors[i].node_id;parent_hops = neighbors[i].hops;parent_coord = neighbors[i].coord;}
			}
		}
		if (max_energy == 0){
			for (i=0;i<NeighborsLen;i++){
				if ((neighbors[i].hops == min_hop)  && (neighbors[i].energy > 0)&& (SinkID == neighbors[i].sink_id))  {
					if (max_energy < neighbors[i].energy) {max_energy = neighbors[i].energy; parent_add = neighbors[i].node_id;parent_hops = neighbors[i].hops;parent_coord = neighbors[i].coord;}
				}
			}
		}
	}
	else{
		//priority: 1)being coordinator, 2)minimum hops, 3)maximum energy
		uint8_t min_hop = 255;
		uint16_t max_energy = 0;
		for (i=0;i<NeighborsLen;i++){
			if ((neighbors[i].coord == 1) && (neighbors[i].energy > 0)&& (SinkID == neighbors[i].sink_id))  {
				if (neighbors[i].hops < min_hop && (!neighbors[i].energy == 0)) {min_hop = neighbors[i].hops;}
			}
		}
		for (i=0;i<NeighborsLen;i++){
			if ((neighbors[i].hops == min_hop) && (neighbors[i].coord == 1)  && (neighbors[i].energy > 0)&& (SinkID == neighbors[i].sink_id)) {
				if (max_energy < neighbors[i].energy) {max_energy = neighbors[i].energy; parent_add = neighbors[i].node_id;parent_hops = neighbors[i].hops;parent_coord = neighbors[i].coord;}
			}
		}
		if (max_energy == 0){
			for (i=0;i<NeighborsLen;i++){
				if ((neighbors[i].hops < min_hop) && (neighbors[i].energy > 0)&& (SinkID == neighbors[i].sink_id))  {min_hop = neighbors[i].hops;}
			}
			for (i=0;i<NeighborsLen;i++){
				if ((neighbors[i].hops == min_hop) && (neighbors[i].energy > 0)&& (SinkID == neighbors[i].sink_id))  {
					if (max_energy < neighbors[i].energy) {max_energy = neighbors[i].energy; parent_add = neighbors[i].node_id;parent_hops = neighbors[i].hops;parent_coord = neighbors[i].coord;}
				}
			}
		}
	}
  }
  
  int Index_finder(uint16_t id){ //Function to find the index of array related to given node_id or create a new index
	for (i=0;i<NeighborsLen;i++){
		if ((neighbors[i].node_id == id)||(neighbors[i].energy == 0)) {
			neighbors[i].node_id = id;
			return i;
		}
	}
	return -1;
  }
  
  event message_t* MSync_R.receive(message_t* bufPtrS, //Receive MSync message
				   void* payload, uint8_t len) {
	MSync_t* rcm = (MSync_t*)payload;
	call Leds.led0Toggle();
	//start Sync-Manager
	if (SinkID == -1){SinkID = rcm->SinkID;SinkCycle[(rcm->SinkID)].scycle = (rcm->cycle);SinkCycle[(rcm->SinkID)].valid_time = (rcm->Valid_Time);} //for the first time
	if ((SinkCycle[(rcm->SinkID)].scycle < (rcm->cycle))||(Neighbors_n == 0)){ //MSync message of new cycle
		SinkCycle[(rcm->SinkID)].scycle = (rcm->cycle);
		SinkCycle[(rcm->SinkID)].valid_time = (rcm->Valid_Time);
		//empty the list of neighbours for new cycle for the related sink
		for (i=0;i<NeighborsLen;i++){
			if ((neighbors[i].sink_id == rcm->SinkID)&&(neighbors[i].cycle > 0)){
				neighbors[i].node_id = 0;
				neighbors[i].hops = 0;
				neighbors[i].sink_id = 0;
				neighbors[i].energy = 0;
				neighbors[i].coord = 0;
				neighbors[i].cycle = 0;
			}
		}
		//add new cycle data to neighbours and parameters
		ID = Index_finder(rcm->Node_ID);
		if (ID>-1){
			neighbors[ID].hops = rcm->hops; 
			neighbors[ID].cycle = rcm->cycle;
			neighbors[ID].sink_id = rcm->SinkID;
			neighbors[ID].coord = rcm->coord;
			neighbors[ID].energy = rcm->energy;
		}
		appparam_MDTC = rcm->appparam_MDTC;
		appparam_MDTE = rcm->appparam_MDTE;
		appparam_a = rcm->appparam_a;
		appparam_b = rcm->appparam_b;
		appparam_c = rcm->appparam_c;
		appparam_d = rcm->appparam_d;
		appparam_SPpMTI_1 = rcm->appparam_SPpMTI_1;
		appparam_SPpMTI_2 = rcm->appparam_SPpMTI_2;
		appparam_SPpMTI_3 = rcm->appparam_SPpMTI_3;
		appparam_SPpMTI_4 = rcm->appparam_SPpMTI_4;
		appparam_mSPpMTI = rcm->appparam_mSPpMTI;
		Valid_Time = rcm->Valid_Time; //valid cycle time
		if (SinkID == rcm->SinkID){ //same sink		
			//set default parent to the new MSync sender 
			parent_add = rcm->Node_ID;
			parent_hops = rcm->hops;
			parent_coord = rcm->coord;
			call MilliTimerValidTime.stop();
			Election_Manager();
		}else if((rcm->hops) < parent_hops){ //new sink is better because it has less hops to sink
			parent_add = rcm->Node_ID;
			parent_hops = rcm->hops;
			parent_coord = rcm->coord;
			SinkID = rcm->SinkID;
			call MilliTimerValidTime.stop();
			Election_Manager();	
		}
	}else if (SinkCycle[(rcm->SinkID)].scycle == (rcm->cycle)) {//MSync message of same cycle, which completes the neighbour list
		ID = Index_finder(rcm->Node_ID);
		if (ID>-1){
			neighbors[ID].hops = rcm->hops; 
			neighbors[ID].cycle = rcm->cycle;
			neighbors[ID].sink_id = rcm->SinkID;
			neighbors[ID].coord = rcm->coord;
			neighbors[ID].energy = rcm->energy;
		}
	}
	//stop Sync-Manager
	return bufPtrS;			   
  }
    
  event message_t* MCoord_R.receive(message_t* bufPtrC, //Receive MCoord message, the node force to be coordinator, complete the neighbour list
				   void* payload, uint8_t len) {
	MCoord_t* rcm = (MCoord_t*)payload;
	//start Coordinator_Indication_Manager,  if a node receive MCoord, it will force to be a coordinator
	ID = Index_finder(rcm->Node_ID);
	if (ID>-1){
		neighbors[ID].hops = rcm->hops; 
		neighbors[ID].cycle = rcm->cycle;
		neighbors[ID].sink_id = rcm->SinkID;
		neighbors[ID].coord = rcm->coord;
		neighbors[ID].energy = rcm->energy;
	}
	appparam_MDTC = rcm->appparam_MDTC;
	appparam_MDTE = rcm->appparam_MDTE;
	appparam_a = rcm->appparam_a;
	appparam_b = rcm->appparam_b;
	appparam_c = rcm->appparam_c;
	appparam_d = rcm->appparam_d;
	appparam_SPpMTI_1 = rcm->appparam_SPpMTI_1;
	appparam_SPpMTI_2 = rcm->appparam_SPpMTI_2;
	appparam_SPpMTI_3 = rcm->appparam_SPpMTI_3;
	appparam_SPpMTI_4 = rcm->appparam_SPpMTI_4;
	appparam_mSPpMTI = rcm->appparam_mSPpMTI;
	Valid_Time = rcm->Valid_Time; //valid cycle time
	coord = TRUE;
	count_coord++;last_cycle_coord = 1;
	call Leds.led1On();
	cont_sync_task = FALSE;
	post msync_broad_task();
	//stop Coordinator_Indication_Manager
	return bufPtrC;
  }			   
	
  task void avrora_broad_task(){ //Task of broad-casting MSync message with updated fields from this node
	if (!locked) {
	  Avrora_t* rcm = (Avrora_t*)call Avrora_P.getPayload(&packet, sizeof(Avrora_t));
	  //rcm->Node_ID = TOS_NODE_ID;
	  count_neighbors();
	  rcm->Node_ID = Neighbors_n;
	  rcm->Parent_ID = parent_add;
	  rcm->cycle = SinkCycle[SinkID].scycle;
	  if (coord == TRUE){rcm->coord = 1;}else if(coord == FALSE){rcm->coord = 0;};
	  if (call Avrora_S.send(AM_BROADCAST_ADDR, &packet, sizeof(Avrora_t)) == SUCCESS) {
		locked = TRUE;
	  }
	}
	else{post avrora_broad_task();}
  }
    
  task void mcoord_uni_task(){ //Task of uni-casting MCoord message with updated fields from this node to the parent which is not coordinator
	if (!locked) {
	  MCoord_t* rcm = (MCoord_t*)call MCoord_P.getPayload(&packet, sizeof(MCoord_t));
	  rcm->Node_ID = TOS_NODE_ID;
	  rcm->cycle = SinkCycle[SinkID].scycle;
	  rcm->hops = parent_hops + 1;
	  if (coord == TRUE){rcm->coord = 1;}else if(coord == FALSE){rcm->coord = 0;};
	  rcm->energy = 0xFFFF - counter_send;//currEnergy;//get energy;
	  rcm->appparam_MDTC = appparam_MDTC;
	  rcm->appparam_MDTE = appparam_MDTE;
	  rcm->appparam_a = appparam_a;
	  rcm->appparam_b = appparam_b;
	  rcm->appparam_c = appparam_c;
	  rcm->appparam_d = appparam_d;
	  rcm->SinkID = SinkID;
	  rcm->appparam_SPpMTI_1 = appparam_SPpMTI_1;
	  rcm->appparam_SPpMTI_2 = appparam_SPpMTI_2;
	  rcm->appparam_SPpMTI_3 = appparam_SPpMTI_3;
	  rcm->appparam_SPpMTI_4 = appparam_SPpMTI_4;
	  rcm->appparam_mSPpMTI = appparam_mSPpMTI;
	  rcm->Parent_ID = parent_add;
	  rcm->Valid_Time = Valid_Time; //valid cycle time
	  if(call PacketAcknowledgements.requestAck(&packet)==SUCCESS){
		  if (call MCoord_S.send(parent_add, &packet, sizeof(MCoord_t)) == SUCCESS) {
			trycoord = trycoord+1;
			locked = TRUE;
			counter_send++;
		  }
	  }
	}
	else{post mcoord_uni_task();}
  }
 
  void Backbone_Fulfil_Manager(){ //Backbone Fulfil Manager
	if (parent_coord == 0){	
		//Send MCoord message to parent with residual info to force parent to be coordinator
		post mcoord_uni_task();
		//update neighbour list
		parent_coord = TRUE;
		for (i=0;i<NeighborsLen;i++){
			if (neighbors[i].node_id == parent_add) {
				neighbors[i].coord = TRUE;
			}
		}
	}			
	post avrora_broad_task();
  }
  
  event void Boot.booted() { //Node start to boot
	call AMControl.start();
  }

  event void AMControl.startDone(error_t err) { //Node start to work. Based on given ID, node choose the area number and startPeriodic(AppCycleTime)
	if (err == SUCCESS) { 
	  call Battery.read(); //for first cycle reading battery
	  //When node starts, based on ID, choose the area
	  if (TOS_NODE_ID > (node_area1_start-1) && TOS_NODE_ID < (node_area1_end+1)){node_area = 0x0001;}
	  if (TOS_NODE_ID > (node_area2_start-1) && TOS_NODE_ID < (node_area2_end+1)){node_area = 0x0002;}
	  if (TOS_NODE_ID > (node_area3_start-1) && TOS_NODE_ID < (node_area3_end+1)){node_area = 0x0003;}
	  if (TOS_NODE_ID > (node_area4_start-1) && TOS_NODE_ID < (node_area4_end+1)){node_area = 0x0004;}
	  //define the array of SinkCycle
	  for (i=0;i<SinknodesLen;i++){
		SinkCycle[i].scycle = 0;
		SinkCycle[i].valid_time = 0;
      }
	  //define the array of neighbors
	  for (i=0;i<NeighborsLen;i++){
		neighbors[i].node_id = 0;
		neighbors[i].hops = 0;
		neighbors[i].sink_id = 0;
		neighbors[i].energy = 0;
		neighbors[i].coord = 0;
		neighbors[i].cycle = 0;
      }
	  call MilliTimerApp.startPeriodic(AppCycleTime);
	}
	else {
	  call AMControl.start();
	}
  }

  event void AMControl.stopDone(error_t err) { //Node doesn't start to work
  }

  task void forwardMDataToParentTask(){ //Task of Forwarding Data packets to parent
	if (!(app_data10 == 0)){
		if ((!locked)&&(parent_add > -1)) {
		  MData5_t* rcm = (MData5_t*)call MDataF_P.getPayload(&packet, sizeof(MData5_t));
		  rcm->flags = flags;
		  rcm->source_add = source_add;
		  rcm->destination_add = destination_add;
		  rcm->app_data1 = app_data1; 
		  rcm->app_data2 = app_data2;
		  rcm->app_data3 = app_data3;
		  rcm->app_data4 = app_data4;
		  rcm->app_data5 = app_data5;
		  rcm->app_data6 = app_data6;
		  rcm->app_data7 = app_data7;
		  rcm->app_data8 = app_data8;
		  rcm->app_data9 = app_data9;
		  rcm->app_data10 = app_data10;
		  rcm->app_data11 = app_data11;
		  
		  if(call PacketAcknowledgements.requestAck(&packet)==SUCCESS){
			  if (call MDataF_S.send(parent_add, &packet, sizeof(MData5_t)) == SUCCESS) {
				trydataF = trydataF+1;
				locked = TRUE;
				counter_send++;
				call Leds.led2Toggle();
			  }
		  }
		}
		else{post forwardMDataToParentTask();}
	}
	else if (!(app_data8 == 0)){
		if ((!locked)&&(parent_add > -1)) {		
		  MData4_t* rcm = (MData4_t*)call MDataF_P.getPayload(&packet, sizeof(MData4_t));
		  rcm->flags = flags;
		  rcm->source_add = source_add;
		  rcm->destination_add = destination_add;
		  rcm->app_data1 = app_data1; 
		  rcm->app_data2 = app_data2;
		  rcm->app_data3 = app_data3;
		  rcm->app_data4 = app_data4;
		  rcm->app_data5 = app_data5;
		  rcm->app_data6 = app_data6;
		  rcm->app_data7 = app_data7;
		  rcm->app_data8 = app_data8;
		  rcm->app_data9 = app_data9;
		  
		  if(call PacketAcknowledgements.requestAck(&packet)==SUCCESS){
			  if (call MDataF_S.send(parent_add, &packet, sizeof(MData4_t)) == SUCCESS) {
				trydataF = trydataF+1;
				locked = TRUE;
				counter_send++;
				call Leds.led2Toggle();
			  }
		  }
		}
		else{post forwardMDataToParentTask();}
	}
	else if (!(app_data6 == 0)){
		if ((!locked)&&(parent_add > -1)) {		
		  MData3_t* rcm = (MData3_t*)call MDataF_P.getPayload(&packet, sizeof(MData3_t));
		  rcm->flags = flags;
		  rcm->source_add = source_add;
		  rcm->destination_add = destination_add;
		  rcm->app_data1 = app_data1; 
		  rcm->app_data2 = app_data2;
		  rcm->app_data3 = app_data3;
		  rcm->app_data4 = app_data4;
		  rcm->app_data5 = app_data5;
		  rcm->app_data6 = app_data6;
		  rcm->app_data7 = app_data7;
		  
		  if(call PacketAcknowledgements.requestAck(&packet)==SUCCESS){
			  if (call MDataF_S.send(parent_add, &packet, sizeof(MData3_t)) == SUCCESS) {
				trydataF = trydataF+1;
				locked = TRUE;
				counter_send++;
				call Leds.led2Toggle();
			  }
		  }
		}
		else{post forwardMDataToParentTask();}
	}
	else if (!(app_data4 == 0)){
		if ((!locked)&&(parent_add > -1)) {		
		  MData2_t* rcm = (MData2_t*)call MDataF_P.getPayload(&packet, sizeof(MData2_t));
		  rcm->flags = flags;
		  rcm->source_add = source_add;
		  rcm->destination_add = destination_add;
		  rcm->app_data1 = app_data1; 
		  rcm->app_data2 = app_data2;
		  rcm->app_data3 = app_data3;
		  rcm->app_data4 = app_data4;
		  rcm->app_data5 = app_data5;
		  
		  if(call PacketAcknowledgements.requestAck(&packet)==SUCCESS){
			  if (call MDataF_S.send(parent_add, &packet, sizeof(MData2_t)) == SUCCESS) {
				trydataF = trydataF+1;
				locked = TRUE;
				counter_send++;
				call Leds.led2Toggle();
			  }
		  }
		}
		else{post forwardMDataToParentTask();}
	}
	else if (!(app_data2 == 0)){
		if ((!locked)&&(parent_add > -1)) {		
		  MData1_t* rcm = (MData1_t*)call MDataF_P.getPayload(&packet, sizeof(MData1_t));
		  rcm->flags = flags;
		  rcm->source_add = source_add;
		  rcm->destination_add = destination_add;
		  rcm->app_data1 = app_data1; 
		  rcm->app_data2 = app_data2;
		  rcm->app_data3 = app_data3;
		  
		  if(call PacketAcknowledgements.requestAck(&packet)==SUCCESS){
			  if (call MDataF_S.send(parent_add, &packet, sizeof(MData1_t)) == SUCCESS) {
				trydataF = trydataF+1;
				locked = TRUE;
				counter_send++;
				call Leds.led2Toggle();
			  }
		  }
		}
		else{post forwardMDataToParentTask();}
	}
	else if (!(source_add == 0)){
		if ((!locked)&&(parent_add > -1)) {		
		  MData0_t* rcm = (MData0_t*)call MDataF_P.getPayload(&packet, sizeof(MData0_t));
		  rcm->flags = flags;
		  rcm->source_add = source_add;
		  rcm->destination_add = destination_add;
		  rcm->app_data1 = app_data1; 
		  
		  if(call PacketAcknowledgements.requestAck(&packet)==SUCCESS){
			  if (call MDataF_S.send(parent_add, &packet, sizeof(MData0_t)) == SUCCESS) {
				trydataF = trydataF+1;
				locked = TRUE;
				counter_send++;
				call Leds.led2Toggle();
			  }
		  }
		}
		else{post forwardMDataToParentTask();}
	}
  }
	
  event message_t* MDataF_R.receive(message_t* bufPtrFD, //Receive MData message from childes, performing packet aggregation and call the task of forwarding to parent
				   void* payload, uint8_t len) {
    app_data1 = 0; app_data2 = 0;app_data3 = 0;app_data4 = 0;app_data5 = 0;app_data6 = 0;app_data7 = 0;app_data8 = 0;app_data9 = 0;app_data10 = 0;app_data11 = 0;
	if (len == sizeof(MData5_t)){
		MData5_t* rcm = (MData5_t*)payload;
		flags = rcm->flags;
		source_add = rcm->source_add;
		destination_add = rcm->destination_add;
		app_data1 = rcm->app_data1;
		app_data2 = rcm->app_data2;
		app_data3 = rcm->app_data3;
		app_data4 = rcm->app_data4;
		app_data5 = rcm->app_data5;
		app_data6 = rcm->app_data6;
		app_data7 = rcm->app_data7;
		app_data8 = rcm->app_data8;
		app_data9 = rcm->app_data9;
		app_data10 = rcm->app_data10;
		app_data11 = rcm->app_data11;	
	}
	else if (len == sizeof(MData4_t)){
		MData4_t* rcm = (MData4_t*)payload;
		flags = rcm->flags;
		source_add = rcm->source_add;
		destination_add = rcm->destination_add;
		app_data1 = rcm->app_data1;
		app_data2 = rcm->app_data2;
		app_data3 = rcm->app_data3;
		app_data4 = rcm->app_data4;
		app_data5 = rcm->app_data5;
		app_data6 = rcm->app_data6;
		app_data7 = rcm->app_data7;
		app_data8 = rcm->app_data8;
		app_data9 = rcm->app_data9;	
	}
	else if (len == sizeof(MData3_t)){
		MData3_t* rcm = (MData3_t*)payload;
		flags = rcm->flags;
		source_add = rcm->source_add;
		destination_add = rcm->destination_add;
		app_data1 = rcm->app_data1;
		app_data2 = rcm->app_data2;
		app_data3 = rcm->app_data3;
		app_data4 = rcm->app_data4;
		app_data5 = rcm->app_data5;
		app_data6 = rcm->app_data6;
		app_data7 = rcm->app_data7;
	}	
	else if (len == sizeof(MData2_t)){
		MData2_t* rcm = (MData2_t*)payload;
		flags = rcm->flags;
		source_add = rcm->source_add;
		destination_add = rcm->destination_add;
		app_data1 = rcm->app_data1;
		app_data2 = rcm->app_data2;
		app_data3 = rcm->app_data3;
		app_data4 = rcm->app_data4;
		app_data5 = rcm->app_data5;
	}		
	else if (len == sizeof(MData1_t)){
		MData1_t* rcm = (MData1_t*)payload;
		flags = rcm->flags;
		source_add = rcm->source_add;
		destination_add = rcm->destination_add;
		app_data1 = rcm->app_data1;
		app_data2 = rcm->app_data2;
		app_data3 = rcm->app_data3;
	}	
	else if (len == sizeof(MData0_t)){
		MData0_t* rcm = (MData0_t*)payload;
		flags = rcm->flags;
		source_add = rcm->source_add;
		destination_add = rcm->destination_add;
		app_data1 = rcm->app_data1;
	}		
	call Leds.led2Toggle();
	if ((flags & B01_16) == 0){ //Aggregation bit is 0, means the packet is not able to aggregate and should just forward
		//forward to parent
		post forwardMDataToParentTask();
	} 
	else if (!((app_data11 == 0)&&(app_data10 == 0))){ //Means the packet is full and not able to aggregate and should just forward
		flags = flags ^ B01_16; //Set the aggregation bit to 0
		//forward to parent		
		post forwardMDataToParentTask();
	} 
	else if ((flags & B02_16) == 0){ //Data type bit is 0, means continuous data type
		//start the timer of MDTC		
		call MilliTimerBuf.startOneShot(appparam_MDTC);
		if (flags_buff == 0) {flags_buff = flags;}
		if (buff_data1 == 0) { buff_source_add = source_add; buff_data1= app_data1;}
		else if (buff_data2 == 0) { buff_data2 = source_add; buff_data3 = app_data1;}
		else if (buff_data4 == 0) { buff_data4 = source_add; buff_data5 = app_data1;}
		else if (buff_data6 == 0) { buff_data6 = source_add; buff_data7 = app_data1;}
		else if (buff_data8 == 0) { buff_data8 = source_add; buff_data9 = app_data1;}
		else if (buff_data10 == 0) { buff_data10 = source_add; buff_data11 = app_data1;}
		else {flags = flags_buff ^ B01_16;source_add = buff_source_add; app_data1 = buff_data1;app_data2 = buff_data2;app_data3 = buff_data3;app_data4 = buff_data4;
			app_data5 = buff_data5;app_data6 = buff_data6;app_data7 = buff_data7;app_data8 = buff_data8;app_data9 = buff_data9;app_data10 = buff_data10;
			 app_data11 = buff_data11; buff_data1 = 0;  buff_data2 = 0;  buff_data3 = 0;  buff_data4 = 0;
			 buff_data5 = 0;  buff_data6 = 0;  buff_data7 = 0;  buff_data8 = 0;  buff_data9 = 0;  buff_data10 = 0;
			 buff_data11 = 0; flags_buff = 0; post forwardMDataToParentTask(); call MilliTimerBuf.stop();
			 }
	} 
	else if ((flags & B02_16) == 1){ //Data type bit is 1, means event data type
		//start the timer of MDTE		
		call MilliTimerBufE.startOneShot(appparam_MDTE);
		if (flags_buffE == 0) {flags_buffE = flags;}
		if (buffE_data1 == 0) { buffE_source_add = source_add; buffE_data1= app_data1;}
		else if (buffE_data2 == 0) { buffE_data2 = source_add; buffE_data3 = app_data1;}
		else if (buffE_data4 == 0) { buffE_data4 = source_add; buffE_data5 = app_data1;}
		else if (buffE_data6 == 0) { buffE_data6 = source_add; buffE_data7 = app_data1;}
		else if (buffE_data8 == 0) { buffE_data8 = source_add; buffE_data9 = app_data1;}
		else if (buffE_data10 == 0) { buffE_data10 = source_add; buffE_data11 = app_data1;}
		else {flags = flags_buffE ^ B01_16;source_add = buffE_source_add; app_data1 = buffE_data1;app_data2 = buffE_data2;app_data3 = buffE_data3;app_data4 = buffE_data4;
			app_data5 = buffE_data5;app_data6 = buffE_data6;app_data7 = buffE_data7;app_data8 = buffE_data8;app_data9 = buffE_data9;app_data10 = buffE_data10;
			 app_data11 = buffE_data11; buff_data1 = 0;  buffE_data2 = 0;  buffE_data3 = 0;  buffE_data4 = 0;
			 buffE_data5 = 0;  buffE_data6 = 0;  buffE_data7 = 0;  buffE_data8 = 0;  buffE_data9 = 0;  buffE_data10 = 0;
			 buffE_data11 = 0; flags_buffE = 0; post forwardMDataToParentTask(); call MilliTimerBufE.stop();
			 }
	}
	return bufPtrFD;
  }
  
  task void sendMDataTask(){ //Task of sending random value as monitored data
	if ((!locked)&&(parent_add > -1)) {
	  MData0_t* rcm = (MData0_t*)call MData_P.getPayload(&packet, sizeof(MData0_t));
	  flags = 0x8000;
	  rcm->flags = flags;
	  rcm->source_add = TOS_NODE_ID;
	  rcm->destination_add = parent_add;
	  rcm->app_data1 = rndDATA; // random sensed data 
	  if(call PacketAcknowledgements.requestAck(&packet)==SUCCESS){
		  if (call MData_S.send(parent_add, &packet, sizeof(MData0_t)) == SUCCESS) {
			trydata = trydata+1;
			locked = TRUE;
			counter_send++;
			call Leds.led2Toggle();
		  }
	  }
    }
	else{post sendMDataTask();}
  }
  
  event void MSync_S.sendDone(message_t* bufPtrS, error_t error) { //MSync broad-casting done
    if (&packet == bufPtrS) {
		locked = FALSE;
		call Leds.led0Toggle();
		if (cont_sync_task == TRUE){ //This part will happen for case of Msync message sendDone(after new cycle), it call random backoff time to receive neighbours packets
			cont_sync_task = FALSE;
			//wait random backoff time
			randBackoffPeriod = (float)(call Random.rand16());
			randBackoffPeriod = (randBackoffPeriod/65535.0F);
			randBackoffPeriod = randBackoffPeriod * MAX_RANDOM_THRESHOLD;
			if (randBackoffPeriod < ((float)(MIN_RANDOM_THRESHOLD))){randBackoffPeriod = randBackoffPeriod +((float)(MIN_RANDOM_THRESHOLD));}	
			call MilliTimer.startOneShot((uint16_t)(randBackoffPeriod)); //start random backoff time
		}
	}
  }
  
  event void Avrora_S.sendDone(message_t* bufPtrA, error_t error) { //MData sending done
	if (&packet == bufPtrA) {locked = FALSE;}
  }
  
  event void MilliTimerACK.fired(){ //repeat message after 512ms
    if (rep_mode != 0){
		if (rep_mode == 1){post mcoord_uni_task();rep_mode = 0;}
		if (rep_mode == 2){post sendMDataTask();rep_mode = 0;}
		if (rep_mode == 3){post forwardMDataToParentTask();rep_mode = 0;}
	}
  } 
  
  event void MData_S.sendDone(message_t* bufPtrD, error_t error) { //MData sending done
    if ((&packet == bufPtrD)){locked = FALSE;}
	if ((&packet == bufPtrD) && (call PacketAcknowledgements.wasAcked(bufPtrD)==SUCCESS)){
		call Leds.led2Toggle();
		locked = FALSE;
		trydata = 1;
	}else{
		if (trydata < 3){
			trydata = trydata+1;
			rep_mode = 2;
			call MilliTimerACK.startOneShot(512); //repeat message after 512ms
		}
	}
  }
  
  event void MDataF_S.sendDone(message_t* bufPtrFD, error_t error) { //MData sending done
    if ((&packet == bufPtrFD)){locked = FALSE;}//trydata = trydata+1;}
	if ((&packet == bufPtrFD) && (call PacketAcknowledgements.wasAcked(bufPtrFD)==SUCCESS)){
		call Leds.led2Toggle();
		locked = FALSE;
		trydataF = 1;
	}else{
		if (trydataF < 3){
			trydataF = trydataF+1;
			rep_mode = 3;
			call MilliTimerACK.startOneShot(512); //repeat message after 512ms
		}
	}
  }  
  
  event void MCoord_S.sendDone(message_t* bufPtrC, error_t error) { //MCoord sending done
    if ((&packet == bufPtrC)){locked = FALSE;}//trycoord = trycoord+1;}
	if ((&packet == bufPtrC) && (call PacketAcknowledgements.wasAcked(bufPtrC)==SUCCESS)){
		locked = FALSE;
		trycoord = 1;
	}else{
		if (trycoord < 4){
			trycoord = trycoord+1;
			rep_mode = 1;
			call MilliTimerACK.startOneShot(100); //repeat message after 40ms
		}
	}
  }
  
  event void MilliTimerValidTime.fired(){ //it means the selected sink is not valid any more
	//message for debug
	if (!locked) {
	  Avrora_t* rcm = (Avrora_t*)call Avrora_P.getPayload(&packet, sizeof(Avrora_t));
	  rcm->Node_ID = 0xFFFF;
	  rcm->Parent_ID = (uint16_t)(((SinkCycle[SinkID].valid_time)));
	  rcm->cycle = SinkCycle[SinkID].scycle;
	  if (coord == TRUE){rcm->coord = 1;}else if(coord == FALSE){rcm->coord = 0;};

	  if (call Avrora_S.send(AM_BROADCAST_ADDR, &packet, sizeof(Avrora_t)) == SUCCESS) {
		locked = TRUE;
	  }
	}
	for (i=0;i<NeighborsLen;i++){
		if ((neighbors[i].sink_id == SinkID)&&(neighbors[i].cycle > 0)){
			neighbors[i].node_id = 0;
			neighbors[i].hops = 0;
			neighbors[i].sink_id = 0;
			neighbors[i].energy = 0;
			neighbors[i].coord = 0;
			neighbors[i].cycle = 0;
		}
	}
	//change selected sink to another sink from neighbours list if there is
	find = 0;
	for (i=0;i<NeighborsLen;i++){
		if ((neighbors[i].sink_id != SinkID)&&(neighbors[i].cycle > 0)){
			SinkID = neighbors[i].sink_id;
			find = 1;
		}
	}
	//maybe it does not have info from other sink
	if (find == 1){
		Parent_Selector_Manager();
		Election_Manager();
	}else {
		SinkID = -1;
	}
  }
  
  event void MilliTimer.fired(){ //End of random backoff time, again call Parent_Selector_Manager() to select parent within new neighbours and send MCoord if necessary
  	//call timer to delete invalid data from neighbours list, considering an amount of delay time and stagger of dissemination
	if ((SinkCycle[SinkID].valid_time) > 0){call MilliTimerValidTime.stop(); call MilliTimerValidTime.startOneShot((uint32_t)(((SinkCycle[SinkID].valid_time)*61440)+10240+(5120/(parent_hops+2))));}
    Parent_Selector_Manager();
	Backbone_Fulfil_Manager();
  }
  
  event void MilliTimerBuf.fired(){ //If MDTC end, the aggregation stops and the packet forward to parent
	flags = flags_buff ^ B01_16;source_add = buff_source_add; app_data1 = buff_data1;app_data2 = buff_data2;app_data3 = buff_data3;app_data4 = buff_data4;
	app_data5 = buff_data5;app_data6 = buff_data6;app_data7 = buff_data7;app_data8 = buff_data8;app_data9 = buff_data9;app_data10 = buff_data10;
	app_data11 = buff_data11; buff_data1 = 0;  buff_data2 = 0;  buff_data3 = 0;  buff_data4 = 0;
	 buff_data5 = 0;  buff_data6 = 0;  buff_data7 = 0;  buff_data8 = 0;  buff_data9 = 0;  buff_data10 = 0;
	 buff_data11 = 0; flags_buff = 0;
	post forwardMDataToParentTask();
  }
  
  event void MilliTimerBufE.fired(){ //If MDTE end, the aggregation stops and the packet forward to parent
	flags = flags_buffE ^ B01_16;source_add = buffE_source_add; app_data1 = buffE_data1;app_data2 = buffE_data2;app_data3 = buffE_data3;app_data4 = buffE_data4;
	app_data5 = buffE_data5;app_data6 = buffE_data6;app_data7 = buffE_data7;app_data8 = buffE_data8;app_data9 = buffE_data9;app_data10 = buffE_data10;
	app_data11 = buffE_data11; buff_data1 = 0;  buffE_data2 = 0;  buffE_data3 = 0;  buffE_data4 = 0;
	 buffE_data5 = 0;  buffE_data6 = 0;  buffE_data7 = 0;  buffE_data8 = 0;  buffE_data9 = 0;  buffE_data10 = 0;
	 buffE_data11 = 0; flags_buffE = 0;
	post forwardMDataToParentTask();
  }
  
  event void MilliTimerApp.fired(){ //The application timer to call send data (sample application) also in each period the current energy of node updates
	// Updates battery
	call Battery.read();
	
	// Application sends MData
	Appcounter++;
	if (node_area == 0x0001){ //This timer fires every 35 second, area1 will monitor and send data every 35 seconds
		if (Appcounter == 1){ 
			rndDATA = call Random.rand16(); // random sensed data
			post sendMDataTask();
			Appcounter = 0x0000;
		}
	}
	else if (node_area == 0x0002){	//This timer fires every 35 second, area2 will monitor and send data every 70 seconds
		if(Appcounter == 2){ 
			rndDATA = call Random.rand16(); // random sensed data
			post sendMDataTask();
			Appcounter = 0x0000;
		}
	}else if (node_area == 0x0003){
	}else if (node_area == 0x0004){
	}	
  }
  
  event void Battery.readDone(error_t result, uint16_t data){ //For update current energy of node
	if (result == SUCCESS) {	
	  currEnergy = data; 
	}
  }
}