//
//  main.m
//  Marvel
//
//  Copyright 2004-2009 Karelia Software. All rights reserved.
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
#include "Debug.h"

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


int main(int argc, char *argv[])
{
// pull in OmniObjectMeter iff DEBUG and OOM are set in Application Debug.xcconfig
#ifdef DEBUG
	#ifdef OOM
		__OOMInit();
	#endif
#endif
	
    UInt32 modifierKeys = GetCurrentEventKeyModifiers();
    if ((modifierKeys & controlKey) || (modifierKeys & shiftKey))
	{
		NSBeep();
		enableCoreDumps();
	}
	
	LOG((@"required = %d, allowed = %d", MAC_OS_X_VERSION_MIN_REQUIRED, MAC_OS_X_VERSION_MAX_ALLOWED));
	
    return NSApplicationMain(argc, (const char **) argv);
}
