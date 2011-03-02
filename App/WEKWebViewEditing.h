//
//  WEKWebViewEditing.h
//  Sandvox
//
//  Created by Mike on 27/05/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import <WebKit/WebKit.h>


@class SVLink;


@interface WebView (WEKWebViewEditing)

#pragma mark Links

- (BOOL)canCreateLink;
- (BOOL)canUnlink;

- (SVLink *)selectedLink;
- (NSArray *)selectedAnchorElements;
- (NSString *)linkValue;

- (void)createLink:(SVLink *)link userInterface:(BOOL)userInterface;
- (IBAction)unlink:(id)sender;
- (IBAction)selectLink:(id)sender;


@end

