//
//  SVBannerPickerController.m
//  Sandvox
//
//  Created by Mike on 23/07/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVBannerPickerController.h"

#import "KTMaster.h"

#import "KSInspectorViewController.h"


@implementation SVBannerPickerController

- (void)dealloc;
{
    [self unbind:@"canChooseBannerType"];
    
    [super dealloc];
}

#pragma mark Banner Type

- (NSNumber *)fillType;
{
    NSNumber *result = [super fillType];
    
    // Ugly hack, but it works. Pretend design-supplied is selected when design doesn't support it
    if (![self canChooseBannerType])
    {
        result = nil;
    }
    
    return result;
}
+ (NSSet *)keyPathsForValuesAffectingFillType;
{
    return [NSSet setWithObject:@"canChooseBannerType"];
}

@synthesize canChooseBannerType = _canChooseBannerType;
- (void)setNilValueForKey:(NSString *)key;
{
    if ([key isEqualToString:@"canChooseBannerType"])
    {
        [self setCanChooseBannerType:NO];
    }
    else
    {
        [super setNilValueForKey:key];
    }
}

- (BOOL)shouldShowFileChooser;
{
    BOOL result = [super shouldShowFileChooser];
    
    if ([[self fillType] boolValue])
    {
        id banner = [[oInspectorViewController inspectedObjectsController]
                     valueForKeyPath:@"selection.master.banner"];
        result = (banner == nil);
    }
        
    return result;
}

- (BOOL)setImageFromPasteboardItem:(id <SVPasteboardItem>)item;
{
    NSURL *URL = [item URL];
    if (!URL) return NO;
    
    KTMaster *master = [[oInspectorViewController inspectedObjectsController]
                        valueForKeyPath:@"selection.master"];
    
    [master setBannerWithContentsOfURL:URL];
    
    return YES;
}

@end
