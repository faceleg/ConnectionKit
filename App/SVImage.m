// 
//  SVImage.m
//  Sandvox
//
//  Created by Mike on 27/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVImage.h"

#import "SVApplicationController.h"
#import "SVImageDOMController.h"
#import "KTMaster.h"
#import "SVMediaRecord.h"
#import "KTPage.h"
#import "SVTextAttachment.h"
#import "SVWebEditorHTMLContext.h"

#import "NSManagedObject+KTExtensions.h"


@implementation SVImage 

+ (SVImage *)insertNewImageWithMedia:(SVMediaRecord *)media;
{
    OBPRECONDITION(media);
    
    SVImage *result = [self insertNewImageInManagedObjectContext:[media managedObjectContext]];
    [result setMedia:media];
    
    [result makeOriginalSize];
    [result setConstrainProportions:YES];
    
    return result;
}

+ (SVImage *)insertNewImageInManagedObjectContext:(NSManagedObjectContext *)context;
{
    SVImage *result = [NSEntityDescription insertNewObjectForEntityForName:@"Image"
                                                    inManagedObjectContext:context];
    return result;
}

- (void)awakeFromInsert
{
    [super awakeFromInsert];
    
    // Use same format & compression as last image
    BOOL prefersPNG = [[NSUserDefaults standardUserDefaults] boolForKey:kSVPrefersPNGImageFormatKey];
    if (prefersPNG)
    {
        [self setStorageType:[NSNumber numberWithInteger:NSPNGFileType]];
    }
}

- (void)willInsertIntoPage:(KTPage *)page;
{
    // Placeholder image
    if (![self media])
    {
        SVMediaRecord *media = [[[page rootPage] master] makePlaceholdImageMediaWithEntityName:@"GraphicMedia"];
        [self setMedia:media];
        
        [self makeOriginalSize];    // calling super will scale back down if needed
        [self setConstrainProportions:YES];
    }
    
    [super willInsertIntoPage:page];
    
    // Show caption
    if ([[[self textAttachment] placement] intValue] != SVGraphicPlacementInline)
    {
        [self setShowsCaption:YES];
    }
}

- (void)didAddToPage:(id <SVPage>)page;
{
    [super didAddToPage:page];
    
    
    // Start off at a decent size.
    NSNumber *maxWidth = [NSNumber numberWithUnsignedInteger:490];
    if ([self isPagelet]) maxWidth = [NSNumber numberWithUnsignedInteger:200];
    
    if ([[self width] isGreaterThan:maxWidth])
    {
        [self setWidth:maxWidth];
    }
}

#pragma mark Media

- (void)setMediaWithURL:(NSURL *)URL;
{
    [super setMediaWithURL:URL];
    
    if ([self constrainProportions])    // generally true
    {
        // Resize image to fit in space
        NSNumber *width = [self width];
        [self makeOriginalSize];
        if ([[self width] isGreaterThan:width]) [self setWidth:width];
    }
}

#pragma mark Metrics

@dynamic alternateText;

#pragma mark Placement

- (BOOL)canPlaceInline; { return YES; }

#pragma mark Link

@dynamic link;

#pragma mark Publishing

@dynamic storageType;
@dynamic compressionFactor;

#pragma mark HTML

- (void)writeBody:(SVHTMLContext *)context
{
    // alt=
    NSString *alt = [self alternateText];
    if (!alt) alt = @"";
    
    // Link
    BOOL isPagelet = [self isPagelet];
    if (isPagelet && [self link])
    {
        [context startAnchorElementWithHref:[[self link] URLString] title:nil target:nil rel:nil];
    }
    
    
    // Image needs unique ID for DOM Controller to find
    NSString *idName = [@"image-" stringByAppendingString:[self elementIdName]];
    
    // Actually write the image
    SVMediaRecord *media = [self media];
    if (media)
    {
        [context writeImageWithIdName:idName
                            className:(isPagelet ? nil : [self className])
                          sourceMedia:media
                                  alt:alt
                                width:[self width]
                               height:[self height]];
    }
    else
    {
        NSURL *URL = [self imagePreviewURL];
        [context writeImageWithIdName:idName
                            className:(isPagelet ? nil : [self className])
                                  src:(URL ? [context relativeURLStringOfURL:URL] : @"")
                                  alt:alt
                                width:[[self width] description]
                               height:[[self height] description]];
    }
    
    [context addDependencyOnObject:self keyPath:@"media"];
    [context addDependencyOnObject:self keyPath:@"className"];
    
    
    if ([self isPagelet] && [self link]) [context endElement];
}

- (BOOL)shouldPublishEditingElementID; { return NO; }

#pragma mark Thumbnail

- (id <IMBImageItem>)thumbnail { return [self media]; }
+ (NSSet *)keyPathsForValuesAffectingThumbnail { return [NSSet setWithObject:@"media"]; }

#pragma mark Serialization

- (void)populateSerializedProperties:(NSMutableDictionary *)propertyList;
{
    [super populateSerializedProperties:propertyList];
    
    // Write image data
    SVMediaRecord *media = [self media];
    
    NSData *data = [media fileContents];
    [propertyList setValue:data forKey:@"fileContents"];
    
    NSURL *URL = [self imagePreviewURL];
    [propertyList setValue:[URL absoluteString] forKey:@"sourceURL"];
}

- (void)awakeFromPropertyList:(id)propertyList;
{
    [super awakeFromPropertyList:propertyList];
    
    // Pull out image data
    NSData *data = [propertyList objectForKey:@"fileContents"];
    if (data)
    {
        NSString *url = [propertyList objectForKey:@"sourceURL"];
        
        NSURLResponse *response = [[NSURLResponse alloc]
                                   initWithURL:(url ? [NSURL URLWithString:url] : nil)
                                   MIMEType:nil
                                   expectedContentLength:[data length]
                                   textEncodingName:nil];
        
        SVMediaRecord *media = [SVMediaRecord mediaWithFileContents:data
                                                        URLResponse:response
                                                         entityName:@"GraphicMedia"
                                     insertIntoManagedObjectContext:[self managedObjectContext]];
        [response release];
        
        [self setMedia:media];
    }
}

@end
