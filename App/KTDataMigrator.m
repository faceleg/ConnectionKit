//
//  KTDataMigrator.m
//  KTComponents
//
//  Created by Terrence Talbot on 8/31/05.
//  Copyright 2005-2009 Karelia Software. All rights reserved.
//

#import "KTDataMigrator.h"

#import "KT.h"
#import "KTDesign.h"
#import "KTDocument.h"
#import "KTSite.h"
#import "KTElementPlugin.h"
#import "KTMaster+Internal.h"
#import "KTMediaManager.h"
#import "KTPage+Internal.h"
#import "KTPagelet+Internal.h"
#import "KTUtilities.h"

#import "KTStoredArray.h"
#import "KTStoredDictionary.h"
#import "KTStoredSet.h"

#import "NSArray+Karelia.h"
#import "NSData+Karelia.h"
#import "NSError+Karelia.h"
#import "NSFileManager+Karelia.h"
#import "NSManagedObject+KTExtensions.h"
#import "NSManagedObjectContext+KTExtensions.h"
#import "NSManagedObjectModel+KTExtensions.h"
#import "NSObject+Karelia.h"
#import "NSSortDescriptor+Karelia.h"
#import "NSString+Karelia.h"
#import "NSThread+Karelia.h"
#import "NSURL+Karelia.h"

#import <QTKit/QTKit.h>

#import "Debug.h"



@interface KTDataMigrator ()

// Accessors
- (void)setOldManagedObjectModel:(NSManagedObjectModel *)anOldManagedObjectModel;
- (void)setOldManagedObjectContext:(NSManagedObjectContext *)anOldManagedObjectContext;
- (void)setOldStoreURL:(NSURL *)aStoreURL;
- (void)setMigratedDocumentURL:(NSURL *)URL;
- (void)setMigratedDocument:(KTDocument *)document;

// Generic migration methods
- (BOOL)_migrate:(NSError **)outError;
- (BOOL)backupOldDocumentAfterMigration:(NSError **)outError;
- (BOOL)genericallyMigrateDataFromOldModelVersion:(NSString *)aVersion error:(NSError **)error;

- (NSSet *)matchingAttributesFromObject:(NSManagedObject *)oldObject toObject:(NSManagedObject *)newObject;
- (void)migrateMatchingAttributesFromObject:(NSManagedObject *)managedObjectA toObject:(NSManagedObject *)managedObjectB;
- (void)migrateAttributes:(NSSet *)attributeKeys fromObject:(NSManagedObject *)oldObject toObject:(NSManagedObject *)newObject;


// Element migration
- (void)migrateCodeInjection:(NSString *)code toKey:(NSString *)newKey propogate:(NSNumber *)propogate toPage:(KTPage *)newPage;
- (BOOL)migrateChildrenFromPage:(NSManagedObject *)oldParentPage toPage:(KTPage *)newParentPage error:(NSError **)error;

- (BOOL)migratePageletsFromPage:(NSManagedObject *)oldPage toPage:(KTPage *)newPage error:(NSError **)error;

+ (NSSet *)elementAttributesToIgnore;
- (BOOL)migrateElementContainer:(NSManagedObject *)oldElementContainer toElement:(KTAbstractElement *)newElement error:(NSError **)error;
- (BOOL)migrateElement:(NSManagedObject *)oldElement toElement:(KTAbstractElement *)newElement error:(NSError **)error;

- (BOOL)migrateDocumentInfo:(NSError **)error;

+ (BOOL)validatePathForNewStore:(NSString *)aStorePath error:(NSError **)outError;

@end


/*! model changes, by version:
 
 10000: shipped w/ public betas b11, b12
 base version
 
 10001: shipped w/ public beta b13
 Media added isPublished, a boolean attribute, with a default of NO
 
 10002: shipped w/ beta b15
 DocumentInfo added siteID, a string, meant to store a GUID
 Page added useAbsoluteLinks, an optional boolean with no default
 Page added shortenedTitleHTML, an optional string with no default
 Page added pageTitleFormat, an optional string with no default
 Page changed shortTitle to fileName, still an optional string with no default
 Media added cachedImages, an optional to-many relationship to CachedImage
 added CachedImage, a new entity for storing info about ~/Library/Caches/Sandvox/<Images>
 
 15001: Brand new model for 1.5. Too many changes to list here.
 
 */


#pragma mark -


@implementation KTDataMigrator

+ (void)initialize
{
	[QTMovie class];	// Ensure QTMovie has been sent its own +initialize message on the main thread
}

/*  Provides a lookup table for converting old plugin identifiers to new.
 */
