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
}

#pragma mark Other

@property(nonatomic, retain) NSWindow *inspectedWindow;

- (IBAction)setLinkURL:(id)sender;
- (IBAction)clearLinkDestination:(id)sender;

@end