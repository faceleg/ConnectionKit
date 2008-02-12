//
//  main.m
//  Marvel
//
//  Copyright (c) 2004-2005 Biophony LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Foundation/NSDebug.h>
#import <Carbon/Carbon.h>
#include <stdlib.h>
#import <sys/types.h>
#import <sys/time.h>
#import <sys/resource.h>
#include <stdio.h>
#include <errno.h>

#ifdef DEBUG
	#ifdef OOM
		#import <OmniObjectMeterFramework/OOMPublic.h>
	#endif
#endif



// courtesy of http://www.macedition.com/bolts/bolts_20030210.php
void enableCoreDumps ()
{
	struct rlimit rl;
	
	rl.rlim_cur = RLIM_INFINITY;
	rl.rlim_max = RLIM_INFINITY;
	
	if (setrlimit (RLIMIT_CORE, &rl) == -1) {
		fprintf (stderr, 
				 "error in setrlimit for RLIMIT_CORE: %d (%s)\n",
				 errno, strerror(errno));
	}
	else
	{
		fprintf (stderr, 
				 "Core file will be saved on abort.  Paste \"kill -ABRT %d\" (without the quotes) to into the Terminal to halt and create core dump.\n",
				 [[NSProcessInfo processInfo] processIdentifier]);
	}
	
} // enableCoreDumps


// courtesy http://www.cocoabuilder.com/archive/message/cocoa/2001/7/13/20754
#define KeyShift	0x38
#define KeyControl	0x3b
#define KeyOption	0x3A
#define KeyCommand	0x37
#define KeyCapsLock	0x39
#define KeySpace	0x31
#define KeyTabs		0x30

int IsKeyPressed(unsigned short key)
{
	unsigned char km[16];
	GetKeys((void *)km);
	return ((km[key>>3] >> (key & 7)) & 1) ? 1 : 0;
}

int main(int argc, char *argv[])
{
// pull in OmniObjectMeter iff DEBUG and OOM are set in Application Debug.xcconfig
#ifdef DEBUG
	#ifdef OOM
		__OOMInit();
	#endif
#endif
	
	if ( IsKeyPressed(KeyControl) || IsKeyPressed(KeyOption) ) /// be flexible; option easier to hit with double-click
	{
		NSBeep();
		enableCoreDumps();
	}
	
	
    return NSApplicationMain(argc, (const char **) argv);
}
