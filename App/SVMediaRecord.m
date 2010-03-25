//
//  SVMedia.m
//  Sandvox
//
//  Created by Mike on 23/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVMediaRecord.h"

#import "NSManagedObject+KTExtensions.h"

#import "NSError+Karelia.h"
#import "NSImage+Karelia.h"
#import "NSURL+Karelia.h"

#import "BDAlias.h"


NSString *kSVDidDeleteMediaRecordNotification = @"SVMediaWasDeleted";


@interface SVMediaRecord ()

@property(nonatomic, retain, readwrite) BDAlias *alias;

@property(nonatomic, copy) NSURLResponse *fileURLResponse;

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
    OBPRECONDITION(context);
    
    
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[URL path]
                                                                                error:outError];
    
    SVMediaRecord *result = nil;
    if (attributes)
    {
        BDAlias *alias = [BDAlias aliasWithPath:[URL path] error:outError];	// make sure alias can be created first
		if (alias)
		{
			result = [NSEntityDescription insertNewObjectForEntityForName:entityName
                                               inManagedObjectContext:context];
			[result setAlias:alias];
			[result setFileAttributes:attributes];
			[result setPreferredFilename:[URL lastPathComponent]];
		}
    }
    return result;
}

+ (SVMediaRecord *)mediaWithFileContents:(NSData *)data
                             URLResponse:(NSURLResponse *)response
                              entityName:(NSString *)entityName
          insertIntoManagedObjectContext:(NSManagedObjectContext *)context;
{
    OBPRECONDITION(data);
    OBPRECONDITION(context);

    
    SVMediaRecord *result = [NSEntityDescription insertNewObjectForEntityForName:entityName
                                                    inManagedObjectContext:context];
    
    result->_data = [data copy];
    [result setFileURLResponse:response];
    [result setPreferredFilename:[response suggestedFilename]];
    
    return result;
}

#pragma mark Dealloc

- (void)dealloc
{
    [_URL release];
    [_URLResponse release];
    
    [super dealloc];
}

#pragma mark Updating Media Records

- (BOOL)moveToURL:(NSURL *)URL error:(NSError **)error;
{
    if ([[NSFileManager defaultManager] moveItemAtPath:[[self fileURL] path]
                                                toPath:[URL path]
                                                 error:error])
    {
        [self setFileURL:URL];
        return YES;
    }
    
    return NO;
}

- (void)moveToURLWhenDeleted:(NSURL *)URL;
{
    [self willMoveToURLWhenDeleted:URL];
    _moveWhenSaved = YES;
}

- (void)willMoveToURLWhenDeleted:(NSURL *)URL;
{
    OBPRECONDITION(URL);
    
    OBASSERT(!_destinationURL); // shouldn't be possible to schedule twice
    URL = [URL copy];
    [_destinationURL release]; _destinationURL = URL;
}

- (void)willSave
{
    // Once deleted, there is no way to know our URL, so fix it in position
    if ([self isDeleted])
    {
        [self setFileURL:[self fileURL]];
    }
}

- (void)didSave
{
    BOOL inserted = [self isInserted];
    BOOL deleted = [self isDeleted];
    
    
    // Post notification
    if (deleted)
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:kSVDidDeleteMediaRecordNotification object:self];
    }
    
    
    // Make the move if requested.
    // TODO: Be really sure the move isn't from a location outside the document
    if (_destinationURL && (inserted || deleted))
    {
        // In case the deletion is undone, record the original destination. If that's what's happening then we're all done
        NSURL *oldURL = (inserted) ? nil : [[self fileURL] copy];
        
        if (_moveWhenSaved)
        {
            [self moveToURL:_destinationURL error:NULL];
        }
        else
        {
            [self setFileURL:_destinationURL];
        }
        
        [_destinationURL release]; _destinationURL = oldURL;
    }
    
    
    // After insertion, don't want URL to be fixed as it could be changed by the document moving or something
    if (inserted)
    {
        [self setFileURL:nil];
    }
}

#pragma mark Location

- (NSURL *)fileURL;
{
	// If the URL has been fixed, use that!
    NSURL *result = _URL;
    
    if (!result)
    {
        // Just before copying into the document, media is assigned a filename, which won't have been persisted yet
        NSString *filename = [self committedValueForKey:@"filename"];
        if (!filename)
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

- (void)setFileURL:(NSURL *)URL;
{
    URL = [URL copy];
    [_URL release]; _URL = URL;
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

- (WebResource *)webResource;
{
    NSURLResponse *response = [self fileURLResponse];
    
    WebResource *result = [[WebResource alloc] initWithData:[self fileContents]
                                                        URL:[response URL]
                                                   MIMEType:[response MIMEType]
                                           textEncodingName:[response textEncodingName]
                                                  frameName:nil];
    return [result autorelease];
}

@synthesize fileURLResponse = _URLResponse;

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

#pragma mark Thumbnail

- (id)imageRepresentation
{
    id result = ([self areContentsCached] ? (id)[self fileContents] : (id)[self fileURL]);
    return result;
}

- (NSString *)imageRepresentationType
{
    NSString *result = ([self areContentsCached] ? IKImageBrowserNSDataRepresentationType : IKImageBrowserNSURLRepresentationType);
    return result;
}

#pragma mark File Management

- (BOOL)validateForInsert:(NSError **)error
{
    BOOL result = [super validateForInsert:error];
    if (result)
    {
        // When inserting media, it must either refer to an alias, or raw data
        result = ([self alias] || _data);
        if (!result && error) *error = [NSError errorWithDomain:NSCocoaErrorDomain
                                                           code:NSValidationMissingMandatoryPropertyError
                                           localizedDescription:@"New media must be sourced from data or an alias"];
    }
    return result;
}

- (BOOL)isDeletedFromDocument;
{
    BOOL result = ([self isInserted] || ![self managedObjectContext]);
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
        [self setFileURL:URL];
    }
    
    
    return result;
}

@end


#pragma mark -


@implementation NSObject (SVMediaRecord)

- (void)replaceMedia:(SVMediaRecord *)media forKeyPath:(NSString *)keyPath;
{
    SVMediaRecord *oldMedia = [self valueForKeyPath:keyPath];
    if (oldMedia) [[oldMedia managedObjectContext] deleteObject:oldMedia];
    
    [self setValue:media forKeyPath:keyPath];
}

@end

