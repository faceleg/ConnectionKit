//
//  SVEditingController.h
//  Sandvox
//
//  Created by Mike on 21/08/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "WebEditingKit.h"


@class SVLink;


@interface SVEditingController : WEKEditingController

#pragma mark Alignment
- (NSTextAlignment)wek_alignment;


#pragma mark Links

- (BOOL)canCreateLink;

- (SVLink *)selectedLink;

- (void)createLink:(SVLink *)link userInterface:(BOOL)userInterface;
- (void)makeSelectedLinksOpenInNewWindow;   // support method, called by above

- (void)updateLinkManager;


#pragma mark Lists
- (BOOL)orderedList;
- (BOOL)unorderedList;

@end
