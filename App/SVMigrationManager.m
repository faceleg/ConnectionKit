//
//  SVMigrationManager.m
//  Sandvox
//
//  Created by Mike on 14/02/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "SVMigrationManager.h"

#import "SVMediaMigrationPolicy.h"

#import "SVArticle.h"
#import "KTDesign.h"
#import "KTDocument.h"
#import "SVGraphicFactory.h"
#import "KTImageScalingSettings.h"
#import "KTMaster.h"
#import "SVMediaGraphic.h"
#import "SVMediaRecord.h"
#import "KTPage.h"
#import "SVSidebarPageletsController.h"
#import "SVTextAttachment.h"
#import "KT.h"

#import "NSManagedObjectContext+KTExtensions.h"

#import "NSError+Karelia.h"
#import "KSExtensibleManagedObject.h"
#import "KSURLUtilities.h"


@interface SVMigrationManager ()
@property(nonatomic) float migrationProgressOverride;
@end


#define SUPER_PROGRESS_MAX 0.8f


#pragma mark -


@implementation SVMigrationManager

- (id)initWithSourceModel:(NSManagedObjectModel *)sourceModel
               mediaModel:(NSManagedObjectModel *)mediaModel
         destinationModel:(NSManagedObjectModel *)destinationModel;
{
    OBPRECONDITION(mediaModel);
    
    if (self = [super initWithSourceModel:sourceModel destinationModel:destinationModel])
    {
        _mediaModel = [mediaModel retain];
    }
    
    return self;
}

- (id)initWithSourceModel:(NSManagedObjectModel *)sourceModel destinationModel:(NSManagedObjectModel *)destinationModel;
{
    return [self initWithSourceModel:sourceModel mediaModel:nil destinationModel:destinationModel];
}

#pragma mark Migration

- (void)migrateEmbeddedImagesFromRichText:(SVRichText *)richText mapping:(NSEntityMapping *)mapping;
{
    NSMutableAttributedString *html = [[richText attributedHTMLString] mutableCopy];
    
    
    // Search for embedded images
    NSScanner *imageScanner = [[NSScanner alloc] initWithString:[html string]];
    while (![imageScanner isAtEnd])
    {
        // Look for an image tag
        [imageScanner scanUpToString:@"<img" intoString:NULL];
        if ([imageScanner isAtEnd]) break;
        
        NSRange range = NSMakeRange([imageScanner scanLocation], 0);
        NSString *fragment = [[html string] substringFromIndex:range.location];
        NSXMLDocument *doc = [[NSXMLDocument alloc] initWithXMLString:fragment options:NSXMLDocumentTidyXML error:NULL];
        OBASSERT(doc);  // XML tidy shouldn't fail
        
        NSXMLElement *imageElement = [doc rootElement];
        NSString *src = [[imageElement attributeForName:@"src"] stringValue];
        if (src)
        {
            NSURL *srcURL = [NSURL URLWithString:src];
            if (srcURL)
            {
                // Create a graphic from the image
                SVMediaGraphic *graphic = (id)[[SVGraphicFactory mediaPlaceholderFactory] insertNewGraphicInManagedObjectContext:[self destinationContext]];
                
                if ([[srcURL scheme] isEqualToString:@"svxmedia"])
                {
                    SVMediaRecord *record = (id)[SVMediaMigrationPolicy
                                                 createDestinationInstanceForSourceInstance:nil
                                                 mediaContainerIdentifier:[srcURL ks_lastPathComponent]
                                                 entityMapping:mapping
                                                 manager:self
                                                 error:NULL];
                    
                    // Media migration does not assign a SVMedia object to the record, so we do it
                    if (record)
                    {
                        [record forceUpdateFromURL:[self destinationURLOfMediaWithFilename:[record filename]]];
                        [graphic performSelector:@selector(setSourceWithMediaRecord:) withObject:record];
                    }
                }
                if (![graphic media])
                {
                    [graphic setSourceWithExternalURL:srcURL];
                }
                
                
                // Alt text
                NSString *alt = [[imageElement attributeForName:@"alt"] stringValue];
                if (alt) [graphic setExtensibleProperty:alt forKey:@"alternateText"];
                
                
                // Metrics. Limit in article to old width 
                [graphic makeOriginalSize];
                
                if ([richText isKindOfClass:[SVArticle class]])
                {
                    KTDesign *design = [[[(SVArticle *)richText page] master] design];
                    KTImageScalingSettings *settings = [design imageScalingSettingsForUse:@"inTextMediumImage"];
                    NSUInteger width = [settings size].width;
                    
                    if ([[graphic width] unsignedIntegerValue] > width)
                    {
                        [graphic setContentWidth:[NSNumber numberWithUnsignedInteger:width]];
                    }
                }
                
                
                // Insert attachment too
                SVTextAttachment *attachment = [SVTextAttachment textAttachmentWithGraphic:graphic];
                
                [imageScanner scanUpToString:@">" intoString:NULL];
                range.length = [imageScanner scanLocation] - range.location + 1;
                
                [html addAttribute:@"SVAttachment" value:attachment range:range];
                
                
                // Wrap?
                NSArray *class = [[[imageElement attributeForName:@"class"] stringValue] componentsSeparatedByString:@" "];
                if ([class containsObject:@"narrow"])
                {
                    [attachment setCausesWrap:NSBOOL(YES)];
                    [attachment setWrap:[NSNumber numberWithInt:SVGraphicWrapFloat_1_0]];
                }
                else if (![richText attachmentsMustBeWrittenInline] && [class containsObject:@"wide"])
                {
                    [attachment setCausesWrap:NSBOOL(YES)];
                    [attachment setWrap:[NSNumber numberWithInt:SVGraphicWrapCenterSplit]];
                }
                else
                {
                    [attachment setCausesWrap:NSBOOL(NO)];
                }
            }
        }
        
        [doc release];
    }    
    
    
    [imageScanner release];
    
    [richText setAttributedHTMLString:html];
    [html release];
}

