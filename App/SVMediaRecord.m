//
//  SVMedia.m
//  Sandvox
//
//  Created by Mike on 23/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVMediaRecord.h"

#import "NSManagedObject+KTExtensions.h"

#import "NSURL+Karelia.h"

#import "BDAlias.h"


NSString *kSVMediaWantsCopyingIntoDocumentNotification = @"SVMediaWantsCopyingIntoDocument";


@interface SVMediaRecord ()
@property(nonatomic, retain, readwrite) BDAlias *alias;
@end


#pragma mark -


@implementation SVMediaRecord

#pragma mark Creating New Media

+ (SVMediaRecord *)mediaWithURL:(NSURL *)URL
                     entityName:(NSString *)entityName
 insertIntoManagedObjectContext:(NSManagedObjectContext *)context
                          error:(NSError **)outError;
{
    OBPRECONDITION(URL);
    
    
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[URL path]
                                                                                error:outError];
    
    SVMediaRecord *result = nil;
    if (attributes)
    {
        result = [NSEntityDescription insertNewObjectForEntityForName:entityName
                                               inManagedObjectContext:context];
        
        [result setAlias:[BDAlias aliasWithPath:[URL path]]];
        [result setFileAttributes:attributes];
        [result setPreferredFilename:[URL lastPathComponent]];
    }
    
    return result;
}

+ (SVMediaRecord *)mediaWithContents:(NSData *)data
                          entityName:(NSString *)entityName
      insertIntoManagedObjectContext:(NSManagedObjectContext *)context;
{
    OBPRECONDITION(data);
    
    
    SVMediaRecord *result = [NSEntityDescription insertNewObjectForEntityForName:entityName
                                                    inManagedObjectContext:context];
    
    result->_data = [data copy];
    
    return result;
}

#pragma mark Location

- (NSURL *)fileURL;
{
	// If the URL has been fixed, use that!
    NSURL *result = _URL;
    
    if (!result)
    {
        // Just before copying into the document, media is assigned a filename, which won't have been persisted yet
        if ([self filename] && ![self committedValueForKey:@"filename"])
        {
            // Figure out proper values for these two
            if ([self isInserted])
            {
                return [self deletedFileURL];
            }
            else
            {
                return [self savedFileURL];
            }
        }
        else
        {
            // Get best path we can out of the alias
            NSString *path = [[self alias] fullPath];
            if (!path) path = [[self alias] lastKnownPath];
            
            // Ignore files which are in the Trash
            if ([path rangeOfString:@".Trash"].location != NSNotFound) path = nil;
            
            
            if (path) result = [NSURL fileURLWithPath:path];
        }
    }
    
    return result;
}

- (NSURL *)savedFileURL;
{
    NSURL *storeURL = [[[self objectID] persistentStore] URL];
    NSURL *docURL = [storeURL URLByDeletingLastPathComponent];
    
    NSURL *result = [docURL URLByAppendingPathComponent:[self filename]
                                            isDirectory:NO];
    return result;
}

#pragma mark Location Support

@dynamic filename;
- (NSString *)Xfilename // not sure we actually need the custom logic
{
    [self willAccessValueForKey:@"filename"];
    NSString *result = [self primitiveValueForKey:@"filename"];
    [self didAccessValueForKey:@"filename"];
    
    // If there's a sequence of events:
    //  1.  Insert media
    //  2.  Other stuff
    //  3.  Save doc
    //  4.  Undo
    //  The undo will return our filename to nil, but we do have one really. So, fallback to the committed value
    if (!result)
    {
        result = [self committedValueForKey:@"filename"];
    }
    
    return result;
}


- (BDAlias *)alias
{
	BDAlias *result = [self wrappedValueForKey:@"alias"];
	
	if (!result)
	{
		NSData *aliasData = [self valueForKey:@"aliasData"];
		if (aliasData)
		{
			result = [BDAlias aliasWithData:aliasData];
			[self setPrimitiveValue:result forKey:@"alias"];
		}
	}
	
	return result;
}

- (void)setAlias:(BDAlias *)alias
{
	[self setWrappedValue:alias forKey:@"alias"];
	[self setValue:[alias aliasData] forKey:@"aliasData"];
}

@dynamic shouldCopyFileIntoDocument;

@dynamic preferredFilename;
- (BOOL)validatePreferredFilename:(NSString **)filename error:(NSError **)outError
{
    //  Make sure it really is just a filename and not a path
    BOOL result = [[*filename pathComponents] count] == 1;
    if (!result && outError)
    {
        NSDictionary *info = [NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"perferredFilename \"%@\" is a path; not a filename", *filename]
                                                         forKey:NSLocalizedDescriptionKey];
        *outError = [NSError errorWithDomain:NSCocoaErrorDomain
                                        code:NSValidationStringPatternMatchingError
                                    userInfo:info];
    }
    
    return result;
}

#pragma mark Contents Cache

- (NSData *)fileContents;
{
    return _data;
}

@synthesize fileAttributes = _attributes;
- (NSDictionary *)fileAttributes
{
    // Lazily load from disk
    if (!_attributes)
    {
        NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[[self fileURL] path]
                                                                                    error:NULL];
        [self setFileAttributes:attributes];
    }
    
    return _attributes;
}

- (BOOL)areContentsCached;
{
    return (_data != nil);
}

- (void)didTurnIntoFault
{
    [super didTurnIntoFault];
    
    [_data release]; _data = nil;
}

#pragma mark File Management

- (void)willSave
{
    [super willSave];
    
    // Ask the document to figure out the filename we'll be using
    if (![self filename] && [[self shouldCopyFileIntoDocument] boolValue])
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"SVMediaWantsCopyingIntoDocument" object:self];
    }
}

- (BOOL)validateForInsert:(NSError **)error
{
    BOOL result = [super validateForInsert:error];
    if (result)
    {
        // To be valid, external media should have an alias.
        // We can't test whether filename is valid here (in-document media should have a unqiue filename) since it won't have been generated yet
        if (![[self shouldCopyFileIntoDocument] boolValue])
        {
            result = ([self alias] != nil);
            // TODO: Generate proper error object
            if (!result && error) *error = nil;
        }
    }
    return result;
}

#pragma mark Writing Files

- (BOOL)writeToURL:(NSURL *)URL updateFileURL:(BOOL)updateFileURL error:(NSError **)outError;
{
    // Try writing out data from memory. It'll fail if there was none
    NSData *data = [self fileContents];
    BOOL result = [data writeToURL:URL options:0 error:outError];
    if (result)
    {
        if ([self fileAttributes])
        {
            result = [[NSFileManager defaultManager] setAttributes:[self fileAttributes]
                                                      ofItemAtPath:[URL path]
                                                             error:outError];
        }
    }
    else
    {
        // Fallback to copying the file
        result = [[NSFileManager defaultManager] copyItemAtPath:[[self fileURL] path]
                                                         toPath:[URL path]
                                                          error:outError];
    }
    
    
    // Update fileURL to match
    if (updateFileURL && result)
    {
        URL = [URL copy];
        [_URL release]; _URL = URL;
    }
    
    
    return result;
}
@end
