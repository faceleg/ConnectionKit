//
//  SVFillController.h
//  Sandvox
//
//  Created by Mike on 11/10/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "SVPasteboardItem.h"


@class KSInspectorViewController, SVMedia;


@interface SVFillController : NSObject
{
    IBOutlet KSInspectorViewController  *oInspectorViewController;
    IBOutlet NSPopUpButton              *oPopUpButton;
    
@private
    NSNumber    *_bannerType;
    SVMedia     *_imageMedia;
    NSImage     *_image;
}

@property(nonatomic, copy) NSNumber *fillType;    // bindable
- (IBAction)fillTypeChosen:(NSPopUpButton *)sender;
- (BOOL)shouldShowFileChooser;  // Subclasses override to return YES when a file-based fill is chosen


#pragma mark Image Fill

@property(nonatomic, retain) SVMedia *imageMedia;   // bind this to the model
- (IBAction)chooseFile:(id)sender;
- (BOOL)chooseFile;

- (BOOL)setImageFromPasteboardItem:(id <SVPasteboardItem>)item;    // subclasses MUST implement
- (IBAction)imageEdited:(id)sender;
@property(nonatomic, retain, readonly) NSImage *image;  // bind UI to this

@end
