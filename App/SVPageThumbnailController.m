//
//  SVPageThumbnailController.m
//  Sandvox
//
//  Created by Mike on 11/10/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVPageThumbnailController.h"

#import "SVMediaRecord.h"
#import "SVSiteItem.h"

#import "NSImage+Karelia.h"

#import "KSInspectorViewController.h"


@implementation SVPageThumbnailController

#pragma mark Init

- (id)init;
{
    self = [super init];
    
    _dependenciesTracker = [[KSDependenciesTracker alloc] init];
    [_dependenciesTracker setDelegate:self];
    
    return self;
}

#pragma mark Custom Image

- (BOOL)shouldShowFileChooser;
{
    BOOL result = [super shouldShowFileChooser];
    
    if ([[self fillType] intValue] == 1)    // custom thumbnail
    {
        result = YES;
    }
    
    return result;
}

- (BOOL)setImageFromPasteboardItem:(id <SVPasteboardItem>)item;
{
    NSManagedObjectContext *context = [[oInspectorViewController representedObject] managedObjectContext];
    
    SVMediaRecord *media = [SVMediaRecord mediaByReferencingURL:[item URL]
                                            entityName:@"Thumbnail"
                        insertIntoManagedObjectContext:context
                                                 error:NULL];
    
    [[oInspectorViewController inspectedObjectsController] replaceMedia:media
                                                             forKeyPath:@"selection.customThumbnail"];
    
    return YES;
}

- (BOOL)fillTypeIsCustomImage;
{
    return [[self fillType] intValue] == SVThumbnailTypeCustom;
}
+ (NSSet *)keyPathsForValuesAffectingFillTypeIsCustomImage; { return [NSSet setWithObject:@"fillType"]; }

#pragma mark Image Picker

- (void)updatePickFromPageThumbnail
{
    [_dependenciesTracker removeAllDependencies];
    [[oImagePicker selectedItem] setImage:nil];
    
    SVSiteItem *page = [[oInspectorViewController inspectedObjects] lastObject]; 
    if (page)
    {
        SVPageThumbnailHTMLContext *context = [[SVPageThumbnailHTMLContext alloc] init];
        [context setDelegate:self];
        
        // This will call a delegate methods which will update the UI
        [context writeImageRepresentationOfPage:page width:32 height:32 attributes:nil options:SVImageScaleAspectFit];
        
        [context setDelegate:nil];
        [context release];
    }
}

- (BOOL)fillTypeIsImage;
{
    return [[self fillType] intValue] >= SVThumbnailTypePickFromPage;
}
+ (NSSet *)keyPathsForValuesAffectingFillTypeIsImage; { return [NSSet setWithObject:@"fillType"]; }

- (void)pageThumbnailHTMLContext:(SVPageThumbnailHTMLContext *)context didAddMedia:(SVMedia *)media;
{
    NSImage *result;
    if ([media mediaData])
    {
        result = [[NSImage alloc] initWithData:[media mediaData]];
    }
    else
    {
        result = [[NSImage alloc] initWithThumbnailOfURL:[media mediaURL] maxPixelSize:32];
    }
    
    [[oImagePicker selectedItem] setImage:result];
    [result release];
}

- (void) pageThumbnailHTMLContext:(SVPageThumbnailHTMLContext *)context addDependency:(KSObjectKeyPathPair *)dependency;
{
    [_dependenciesTracker addDependency:dependency];
}

- (void) dependenciesTracker:(KSDependenciesTracker *)tracker didObserveChange:(NSDictionary *)change forDependency:(KSObjectKeyPathPair *)dependency;
{
    [self updatePickFromPageThumbnail];
}

@end


#pragma mark -


@implementation SVFillTypeFromThumbnailType

+ (Class)transformedValueClass; { return [NSNumber class]; }
+ (BOOL)allowsReverseTransformation; { return YES; }

- (id)transformedValue:(id)value;           // by default returns value
{
    if ([value intValue] > SVThumbnailTypePickFromPage) value = [NSNumber numberWithInt:SVThumbnailTypePickFromPage];
    return value;
}

@end


#pragma mark -


@implementation SVPageThumbnailPickerCell

/*  This feels a pretty dirty solution, but it works. By overriding this method rather than calling -setPullsDown: you get what looks like a pull down button (arrow drawing, menu placement), but behaves like a popup.
 */
- (BOOL)pullsDown; { return YES; }

- (void)drawTitleWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{   // don't want to ever see the title
}

@end


