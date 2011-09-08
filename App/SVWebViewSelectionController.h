//
//  SVWebViewSelectionController.h
//  Sandvox
//
//  Created by Mike on 21/08/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "WEKEditingController.h"


@class SVLink;


@interface SVWebViewSelectionController : WEKEditingController



#pragma mark Links

- (BOOL)canCreateLink;
- (BOOL)canUnlink;

- (SVLink *)selectedLink;
- (NSArray *)selectedAnchorElements;
- (NSString *)linkValue;

- (void)createLink:(SVLink *)link userInterface:(BOOL)userInterface;
- (void)makeSelectedLinksOpenInNewWindow;   // support method, called by above
- (IBAction)unlink:(id)sender;
- (IBAction)selectLink:(id)sender;


@end
