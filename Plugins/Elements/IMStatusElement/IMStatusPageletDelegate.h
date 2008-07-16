//
//  IMStatusPageletDelegate.h
//  IMStatusPagelet
//
//  Created by Greg Hulands on 31/08/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SandvoxPlugin.h"


typedef enum { IMServiceIChat, IMServiceSkype, IMServiceYahoo = 2, } IMService;


@interface IMStatusPageletDelegate : KTAbstractPluginDelegate 
{
	NSMutableArray *myConfigs;
}

@end

extern NSString *IMServiceKey;
extern NSString *IMHTMLKey; // #USER# will be substituted with the username #ONLINE# and #OFFLINE# will be replaced with the relavant url
extern NSString *IMOnlineImageKey;
extern NSString *IMOfflineImageKey;