+ (NSString *)currentPluginIdentifierForOldIdentifier:(NSString *)oldIdentifier
{
    OBPRECONDITION(oldIdentifier);
    
    static NSDictionary *sPluginIdentifiers;
    if (!sPluginIdentifiers)
    {
        sPluginIdentifiers = [[NSDictionary alloc] initWithObjectsAndKeys:
                              @"sandvox.RichTextElement", @"sandvox.TextPage",
                              @"sandvox.RichTextElement", @"sandvox.TextPagelet",
                              @"sandvox.RichTextElement", @"sandvox.TextElement",
                              @"sandvox.ImageElement", @"sandvox.ImageElement",
                              @"sandvox.ImageElement", @"sandvox.PhotoPagelet",
                              @"sandvox.ImageElement", @"sandvox.PhotoPage",
                              @"sandvox.AmazonElement", @"sandvox.AmazonList",
                              @"sandvox.BadgeElement", @"sandvox.BadgePagelet",
                              @"sandvox.ContactElement", @"sandvox.ContactElement",
                              @"sandvox.ContactElement", @"sandvox.ContactPage",
                              @"sandvox.ContactElement", @"sandvox.ContactPagelet",
                              @"sandvox.DeliciousElement", @"sandvox.DeliciousPagelet",
                              @"sandvox.DiggElement", @"sandvox.DiggPagelet",
                              @"sandvox.DownloadElement", @"sandvox.FileDownload",
                              @"sandvox.FeedElement", @"sandvox.FeedPagelet",
                              @"sandvox.FlickrElement", @"sandvox.FlickrPagelet",
                              @"sandvox.HTMLElement", @"sandvox.HTMLElement",
                              @"sandvox.HTMLElement", @"sandvox.HTMLPage",
                              @"sandvox.HTMLElement", @"sandvox.HTMLPagelet",
                              @"sandvox.IFrameElement", @"sandvox.IFramePagelet",
                              @"sandvox.IMStatusElement", @"sandvox.IMPagelet",
                              @"sandvox.IndexElement", @"sandvox.IndexPagelet",
                              @"sandvox.LinkElement", @"sandvox.LinkPage",
                              @"sandvox.LinkListElement", @"sandvox.LinkListPagelet",
                              @"sandvox.PageCounterElement", @"com.karelia.pagelet.PageCounter",
                              @"sandvox.RSSBadgeElement", @"sandvox.RSSBadgePagelet",
                              @"sandvox.SiteMapElement", @"sandvox.SiteMapPage",
                              @"sandvox.VideoElement", @"sandvox.VideoElement",
                              @"sandvox.VideoElement", @"sandvox.MoviePage",
                              @"sandvox.VideoElement", @"sandvox.MoviePagelet",
                              nil];
    }
    
    NSString *result = [sPluginIdentifiers objectForKey:oldIdentifier];
		// Clang warning?  Why?
    if (!result) result = oldIdentifier;
    
    OBPOSTCONDITION(result);
    return result;
}

#pragma mark -
#pragma mark Init & Dealloc

/*! upgrades the document, in-place, returning whether procedure was successful */
- (id)initWithDocumentURL:(NSURL *)docURL
{
	[super init];
    
    OBPRECONDITION(docURL);
    OBPRECONDITION([docURL isFileURL]);
    
    [self setOldStoreURL:docURL];
    [self setMigratedDocumentURL:docURL];
    
    return self;
}

- (void)dealloc
{
	[self setMigratedDocument:nil];
    [self setMigratedDocumentURL:nil];
    
	[self setOldStoreURL:nil];
	[self setOldManagedObjectContext:nil];
	[self setOldManagedObjectModel:nil];
	
    [super dealloc];
}

#pragma mark -
#pragma mark Accessors

- (NSManagedObjectModel *)oldManagedObjectModel
{
    return myOldManagedObjectModel; 
}

- (void)setOldManagedObjectModel:(NSManagedObjectModel *)anOldManagedObjectModel
{
    [anOldManagedObjectModel retain];
    [myOldManagedObjectModel release];
    myOldManagedObjectModel = anOldManagedObjectModel;
}

- (NSManagedObjectContext *)oldManagedObjectContext
{
    return myOldManagedObjectContext; 
}

- (void)setOldManagedObjectContext:(NSManagedObjectContext *)anOldManagedObjectContext
{
    [anOldManagedObjectContext retain];
    [myOldManagedObjectContext release];
    myOldManagedObjectContext = anOldManagedObjectContext;
}

- (NSURL *)oldStoreURL
{
	return myOldStoreURL;
}

- (void)setOldStoreURL:(NSURL *)aStoreURL
{
	[aStoreURL retain];
	[myOldStoreURL release];
	myOldStoreURL = aStoreURL;
}

- (NSURL *)migratedDocumentURL { return myMigratedDocumentURL; }

- (void)setMigratedDocumentURL:(NSURL *)URL
{
    URL = [URL copy];
    [myMigratedDocumentURL release];
    myMigratedDocumentURL = URL;
}

- (KTDocument *)migratedDocument { return myMigratedDocument; }

- (void)setMigratedDocument:(KTDocument *)document
{
    [document retain];
    [myMigratedDocument release];
    myMigratedDocument = document;
}

- (unsigned)countOfPagesToMigrate { return myCountOfPagesToMigrate; }

- (void)_setCountOfPagesToMigrate:(NSNumber *)count
{
    [self willChangeValueForKey:@"countOfPagesToMigrate"];
    myCountOfPagesToMigrate = [count unsignedIntValue];
    [self didChangeValueForKey:@"countOfPagesToMigrate"];
}

- (unsigned)countOfPagesMigrated { return myCountOfPagesMigrated; }

- (void)incrementCountOfPagesMigrated
{
    [self willChangeValueForKey:@"countOfPagesMigrated"];
    myCountOfPagesMigrated++;
    [self didChangeValueForKey:@"countOfPagesMigrated"];
}

#pragma mark -
#pragma mark Migration

- (BOOL)migrate:(NSError **)outError
{
    BOOL result = [self _migrate:outError];
    
    return result;
}

