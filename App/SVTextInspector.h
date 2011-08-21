//
//  SVTextInspector.h
//  Sandvox
//
//  Created by Mike on 22/07/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "KSInspectorViewController.h"


@interface SVTextInspector : KSInspectorViewController
{
    IBOutlet NSSegmentedControl *oAlignmentSegmentedControl;
    
    IBOutlet NSPopUpButton      *oListPopUp;
    IBOutlet NSView             *oListDetailsView;
    IBOutlet NSTextField        *oIndentLevelField;
    IBOutlet NSSegmentedControl *oIndentLevelSegmentedControl;
    
  @private
}

- (IBAction)changeAlignment:(NSSegmentedControl *)sender;

- (IBAction)changeIndent:(NSSegmentedControl *)sender;


@end
