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
#import "SVLink.h"
#import "KTMaster.h"
#import "SVMediaRecord.h"
#import "KTPage.h"
#import "SVTextAttachment.h"
#import "SVWebEditorHTMLContext.h"

#import "NSManagedObject+KTExtensions.h"

#import "NSBitmapImageRep+Karelia.h"


@interface SVImage ()
@property(nonatomic, copy) NSData *linkData;
@end


#pragma mark -


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

- (BOOL)isPagelet;
{
    // Images are no longer pagelets once you turn off all additional stuff like title & caption
    if ([[self placement] intValue] == SVGraphicPlacementInline &&
        ![self showsTitle] &&
        ![self showsIntroduction] &&
        ![self showsCaption])
    {
        return NO;
    }
    else
    {
        return [super isPagelet];
    }
}

- (BOOL)mustBePagelet; { return NO; }

+ (NSSet *)keyPathsForValuesAffectingIsPagelet;
{
    return [NSSet setWithObjects:
            @"placement",
            @"showsTitle",
            @"showsIntroduction",
            @"showsCaption", nil];
}

#pragma mark Link

- (SVLink *)link;
{
    [self willAccessValueForKey:@"link"];
    SVLink *result = [self primitiveValueForKey:@"link"];
    [self didAccessValueForKey:@"link"];
    
    if (!result)
    {
        NSData *data = [self linkData];
        if (data)
        {
            result = [NSKeyedUnarchiver unarchiveObjectWithData:data];
            
            SVSiteItem *page = [SVSiteItem siteItemForPreviewPath:[result URLString]
                                       inManagedObjectContext:[self managedObjectContext]];
            
            if (page) result = [SVLink linkWithSiteItem:page openInNewWindow:[result openInNewWindow]];

            [self setPrimitiveValue:result forKey:@"link"];
        }
    }
    
    return result;
}

- (void)setLink:(SVLink *)link;
{
    [self willChangeValueForKey:@"link"];
    [self setPrimitiveValue:link forKey:@"link"];
    [self didChangeValueForKey:@"link"];
    
    
    // If the link is to a page, actually archive a different link that references the ID-only
    if ([link page])
    {
        link = [SVLink linkWithURLString:[link URLString] openInNewWindow:[link openInNewWindow]];
    }
    
    NSData *data = (link ? [NSKeyedArchiver archivedDataWithRootObject:link] : nil);
    [self setLinkData:data];
}

@dynamic linkData;

#pragma mark Publishing

@dynamic storageType;

- (NSString *)type;
{
    return [NSBitmapImageRep ks_typeForBitmapImageFileType:[[self storageType] intValue]];
}

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
    NSString *idName = [@"image-" stringByAppendingString:[self elementID]];
    
    
    // Actually write the image
    [context pushElementAttribute:@"id" value:idName];
    [self buildClassName:context];
    
    SVMediaRecord *media = [self media];
    if (media)
    {
        [context writeImageWithSourceMedia:media
                                       alt:alt
                                     width:[self width]
                                    height:[self height]
                                      type:[self type]];
    }
    else
    {
        NSURL *URL = [self externalSourceURL];
        
        [context writeImageWithSrc:(URL ? [context relativeURLStringOfURL:URL] : @"")
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
    
    NSURL *URL = [self sourceURL];
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
