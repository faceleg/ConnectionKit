//
//  SVMigrationManager.m
//  Sandvox
//
//  Created by Mike on 14/02/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "SVMigrationManager.h"

#import "SVMediaMigrationPolicy.h"

#import "KTDocument.h"
#import "SVGraphicFactory.h"
#import "SVMediaGraphic.h"
#import "SVMediaRecord.h"
#import "SVRichText.h"
#import "SVTextAttachment.h"
#import "KT.h"

#import "KSExtensibleManagedObject.h"
#import "KSURLUtilities.h"


@interface SVMigrationManager ()
@property(nonatomic) float migrationProgressOverride;
@end


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
                SVMediaGraphic *graphic = (id)[[SVGraphicFactory mediaPlaceholderFactory] insertNewGraphicInManagedObjectContext:[richText managedObjectContext]];
                
                if ([[srcURL scheme] isEqualToString:@"svxmedia"])
                {
                    SVMediaRecord *record = [SVMediaMigrationPolicy createDestinationInstanceForSourceInstance:nil
                                                                          mediaContainerIdentifier:[srcURL ks_lastPathComponent]
                                                                                     entityMapping:mapping
                                                                                           context:[richText managedObjectContext]
                                                                                           manager:self
                                                                                             error:NULL];
                    
                    // Media migration does not assign a SVMedia object to the record, so we do it
                    [record forceUpdateFromURL:[self destinationURLOfMediaWithFilename:[record filename]]];
                    [graphic setSourceWithMediaRecord:record];
                }
                if (![graphic media])
                {
                    [graphic setSourceWithExternalURL:srcURL];
                }
                
                
                // Alt text
                NSString *alt = [[imageElement attributeForName:@"alt"] stringValue];
                if (alt) [graphic setExtensibleProperty:alt forKey:@"alternateText"];
                
                
                // Metrics
                [graphic makeOriginalSize];
                
                
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

- (BOOL)migrateDocumentFromURL:(NSURL *)sourceDocURL
              toDestinationURL:(NSURL *)dURL
                         error:(NSError **)outError;
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
    
    
    
    // Import embedded images
    if (result)
    {
        KTDocument *dDoc = [[KTDocument alloc] initWithContentsOfURL:dURL
                                                              ofType:kSVDocumentTypeName
                                                               error:outError];
        if (dDoc)
        {
            NSArray *richText = [[dDoc managedObjectContext] fetchAllObjectsForEntityForName:@"RichText" error:NULL];
            NSEntityMapping *mapping = [[mappingModel entityMappingsByName] objectForKey:@"EmbeddedImageToGraphicMedia"];
            
            NSUInteger i = 0;
            float count = [richText count];
            
            for (SVRichText *aRichTextObject in richText)
            {
                [self migrateEmbeddedImagesFromRichText:aRichTextObject mapping:mapping];
                
                // Update progress to match
                i++;
                float override = 0.8f + 0.2f * (i / count);
                [self setMigrationProgressOverride:override];
            }
            
            
            result = [dDoc saveToURL:[dDoc fileURL] ofType:[dDoc fileType] forSaveOperation:NSSaveOperation error:outError];
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
    return [_destinationURL ks_URLByAppendingPathComponent:filename isDirectory:NO];
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
        result = 0.8 * [super migrationProgress];
    }
    return result;
}
+ (NSSet *)keyPathsForValuesAffectingMigrationProgress;
{
    return [NSSet setWithObject:@"migrationProgressOverride"];
}

@synthesize migrationProgressOverride = _progressOverride;

@end