/*  Handles all migration, regardless of thread
 */
- (BOOL)_migrate:(NSError **)outError
{
    // Use the original URL as our newStoreURL
	BOOL result = NO;
	NSError *localError = nil;
        
    
    @try        // This means that you can call return and @finally code will still be called. Just make sure result is set.
    {
        if (![self migratedDocumentURL] || ![[self migratedDocumentURL] isFileURL])
        {
            NSString *errorDescription = [NSString stringWithFormat:
                                          NSLocalizedString(@"Unable to upgrade document at path %@. Path does not appear to be a file.","Alert: Unable to upgrade document at path %@. Path does not appear to be a file."),
                                          [[self migratedDocumentURL] absoluteString]];
            
            NSError *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadInvalidFileNameError localizedDescription:errorDescription];
            if (outError)
			{
				*outError = error;
			}
            
            result = NO;    return result;
        }
        
        
        // Check that we have a good path and we can write to it
        if (![KTDataMigrator validatePathForNewStore:[[self migratedDocumentURL] path] error:outError])
        {
            result = NO;    return result;
        }
        
        
        // Migrate!
        result = [self genericallyMigrateDataFromOldModelVersion:kKTModelVersion_ORIGINAL error:&localError];
        if (!result) return NO;
        
        
        // Backup the old doc
        result = [self backupOldDocumentAfterMigration:&localError];
        if (!result) return NO;
        
        
        // Save the new doc to the correct location
        KTDocument *document = [self migratedDocument];
        result = [document saveToURL:[self migratedDocumentURL] ofType:[document fileType] forSaveOperation:NSSaveAsOperation error:outError];
        
        [self setMigratedDocument:nil];
    }
    
    
    
    @catch (NSException *exception)
    {
        result = NO;
		
		// We want to receive any exceptions back through the feedback reporter
		[NSApp performSelectorOnMainThread:@selector(reportException:) withObject:exception waitUntilDone:NO];
    }
    @finally
    {
        // Recover failed migrations and pass out an error
        if (!result && outError)
        {
            if (localError)
            {
                *outError = [NSError errorWithDomain:kKTDataMigrationErrorDomain code:KSCannotUpgrade localizedDescription:
                             [NSString stringWithFormat:
                              NSLocalizedString(@"Unable to migrate document data from %@, reason: %@.","Alert: Unable to migrate document data from %@ to %@, reason: %@."),
                              [[self oldStoreURL] lastPathComponent], localError]];
            }
            else
            {
                *outError = [NSError errorWithDomain:kKTDataMigrationErrorDomain code:KSCannotUpgrade localizedDescription:
                             [NSString stringWithFormat:
                              NSLocalizedString(@"Unable to migrate document data from %@.","Alert: Unable to migrate document data from %@ to %@."),
                              [[self oldStoreURL] lastPathComponent]]];
            }
        }
    }
    
    return result;
}

/*  Performs the migration on a background thread.
 */
- (void)migrateWithDelegate:(id)delegate
         didMigrateSelector:(SEL)didMigrateSelector
                contextInfo:(void *)contextInfo
{
    OBPRECONDITION([NSThread isMainThread]);
    
    
    // Build the callback invocation
    SEL callbackSelector = @selector(dataMigrator:didMigrate:error:contextInfo:);
    NSInvocation *callback = [NSInvocation invocationWithMethodSignature:[delegate methodSignatureForSelector:callbackSelector]];
    [callback setTarget:delegate];
    [callback setSelector:callbackSelector];
    [callback setArgument:&self atIndex:2];
    [callback setArgument:&contextInfo atIndex:5];  // Arguments 3 & 4 will be filled in after migration
    [callback retainArguments];
    
    
    // Log
    NSLog(@"Preparing to migrate");
    
    
    [NSThread detachNewThreadSelector:@selector(threadedMigrateWithCallback:) toTarget:self withObject:callback];
}

- (void)threadedMigrateWithCallback:(NSInvocation *)callback
{
    OBPRECONDITION([self oldStoreURL]);
    
    
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    
    // Do the migration
    NSError *error = nil;
    BOOL result = [self _migrate:&error];
    
    // Let our delegate know the result
    [callback setArgument:&result atIndex:3];
    [callback setArgument:&error atIndex:4];
    [callback retainArguments];
    
    [callback performSelectorOnMainThread:@selector(invoke) withObject:nil waitUntilDone:NO];
    
    
    [pool release];
}

- (BOOL)backupOldDocumentAfterMigration:(NSError **)outError
{
    NSString *modelVersion = kKTModelVersion_ORIGINAL;
    
    
    // move the original to a new location
    NSString *originalPath = [[self oldStoreURL] path];
	NSString *destinationPath = [KTDataMigrator renamedFileName:originalPath modelVersion:modelVersion];
	
	BOOL result = [[NSFileManager defaultManager] movePath:originalPath toPath:destinationPath handler:nil];
	if (result)
    {
        // Set old store URL
        [self setOldStoreURL:[NSURL fileURLWithPath:destinationPath]];
    }
    else
	{
		// we cannot proceed, pass back an error and return NO
		NSString *errorDescription = [NSString stringWithFormat:
                                      NSLocalizedString(@"Unable to rename document from %@ to %@. Upgrade cannot be completed.","Alert: Unable to rename document from %@ to %@. Upgrade cannot be completed."),
                                      originalPath, destinationPath];
		
		NSError *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileWriteUnknownError localizedDescription:errorDescription];
		if (outError)
		{
			*outError = error;
		}
	}
    
    return result;
}

