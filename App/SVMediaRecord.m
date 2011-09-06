//
//  SVMediaRecord.m
//  Sandvox
//
//  Created by Mike on 23/01/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVMediaRecord.h"

#import "NSManagedObject+KTExtensions.h"

#import "NSError+Karelia.h"
#import "NSImage+Karelia.h"
#import "NSString+Karelia.h"
#import "KSURLUtilities.h"
#import "KSThreadProxy.h"

#import "BDAlias.h"


NSString *kSVDidDeleteMediaRecordNotification = @"SVMediaWasDeleted";


@interface SVMediaRecord ()

@property(nonatomic, copy) NSString *primitiveFilename;

@property(nonatomic, retain, readwrite) SVMedia *media;
@property(nonatomic, retain, readwrite) BDAlias *alias;

@end


#pragma mark -


@implementation SVMediaRecord

#pragma mark Creating New Media

+ (SVMediaRecord *)mediaByReferencingURL:(NSURL *)URL
                     entityName:(NSString *)entityName
 insertIntoManagedObjectContext:(NSManagedObjectContext *)context
                          error:(NSError **)outError;
{
    OBPRECONDITION(URL);
    OBPRECONDITION(context);
    
    
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[URL path]
                                                                                error:outError];
    
    SVMediaRecord *result = nil;
    BDAlias *alias = [BDAlias aliasWithPath:[URL path] error:outError];	// make sure alias can be created first
    if (alias)
    {
        result = [NSEntityDescription insertNewObjectForEntityForName:entityName
                                               inManagedObjectContext:context];
        [result setAlias:alias];
        [result setFileAttributes:attributes];
        [result setPreferredFilename:[URL ks_lastPathComponent]];
    }
    
    return result;
}

+ (SVMediaRecord *)mediaRecordWithMedia:(SVMedia *)media
                             entityName:(NSString *)entityName
         insertIntoManagedObjectContext:(NSManagedObjectContext *)context;
{
    OBPRECONDITION(media);
    OBPRECONDITION(context);

    SVMediaRecord *result = [NSEntityDescription insertNewObjectForEntityForName:entityName
                                                          inManagedObjectContext:context];
    
    if (media.fileURL) [result setAlias:[BDAlias aliasWithPath:media.fileURL.path]];
    [result setMedia:media];
    [result setPreferredFilename:[media preferredFilename]];
    
    return result;
}

+ (SVMediaRecord *)mediaWithBundledURL:(NSURL *)URL
                            entityName:(NSString *)entityName
        insertIntoManagedObjectContext:(NSManagedObjectContext *)context;
{
    SVMediaRecord *result = [NSEntityDescription insertNewObjectForEntityForName:entityName
                                                          inManagedObjectContext:context];
    
    [result readFromURL:URL options:0 error:NULL];
    [result setFilename:[@"Shared/" stringByAppendingString:[URL ks_lastPathComponent]]];
    [result setPreferredFilename:[URL ks_lastPathComponent]];
    [result setShouldCopyFileIntoDocument:[NSNumber numberWithBool:NO]];
    
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[URL path]
                                                                                error:NULL];
    [result setFileAttributes:attributes];
    
    return result;
}

#pragma mark Dealloc

- (void)dealloc
{
    [_filename release];
    [_media release];       //_media = nil; // why set to nil?! Mike.
    [_nextObject release];	_nextObject = nil;
    
    [super dealloc];
}

#pragma mark Updating Media Records

- (BOOL)moveToURL:(NSURL *)URL error:(NSError **)error;
{
    if ([[NSFileManager defaultManager] moveItemAtPath:[[self fileURL] path]
                                                toPath:[URL path]
                                                 error:error])
    {
        [self forceUpdateFromURL:URL];
        return YES;
    }
    
    return NO;
}

- (void)didSave
{
    // Post notification
    BOOL deleted = [self isDeleted];
    if (deleted)
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:kSVDidDeleteMediaRecordNotification object:self];
    }
}

#pragma mark Location

- (NSURL *)fileURL;
{
	// If the URL has been fixed, use that!
    NSURL *result = [[self media] fileURL];    
    return result;
}

- (BOOL)isPlaceholder;
{
    return ([[self filename] hasPrefix:@"shared/"] || [[self filename] hasPrefix:@"Shared/"]);
}

