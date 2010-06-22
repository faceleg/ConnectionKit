//
//  SVWebEditorView.h
//  Sandvox
//
//  Created by Mike on 22/06/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "WEKWebEditorView.h"


@interface SVWebEditorView : WEKWebEditorView

#pragma mark Graphic Placement
// Give delegate a chance to do action, if not beep.
//  HOWEVER. don't think we actually need this! window controller is taking care of it
- (IBAction)placeInline:(id)sender;
- (IBAction)placeAsBlock:(id)sender;
- (IBAction)placeAsCallout:(id)sender;
- (IBAction)placeInSidebar:(id)sender;

@end
