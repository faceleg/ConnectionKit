//
//  SVBannerPickerController.m
//  Sandvox
//
//  Created by Mike on 23/07/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVBannerPickerController.h"

#import "KTDocument.h"
#import "KTMaster.h"

#import "KSInspectorViewController.h"


@implementation SVBannerPickerController

- (void)dealloc
{
    [_bannerType release];
    
    [super dealloc];
}

#pragma mark Banner Type

@synthesize bannerType = _bannerType;
- (NSNumber *)bannerType;
{
    NSNumber *result = _bannerType;
    
    // Ugly hack, but it works. Pretend design-supplied is selected when design doesn't support it
    if (![self canChooseBannerType])
    {
        result = nil;
    }
    
    return result;
}
+ (NSSet *)keyPathsForValuesAffectingBannerType;
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

- (IBAction)bannerTypeChosen:(NSPopUpButton *)sender;
{
    // Make sure an image is chosen
    if ([[self bannerType] boolValue])
    {
        id banner = [[oInspectorViewController inspectedObjectsController]
                     valueForKeyPath:@"selection.master.banner"];
        
        if (!banner && ![self chooseBanner])
        {
            [self setBannerType:[NSNumber numberWithBool:NO]];
            return;
        }
    }
    
    
    // Push down to model
    NSDictionary *info = [self infoForBinding:@"bannerType"];
    [[info objectForKey:NSObservedObjectKey] setValue:[self bannerType]
                                           forKeyPath:[info objectForKey:NSObservedKeyPathKey]];
}

#pragma mark Custom Banner

- (IBAction)chooseBanner:(id)sender;
{
    [self chooseBanner];
}

- (BOOL)chooseBanner;
{
    KTDocument *document = [oInspectorViewController representedObject];
    NSOpenPanel *panel = [document makeChooseDialog];
 	[panel setAllowedFileTypes:[NSArray arrayWithObject:(NSString *)kUTTypeImage]];
   
    if ([panel runModal] == NSFileHandlingPanelOKButton)
    {
        NSURL *URL = [panel URL];
        
        KTMaster *master = [[oInspectorViewController inspectedObjectsController]
                            valueForKeyPath:@"selection.master"];
        
        [master setBannerWithContentsOfURL:URL];
        
        return YES;
    }
    
    return NO;
}

@end
