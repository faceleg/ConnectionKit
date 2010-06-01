//
//  SVWrapInspector.h
//  Sandvox
//
//  Created by Mike on 22/02/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "KSInspectorViewController.h"


@interface SVWrapInspector : KSInspectorViewController
{
    IBOutlet NSMatrix   *oPlacementRadioButtons;
    
    IBOutlet NSButton   *oWrapLeftButton;
    IBOutlet NSButton   *oWrapRightButton;
    IBOutlet NSButton   *oWrapLeftSplitButton;
    IBOutlet NSButton   *oWrapCenterButton;
    IBOutlet NSButton   *oWrapRightSplitButton;
    
  @private
    NSNumber    *_placement;
}

@property(nonatomic, copy) NSNumber *graphicPlacement;  // SVGraphicPlacement, bindable

@end