- (BOOL)genericallyMigrateDataFromOldModelVersion:(NSString *)aVersion error:(NSError **)outError
{
	// Set up old model and Core Data stack
	NSManagedObjectModel *model = [KTUtilities modelWithVersion:aVersion];
    [model makeGeneric];
    [self setOldManagedObjectModel:model];
    
    [self setOldManagedObjectContext:[KTUtilities contextWithURL:[self oldStoreURL] 
														   model:[self oldManagedObjectModel]]];
	
    
    // Set up the new document
    NSError *error = nil;
    NSManagedObject *oldRoot = [[[self oldManagedObjectContext] objectsWithEntityName:@"Root" predicate:nil error:&error] firstObjectKS];
    if (!oldRoot)
    {
        NSMutableDictionary *errorInfo = [NSMutableDictionary dictionaryWithObject:@"Root page could not be found."
                                                                           forKey:NSLocalizedDescriptionKey];
        if (error) [errorInfo setObject:error forKey:NSUnderlyingErrorKey];
        
		if (outError)
		{
			*outError = [NSError errorWithDomain:kKTDataMigrationErrorDomain
											code:KareliaError
										userInfo:errorInfo];
		}
        return NO;
    }
    
    NSString *oldRootPluginIdentifier = [oldRoot valueForKey:@"pluginIdentifier"];
    NSString *newRootPluginIdentifier = [[self class] currentPluginIdentifierForOldIdentifier:oldRootPluginIdentifier];
    KTElementPlugin *newRootPlugin = [KTElementPlugin pluginWithIdentifier:newRootPluginIdentifier];
    
    KTDocument *newDoc = [[KTDocument alloc] initWithType:kKTDocumentUTI rootPlugin:newRootPlugin error:outError];
    if (newDoc)
    {
        [[newDoc undoManager] disableUndoRegistration];
        
        [self setMigratedDocument:newDoc];
        [newDoc release];
    }
    else
    {
        return NO;
    }
	
    
	// Migrate (this recurses into pages and so on)
    BOOL result = [self migrateDocumentInfo:outError];
    return result;
}

- (void)cancel
{
    myIsCancelled = YES;
}

- (BOOL)isCancelled { return myIsCancelled; }

#pragma mark -
#pragma mark Page Migration

/*  Imports an old page and converts it to a new page. The new page must already have been created.
 *  This method operates recursively, importing the children of the old page and so on.
 */
- (BOOL)migratePage:(NSManagedObject *)oldPage toPage:(KTPage *)newPage error:(NSError **)error
{
    // Figure out which keys are common between 1.2 and 1.5
    NSMutableSet *matchingKeys = [[self matchingAttributesFromObject:oldPage toObject:newPage] mutableCopy];
    [matchingKeys minusSet:[[self class] elementAttributesToIgnore]];
    [matchingKeys removeObject:@"isStale"];
    [matchingKeys removeObject:@"allowComments"];
    
    
    // It is essential that "publishedPath" is migrated before anything involving other paths/titles
    [matchingKeys removeObject:@"publishedPath"];
    [newPage setValue:[oldPage valueForKey:@"publishedPath"] forKey:@"publishedPath"];
    
    
    // Migrate filenames manually, since the acceessor behavior is different for 1.2
    [matchingKeys removeObject:@"fileName"];
    NSString *filename = [oldPage valueForKey:@"fileName"];
    if (filename) [newPage setFileName:filename];
    
    
    // Do automated migration of remaining keys. However, there's a couple of special cases we should NOT import.
    [self migrateAttributes:matchingKeys fromObject:oldPage toObject:newPage];
    [matchingKeys release];
    
    
    // Comments work slightly differently in 1.5, so migrate them manually.
    BOOL allowComments = NO;
    if ([[newPage master] valueForKey:@"haloscanUserName"])
    {
        allowComments = [oldPage boolForKey:@"allowComments"];
    }
    [newPage setBool:allowComments forKey:@"allowComments"];
    
    
    // Keywords
    KTStoredArray *keywords = [oldPage valueForKey:@"keywords"];
    [newPage setKeywords:[keywords allValues]];
    
    
    // Migrate Code Injection from the weird old addString2 hack.
    NSString *addString2 = [oldPage valueForKey:@"addString2"];
    NSDictionary *addString2Dictionary = nil;
	if (addString2)
    {
        addString2Dictionary = [NSData foundationObjectFromEncodedString:addString2];
    }
	
	[self migrateCodeInjection:[addString2Dictionary valueForKey:@"insertBody"]
						 toKey:@"codeInjectionBodyTag"
					 propogate:[addString2Dictionary valueForKey:@"propagateInsertBody"]
						toPage:newPage];
	
	[self migrateCodeInjection:[addString2Dictionary valueForKey:@"insertEndBody"]
						 toKey:@"codeInjectionBodyTagEnd"
					 propogate:[addString2Dictionary valueForKey:@"propagateInsertEndBody"]
						toPage:newPage];
	
	[self migrateCodeInjection:[oldPage valueForKey:@"insertPrelude"]
						 toKey:@"codeInjectionBeforeHTML"
					 propogate:[addString2Dictionary valueForKey:@"propagateInsertPrelude"]
						toPage:newPage];
	
	[self migrateCodeInjection:[oldPage valueForKey:@"insertHead"]
						 toKey:@"codeInjectionHeadArea"
					 propogate:[addString2Dictionary valueForKey:@"propagateInsertHead"]
						toPage:newPage];
    
    
    // Migrate custom summary if it exists, including media refs
    NSString *customSummary = [oldPage valueForKey:@"summaryHTML"];
    if (customSummary && ![customSummary isEqualToString:@""])
    {
        customSummary = [[[self migratedDocument] mediaManager] importLegacyMediaFromString:customSummary
                                                                   scalingSettingsName:@"inTextMediumImage"
                                                                            oldElement:oldPage
                                                                            newElement:newPage];
        
        [newPage setCustomSummaryHTML:customSummary];
    }
    
    
    // We want photo grids to have navigation arrows turned on.
    if ([newPage isCollection] && [[newPage valueForKey:@"collectionIndexBundleIdentifier"] isEqualToString:@"sandvox.PhotoGridIndex"])
    {
        [newPage setBool:YES forKey:@"collectionShowNavigationArrows"];
    }
    
    
    // Migrate the special addX properties
    BOOL excludeFromSitemap = [oldPage boolForKey:@"addBool1"];
    [newPage setBool:!excludeFromSitemap forKey:@"includeInSiteMap"];
    
    
    // Import plugin-specific properties
    BOOL result = [self migrateElementContainer:oldPage toElement:newPage error:error];
    
	
	if (result)
	{
		// Thumbnail - do this after plugin properties to keep it up-to-date.
		KTMediaContainer *thumbnail = [[[self migratedDocument] mediaManager] mediaContainerWithMediaRefNamed:@"thumbnail" element:oldPage];
		if (thumbnail)
		{
			[newPage setThumbnail:thumbnail];
		}
		
		
		// Import pagelets
		result = [self migratePageletsFromPage:oldPage toPage:newPage error:error];
        
        
        // We're pretty much done with that page, update the UI
        [self performSelectorOnMainThread:@selector(incrementCountOfPagesMigrated) withObject:nil waitUntilDone:NO];
		
		
		if (result)
		{
			// Create new KTPage objects for each child page and then recursively migrate them too
			result = [self migrateChildrenFromPage:oldPage toPage:newPage error:error];
		}
	}
	
	
	return result;
}

