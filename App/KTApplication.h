//
//  KTApplication.h
//  Marvel
//
//  Created by Terrence Talbot on 10/2/04.
//  Copyright 2004-2011 Karelia Software. All rights reserved.
//

//  Supplements -sendEvent: to broadcast modifier key changes to any interested party


#import <Cocoa/Cocoa.h>
#import "KSApplication.h"


extern NSString *KTApplicationDidSendFlagsChangedEvent; // used by Web Editor to track change when it's not first responder


@interface KTApplication : KSApplication


@end