//
//  SVLinkInspector.h
//  Sandvox
//
//  Created by Mike on 10/01/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "KSInspectorViewController.h"

#import "SVLink.h"
#import "KTLinkSourceView.h"

#import <WebKit/WebKit.h>


@class KSEmailAddressComboBox;


@interface SVLinkInspector : KSInspectorViewController <KTLinkSourceViewDelegate>
{
    IBOutlet NSPopUpButton      *oLinkTypePopUpButton;
    IBOutlet NSTabView          *oTabView;
    
    IBOutlet KTLinkSourceView       *oLinkSourceView;
    IBOutlet NSTextField            *oLinkField;
    IBOutlet NSButton               *oExternalLinkOpenInNewWindowCheckbox;
    IBOutlet KSEmailAddressComboBox *oEmailAddressField;
    IBOutlet NSButton               *oOpenInNewWindowCheckbox;
    
  @private
}


#pragma mark UI Actions

- (IBAction)selectLinkType:(NSPopUpButton *)sender;

- (IBAction)setLinkURL:(id)sender;
- (IBAction)openInNewWindow:(NSButton *)sender;
- (IBAction)clearLinkDestination:(id)sender;

@end