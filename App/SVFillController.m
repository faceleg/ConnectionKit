//
//  SVFillController.m
//  Sandvox
//
//  Created by Mike on 11/10/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVFillController.h"

#import "KTDocument.h"


@implementation SVFillController

- (void)dealloc
{
    [_bannerType release];
    
    [super dealloc];
}

@synthesize fillType = _bannerType;

- (IBAction)fillTypeChosen:(NSPopUpButton *)sender;
{
    // Make sure an image is chosen
    if ([self shouldShowFileChooser])
    {
        if (![self chooseFile])
        {
            // Reset fill type
            [self setFillType:[NSNumber numberWithBool:NO]];
            return;
        }
    }
    
    
    // Push down to model
    NSDictionary *info = [self infoForBinding:@"fillType"];
    [[info objectForKey:NSObservedObjectKey] setValue:[self fillType]
                                           forKeyPath:[info objectForKey:NSObservedKeyPathKey]];
}

- (BOOL)shouldShowFileChooser; { return NO; }

#pragma mark Custom Banner

- (IBAction)chooseFile:(id)sender;
{
    [self chooseFile];
}

- (BOOL)chooseFile;
{
    KTDocument *document = [oInspectorViewController representedObject];
    NSOpenPanel *panel = [document makeChooseDialog];
 	[panel setAllowedFileTypes:[NSArray arrayWithObject:(NSString *)kUTTypeImage]];
    
    if ([panel runModalForTypes:[panel allowedFileTypes]] == NSFileHandlingPanelOKButton)
    {
        NSURL *URL = [panel URL];
        return [self setFileWithURL:URL];
    }
    
    return NO;
}

- (BOOL)setFileWithURL:(NSURL *)URL; { return NO; }

@end
