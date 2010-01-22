//
//  SVMedia.m
//  Sandvox
//
//  Created by Mike on 22/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVMediaWrapper.h"

#import "KTMediaFile.h"

#import "NSURL+Karelia.h"


@implementation SVMediaWrapper

- (id)initWithURL:(NSURL *)URL;
{
    OBPRECONDITION(URL);
    
    BDAlias *alias = [[BDAlias alloc] initWithPath:URL];
    self = [self initWithAlias:alias];
    [alias release];
    
    return self;
}

- (id)initWithAlias:(BDAlias *)alias;
{
    
}

- (id)initWithURLInDocument:(NSURL *)URL;
{
    OBPRECONDITION(URL);

    [self init];
    
    _fileURL = [URL copy];
    [self setPreferredFilename:[URL lastPathComponent]];
    
    return self;
}

- (id)initWithMediaFile:(KTMediaFile *)mediaFile;
{
    OBPRECONDITION(mediaFile);
    //OBPRECONDITION(![mediaFile isInserted]);                              // FIXME: relaxed these during development
    //OBPRECONDITION([[mediaFile objectID] persistentStore]);
    
    [self init];
    
    _fileURL = [[mediaFile fileURL] copy];
    _mediaFile = [mediaFile retain];
    _preferredFilename = [[mediaFile preferredFilename] copy];
    _shouldCopyIntoDocument = [[mediaFile shouldCopyFileIntoDocument] boolValue];
    _committed = ![mediaFile isInserted];
    
    return self;
}

- (void)dealloc
{
    [_mediaFile release];
    [super dealloc];
}

@synthesize mediaFile = _mediaFile;

#pragma mark Accessing Files

- (NSURL *)fileURL; // wherever the file was last seen. Like -[NSFileWrapper filename] but beter
{
    NSURL *result = _fileURL;
    if (!result)
    {
        // Get best path we can out of the alias
        NSString *path = [[self alias] fullPath];
        if (!path) path = [[self alias] lastKnownPath];
        
        // Ignore files which are in the Trash
        if ([path rangeOfString:@".Trash"].location != NSNotFound) path = nil;
        
        if (path) result = [NSURL fileURLWithPath:path];
    }
     
    return result;
}

@synthesize preferredFilename = _preferredFilename;

- (NSData *)fileContents;
{
    NSData *result = [[self mediaFile] contents];
    return result;
}

@synthesize shouldCopyIntoDocument = _shouldCopyIntoDocument;
@synthesize hasBeenCopiedIntoDocument = _committed;

#pragma mark Writing Files

- (BOOL)writeToURL:(NSURL *)URL updateFileURL:(BOOL)updateFileURL error:(NSError **)outError;
{
    
    // Try writing out data from memory. It'll fail if there was none
    NSData *data = [self fileContents];
    BOOL result = [data writeToURL:URL options:0 error:outError];
    //if (result) [[NSFileManager defaultManager] setAttributes:[self fileAttributes] ofItemAtPath:<#(NSString *)path#> error:<#(NSError **)error#>];
    
    // Fallback to copying the file
    if (!result)
    {
        result = [[NSFileManager defaultManager] copyItemAtPath:[[self fileURL] path]
                                                         toPath:[URL path]
                                                          error:outError];
    }
    
    
    return result;
}

@end