- (BOOL)isEditableText	// used by SVURLPreviewController and KTPageDetailsController
{
	NSString *type = [self typeOfFile];
	// Don't want to edit any old text as that includes things like RTF. Plain text would be ideal, but for some reason neither HTML or XML conform to it (or each other!) so cover them specially
	return ([type conformsToUTI:(NSString *)kUTTypePlainText] ||
			[type conformsToUTI:(NSString *)kUTTypeHTML] ||
			[type conformsToUTI:(NSString *)kUTTypeXML]);
}

#pragma mark Updating File Wrappers

- (BOOL)readFromURL:(NSURL *)URL options:(NSUInteger)options error:(NSError **)error;
{
    // Warn if file doesn't exist
    if ([URL isFileURL])
    {
        if (![[NSFileManager defaultManager] fileExistsAtPath:[URL path]])
        {
            NSLog(@"Media not located");
        }
    }
    
    
    SVMedia *media = [[SVMedia alloc] initByReferencingURL:URL];
    [self setMedia:media];
    [media release];
    
    // Pass on to next object as well
    [[self nextObject] forceUpdateFromURL:URL];
    
    return YES;
}

#pragma mark Location Support

@dynamic filename;

@synthesize primitiveFilename = _filename;
- (void)setPrimitiveFilename:(NSString *)filename;
{
    // Ignore any changes the context might want to make after filename has been fixed
    if ([self primitiveFilename]) return;
    
    OBASSERT(!_filename);
    _filename = [filename copy];
}

@dynamic shouldCopyFileIntoDocument;

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

- (BDAlias *)autosaveAlias
{
	BDAlias *result = [self wrappedValueForKey:@"autosaveAlias"];
	
	if (!result)
	{
		NSData *aliasData = [self valueForKey:@"autosaveAliasData"];
		if (aliasData)
		{
			result = [BDAlias aliasWithData:aliasData];
			[self setPrimitiveValue:result forKey:@"autosaveAlias"];
		}
	}
	
	return result;
}

- (void)setAutosaveAlias:(BDAlias *)alias
{
    [self willChangeValueForKey:@"autosaveAlias"];
	[self setPrimitiveValue:alias forKey:@"autosaveAlias"];
	[self setValue:[alias aliasData] forKey:@"autosaveAliasData"];
    [self didChangeValueForKey:@"autosaveAlias"];
}

@dynamic preferredFilename;
- (BOOL)validatePreferredFilename:(NSString **)filename error:(NSError **)outError
{
    //  Make sure it really is just a filename and not a path
    BOOL result = [[*filename pathComponents] count] == 1;
    if (!result && outError)
    {
        *outError = [KSError validationErrorWithCode:NSValidationStringPatternMatchingError
                                              object:self
                                                 key:@"preferredFilename"
                                               value:*filename
                          localizedDescriptionFormat:@"preferredFilename \"%@\" is a path; not a filename", *filename];
    }
    
    return result;
}

- (NSString *)typeOfFile
{
	NSString *fileName = [self preferredFilename];
	NSString *UTI = [KSWORKSPACE ks_typeForFilenameExtension:[fileName pathExtension]];
	return UTI;
}

#pragma mark Contents Cache

- (SVMedia *)media;
{
    if (!_media)
    {
        // Maybe it was autosaved as data?
        _media = [[self extensiblePropertyForKey:@"media"] retain];
        
        if (!_media)
        {
            // Get best path we can out of the alias
            NSString *path = [[self autosaveAlias] fullPath];
            if (!path) path = [[self alias] fullPath];
            if (!path) path = [[self autosaveAlias] lastKnownPath];
            if (!path) path = [[self alias] lastKnownPath];
            
            // Ignore *external* files which are in the Trash
            if (![[self shouldCopyFileIntoDocument] boolValue] &&
                [path rangeOfString:@".Trash"].location != NSNotFound)
            {
                path = nil;
            }
            
            
            if (path)
            {
                _media = [[SVMedia alloc] initByReferencingURL:[NSURL fileURLWithPath:path]];
            }
        }
    }
    
    return _media;
}
- (void)setMedia:(SVMedia *)media;
{
    [media retain];
    [_media release]; _media = media;
    
    // Also persist in-memory media for now in case of having to restore from autosave
    if ([self managedObjectContext] && [self extensiblePropertyForKey:@"media"])
    {
        [self removeExtensiblePropertyForKey:@"media"];
    }
    if ([media mediaData])
    {
        [self setExtensibleProperty:media forKey:@"media"];
    }
}
+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key;
{
    return ([key isEqualToString:@"media"] ?
            YES :
            [super automaticallyNotifiesObserversForKey:key]);
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
    return ([_media webResource] != nil);
}

