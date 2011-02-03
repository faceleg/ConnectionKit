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

#import "KSInspectorViewController.h"


@implementation SVPageThumbnailController

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

- (BOOL)fillTypeIsImage;
{
    return [[self fillType] intValue] >= SVThumbnailTypePickFromPage;
}
+ (NSSet *)keyPathsForValuesAffectingFillTypeIsImage; { return [NSSet setWithObject:@"fillType"]; }

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

@end


