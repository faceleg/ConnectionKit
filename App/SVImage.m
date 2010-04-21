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
#import "SVMediaRecord.h"
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

- (void)awakeFromInsertIntoPage:(id <SVPage>)page;
{
    [super awakeFromInsertIntoPage:page];
    
    
    // Start off at a decent size.
    NSNumber *maxWidth = [NSNumber numberWithUnsignedInteger:490];
    if ([self isPagelet]) maxWidth = [NSNumber numberWithUnsignedInteger:200];
    
    if ([[self width] isGreaterThan:maxWidth])
    {
        [self setWidth:maxWidth];
    }
    
    // Show caption
    [self setShowsCaption:YES];
}

#pragma mark Metrics

@dynamic alternateText;

#pragma mark Placement

- (BOOL)canBePlacedInline; { return YES; }

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
        [context writeAnchorStartTagWithHref:[[self link] URLString] title:nil target:nil rel:nil];
    }
    
    // Actually write the image
    SVMediaRecord *media = [self media];
    if (media)
    {
        [context writeImageWithIdName:[self editingElementID]
                            className:(isPagelet ? nil : [self className])
                          sourceMedia:media
                                  alt:alt
                                width:[self width]
                               height:[self height]];
    }
    else
    {
        [context writeImageWithIdName:[self editingElementID]
                            className:(isPagelet ? nil : [self className])
                                  src:[context relativeURLStringOfURL:[self imagePreviewURL]]
                                  alt:alt
                                width:[[self width] description]
                               height:[[self height] description]];
    }
    
    [context addDependencyOnObject:self keyPath:@"media"];
    [context addDependencyOnObject:self keyPath:@"className"];
    
    
    if ([self isPagelet] && [self link]) [context writeEndTag];
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
    [propertyList setValue:URL forKey:@"sourceURL"];
}

- (void)awakeFromPropertyList:(id)propertyList;
{
    [super awakeFromPropertyList:propertyList];
    
    // Pull out image data
    NSData *data = [propertyList objectForKey:@"fileContents"];
    if (data)
    {
        NSURLResponse *response = [[NSURLResponse alloc]
                                   initWithURL:[propertyList objectForKey:@"sourceURL"]
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
