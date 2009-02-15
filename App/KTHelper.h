//
//  KTHelper.h
//  Marvel
//
//  Created by Mike on 27/12/2007.
//  Copyright 2007-2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface KTHelper : NSObject
{
	id				myWindowController;
}

- (id)initWithWindowController:(id)aWindowController;
- (id)controller;

@end

