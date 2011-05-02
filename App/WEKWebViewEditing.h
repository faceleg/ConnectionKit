//
//  WEKWebViewEditing.h
//  Sandvox
//
//  Created by Mike on 27/05/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import <WebKit/WebKit.h>


@class SVLink, WEKSelection;


@interface WebView (WEKWebViewEditing)

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


#pragma mark Selection
@property(nonatomic, assign, setter=wek_setSelection) WEKSelection *wek_selection;

@end


#pragma mark -


// DOMRange will modify itself to match the selection, which can be undesireable. This class is properly immutable
@interface WEKSelection : NSObject
{
  @private
    DOMNode *_startContainer;
    int     _startOffset;
    DOMNode *_endContainer;
    int     _endOffset;
    
    NSSelectionAffinity _affinity;
}

- (id)initWithDOMRange:(DOMRange *)range affinity:(NSSelectionAffinity)affinity;

@property(nonatomic, readonly) DOMNode *startContainer;
@property(nonatomic, readonly) int startOffset;
@property(nonatomic, readonly) DOMNode *endContainer;
@property(nonatomic, readonly) int endOffset;
@property(nonatomic, readonly) NSSelectionAffinity affinity;

@end


