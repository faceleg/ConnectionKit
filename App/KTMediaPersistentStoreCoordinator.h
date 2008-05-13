//
//  KTMediaPersistentStoreCoordinator.h
//  Marvel
//
//  Created by Mike on 13/05/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class KTMediaManager;


@interface KTMediaPersistentStoreCoordinator : NSPersistentStoreCoordinator
{
	@private
	KTMediaManager *myMediaManager;
}

- (KTMediaManager *)mediaManager;
- (void)setMediaManager:(KTMediaManager *)mediaManager;

@end
