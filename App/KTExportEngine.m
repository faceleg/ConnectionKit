//
//  KTExportEngine.m
//  Marvel
//
//  Created by Mike on 17/12/2008.
//  Copyright 2008-2011 Karelia Software. All rights reserved.
//

#import "KTExportEngine.h"


@implementation KTExportEngine

/*  Before publishing can start, we must remove any existing file/directory by the name
 */
- (void)start
{
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"ExportShouldReplaceExistingFile"])
    {
        NSString *exportPath = [self baseRemotePath];
        if ([[NSFileManager defaultManager] fileExistsAtPath:exportPath])
        {
            NSError *error = nil;
            if (![[NSFileManager defaultManager] removeItemAtPath:exportPath error:&error])
            {
                // We can't continue because the pesky file can't be removed
                [self engineDidPublish:NO error:error];
                return;
            }
        }
    }
    
    [super start];
}

- (void)createConnection
{
    [super createConnection];
	
    // Create site directory
    [[self connection] createDirectory:[self baseRemotePath]];
}

@end
