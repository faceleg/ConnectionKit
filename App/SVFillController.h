//
//  SVFillController.h
//  Sandvox
//
//  Created by Mike on 11/10/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class KSInspectorViewController;


@interface SVFillController : NSObject
{
    IBOutlet KSInspectorViewController  *oInspectorViewController;
    IBOutlet NSPopUpButton              *oPopUpButton;
    
@private
    NSNumber    *_bannerType;
}

@property(nonatomic, copy) NSNumber *fillType;    // bindable
- (IBAction)fillTypeChosen:(NSPopUpButton *)sender;

- (IBAction)chooseFile:(id)sender;
- (BOOL)chooseFile;
- (BOOL)setFileWithURL:(NSURL *)URL;    // subclasses MUST implement

@end
