//
//  IMStatusPlugin.h
//  IMStatusElement
//
//  Created by Dan Wood on 3/3/10.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SandvoxPlugin.h"

typedef enum { IMServiceIChat, IMServiceSkype, IMServiceYahoo = 2, } IMService;




@interface IMStatusPlugin : SVPageletPlugIn {

	NSMutableArray *myConfigs;
	
	NSString *_headlineText;
	NSString *_onlineText;
	NSString *_offlineText;
	NSString *_username;
	int _selectedIMService;


}

@property (copy) NSString *headlineText;
@property (copy) NSString *onlineText;
@property (copy) NSString *offlineText;
@property (copy) NSString *username;
@property (assign) int selectedIMService;


@end


extern NSString *IMServiceKey;
extern NSString *IMHTMLKey; // #USER# will be substituted with the username #ONLINE# and #OFFLINE# will be replaced with the relavant url
extern NSString *IMOnlineImageKey;
extern NSString *IMOfflineImageKey;

