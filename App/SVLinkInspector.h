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
  @private
    NSWindow                *_inspectedWindow;
    DOMHTMLAnchorElement    *_inspectedLink;
}

@property(nonatomic, retain) NSWindow *inspectedWindow;
@property(nonatomic, retain) DOMHTMLAnchorElement *inspectedLink;

- (IBAction)clearLinkDestination:(id)sender;

@end
