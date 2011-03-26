//
//  NSDocument+KTExtensions.m
//  Marvel
//
//  Created by Mike on 21/10/2008.
//  Copyright 2008-2011 Karelia Software. All rights reserved.
//

#import "NSDocument+KTExtensions.h"

#import "NSError+Karelia.h"


@implementation NSDocument (KTExtensions)

/*  Copies the document to the specified URL WITHOUT saving it first.
 *  Existing files are either deleted or moved to the trash as specified
 */
- (BOOL)copyDocumentToURL:(NSURL *)URL recycleExistingFiles:(BOOL)recycle error:(NSError **)outError
{
    OBPRECONDITION(URL);
    OBPRECONDITION([URL isFileURL]);
    OBPRECONDITION([URL path]);
    
    
    BOOL result = YES;
	
    
    // Disallow copy to the same location
    NSString *destinationPath = [[URL path] stringByResolvingSymlinksInPath];
    NSString *sourcePath = [[[self fileURL] path] stringByResolvingSymlinksInPath];
    if ([destinationPath isEqualToString:sourcePath])
    {
        if (outError)
        {
            *outError = [NSError errorWithDomain:kKareliaErrorDomain
                                            code:KareliaError
                            localizedDescription:NSLocalizedString(@"Cannot copy document over itself.", "alert message")
                     localizedRecoverySuggestion:NSLocalizedString(@"Please choose a different location to copy to.", "error recovery suggestion")
                                 underlyingError:nil];
        }
        
        return NO;
    }
    
    
    // Delete any existing file if requested
    NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:destinationPath])
    {
        if (recycle)
        {
            result = [[NSWorkspace sharedWorkspace] performFileOperation:NSWorkspaceRecycleOperation 
                                                                  source:[destinationPath stringByDeletingLastPathComponent]
                                                             destination:nil
                                                                   files:[NSArray arrayWithObject:[destinationPath lastPathComponent]] 
                                                                     tag:0];
            
        }
        else
        {
            result = [fm removeFileAtPath:destinationPath handler:self];
        }
        
        if (!result)
        {
            if (outError)
            {
                *outError = [NSError errorWithDomain:kKareliaErrorDomain
                                                code:KareliaError
                                localizedDescription:NSLocalizedString(@"The document could not be copied. Sandvox was unable to remove an existing file or folder at the same location.", "alert message")];
            }
            
            return NO;
        }
    }
            
    
    // Grab the date
    NSDate *now = [NSDate date];
    
    
    // Make the backup
    result = [fm copyPath:sourcePath toPath:destinationPath handler:self];
    if (result)
    {
        // update the creation/lastModification times to now
        //  what key is "Last opened" that we see in Finder?
        //  until we know that, only update mod time
        NSDictionary *dateInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                  //now, NSFileCreationDate,
                                  now, NSFileModificationDate,
                                  nil];
        (void)[fm changeFileAttributes:dateInfo atPath:destinationPath];
    }
    else
    {
        if (outError)
        {
            *outError = [NSError errorWithDomain:kKareliaErrorDomain
                                            code:KareliaError
                            localizedDescription:NSLocalizedString(@"The document could not be copied.", "alert message")];
        }
    }

	return result;
}

@end
