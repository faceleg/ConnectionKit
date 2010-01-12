//
//  SVLinkInspector.h
//  Sandvox
//
//  Created by Mike on 10/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "KSInspectorViewController.h"

#import "KTLinkSourceView.h"

#import <WebKit/WebKit.h>


@interface SVLinkInspector : KSInspectorViewController <KTLinkSourceViewDelegate>
{
    IBOutlet KTLinkSourceView   *oLinkSourceView;
    IBOutlet NSTextField        *oLinkField;
    
  @private
    NSFormatter *_URLFormatter;
    
    NSWindow                *_inspectedWindow;
    DOMHTMLAnchorElement    *_inspectedLink;
    NSObjectController      *_inspectedTextControllerController;
    
    NSString *_linkDestination; // weak, temporary ref
}

#pragma mark Other

@property(nonatomic, retain) NSWindow *inspectedWindow;
@property(nonatomic, readonly) DOMHTMLAnchorElement *inspectedLink;
- (NSObjectController *)inspectedTextControllerController;

- (IBAction)setLinkURL:(id)sender;
- (IBAction)clearLinkDestination:(id)sender;

- (NSString *)linkDestinationURLString;

@end


// When changing the URL, this message is sent up the responder chain. A suitable object should handle it by asking the sender for the appropriate link properties. For now, this is best done by sending it a -linkDestinationURLString: method.
@interface NSObject (SVLinkInspectorResponderMethod)
- (void)changeLinkDestination:(SVLinkInspector *)sender;
@end