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
    
  @private
    
    NSUInteger  _listStyle;
}

- (IBAction)changeAlignment:(NSSegmentedControl *)sender;

@property(nonatomic) NSUInteger listStyle;

@end