- (void)migrateCodeInjection:(NSString *)code toKey:(NSString *)newKey propogate:(NSNumber *)propogate toPage:(KTPage *)newPage
{
    if (code && ![code isEqualToString:@""])
    {
        if (!propogate || [propogate boolValue])    // nil values are assumed to be a YES
        {
            if ([newPage isRoot])
            {
                [[newPage master] setValue:code forKey:newKey];
            }
            else
            {
                [newPage setValue:code forKey:newKey recursive:YES];
            }
        }
        else
        {
            [newPage setValue:code forKey:newKey];
        }
    }
}

/*  Migrate the children of one page to another
 */
- (BOOL)migrateChildrenFromPage:(NSManagedObject *)oldParentPage toPage:(KTPage *)newParentPage error:(NSError **)error
{
    NSSet *oldChildPages = [oldParentPage valueForKey:@"children"];
    NSArray *sortedOldChildren = [[oldChildPages allObjects] sortedArrayUsingDescriptors:[NSSortDescriptor orderingSortDescriptors]];
    
    NSEnumerator *childrenEnumerator = [sortedOldChildren objectEnumerator];
    NSManagedObject *aChildPage;
    while (aChildPage = [childrenEnumerator nextObject])
    {
        // Use a local autorelease pool to keep memory down
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        
        
        // Insert a new child page of the right type.
        NSString *pluginIdentifier = [aChildPage valueForKey:@"pluginIdentifier"];
        pluginIdentifier = [[self class] currentPluginIdentifierForOldIdentifier:pluginIdentifier];
        KTElementPlugin *plugin = [KTElementPlugin pluginWithIdentifier:pluginIdentifier];
        
        if (!plugin)
        {
			if (error)
			{
				*error = [NSError errorWithDomain:kKTDataMigrationErrorDomain
											 code:KareliaError
							 localizedDescription:[NSString stringWithFormat:NSLocalizedString(@"No plug-in found with the identifier %@", @""), pluginIdentifier]];
			}
            [pool release];
			return NO;
        }
        
        KTPage *aNewPage = [KTPage insertNewPageWithParent:newParentPage plugin:plugin];
        
        
        // Migrate data from old page to new
        if (![self migratePage:aChildPage toPage:aNewPage error:error])
        {
            [pool release];
            return NO;
        }
        
        
        // Save the migrated objects. Otherwise for really big sites a single final save uses too much memory
        /*KTDocument *document = [self migratedDocument];
		if (![document writeToURL:[document fileURL] ofType:[document fileType] forSaveOperation:NSSaveOperation originalContentsURL:[document fileURL] includeMetadata:NO error:error])
        {
            [pool release];
            return NO;
        }*/     // Disabled since it wasn't the root problem, and signifcantly slow doc importing.
        
		
		// Tidy up.The old page is finished with, it can be turned back into a fault to conserve memory
		[[aChildPage managedObjectContext] refreshObject:aChildPage mergeChanges:NO];
		[pool release];
    }
    
    
    return YES;
}