/*- (void)willTurnIntoFault
{
    [super willTurnIntoFault];
    
    // Only throw away data if it can be reloaded
    if ([self fileURL])
    {
        [_webResource release]; _webResource = nil;
    }
}*/

#pragma mark File Management

- (BOOL)validateMedia:(NSError **)error;
{
    // Media must be referred to in the package, by alias, or stored raw in extensible properties
    
    BOOL result = ([self filename] || [self alias] || [self extensiblePropertyForKey:@"media"]);
    if (!result && error)
    {
        *error = [KSError validationErrorWithCode:NSValidationMissingMandatoryPropertyError
                                           object:self
                                              key:nil
                                            value:nil
                       localizedDescriptionFormat:@"Media has no source"];
    }
    
    return result;
}

- (BOOL)validateForInsert:(NSError **)error
{
    BOOL result = [super validateForInsert:error];
    if (result) result = [self validateMedia:error];
    return result;
}

- (BOOL)validateForUpdate:(NSError **)error;
{
    BOOL result = [super validateForUpdate:error];
    if (result) result = [self validateMedia:error];
    return result;    
}

#pragma mark Writing Files

- (BOOL)writeToURL:(NSURL *)URL updateFileURL:(BOOL)updateFileURL error:(NSError **)outError;
{
    // Try writing out data from memory. It'll fail if there was none
    BOOL result = [[self media] writeToURL:URL error:outError];
    
    if (result)
    {
        if ([self fileAttributes])
        {
            result = [[NSFileManager defaultManager] setAttributes:[self fileAttributes]
                                                      ofItemAtPath:[URL path]
                                                             error:outError];
        }
    }
    
    
    // Update fileURL to match
    if (updateFileURL && result)
    {
        [self forceUpdateFromURL:URL];
    }
    
    
    return result;
}

- (void)willAutosave;
{
    //  Time to store an autosave alias!
    
    NSString *path = [[_media mediaURL] path];
    if (path)
    {
        BDAlias *alias = [BDAlias aliasWithPath:path];
        [self setAutosaveAlias:alias];
    }
}

#pragma mark Matching Media

@synthesize nextObject = _nextObject;
- (void)setNextObject:(id <SVDocumentFileWrapper>)object;
{
    OBPRECONDITION(object != self);
    
    [object retain];
    [_nextObject release]; _nextObject = object;
}

#pragma mark Serialization

- (void)populateSerializedProperties:(NSMutableDictionary *)propertyList;
{
    [[self media] populateSerializedProperties:propertyList];
}

#pragma mark SVDocumentFileWrapper

- (void)forceUpdateFromURL:(NSURL *)URL;
{
    BOOL result = [self readFromURL:URL options:0 error:NULL];
#pragma unused (result)
   OBPOSTCONDITION(result);
}

- (BOOL)shouldRemoveFromDocument;
{
    // YES if we and all following linked objects are marked for deletion.
    // -isDeleted is good enough most of the time, but doesn't catch non-persistent objects marked for deletion (media records added by #62243)
    BOOL result = [self isDeleted] || ![self managedObjectContext];
    if (result)
    {
        id <SVDocumentFileWrapper> next = [self nextObject];
        if (next) result = [next shouldRemoveFromDocument];
    }
    return result;
}

- (BOOL)isDeletedFromDocument;
{
    BOOL result = ([self isInserted] || ![self managedObjectContext]);
    if (result)
    {
        // Let next object have final say. Potentially this could go down a long chain if you have lots of copies of the same file!
        id <SVDocumentFileWrapper> next = [self nextObject];
        if (next) result = [next isDeletedFromDocument];
    }
    
    return result;
}

@end


#pragma mark -


@implementation NSObject (SVMediaRecord)

- (void)replaceMedia:(SVMediaRecord *)media forKeyPath:(NSString *)keyPath;
{
    SVMediaRecord *oldMedia = [self valueForKeyPath:keyPath];
    [[oldMedia managedObjectContext] deleteObject:oldMedia];    // does nothing if oldMedia is nil
    
    [self setValue:media forKeyPath:keyPath];
}

@end

