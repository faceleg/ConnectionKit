//
//  KTDesignPlaceholder.m
//  Marvel
//
//  Created by Mike on 30/05/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import "KTDesignPlaceholder.h"


@implementation KTDesignPlaceholder

- (id)initWithBundleIdentifier:(NSString *)identifier
{
    OBPRECONDITION(identifier);
    
    // We are being incredibly cheeky and sidestepping KSPlugInWrapper's usual initialization in order
    // to accomodate having a nil bundle.
    self = [super init];
    
    if (self)
    {
        myBundleIdentifier = [identifier copy];
    }
    
    return self;
}

- (void)dealloc
{
    [myBundleIdentifier release];
    [super dealloc];
}

#pragma mark -
#pragma mark Accessors

/*  We have no bundle, so figure the remote path directly from the identifier
 */
- (NSString *)remotePath
{
	NSString *result = [[self class] remotePathForDesignWithIdentifier:myBundleIdentifier];
	return result;
}

@end
