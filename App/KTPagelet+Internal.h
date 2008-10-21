//
//  KTPagelet+Internal.h
//  Marvel
//
//  Created by Mike on 20/10/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//


#import "KTPagelet.h"

#import "KTWebViewComponentProtocol.h"


@interface KTPagelet (Internal) <KTWebViewComponent>

#pragma mark Initialization

// general constructor
+ (KTPagelet *)pageletWithPage:(KTPage *)aPage plugin:(KTElementPlugin *)plugin;

+ (KTPagelet *)insertNewPageletWithPage:(KTPage *)page
                       pluginIdentifier:(NSString *)pluginIdentifier
                               location:(KTPageletLocation)location;

// drag-and-drop constructor
+ (KTPagelet *)pageletWithPage:(KTPage *)aPage dataSourceDictionary:(NSDictionary *)aDictionary;


#pragma mark Support

- (NSString *)shortDescription;
- (BOOL)canHaveTitle;

@end
