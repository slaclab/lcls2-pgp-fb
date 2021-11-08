#include <sys/types.h>
#include <unistd.h>
#include <stdio.h>
#include <termios.h>
#include <sstream>
#include <iomanip>
#include <iostream>
#include <string.h>
#include <stdlib.h>
#include <time.h>
#include <stdint.h>
#include <new>

#include "DmaDriver.h"

void printUsage(char* name) {
    printf( "Usage: %s [-h]  [options]\n"
            "    -h          Show usage\n"
            "    -d          Set device name\n"
            "    -L <lanes>  Mask of lanes\n"
            "    -N <events> number of times to send\n"
            "    -o          Print out up to maxPrint words when reading data\n"
            "    -r          Report rate\n",
            "    -R <usec>   Read delay\n",
            "    -W <usec>   Write delay\n",
            name
            );
}

void* countThread(void*);
void* readThread (void*);
void* writeThread(void*);

static int      count = 0;
static int64_t  bytes = 0;
static unsigned lanes = 0;
static unsigned buffs = 0;
static unsigned errs  = 0;
static unsigned polls = 0;
static int fd = -1;
static unsigned maxPrint = 1024;
static bool          print = false;
static unsigned      numb = 10;
static unsigned            nevents             = unsigned(-1);
static unsigned readDelay = 0;
static unsigned writeDelay = 0;

int main (int argc, char **argv) {
  const char*         dev = "/dev/datadev_0";
  bool                reportRate          = false;
  unsigned            lanem               = 0;

  //  char*               endptr;
  extern char*        optarg;
  int c;
  while( ( c = getopt( argc, argv, "hd:L:N:c:o:rR:W:" ) ) != EOF ) {
    switch(c) {
    case 'd':
      dev = optarg;
      break;
    case 'L':
      lanem = strtoul(optarg,NULL,0);
      break;
    case 'N':
      nevents = strtoul(optarg,NULL, 0);
      break;
    case 'c':
      numb = strtoul(optarg, NULL, 0);
      break;
    case 'o':
      maxPrint = strtoul(optarg, NULL, 0);
      print = true;
      break;
    case 'r':
      reportRate = true;
      break;
    case 'R':
      readDelay = strtoul(optarg, NULL, 0);
      break;
    case 'W':
      writeDelay = strtoul(optarg, NULL, 0);
      break;
    case 'h':
      printUsage(argv[0]);
      return 0;
      break;
    default:
      printf("Error: Option could not be parsed, or is not supported yet!\n");
      printUsage(argv[0]);
      return 0;
      break;
    }
  }

  if ( (fd = open(dev, O_RDWR)) <= 0 ) {
    std::cout << "Error opening " << dev << std::endl;
    return(1);
  }

  uint8_t mask[DMA_MASK_SIZE];
  dmaInitMaskBytes(mask);
  for(unsigned i=0; i<8; i++)
      if ((1<<i) & lanem)
          dmaAddMaskBytes (mask, (i<<8)|1);
  dmaSetMaskBytes(fd,mask);

#define NEW_THREAD(name,args) {                                 \
      pthread_attr_t tattr;                                     \
      pthread_attr_init(&tattr);                                \
      pthread_t thr;                                            \
      if (pthread_create(&thr, &tattr, &name, args))            \
          perror("Error creating thread");                      \
  }

  //  Reporting thread
  if (reportRate) 
      NEW_THREAD(countThread,0);

  NEW_THREAD(readThread ,0);
  NEW_THREAD(writeThread,0);

  while(1)
      usleep(1000000);

  return 0;
}

void* writeThread(void* args)
{
    const size_t maxSize = 0x800;
    uint32_t* data[8];
    for(unsigned j=0; j<8; j++) {
        data[j] = new uint32_t[maxSize];
        for(unsigned i=0; i<maxSize; i++)
            data[j][i] = (i&0xffff) | (j<<24);
    }

    uint32_t flags,dest;
    flags = 0;

    while(1) {
        for(unsigned i=1; i<8; i++) {
            dest = (i<<8) | 1;
            dmaWrite(fd, data[i], maxSize, flags, dest);
        }
        usleep(writeDelay);
    }
    return 0;
}

void* readThread(void* args)
{
    const size_t maxSize = 0x80000;
    uint32_t* data  = new uint32_t[maxSize];
    uint32_t flags,error,dest;

    // DMA Read
    while(1) {
        bool lerr = false;
        
        ssize_t ret = dmaRead(fd, data, maxSize, &flags, &error, &dest);
        if (ret < 0) {
            perror("Reading buffer");
            break;
        }

        polls++;

        if (ret==0) {
            continue;
        }

        unsigned lane   = (dest>>8)&7;
        unsigned vc     = dest&0xff;

        if (print) {
            printf("Lane[%u]:vc[%u]:size[%zu]\n",lane,vc,ret);
            unsigned maxW = (ret < maxPrint) ? ret/4 : maxPrint/4;
            for (unsigned x=0; x<maxW; x++) {
                printf("%08x%c", data[x], (x%8)==7 ? '\n':' ');
            }
            if (maxW%8)
                printf("\n");
            
            if (count >= numb)
                print = false;
        }

        bytes += ret;
        count++;

        usleep(readDelay);
    }
    return 0;
}

void* countThread(void* args)
{
  timespec tv;
  clock_gettime(CLOCK_REALTIME,&tv);
  unsigned opolls = polls;
  unsigned ocount = count;
  int64_t  obytes = bytes;
  while(1) {
    usleep(1000000);
    timespec otv = tv;
    clock_gettime(CLOCK_REALTIME,&tv);
    unsigned npolls = polls;
    unsigned ncount = count;
    int64_t  nbytes = bytes;

    double dt     = double( tv.tv_sec - otv.tv_sec) + 1.e-9*(double(tv.tv_nsec)-double(otv.tv_nsec));
    double prate  = double(npolls-opolls)/dt;
    double rate   = double(ncount-ocount)/dt;
    double dbytes = double(nbytes-obytes)/dt;
    unsigned dbsc = 0, rsc=0, prsc=0;

    if (count < 0) break;

    static const char scchar[] = { ' ', 'k', 'M' };

    if (prate > 1.e6) {
      prsc     = 2;
      prate   *= 1.e-6;
    }
    else if (prate > 1.e3) {
      prsc     = 1;
      prate   *= 1.e-3;
    }

    if (rate > 1.e6) {
      rsc     = 2;
      rate   *= 1.e-6;
    }
    else if (rate > 1.e3) {
      rsc     = 1;
      rate   *= 1.e-3;
    }

    if (dbytes > 1.e6) {
      dbsc    = 2;
      dbytes *= 1.e-6;
    }
    else if (dbytes > 1.e3) {
      dbsc    = 1;
      dbytes *= 1.e-3;
    }

    printf("Rate %7.2f %cHz [%u]:  Size %7.2f %cBps [%lld B]  lanes %02x  buffs %04x  errs %04x : polls %7.2f %cHz\n",
           rate  , scchar[rsc ], ncount,
           dbytes, scchar[dbsc], (long long)nbytes, lanes, buffs, errs,
           prate , scchar[prsc]);
    lanes = 0;
    buffs = 0;

    opolls = npolls;
    ocount = ncount;
    obytes = nbytes;
  }
  return 0;
}
