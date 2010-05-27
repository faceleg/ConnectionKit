//
//  WEKWebViewEditing.h
//  Sandvox
//
//  Created by Mike on 27/05/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import <WebKit/WebKit.h>


@interface WebView (WEKWebViewEditing)

#pragma mark Links

- (BOOL)canCreateLink;
- (BOOL)canUnlink;
- (NSArray *)selectedAnchorElements;
- (NSString *)linkValue;

- (void)createLink:(NSString *)link userInterface:(BOOL)userInterface;
- (IBAction)unlink:(id)sender;


@end

