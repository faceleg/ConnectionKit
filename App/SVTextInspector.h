//
//  SVTextInspector.h
//  Sandvox
//
//  Created by Mike on 22/07/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "KSInspectorViewController.h"


@class SVEditingController;


@interface SVTextInspector : KSInspectorViewController
{
    IBOutlet NSSegmentedControl *oAlignmentSegmentedControl;
    
    IBOutlet NSPopUpButton      *oListPopUp;
    IBOutlet NSSegmentedControl *oIndentLevelSegmentedControl;
    
  @private
    
    SVEditingController   *_editingController;
}

- (IBAction)changeAlignment:(NSSegmentedControl *)sender;

- (IBAction)changeIndent:(NSSegmentedControl *)sender;

@property(nonatomic, retain, readonly) SVEditingController *editingController;


@end
