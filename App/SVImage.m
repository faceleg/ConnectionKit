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
#import "SVMediaGraphicInspector.h"
#import "SVMediaRecord.h"
#import "KTPage.h"
#import "SVTextAttachment.h"
#import "SVWebEditorHTMLContext.h"

#import "NSManagedObject+KTExtensions.h"

#import "NSBitmapImageRep+Karelia.h"
#import "NSString+Karelia.h"
#import "NSURL+Karelia.h"


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
    [result setTypeToPublish:[media typeOfFile]];
    
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

- (void)willInsertIntoPage:(KTPage *)page;
{
    // Placeholder image
    if (![self media])
    {
        SVMediaRecord *media = [[[page rootPage] master] makePlaceholdImageMediaWithEntityName:@"GraphicMedia"];
        [self setMedia:media];
        [self setTypeToPublish:[media typeOfFile]];
        
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
    
    // Match file type
    [self setTypeToPublish:[[self media] typeOfFile]];
}

- (NSArray *) allowedFileTypes
{
	return [NSArray arrayWithObject:(NSString *)kUTTypeImage];
}

#pragma mark Metrics

@dynamic alternateText;

#pragma mark Placement

- (BOOL)displayInline;
{
    BOOL result = [super displayInline];
    
    // Images become inline once you turn off all additional stuff like title & caption
    if (![self isPagelet])
    {
        SVTextAttachment *attachment = [self textAttachment];
        if (![[attachment causesWrap] boolValue])
        {
            result = YES;
        }
        else
        {
            SVGraphicWrap wrap = [[attachment wrap] intValue];
            result = (wrap == SVGraphicWrapRight ||
                      wrap == SVGraphicWrapLeft ||
                      wrap == SVGraphicWrapCenter);
        }
    }
    
    return result;
}

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

- (BOOL)canDisplayInline; { return YES; }

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

- (NSBitmapImageFileType)storageType;
{
    NSBitmapImageFileType result = [NSBitmapImageRep typeForUTI:[self typeToPublish]];
    return result;
}
- (void) setStorageType:(NSBitmapImageFileType)storageType;
{
    [self setTypeToPublish:[NSBitmapImageRep ks_typeForBitmapImageFileType:storageType]];
}
+ (NSSet *)keyPathsForValuesAffectingStorageType;
{
    return [NSSet setWithObject:@"typeToPublish"];
}

@dynamic typeToPublish;

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
    if ([self displayInline]) [self buildClassName:context];
    
    [context buildAttributesForElement:@"img" bindSizeToObject:self];
    
    SVMediaRecord *media = [self media];
    if (media)
    {
        [context writeImageWithSourceMedia:media
                                       alt:alt
                                     width:[self width]
                                    height:[self height]
                                      type:[self typeToPublish]];
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
    
    
    if ([self isPagelet] && [self link]) [context endElement];
}

- (BOOL)shouldPublishEditingElementID; { return NO; }

#pragma mark Inspector

- (NSString *)plugInIdentifier; // use standard reverse DNS-style string
{
	return @"com.karelia.sandvox.SVImage";
}

+ (SVInspectorViewController *)makeInspectorViewController;
{
    SVInspectorViewController *result = [[[SVMediaGraphicInspector alloc]
                                          initWithNibName:@"SVImage" bundle:nil]
                                         autorelease];
    
    return result;
}

#pragma mark Thumbnail

- (id <SVMedia>)thumbnail { return [self media]; }
+ (NSSet *)keyPathsForValuesAffectingThumbnail { return [NSSet setWithObject:@"media"]; }

#pragma mark Serialization

- (void)populateSerializedProperties:(NSMutableDictionary *)propertyList;
{
    [super populateSerializedProperties:propertyList];
    
    // Write image data
    SVMediaRecord *media = [self media];
    
    NSData *data = [NSData newDataWithContentsOfMedia:media];
    [propertyList setValue:data forKey:@"fileContents"];
    [media release];
    
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
        NSString *urlString = [propertyList objectForKey:@"sourceURL"];
        NSURL *url = [NSURL URLWithString:urlString];
        
        NSString *type = [NSString MIMETypeForUTI:
                          [NSString UTIForFilenameExtension:[url pathExtension]]];
        
        WebResource *resource = [[WebResource alloc] initWithData:data
                                                              URL:url
                                                         MIMEType:type
                                                 textEncodingName:nil
                                                        frameName:nil];
        
        SVMediaRecord *media = [SVMediaRecord mediaWithWebResource:resource
                                                        entityName:@"GraphicMedia"
                                    insertIntoManagedObjectContext:[self managedObjectContext]];
        [resource release];
        
        [self setMedia:media];
    }
}

@end