/*  Root is special because it contains a bunch of properties which now belong on KTMaster.
 *  Otherwise, we can do normal page migration.
 */
- (BOOL)migrateRootPage:(NSManagedObject *)oldRoot error:(NSError **)error
{
    OBASSERT(oldRoot);
    
    // Migrate simple properties from Root to the Master
    KTSite *newDocInfo = [[self migratedDocument] site];
    KTPage *newRoot = [newDocInfo root];
    KTMaster *newMaster = [newRoot master];
    
    [self migrateMatchingAttributesFromObject:oldRoot toObject:newMaster];
    
    
    // Import the design separately
    NSString *designIdentifier = [oldRoot valueForKey:@"designBundleIdentifier"];
    if (designIdentifier) [newMaster setDesignBundleIdentifier:designIdentifier];   // Fallback to Sandvox default
    
    
    // Media copying and google stuff are document settings
    [newDocInfo setCopyMediaOriginals:[oldRoot integerForKey:@"copyMediaOriginals"]];
    
    BOOL generateGoogleSitemap = [oldRoot boolForKey:@"addBool2"];
    [newDocInfo setBool:generateGoogleSitemap forKey:@"generateGoogleSitemap"];
    
    
    // Migrate master media - logo, banner & favicon
    KTMediaContainer *favicon = [[[self migratedDocument] mediaManager] mediaContainerWithMediaRefNamed:@"favicon" element:oldRoot];
    [newMaster setFavicon:favicon];
    
    // Migrate logo
    KTMediaContainer *logo = [[[self migratedDocument] mediaManager] mediaContainerWithMediaRefNamed:@"headerImage" element:oldRoot];
    [newMaster setLogoImage:logo];
    
    KTMediaContainer *banner = [[[self migratedDocument] mediaManager] mediaContainerWithMediaRefNamed:@"bannerImage" element:oldRoot];
    [newMaster setBannerImage:banner];
    
    
    // Migrate the weird old addString2 hack.
    NSString *addString2 = [oldRoot valueForKey:@"addString2"];
    if (addString2)
    {
        NSDictionary *addString2Dictionary = [NSData foundationObjectFromEncodedString:addString2];
		
        [newDocInfo setValue:[addString2Dictionary valueForKey:@"googleAnalytics"] forKey:@"googleAnalyticsCode"];
        [newDocInfo setValue:[addString2Dictionary valueForKey:@"googleSiteVerification"] forKey:@"googleSiteVerification"];
	}
    
    
    // Continue with normal page migration
    BOOL result = [self migratePage:oldRoot toPage:newRoot error:error];
    
    
    return result;
}

#pragma mark -
#pragma mark Pagelet Migration

- (BOOL)migratePagelet:(NSManagedObject *)oldPagelet toPagelet:(KTPagelet *)newPagelet error:(NSError **)error
{
    // Migrate the matching keys. However, there's a couple of special cases we should NOT import.
    NSMutableSet *matchingKeys = [[self matchingAttributesFromObject:oldPagelet toObject:newPagelet] mutableCopy];
    [matchingKeys minusSet:[[self class] elementAttributesToIgnore]];
    
    [self migrateAttributes:matchingKeys fromObject:oldPagelet toObject:newPagelet];
    
    [matchingKeys release];
    
    
    // Do normal element migration
    BOOL result = [self migrateElementContainer:oldPagelet toElement:newPagelet error:error];
    return result;
}

- (BOOL)migratePageletsFromPage:(NSManagedObject *)oldPage toPage:(KTPage *)newPage error:(NSError **)error
{
    NSSet *oldCallouts = [oldPage valueForKey:@"callouts"];
    NSSet *oldSidebars = [oldPage valueForKey:@"sidebars"];
    
    NSMutableSet *oldPagelets = [oldCallouts mutableCopy];  [oldPagelets unionSet:oldSidebars];
    NSArray *sortedOldPagelets = [[oldPagelets allObjects] sortedArrayUsingDescriptors:[NSSortDescriptor orderingSortDescriptors]];
    [oldPagelets release];
    
    NSEnumerator *oldPageletsEnumerator = [sortedOldPagelets objectEnumerator];
    NSManagedObject *anOldPagelet;
    while (anOldPagelet = [oldPageletsEnumerator nextObject])
    {
        NSString *pageletIdentifier = [[self class] currentPluginIdentifierForOldIdentifier:[anOldPagelet valueForKey:@"pluginIdentifier"]];
        KTPageletLocation pageletLocation = ([anOldPagelet valueForKey:@"calloutOwner"]) ? KTCalloutPageletLocation : KTSidebarPageletLocation;
        KTPagelet *newPagelet = [KTPagelet insertNewPageletWithPage:newPage pluginIdentifier:pageletIdentifier location:pageletLocation];
        
        if (![self migratePagelet:anOldPagelet toPagelet:newPagelet error:error])
        {
            return NO;
        }
		
		// The pagelet is finished with, so it can be turned back into a fault to conserve memory
		[[anOldPagelet managedObjectContext] refreshObject:anOldPagelet mergeChanges:NO];
    }
    
    return YES;
}

#pragma mark -
#pragma mark Element Migration

+ (NSSet *)elementAttributesToIgnore
{
    static NSSet *result;
    if (!result)
    {
        result = [[NSSet alloc] initWithObjects:@"pluginIdentifier", @"pluginVersion", @"ordering", nil];
    }
    
    return result;
}