- (void)uniqueSidebarPageletSortKeys
{
    // Make sure sidebar pagelets have unique sort keys
    NSArray *pagelets = [SVSidebarPageletsController allSidebarPageletsInManagedObjectContext:[self destinationContext]];
    if ([pagelets count] < 2) return;
    
    
    // Bump following pagelets along as needed
    NSInteger nextSortKey = [[[pagelets objectAtIndex:0] sortKey] integerValue];
    NSUInteger i = 1;
    
    for (; i < [pagelets count]; i++)
    {
        SVGraphic *nextPagelet = [pagelets objectAtIndex:i];
        
        if ([[nextPagelet sortKey] integerValue] < nextSortKey)
        {
            [nextPagelet setSortKey:[NSNumber numberWithInteger:nextSortKey]];
        }
        else
        {
            nextSortKey = [[nextPagelet sortKey] integerValue];
        }
        
        nextSortKey++;
    }
}

- (BOOL)migrateDocumentFromURL:(NSURL *)sourceDocURL
              toDestinationURL:(NSURL *)dURL
                         error:(NSError **)outError;
{
    @try
    {
        // Create context for accessing media during migration
        NSPersistentStoreCoordinator *coordinator = [[NSPersistentStoreCoordinator alloc]
                                                     initWithManagedObjectModel:[self sourceMediaModel]];
        
        NSURL *sMediaStoreURL = [sourceDocURL ks_URLByAppendingPathComponent:@"media.xml" isDirectory:NO];
        
        if (![coordinator addPersistentStoreWithType:NSXMLStoreType
                                       configuration:nil
                                                 URL:sMediaStoreURL
                                             options:nil
                                               error:outError])
        {
            [coordinator release];
            return NO;
        }
        
        _mediaContext = [[NSManagedObjectContext alloc] init];
        [_mediaContext setPersistentStoreCoordinator:coordinator];
        [coordinator release];
        
        
        
        // Do the basic migration
        NSURL *modelURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"Sandvox" ofType:@"cdm"]];
        NSMappingModel *mappingModel = [[NSMappingModel alloc] initWithContentsOfURL:modelURL];
        
        _docURL = sourceDocURL;
        _destinationURL = dURL;
        NSURL *sStoreURL = [KTDocument datastoreURLForDocumentURL:sourceDocURL type:kSVDocumentTypeName_1_5];
        NSURL *dStoreURL = [KTDocument datastoreURLForDocumentURL:dURL type:nil];
        
        NSError *error; // NSMigrationManager hates it if you don't provide an error pointer
        BOOL result = [self migrateStoreFromURL:sStoreURL
                                           type:NSSQLiteStoreType
                                        options:nil
                               withMappingModel:mappingModel
                               toDestinationURL:dStoreURL
                                destinationType:NSBinaryStoreType
                             destinationOptions:nil
                                          error:&error];
        if (outError) *outError = error;
        
        
        
        // Custom phase
        if (result)
        {
            KTDocument *dDoc = [[KTDocument alloc] initWithContentsOfURL:dURL
                                                                  ofType:kSVDocumentTypeName
                                                                   error:outError];
            if (dDoc)
            {
                _destinationContextOverride = [dDoc managedObjectContext];
                
                
                // #108740
                // Make each non-embedded media graphic original size
                NSArray *graphics = [_destinationContextOverride fetchAllObjectsForEntityForName:@"MediaGraphic" error:NULL];
                [graphics makeObjectsPerformSelector:@selector(makeOriginalSize)];
                
                // Constrain proportions
                for (SVMediaGraphic *aGraphic in graphics)
                {
                    if ([aGraphic isConstrainProportionsEditable] &&
                        [[aGraphic width] intValue] > 0 &&
                        [[aGraphic height] intValue] > 0)
                    {
                        [aGraphic setConstrainsProportions:YES];
                    }
                }
                
                // Import embedded images
                NSArray *richText = [_destinationContextOverride fetchAllObjectsForEntityForName:@"RichText" error:NULL];
                NSEntityMapping *mapping = [[mappingModel entityMappingsByName] objectForKey:@"EmbeddedImageToGraphicMedia"];
                
                NSUInteger i = 0;
                float count = [richText count];
                
                for (SVRichText *aRichTextObject in richText)
                {
                    [self migrateEmbeddedImagesFromRichText:aRichTextObject mapping:mapping];
                    
                    // Update progress to match
                    i++;
                    float override = SUPER_PROGRESS_MAX + 0.2f * (i / count);
                    [self setMigrationProgressOverride:override];
                }
                
                
                // Then reduce size to fit on page
                [dDoc designDidChange];
                
                
                // Search for thumbnails. #108951
                // Do after resizing media, so can pick the biggest. #109087
                NSArray *pages = [_destinationContextOverride fetchAllObjectsForEntityForName:@"Page" error:NULL];
                [pages makeObjectsPerformSelector:@selector(guessThumbnailSourceGraphic)];
                
                
                
                [self uniqueSidebarPageletSortKeys];

                
                
                
                result = [dDoc saveToURL:[dDoc fileURL] ofType:[dDoc fileType] forSaveOperation:NSSaveOperation error:outError];
                _destinationContextOverride = nil;
                [dDoc close];
                [dDoc release];
            }
            else
            {
                result = NO;
            }
        }
        
        
        
        _docURL = nil;
        _destinationURL = nil;
        [mappingModel release];
        [_mediaContext release];
        
        return result;
    }
    @catch (NSException *exception)
    {
        NSError *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSMigrationError localizedDescription:[exception reason]];
        [self cancelMigrationWithError:error];
        if (outError) *outError = error;
        
        
        [NSApp reportException:exception];
    }
    
    
    return NO;
}

