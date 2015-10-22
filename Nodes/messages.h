/*
Author: Mohammadreza Iman
Project Name: THESEUS
A master degree thesis project
Federal University of Rio de Janeiro (UFRJ), PPGI, Brazil
mohammadreza.iman@hotmail.com
*/
#ifndef THESEUS_H
#define THESEUS_H

typedef nx_struct MSync {
  nx_uint16_t Node_ID;
  nx_uint8_t hops;
  nx_uint16_t cycle;
  nx_uint8_t coord;
  nx_uint16_t energy;
  nx_uint16_t appparam_MDTC;
  nx_uint16_t appparam_MDTE;
  nx_uint8_t appparam_a;
  nx_uint8_t appparam_b;
  nx_uint8_t appparam_c;
  nx_uint8_t appparam_d;
  nx_uint8_t SinkID;
  nx_uint8_t appparam_SPpMTI_1;
  nx_uint8_t appparam_SPpMTI_2;
  nx_uint8_t appparam_SPpMTI_3;
  nx_uint8_t appparam_SPpMTI_4;
  nx_uint8_t appparam_mSPpMTI;
  nx_uint16_t Parent_ID;
  nx_uint16_t Valid_Time;
} MSync_t;
typedef nx_struct MCoord {
  nx_uint16_t Node_ID;
  nx_uint8_t hops;
  nx_uint16_t cycle;
  nx_uint8_t coord;
  nx_uint16_t energy;
  nx_uint16_t appparam_MDTC;
  nx_uint16_t appparam_MDTE;
  nx_uint8_t appparam_a;
  nx_uint8_t appparam_b;
  nx_uint8_t appparam_c;
  nx_uint8_t appparam_d;
  nx_uint8_t SinkID;
  nx_uint8_t appparam_SPpMTI_1;
  nx_uint8_t appparam_SPpMTI_2;
  nx_uint8_t appparam_SPpMTI_3;
  nx_uint8_t appparam_SPpMTI_4;
  nx_uint8_t appparam_mSPpMTI;
  nx_uint16_t Parent_ID;
  nx_uint16_t Valid_Time;
} MCoord_t;
typedef nx_struct MData0 {
  nx_uint16_t flags;
  nx_uint16_t source_add;
  nx_uint16_t destination_add;
  nx_uint16_t app_data1;
} MData0_t;
typedef nx_struct MData1 {
  nx_uint16_t flags;
  nx_uint16_t source_add;
  nx_uint16_t destination_add;
  nx_uint16_t app_data1;
  nx_uint16_t app_data2;
  nx_uint16_t app_data3;
} MData1_t;
typedef nx_struct MData2 {
  nx_uint16_t flags;
  nx_uint16_t source_add;
  nx_uint16_t destination_add;
  nx_uint16_t app_data1;
  nx_uint16_t app_data2;
  nx_uint16_t app_data3;
  nx_uint16_t app_data4;
  nx_uint16_t app_data5;
} MData2_t;
typedef nx_struct MData3 {
  nx_uint16_t flags;
  nx_uint16_t source_add;
  nx_uint16_t destination_add;
  nx_uint16_t app_data1;
  nx_uint16_t app_data2;
  nx_uint16_t app_data3;
  nx_uint16_t app_data4;
  nx_uint16_t app_data5;
  nx_uint16_t app_data6;
  nx_uint16_t app_data7;
} MData3_t;
typedef nx_struct MData4 {
  nx_uint16_t flags;
  nx_uint16_t source_add;
  nx_uint16_t destination_add;
  nx_uint16_t app_data1;
  nx_uint16_t app_data2;
  nx_uint16_t app_data3;
  nx_uint16_t app_data4;
  nx_uint16_t app_data5;
  nx_uint16_t app_data6;
  nx_uint16_t app_data7;
  nx_uint16_t app_data8;
  nx_uint16_t app_data9;
} MData4_t;
typedef nx_struct MData5 {
  nx_uint16_t flags;
  nx_uint16_t source_add;
  nx_uint16_t destination_add;
  nx_uint16_t app_data1;
  nx_uint16_t app_data2;
  nx_uint16_t app_data3;
  nx_uint16_t app_data4;
  nx_uint16_t app_data5;
  nx_uint16_t app_data6;
  nx_uint16_t app_data7;
  nx_uint16_t app_data8;
  nx_uint16_t app_data9;
  nx_uint16_t app_data10;
  nx_uint16_t app_data11;
} MData5_t;
typedef nx_struct Avrora {
  nx_uint16_t Node_ID;
  nx_uint16_t Parent_ID;
  nx_uint16_t cycle;
  nx_uint8_t coord;
} Avrora_t;
typedef struct {
  uint16_t node_id;
  uint8_t hops;
  uint16_t cycle;
  uint8_t sink_id;
  bool coord;
  uint16_t energy;
} Neighbors_t;
typedef struct {
  uint16_t scycle;
  uint16_t valid_time;
} SinkCycle_t;

enum {
  AM_MSYNC = 1,AM_MCOORD = 2,AM_MDATA = 3,AM_AVRORA = 4,
};

#endif