- (BOOL)migrateElementContainer:(NSManagedObject *)oldElementContainer toElement:(KTAbstractElement *)newElement error:(NSError **)error
{
    // 1.5 doesn't support the old nested element hierarchy. Instead we do the import from the subelement
    NSManagedObject *oldElement = oldElementContainer;
    NSSet *subelements = [oldElementContainer valueForKey:@"elements"];
    if ([subelements count] > 0)
    {
        oldElement = [subelements anyObject];
    }
    
    
    // Migrate element properties
    BOOL result = [self migrateElement:oldElement toElement:newElement error:error];
	
    
    // We then specially handle importing introductionHTML as it is a container-level property
    if (result)
    {
        // Figure out the maximum image size we'll allow
        NSString *settings = @"inTextMediumImage";
        if ([newElement isKindOfClass:[KTPagelet class]])
        {
            settings = @"sidebarImage";
        }
        
        
        // Update media refs to the new system.
        NSString *oldText;
        if ([[[oldElementContainer entity] attributesByName] objectForKey:@"introductionHTML"])
        {
            oldText = [oldElementContainer valueForKey:@"introductionHTML"];
        }
        else
        {
            oldText = [oldElementContainer valueForKeyPath:@"pluginProperties.introductionHTML"];
        }
        
        NSString *newText = [[newElement mediaManager] importLegacyMediaFromString:oldText
                                                         scalingSettingsName:settings
                                                                  oldElement:oldElementContainer
                                                                  newElement:newElement];
        
        [newElement setValue:newText forKey:@"introductionHTML"];
    }
    
	
	// If the element is finished with, it can be turned back into a fault to conserve memory
    if (oldElement != oldElementContainer)
	{
		[[oldElement managedObjectContext] refreshObject:oldElement mergeChanges:NO];
	}
	
    
    return result;
}

/*  Handles generic migration of elements. Mostly this comprises moving over plugin properties.
 */
- (BOOL)migrateElement:(NSManagedObject *)oldElement toElement:(KTAbstractElement *)newElement error:(NSError **)error
{
    // Exit if the user cancelled
    if ([self isCancelled])
    {
		if (error)
		{
			*error = nil;
		}
        return NO;
    }
    
    KTStoredDictionary *oldPluginProperties = [oldElement valueForKey:@"pluginProperties"];
    BOOL result = [newElement importPluginProperties:[oldPluginProperties dictionary] fromPlugin:oldElement error:error];
    return result;
}

#pragma mark -
#pragma mark Site-Level Migration

/*  Takes the old document info object and copies out all properties that still apply.
 */
- (BOOL)migrateDocumentInfo:(NSError **)error
{
	// Retrieve document infos
    NSArray *docInfos = [[self oldManagedObjectContext] allObjectsWithEntityName:@"Site" error:error];
    if (!docInfos) return NO;
    
    NSManagedObject *oldDocInfo = [docInfos firstObjectKS];
    OBASSERT(oldDocInfo);
    
    KTSite *newDocInfo = [[self migratedDocument] site];
    OBASSERT(newDocInfo);
    
    
    // Run through attributes, copying those that still remain.
	NSMutableSet *attributes = [[self matchingAttributesFromObject:oldDocInfo toObject:newDocInfo] mutableCopy];
	[self migrateAttributes:attributes fromObject:oldDocInfo toObject:newDocInfo];
	
    
    // Migrate host properties
    KTStoredDictionary *oldHostProperties = [oldDocInfo valueForKey:@"hostProperties"];
    KTHostProperties *newHostProperties = [[[self migratedDocument] site] hostProperties];
    [newHostProperties setValuesForKeysWithDictionary:[oldHostProperties dictionary]];
    
    
    // Move onto individual pages
    BOOL result = NO;
    NSArray *allPages = [[self oldManagedObjectContext] allObjectsWithEntityName:@"Page" error:error];
    if (allPages)
    {
        [self performSelectorOnMainThread:@selector(_setCountOfPagesToMigrate:)
                               withObject:[NSNumber numberWithUnsignedInt:[allPages count]]
                            waitUntilDone:NO];
        
        result = [self migrateRootPage:[oldDocInfo valueForKey:@"root"] error:error];
    }
    
    return result;
}

#pragma mark -
#pragma mark Generic Migration methods

/*  Compares two objects to find their common attributes.
 */
- (NSSet *)matchingAttributesFromObject:(NSManagedObject *)oldObject toObject:(NSManagedObject *)newObject
{
    NSSet *oldAttributeKeys = [[NSSet alloc] initWithArray:[[oldObject entity] attributeKeys]];
	NSSet *newAttributeKeys = [[NSSet alloc] initWithArray:[[newObject entity] attributeKeys]];
	
    NSMutableSet *buffer = [oldAttributeKeys mutableCopy];
    [buffer intersectSet:newAttributeKeys];
    
    // Tidy up
    [oldAttributeKeys release];
    [newAttributeKeys release];
    
    NSSet *result = [[buffer copy] autorelease];
    [buffer release];
    return result;
}

/*  Copies attribute values from managedObjectA to managedObjectB that exist in both entities */
- (void)migrateMatchingAttributesFromObject:(NSManagedObject *)oldObject toObject:(NSManagedObject *)newObject
{
    NSSet *matchingKeys = [self matchingAttributesFromObject:oldObject toObject:newObject];
    [self migrateAttributes:matchingKeys fromObject:oldObject toObject:newObject];
}

