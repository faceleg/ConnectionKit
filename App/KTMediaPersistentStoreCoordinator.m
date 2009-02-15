//
//  KTMediaPersistentStoreCoordinator.m
//  Marvel
//
//  Created by Mike on 13/05/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import "KTMediaPersistentStoreCoordinator.h"


@implementation KTMediaPersistentStoreCoordinator

- (KTMediaManager *)mediaManager { return myMediaManager; }

- (void)setMediaManager:(KTMediaManager *)mediaManager 
{
	myMediaManager = mediaManager;	// weak ref
}

@end
