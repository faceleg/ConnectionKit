//
//  IMStatusPlugin.h
//  IMStatusElement
//
//  Created by Dan Wood on 3/3/10.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SandvoxPlugin.h"
#import "IMStatusService.h"
#import "ABPerson+IMStatus.h"
#import <AddressBook/AddressBook.h>

typedef enum { IMServiceIChat, IMServiceSkype, IMServiceYahoo = 2, } IMService;

NSString *IMServiceKey = @"service";
NSString *IMHTMLKey = @"html"; 
NSString *IMOnlineImageKey = @"online";
NSString *IMOfflineImageKey = @"offline";
NSString *IMWantBorderKey = @"wantBorder";


@interface IMStatusPlugin ()
- (NSString *)onlineImagePath;
- (NSString *)offlineImagePath;
@end


@interface IMStatusPlugin : SVElementPlugIn {

	NSMutableArray *myConfigs;

}

@end


extern NSString *IMServiceKey;
extern NSString *IMHTMLKey; // #USER# will be substituted with the username #ONLINE# and #OFFLINE# will be replaced with the relavant url
extern NSString *IMOnlineImageKey;
extern NSString *IMOfflineImageKey;