/*  Migrates the specified attributes from one object to another.
 *  The migration is clever enough to key-value validation; invalid values are ignored.
 */
- (void)migrateAttributes:(NSSet *)attributeKeys fromObject:(NSManagedObject *)oldObject toObject:(NSManagedObject *)newObject
{
    // Loop through the attributes
    NSEnumerator *keysEnumerator = [attributeKeys objectEnumerator];
    NSString *anAttributeKey;
    while (anAttributeKey = [keysEnumerator nextObject])
	{
        id aValue = [oldObject valueForKey:anAttributeKey];
        
        // Only store the value if it's valid
        if ([newObject validateValue:&aValue forKey:anAttributeKey error:NULL])
        {
            [newObject setValue:aValue forKey:anAttributeKey];
        }
        else
        {
            if (![anAttributeKey isEqualToString:@"collectionSummaryType"])	// It's regular and expected so make an exception
			{
				NSLog(@"Not migrating value for key %@; it is invalid.\n\nOriginal object:\n%@\n\nNew Object:\n%@",
					  anAttributeKey,
					  [oldObject objectID],
					  [newObject objectID]);
			}
        }
    }
}


#pragma mark -
#pragma mark Support

+ (NSString *)renamedFileName:(NSString *)originalFileNameWithExtension modelVersion:(NSString *)aVersion
{
	NSString *fileName = [originalFileNameWithExtension stringByDeletingPathExtension];
	NSString *extension = [originalFileNameWithExtension pathExtension];
	NSString *previous = NSLocalizedString(@"previous",
										   "name appened to copy of file before version migration");
	
	//return [NSString stringWithFormat:@"%@-%@.%@", fileName, aVersion, extension];
	NSString *preferredPath = [NSString stringWithFormat:@"%@-%@.%@", fileName, previous, extension];
    NSString *finalFilename = [[NSFileManager defaultManager] uniqueFilenameAtPath:preferredPath];
    NSString *result = [[preferredPath stringByDeletingLastPathComponent] stringByAppendingPathComponent:finalFilename];
    return result;
}

// this is a slightly cleaned up method from Apple's Migrator example
+ (BOOL)validatePathForNewStore:(NSString *)aStorePath error:(NSError **)outError
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *storeDirectory = [aStorePath stringByDeletingLastPathComponent];
    
	// check that we at least have aStorePath
    if (nil == aStorePath || [@"" isEqualToString:aStorePath])
	{
		if (outError)
		{
			*outError = [NSError errorWithDomain:kKTDataMigrationErrorDomain code:KSNoDocPathSpecified localizedDescription:NSLocalizedString(@"No document path specified.","No document path specified.")];
		}
        return NO;
    }
    
	// does aStorePath already exist? if so, can we overwrite it?
	// if not, does it have a valid parent directory?
	// if not, create a valid path
    BOOL isDirectory = NO;
    if ([fileManager fileExistsAtPath:aStorePath isDirectory:&isDirectory])
	{
        if ( isDirectory ) 
		{
			if (outError)
			{
				*outError = [NSError errorWithDomain:kKTDataMigrationErrorDomain code:KSPathIsDirectory localizedDescription:NSLocalizedString(@"Specified document path is a directory.","Specified document path is a directory.")];
			}
            return NO;
        } 
	} 
	else if ( [fileManager fileExistsAtPath:storeDirectory isDirectory:&isDirectory] ) 
	{
        if ( isDirectory )
		{
            if ( ![fileManager isWritableFileAtPath:storeDirectory] ) 
			{
				if (outError)
				{
					*outError = [NSError errorWithDomain:kKTDataMigrationErrorDomain code:KSDirNotWritable localizedDescription:[NSString stringWithFormat:
                                                                                                                             NSLocalizedString(@"Can\\U2019t write file to path - directory is not writable (%@)","Error: Can't write file to path - directory is not writable (%@)"), storeDirectory]];
				}
                return NO;
            }
        }
		else
		{
			if (outError)
			{
				*outError = [NSError errorWithDomain:kKTDataMigrationErrorDomain code:KSParentNotDirectory localizedDescription:[NSString stringWithFormat:
                                                                                                                             NSLocalizedString(@"Can\\U2019t write file to path - parent is not a directory (%@)","Error: Can't write file to path - parent is not a directory (%@)"), storeDirectory]];
			}
            return NO;
        }
    }
	else
	{
        return [KTUtilities createPathIfNecessary:storeDirectory error:outError];
    }
	
    return YES;
}

@end


#pragma mark -


@implementation KTAbstractElement (KTDataMigratorAdditions)

- (BOOL)importPluginProperties:(NSDictionary *)oldPluginProperties
                    fromPlugin:(NSManagedObject *)oldPlugin
                         error:(NSError **)error
{
    BOOL result = NO;
    
    id delegate = [self delegate];
    if (delegate && [delegate respondsToSelector:@selector(importPluginProperties:fromPlugin:error:)])
    {
        result = [delegate importPluginProperties:oldPluginProperties fromPlugin:oldPlugin error:error];
    }
    else
    {
        [self setValuesForKeysWithDictionary:oldPluginProperties];
        result = YES;
    }
    
    
    return result;
}

@end

