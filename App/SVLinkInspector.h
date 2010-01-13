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


@class SVLink;


@interface SVLinkInspector : KSInspectorViewController <KTLinkSourceViewDelegate>
{
    IBOutlet KTLinkSourceView   *oLinkSourceView;
    IBOutlet NSTextField        *oLinkField;
    IBOutlet NSButton           *oOpenInNewWindowCheckbox;
    
  @private
    NSFormatter *_URLFormatter;
}


#pragma mark Link
- (void)setInspectedLink:(SVLink *)link;    // don't call directly, invoked as a side-effect of -[SVLinkManager setSelectedLink:editable:]


#pragma mark UI Actions
- (IBAction)setLinkURL:(id)sender;
- (IBAction)clearLinkDestination:(id)sender;

@end