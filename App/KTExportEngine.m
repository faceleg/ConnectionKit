//
//  KTExportEngine.m
//  Marvel
//
//  Created by Mike on 17/12/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import "KTExportEngine.h"

#import "NSError+Karelia.h"


@implementation KTExportEngine

/*  Before publishing can start, we must remove any existing file/directory by the name
 */
- (void)start
{
    NSString *exportPath = [self baseRemotePath];
    if ([[NSFileManager defaultManager] fileExistsAtPath:exportPath])
    {
        if (![[NSFileManager defaultManager] removeFileAtPath:exportPath handler:nil])
        {
            // We can't continue because the pesky file can't be removed
            [self didFinish];
            
            NSError *error = [NSError errorWithLocalizedDescription:
                              [NSString stringWithFormat:
                               NSLocalizedString(@"The site could not be exported. Could not remove the existing file at:\r%@",
                                                 @"Export error"),
                               exportPath]];
            
            [[self delegate] publishingEngine:self didFailWithError:error];
            return;
        }
    }
    
    [super start];
}

- (void)createConnection
{
    id <CKConnection> result = [[CKFileConnection alloc] init];
    [self setConnection:result];
	
    // Create site directory
    [result createDirectory:[self baseRemotePath]];
	
	[result release];
}

@end