#pragma mark Media

- (NSManagedObjectModel *)sourceMediaModel; { return _mediaModel; }

- (NSManagedObjectContext *)sourceMediaContext; { return _mediaContext; }

- (NSURL *)sourceURLOfMediaWithFilename:(NSString *)filename;
{
    NSURL *result = [[[_docURL ks_URLByAppendingPathComponent:@"Site" isDirectory:YES]
                      ks_URLByAppendingPathComponent:@"_Media" isDirectory:YES]
                     ks_URLByAppendingPathComponent:filename isDirectory:NO];
    return result;
}

- (NSURL *)destinationURLOfMediaWithFilename:(NSString *)filename;
{
    OBPRECONDITION(filename);
    return [_destinationURL ks_URLByAppendingPathComponent:filename isDirectory:NO];
}

#pragma mark General

- (NSManagedObjectContext *)destinationContext;
{
    return (_destinationContextOverride ? _destinationContextOverride : [super destinationContext]);
}

- (NSFetchRequest *)pagesFetchRequestWithPredicate:(NSString *)predicateString;
{
    // The default request generated by Core Data ignores sub-entites, meaning the home page doesn't get migrated. So, I wrote this custom method that builds a less picky predicate.
    
    NSFetchRequest *result = [[[NSFetchRequest alloc] init] autorelease];
    [result setEntity:[self sourceEntityForEntityMapping:[self currentEntityMapping]]];
    [result setPredicate:[NSPredicate predicateWithFormat:predicateString]];
    
    return result;
}

- (NSNumber *)isNil:(id)anObject; { return NSBOOL(anObject == nil); }
- (NSNumber *)isNotNil:(id)anObject; { return NSBOOL(anObject != nil); }
- (NSNumber *)boolValue:(id)anObject; { return NSBOOL([anObject boolValue]); }

- (id)propertyListFromData:(NSData *)data;
{
    return [NSPropertyListSerialization propertyListFromData:data mutabilityOption:NSPropertyListImmutable format:NULL errorDescription:NULL];
}

- (NSDictionary *)extensiblePropertiesFromData:(NSData *)data;
{
    NSDictionary *result = [KSExtensibleManagedObject unarchiveExtensibleProperties:data];
    return result;
}

#pragma mark Progress

- (float) migrationProgress;
{
    float result;
    if (_progressOverride > 0.0f)
    {
        result = _progressOverride;
    }
    else
    {
        result = SUPER_PROGRESS_MAX * [super migrationProgress];
    }
    return result;
}
+ (NSSet *)keyPathsForValuesAffectingMigrationProgress;
{
    return [NSSet setWithObject:@"migrationProgressOverride"];
}

@synthesize migrationProgressOverride = _progressOverride;

@end
