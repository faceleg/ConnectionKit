//
//  SVWebViewSelectionController.h
//  Sandvox
//
//  Created by Mike on 21/08/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class SVLink;


@interface SVWebViewSelectionController : NSResponder <NSUserInterfaceValidations>
{
  @private
    WebView     *_webView;
    DOMRange    *_selection;
}


- (id)initWithWebView:(WebView *)webView;


#pragma mark Strikethrough
- (IBAction)strikethrough:(id)sender;   // oddly, WebKit doesn't supply this command


#pragma mark Lists

// 0 for non-lists, 1+ for lists, NSMultipleValuesMarker for mixtures
@property(nonatomic, copy) NSNumber *listIndentLevel;
@property(nonatomic, readonly) NSNumber *shallowestListIndentLevel;
@property(nonatomic, readonly) NSNumber *deepestListIndentLevel;
- (NSUInteger)listIndentLevelForDOMNode:(DOMNode *)node;

@property(nonatomic, copy, readonly) NSNumber *listTypeTag;
- (NSNumber *)isOrderedList;
- (NSUInteger)listTypeTagForDOMNode:(DOMNode *)node;

@property(nonatomic, retain) DOMRange *selection;

- (void)insertIntoResponderChainAfterWebView:(WebView *)webView;


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
