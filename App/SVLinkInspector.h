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
    NSWindow                *_inspectedWindow;
    DOMHTMLAnchorElement    *_inspectedLink;
    NSObjectController      *_inspectedTextControllerController;
}

@property(nonatomic, retain) NSWindow *inspectedWindow;
@property(nonatomic, readonly) DOMHTMLAnchorElement *inspectedLink;
- (NSObjectController *)inspectedTextControllerController;

- (IBAction)clearLinkDestination:(id)sender;

@end
