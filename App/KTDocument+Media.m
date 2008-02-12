//
//  KTDocument+Media.m
//  Marvel
//
//  Created by Terrence Talbot on 11/16/06.
//  Copyright 2006 Karelia Software. All rights reserved.
//

#import "KTDocument.h"

#import "KTMediaManager+Internal.h"
#import "BDAlias.h"

@implementation KTDocument (Media)

- (KTMediaManager *)mediaManager
{
	if (!myMediaManager)
	{
		myMediaManager = [[KTMediaManager alloc] initWithDocument:self];
	}
	
	return myMediaManager;
}

- (BOOL)upateMediaStorageAtNextSave { return myShouldUpateMediaStorageAtNextSave; }

- (void)setUpdateMediaStorageAtNextSave:(BOOL)update { myShouldUpateMediaStorageAtNextSave = update; }

@end
