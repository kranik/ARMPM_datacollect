/*
 * Copyright (c) 2013 Tobias Muehlbauer. All rights reserved.
 *  
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"), 
 * to deal in the Software without restriction, including without limitation 
 * the rights to use, copy, modify, merge, publish, distribute, sublicense, 
 * and/or sell copies of the Software, and to permit persons to whom the 
 * Software is furnished to do so, subject to the following conditions:
 *  
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *  
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING 
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER 
 * DEALINGS IN THE SOFTWARE.
 * 
 */
#include <iostream>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <fstream>
#include <time.h>
#include "hidapi.h"

using namespace std;

#define MAX_STR 65

#define REQUEST_DATA        0x37
#define REQUEST_STARTSTOP   0x80
#define REQUEST_STATUS      0x81
#define REQUEST_ONOFF       0x82
#define REQUEST_VERSION     0x83

int main(int argc, char *argv[])
{
  hid_device* device;
  unsigned char buf[MAX_STR];
  buf[0]=0x00;
  memset((void*)&buf[2],0x00,sizeof(buf)-2);

  device=hid_open(0x04d8,0x003f,NULL);
  if (device) {
    hid_set_nonblocking(device,true);
  } else {
    cerr << "no device" << endl;
    exit(-1);
  }

  buf[1] = REQUEST_STATUS;
      if (hid_write(device,buf,sizeof(buf))==-1) {
      cerr << "error" << endl;
      exit(-1);
    }
    if (hid_read(device,buf,sizeof(buf))==-1) {
      cerr << "error" << endl;
      exit(-1);
    }
  bool started = (buf[1] == 0x01);
  if (!started) {
     buf[1] = REQUEST_STARTSTOP;
     if (hid_write(device,buf,sizeof(buf))==-1) {
        cerr << "error" << endl;
        exit(-1);
     }
  }

  buf[1] = REQUEST_STARTSTOP;
  if (hid_write(device,buf,sizeof(buf))==-1) {
     cerr << "error" << endl;
     exit(-1);
  }
  cout << "#Timestamp\tSystem Power(W)" << endl;
  buf[1] = REQUEST_DATA;
  bool first=true;
  string cmd="echo $(date +'%s%N')'\t'";
  struct timespec sleep;
  sleep.tv_sec = 0;
  sleep.tv_nsec = 85000000;
  int len=cmd.size();
  while (true) {
    if (hid_write(device,buf,sizeof(buf))==-1) {
      cerr << "error" << endl;
      exit(-1);
    }
    if (hid_read(device,buf,sizeof(buf))==-1) {
      cerr << "error" << endl;
      exit(-1);
    }

    if(buf[0]==REQUEST_DATA) {
      if (!first) {    
         char watt[7]={'\0'};
         strncpy(watt,(char*)&buf[18],5);
         //Set output to be unbuffered to make sure all printing is done consecutively
         std::cout.setf(std::ios::unitbuf);
         //need to build the command with the now read watt value, system only accepts const char* so need to convert string
         //This makes sure that the time value pronted usign date is as close to the measurement to watt as possible, having a preallocated command string to just append the watt value os the fastest way to generate the command to pass to system
         cmd.append(watt);
         system(cmd.c_str());
         //then remove the watt values to reset the boilerplate echo command, length of original string is already stored
         cmd.erase(len,strlen(watt));
      } else {
         first=false;
      }
    
   }
   nanosleep(&sleep,NULL);
 }

  buf[1] = REQUEST_STARTSTOP;
  if (hid_write(device,buf,sizeof(buf))==-1) {
     cerr << "error" << endl;
     exit(-1);
  }
  hid_close(device);
}
