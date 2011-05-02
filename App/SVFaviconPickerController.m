//
//  SVFaviconPickerController.m
//  Sandvox
//
//  Created by Mike on 10/12/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVFaviconPickerController.h"

#import "KTMaster.h"

#import "KSInspectorViewController.h"


@implementation SVFaviconPickerController

- (BOOL)setImageFromPasteboardItem:(id <SVPasteboardItem>)item;
{
    KTMaster *master = [[oInspectorViewController inspectedObjectsController]
                        valueForKeyPath:@"selection.master"];
    
    [master setFaviconWithContentsOfURL:[item URL]];
    
    return YES;
}

- (BOOL)shouldShowFileChooser;
{
    BOOL result = [super shouldShowFileChooser];
    
    if ([[self fillType] intValue] > 0) // -1 is Sandvox castle
    {
        id banner = [[oInspectorViewController inspectedObjectsController]
                     valueForKeyPath:@"selection.master.faviconMedia"];
        result = (banner == nil);
    }
    
    return result;
}

@end
